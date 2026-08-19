from __future__ import annotations

import hashlib
import secrets
from datetime import UTC, date, datetime, timedelta
from uuid import UUID

from sqlalchemy.exc import IntegrityError

from app.modules.auth.domain import UserRole
from app.modules.auth.models import User
from app.modules.hospital_coordination.domain import CoordinationStatus, StockStatus
from app.modules.hospital_coordination.models import HospitalAvailability
from app.modules.hospital_coordination.repository import SqlAlchemyHospitalCoordinationRepository
from app.modules.hospital_coordination.schemas import AvailabilityView
from app.modules.hospital_coordination.service import HospitalCoordinationService
from app.modules.hospital_dashboard.domain import (
    ClaimStatus,
    DashboardConflict,
    DashboardPermissionDenied,
    DashboardRecordNotFound,
    DepletionStatus,
    InvalidDashboardRequest,
    InvalidInventoryToken,
    InventoryBoxStatus,
)
from app.modules.hospital_dashboard.models import (
    AntivenomBox,
    AntivenomDepletionRequest,
    HospitalAuditEvent,
    HospitalClaimRequest,
)
from app.modules.hospital_dashboard.repository import SqlAlchemyHospitalDashboardRepository
from app.modules.hospital_dashboard.schemas import (
    AntivenomBoxCreate,
    AntivenomBoxCreated,
    AntivenomBoxView,
    AvailabilityPublish,
    ClaimCreate,
    ClaimView,
    DashboardInbox,
    DecisionInput,
    DepletionRequestView,
    DepletionScanCreate,
    InboxDecision,
)


class HospitalDashboardService:
    def __init__(
        self,
        repository: SqlAlchemyHospitalDashboardRepository,
        coordination_repository: SqlAlchemyHospitalCoordinationRepository,
    ) -> None:
        self.repository = repository
        self.coordination_repository = coordination_repository

    async def submit_claim(self, actor: User, payload: ClaimCreate) -> ClaimView:
        self._require_role(actor, UserRole.HOSPITAL_ADMIN)
        facility = await self.repository.facility(payload.facility_id)
        if facility is None:
            raise DashboardRecordNotFound
        if facility.managed_by_user_id is not None:
            raise DashboardConflict
        if await self.repository.pending_claim_for_facility(facility.id) is not None:
            raise DashboardConflict
        claim = HospitalClaimRequest(
            facility_id=facility.id,
            requester_user_id=actor.id,
            verification_method=payload.verification_method.strip().lower(),
            evidence_reference=payload.evidence_reference.strip(),
            status=ClaimStatus.PENDING.value,
            reviewer_user_id=None,
            review_note=None,
            reviewed_at=None,
        )
        self.repository.add(claim)
        try:
            await self.repository.commit()
        except IntegrityError as exc:
            await self.repository.rollback()
            raise DashboardConflict from exc
        await self.repository.refresh(claim)
        return await self._claim_view(claim)

    async def claims_for_actor(self, actor: User) -> list[ClaimView]:
        self._require_role(actor, UserRole.HOSPITAL_ADMIN)
        return [
            await self._claim_view(value)
            for value in await self.repository.claims_for_user(actor.id)
        ]

    async def pending_claims(self, actor: User) -> list[ClaimView]:
        self._require_role(actor, UserRole.GOVERNMENT_ADMIN)
        return [await self._claim_view(value) for value in await self.repository.pending_claims()]

    async def decide_claim(self, actor: User, claim_id: UUID, payload: DecisionInput) -> ClaimView:
        self._require_role(actor, UserRole.GOVERNMENT_ADMIN)
        claim = await self.repository.claim(claim_id, lock=True)
        if claim is None:
            raise DashboardRecordNotFound
        if claim.status != ClaimStatus.PENDING.value:
            raise DashboardConflict
        facility = await self.repository.facility(claim.facility_id, lock=True)
        if facility is None:
            raise DashboardRecordNotFound
        if payload.approve and facility.managed_by_user_id is not None:
            raise DashboardConflict
        now = datetime.now(UTC)
        claim.status = ClaimStatus.APPROVED.value if payload.approve else ClaimStatus.REJECTED.value
        claim.reviewer_user_id = actor.id
        claim.review_note = self._clean(payload.note)
        claim.reviewed_at = now
        if payload.approve:
            facility.managed_by_user_id = claim.requester_user_id
        self.repository.add(
            HospitalAuditEvent(
                facility_id=facility.id,
                actor_user_id=actor.id,
                event_type="facility_claim_approved"
                if payload.approve
                else "facility_claim_rejected",
                entity_id=claim.id,
                details={"verification_method": claim.verification_method},
                note=claim.review_note,
            )
        )
        await self.repository.commit()
        await self.repository.refresh(claim)
        return await self._claim_view(claim)

    async def dashboard(self, actor: User) -> DashboardInbox:
        facility = await self._managed_facility(actor)
        capability = await self.coordination_repository.capability(facility.id)
        if capability is None:
            raise DashboardRecordNotFound
        availability = await self.coordination_repository.latest_availability(facility.id)
        alerts = await self.repository.pre_alerts(facility.id)
        resources = await self.repository.resource_requests(facility.id)
        return DashboardInbox(
            facility=HospitalCoordinationService._facility_view(facility, capability, availability),
            availability=(AvailabilityView.model_validate(availability) if availability else None),
            pre_alerts=[self._pre_alert_dict(value) for value in alerts],
            resource_requests=[self._resource_dict(value) for value in resources],
            boxes=[
                AntivenomBoxView.model_validate(value)
                for value in await self.repository.boxes(facility.id)
            ],
            depletion_requests=[
                DepletionRequestView.model_validate(value)
                for value in await self.repository.depletion_requests(facility.id)
            ],
        )

    async def decide_pre_alert(
        self, actor: User, alert_id: UUID, payload: InboxDecision
    ) -> dict[str, object]:
        facility = await self._managed_facility(actor)
        alert = await self.repository.pre_alert(alert_id, lock=True)
        if alert is None or alert.hospital_id != facility.id:
            raise DashboardRecordNotFound
        if alert.status != CoordinationStatus.PENDING.value:
            raise DashboardConflict
        if self._as_utc(alert.expires_at) <= datetime.now(UTC):
            alert.status = CoordinationStatus.EXPIRED.value
            await self.repository.commit()
            raise DashboardConflict
        alert.status = payload.status
        alert.response_note = self._clean(payload.note)
        alert.responded_by_user_id = actor.id
        alert.responded_at = datetime.now(UTC)
        self._audit(facility.id, actor.id, f"pre_alert_{payload.status}", alert.id, payload.note)
        await self.repository.commit()
        return self._pre_alert_dict(alert)

    async def decide_resource_request(
        self, actor: User, request_id: UUID, payload: InboxDecision
    ) -> dict[str, object]:
        facility = await self._managed_facility(actor)
        request = await self.repository.resource_request(request_id, lock=True)
        if request is None or request.hospital_id != facility.id:
            raise DashboardRecordNotFound
        if request.status != CoordinationStatus.PENDING.value:
            raise DashboardConflict
        if self._as_utc(request.expires_at) <= datetime.now(UTC):
            request.status = CoordinationStatus.EXPIRED.value
            await self.repository.commit()
            raise DashboardConflict
        request.status = payload.status
        request.response_note = self._clean(payload.note)
        request.responded_by_user_id = actor.id
        request.responded_at = datetime.now(UTC)
        self._audit(
            facility.id, actor.id, f"resource_request_{payload.status}", request.id, payload.note
        )
        await self.repository.commit()
        return self._resource_dict(request)

    async def publish_availability(
        self, actor: User, payload: AvailabilityPublish
    ) -> AvailabilityView:
        facility = await self._managed_facility(actor)
        snapshot = await self._append_inventory_snapshot(
            facility.id,
            expires_in_minutes=payload.expires_in_minutes,
            emergency_beds=payload.emergency_beds,
            icu_beds=payload.icu_beds,
            ventilators=payload.ventilators,
            preserve_existing=False,
        )
        self._audit(facility.id, actor.id, "availability_published", snapshot.id, None)
        await self.repository.commit()
        await self.repository.refresh(snapshot)
        return AvailabilityView.model_validate(snapshot)

    async def register_box(self, actor: User, payload: AntivenomBoxCreate) -> AntivenomBoxCreated:
        facility = await self._managed_facility(actor)
        if payload.expiry_date < date.today():
            raise InvalidDashboardRequest
        token = secrets.token_urlsafe(32)
        box = AntivenomBox(
            facility_id=facility.id,
            created_by_user_id=actor.id,
            box_serial=payload.box_serial.strip(),
            product_name=payload.product_name.strip(),
            manufacturer=payload.manufacturer.strip(),
            batch_number=payload.batch_number.strip(),
            expiry_date=payload.expiry_date,
            initial_vials=payload.initial_vials,
            available_vials=payload.initial_vials,
            status=InventoryBoxStatus.ACTIVE.value,
            qr_token_hash=self.hash_token(token),
            depleted_at=None,
        )
        self.repository.add(box)
        try:
            await self.repository.flush()
            await self._append_inventory_snapshot(facility.id, preserve_existing=True)
            self._audit(
                facility.id,
                actor.id,
                "antivenom_box_registered",
                box.id,
                f"batch={box.batch_number}; serial={box.box_serial}",
            )
            await self.repository.commit()
        except IntegrityError as exc:
            await self.repository.rollback()
            raise DashboardConflict from exc
        await self.repository.refresh(box)
        return AntivenomBoxCreated(
            **AntivenomBoxView.model_validate(box).model_dump(),
            qr_token=token,
            qr_notice=(
                "SnakeCare workflow code only. Keep the manufacturer's GS1 DataMatrix and "
                "label; scanning creates a pending change and never decrements stock directly."
            ),
        )

    async def scan_box(
        self, actor: User, payload: DepletionScanCreate
    ) -> AntivenomDepletionRequest:
        self._require_role(actor, UserRole.HOSPITAL_ADMIN)
        box = await self.repository.box_by_hash(self.hash_token(payload.qr_token), lock=True)
        if box is None or box.status != InventoryBoxStatus.ACTIVE.value:
            raise InvalidInventoryToken
        facility = await self._managed_facility(actor)
        if box.facility_id != facility.id:
            raise DashboardPermissionDenied
        if box.expiry_date < date.today() or box.available_vials <= 0:
            raise InvalidInventoryToken
        if await self.repository.pending_depletion(box.id) is not None:
            raise DashboardConflict
        used = payload.used_vials or box.available_vials
        if used > box.available_vials:
            raise InvalidDashboardRequest
        request = AntivenomDepletionRequest(
            box_id=box.id,
            facility_id=facility.id,
            scanned_by_user_id=actor.id,
            requested_used_vials=used,
            status=DepletionStatus.PENDING.value,
            reviewer_user_id=None,
            review_note=None,
            reviewed_at=None,
        )
        self.repository.add(request)
        try:
            await self.repository.flush()
            self._audit(
                facility.id,
                actor.id,
                "antivenom_depletion_scanned",
                request.id,
                None,
            )
            await self.repository.commit()
        except IntegrityError as exc:
            await self.repository.rollback()
            raise DashboardConflict from exc
        await self.repository.refresh(request)
        return request

    async def decide_depletion(
        self, actor: User, request_id: UUID, payload: DecisionInput
    ) -> AntivenomDepletionRequest:
        facility = await self._managed_facility(actor)
        request = await self.repository.depletion_request(request_id, lock=True)
        if request is None or request.facility_id != facility.id:
            raise DashboardRecordNotFound
        if request.status != DepletionStatus.PENDING.value:
            raise DashboardConflict
        box = await self.repository.box(request.box_id, lock=True)
        if box is None or box.facility_id != facility.id:
            raise DashboardRecordNotFound
        if payload.approve and (
            box.status != InventoryBoxStatus.ACTIVE.value
            or request.requested_used_vials > box.available_vials
        ):
            raise DashboardConflict
        now = datetime.now(UTC)
        request.status = (
            DepletionStatus.APPROVED.value if payload.approve else DepletionStatus.REJECTED.value
        )
        request.reviewer_user_id = actor.id
        request.review_note = self._clean(payload.note)
        request.reviewed_at = now
        if payload.approve:
            box.available_vials -= request.requested_used_vials
            if box.available_vials == 0:
                box.status = InventoryBoxStatus.DEPLETED.value
                box.depleted_at = now
            await self.repository.flush()
            await self._append_inventory_snapshot(facility.id, preserve_existing=True)
        self._audit(
            facility.id,
            actor.id,
            "antivenom_depletion_approved" if payload.approve else "antivenom_depletion_rejected",
            request.id,
            request.review_note,
        )
        await self.repository.commit()
        await self.repository.refresh(request)
        return request

    async def _managed_facility(self, actor: User):  # type: ignore[no-untyped-def]
        self._require_role(actor, UserRole.HOSPITAL_ADMIN)
        facility = await self.repository.managed_facility(actor.id)
        if facility is None:
            raise DashboardPermissionDenied
        return facility

    async def _claim_view(self, claim: HospitalClaimRequest) -> ClaimView:
        facility = await self.repository.facility(claim.facility_id)
        requester = await self.repository.user(claim.requester_user_id)
        if facility is None:
            raise DashboardRecordNotFound
        return ClaimView.model_validate(claim).model_copy(
            update={
                "facility_name": facility.name,
                "requester_email": requester.email if requester else None,
            }
        )

    async def _append_inventory_snapshot(
        self,
        facility_id: UUID,
        *,
        expires_in_minutes: int = 30,
        emergency_beds: int | None = None,
        icu_beds: int | None = None,
        ventilators: int | None = None,
        preserve_existing: bool,
    ) -> HospitalAvailability:
        vials = await self.repository.active_vials(facility_id, date.today())
        latest = (
            await self.coordination_repository.latest_availability(facility_id)
            if preserve_existing
            else None
        )
        now = datetime.now(UTC)
        snapshot = HospitalAvailability(
            hospital_id=facility_id,
            antivenom_status=(
                StockStatus.OUT_OF_STOCK.value
                if vials == 0
                else StockStatus.LOW.value
                if vials <= 5
                else StockStatus.AVAILABLE.value
            ),
            antivenom_vials=vials,
            emergency_beds=(latest.emergency_beds if latest else emergency_beds),
            icu_beds=(latest.icu_beds if latest else icu_beds),
            ventilators=(latest.ventilators if latest else ventilators),
            data_source="hospital_reported",
            recorded_at=now,
            expires_at=now + timedelta(minutes=expires_in_minutes),
        )
        self.repository.add(snapshot)
        await self.repository.flush()
        return snapshot

    def _audit(
        self,
        facility_id: UUID,
        actor_id: UUID,
        event_type: str,
        entity_id: UUID | None,
        note: str | None,
    ) -> None:
        self.repository.add(
            HospitalAuditEvent(
                facility_id=facility_id,
                actor_user_id=actor_id,
                event_type=event_type,
                entity_id=entity_id,
                details={},
                note=self._clean(note),
            )
        )

    @staticmethod
    def hash_token(token: str) -> str:
        return hashlib.sha256(token.encode("utf-8")).hexdigest()

    @staticmethod
    def _require_role(actor: User, role: UserRole) -> None:
        if actor.role != role.value:
            raise DashboardPermissionDenied

    @staticmethod
    def _clean(value: str | None) -> str | None:
        return value.strip() or None if value is not None else None

    @staticmethod
    def _as_utc(value: datetime) -> datetime:
        return value.replace(tzinfo=UTC) if value.tzinfo is None else value.astimezone(UTC)

    @staticmethod
    def _pre_alert_dict(value) -> dict[str, object]:  # type: ignore[no-untyped-def]
        return {
            "id": str(value.id),
            "emergency_id": str(value.emergency_id),
            "hospital_id": str(value.hospital_id),
            "shared_payload": value.shared_payload,
            "status": value.status,
            "expires_at": value.expires_at.isoformat(),
            "response_note": value.response_note,
            "created_at": value.created_at.isoformat(),
        }

    @staticmethod
    def _resource_dict(value) -> dict[str, object]:  # type: ignore[no-untyped-def]
        return {
            "id": str(value.id),
            "pre_alert_id": str(value.pre_alert_id),
            "hospital_id": str(value.hospital_id),
            "antivenom_readiness": value.antivenom_readiness,
            "emergency_bed": value.emergency_bed,
            "icu_readiness": value.icu_readiness,
            "ventilator_readiness": value.ventilator_readiness,
            "status": value.status,
            "expires_at": value.expires_at.isoformat(),
            "response_note": value.response_note,
            "created_at": value.created_at.isoformat(),
        }
