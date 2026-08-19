from __future__ import annotations

from datetime import UTC, datetime, timedelta
from uuid import UUID

from app.modules.auth.domain import PermissionDeniedError, UserRole
from app.modules.auth.models import User
from app.modules.hospital_coordination.domain import (
    CoordinationStatus,
    EmergencyNotEligible,
    FacilityNotFound,
    PreAlertNotFound,
)
from app.modules.hospital_coordination.engine import (
    RECOMMENDATION_NOTICE,
    RULESET_VERSION,
    HospitalRecommendationEngine,
)
from app.modules.hospital_coordination.models import (
    HospitalAvailability,
    HospitalCapability,
    HospitalFacility,
    HospitalPreAlert,
    HospitalRecommendation,
    HospitalResourceRequest,
)
from app.modules.hospital_coordination.repository import (
    SqlAlchemyHospitalCoordinationRepository,
)
from app.modules.hospital_coordination.schemas import (
    AvailabilityCreate,
    AvailabilityView,
    CapabilityView,
    FacilityCreate,
    FacilityDirectoryResponse,
    FacilityView,
    PreAlertCreate,
    RecommendationCreate,
    RecommendationResponse,
    RecommendationView,
    ResourceRequestCreate,
)
from app.modules.snakebite_emergency.repository import (
    SqlAlchemySnakebiteEmergencyRepository,
)


class HospitalCoordinationService:
    def __init__(
        self,
        repository: SqlAlchemyHospitalCoordinationRepository,
        emergency_repository: SqlAlchemySnakebiteEmergencyRepository,
        engine: HospitalRecommendationEngine,
    ) -> None:
        self.repository = repository
        self.emergency_repository = emergency_repository
        self.engine = engine

    async def create_facility(self, actor: User, payload: FacilityCreate) -> FacilityView:
        self._require_admin(actor)
        facility = HospitalFacility(
            hfr_id=payload.hfr_id,
            managed_by_user_id=(actor.id if actor.role == UserRole.HOSPITAL_ADMIN.value else None),
            name=payload.name.strip(),
            address=payload.address.strip(),
            city=self._clean(payload.city),
            state=self._clean(payload.state),
            latitude=payload.latitude,
            longitude=payload.longitude,
            emergency_phone=self._clean(payload.emergency_phone),
            directions_url=str(payload.directions_url) if payload.directions_url else None,
            data_source=payload.data_source.value,
            source_updated_at=payload.source_updated_at,
            is_active=True,
        )
        self.repository.add(facility)
        await self.repository.flush()
        capability = HospitalCapability(
            hospital_id=facility.id,
            emergency_24x7=payload.capabilities.emergency_24x7,
            snakebite_trained_staff=payload.capabilities.snakebite_trained_staff,
            can_administer_antivenom=payload.capabilities.can_administer_antivenom,
            icu=payload.capabilities.icu,
            ventilator=payload.capabilities.ventilator,
            dialysis=payload.capabilities.dialysis,
            blood_bank=payload.capabilities.blood_bank,
            data_source=payload.capabilities.data_source.value,
            verified_at=payload.capabilities.verified_at,
        )
        self.repository.add(capability)
        await self.repository.commit()
        await self.repository.refresh(facility)
        await self.repository.refresh(capability)
        return self._facility_view(facility, capability, None)

    async def facility_directory(
        self, *, city: str, search: str | None, limit: int, offset: int
    ) -> FacilityDirectoryResponse:
        total, entries = await self.repository.facility_directory(
            city=city, search=self._clean(search), limit=limit, offset=offset
        )
        return FacilityDirectoryResponse(
            items=[
                self._facility_view(facility, capability, availability)
                for facility, capability, availability in entries
            ],
            total=total,
            source_attribution="OpenStreetMap contributors, ODbL 1.0",
            notice=(
                "Imported map records identify possible facilities only. "
                "They do not verify emergency services, antivenom, beds, or admission."
            ),
        )

    async def record_availability(
        self, actor: User, hospital_id: UUID, payload: AvailabilityCreate
    ) -> AvailabilityView:
        self._require_admin(actor)
        facility = await self.repository.facility(hospital_id)
        if facility is None:
            raise FacilityNotFound
        self._require_facility_publisher(actor, facility)
        snapshot = HospitalAvailability(
            hospital_id=hospital_id,
            antivenom_status=payload.antivenom_status.value,
            antivenom_vials=payload.antivenom_vials,
            emergency_beds=payload.emergency_beds,
            icu_beds=payload.icu_beds,
            ventilators=payload.ventilators,
            data_source=payload.data_source.value,
            recorded_at=payload.recorded_at,
            expires_at=payload.expires_at,
        )
        self.repository.add(snapshot)
        await self.repository.commit()
        await self.repository.refresh(snapshot)
        return AvailabilityView.model_validate(snapshot)

    async def recommend(self, actor: User, payload: RecommendationCreate) -> RecommendationResponse:
        emergency = await self.emergency_repository.get_owned(payload.emergency_id, actor.id)
        if emergency is None:
            raise EmergencyNotEligible
        latitude = payload.latitude if payload.latitude is not None else emergency.latitude
        longitude = payload.longitude if payload.longitude is not None else emergency.longitude
        if latitude is None or longitude is None:
            from app.modules.hospital_coordination.domain import InvalidCoordinationRequest

            raise InvalidCoordinationRequest
        ranked = self.engine.rank(
            await self.repository.facilities_with_status(),
            latitude=latitude,
            longitude=longitude,
            urgency=emergency.urgency,
            max_distance_km=payload.max_distance_km,
        )[: payload.limit]
        items: list[RecommendationView] = []
        for rank, item in enumerate(ranked, start=1):
            recommendation = HospitalRecommendation(
                owner_user_id=actor.id,
                emergency_id=emergency.id,
                hospital_id=item.facility.id,
                rank=rank,
                distance_km=item.distance_km,
                score=item.score,
                score_components=item.score_components,
                reasons=item.reasons,
                warnings=item.warnings,
                ruleset_version=RULESET_VERSION,
                availability_recorded_at=(
                    item.availability.recorded_at if item.availability else None
                ),
            )
            self.repository.add(recommendation)
            items.append(
                RecommendationView(
                    hospital=self._facility_view(item.facility, item.capability, item.availability),
                    rank=rank,
                    distance_km=item.distance_km,
                    score=item.score,
                    score_components=item.score_components,
                    reasons=item.reasons,
                    warnings=item.warnings,
                    ruleset_version=RULESET_VERSION,
                )
            )
        await self.repository.commit()
        return RecommendationResponse(
            items=items,
            generated_at=datetime.now(UTC),
            notice=RECOMMENDATION_NOTICE,
        )

    async def create_pre_alert(self, actor: User, payload: PreAlertCreate) -> HospitalPreAlert:
        emergency = await self.emergency_repository.get_owned(payload.emergency_id, actor.id)
        if emergency is None:
            raise EmergencyNotEligible
        if await self.repository.facility(payload.hospital_id) is None:
            raise FacilityNotFound
        shared: dict[str, object] = {"urgency": emergency.urgency}
        if payload.share_symptoms:
            shared["symptoms"] = emergency.symptoms
            shared["explanation"] = emergency.explanation
        if payload.share_vitals:
            shared["vitals"] = {
                "pulse_bpm": emergency.pulse_bpm,
                "respiratory_rate": emergency.respiratory_rate,
                "oxygen_saturation": emergency.oxygen_saturation,
                "systolic_bp": emergency.systolic_bp,
                "diastolic_bp": emergency.diastolic_bp,
                "consciousness": emergency.consciousness,
            }
        if payload.share_location:
            shared["location"] = {
                "latitude": emergency.latitude,
                "longitude": emergency.longitude,
                "accuracy_m": emergency.location_accuracy_m,
            }
        if payload.share_notes:
            shared["notes"] = emergency.symptom_notes
        alert = HospitalPreAlert(
            owner_user_id=actor.id,
            emergency_id=emergency.id,
            hospital_id=payload.hospital_id,
            shared_payload=shared,
            status=CoordinationStatus.PENDING.value,
            expires_at=datetime.now(UTC) + timedelta(minutes=30),
            notice=(
                "Pre-alert sent to the coordination inbox. It is not an acceptance and "
                "must not delay transport or an emergency call."
            ),
            response_note=None,
            responded_by_user_id=None,
            responded_at=None,
        )
        self.repository.add(alert)
        await self.repository.commit()
        await self.repository.refresh(alert)
        return alert

    async def create_resource_request(
        self, actor: User, payload: ResourceRequestCreate
    ) -> HospitalResourceRequest:
        alert = await self.repository.owned_pre_alert(payload.pre_alert_id, actor.id)
        if alert is None:
            raise PreAlertNotFound
        request = HospitalResourceRequest(
            owner_user_id=actor.id,
            pre_alert_id=alert.id,
            hospital_id=alert.hospital_id,
            antivenom_readiness=payload.antivenom_readiness,
            emergency_bed=payload.emergency_bed,
            icu_readiness=payload.icu_readiness,
            ventilator_readiness=payload.ventilator_readiness,
            status=CoordinationStatus.PENDING.value,
            expires_at=min(
                self.engine.as_utc(alert.expires_at),
                datetime.now(UTC) + timedelta(minutes=20),
            ),
            response_note=None,
            responded_by_user_id=None,
            responded_at=None,
        )
        self.repository.add(request)
        await self.repository.commit()
        await self.repository.refresh(request)
        return request

    async def list_pre_alerts(self, actor: User) -> list[HospitalPreAlert]:
        return await self.repository.list_pre_alerts(actor.id)

    async def list_resource_requests(self, actor: User) -> list[HospitalResourceRequest]:
        return await self.repository.list_resource_requests(actor.id)

    @staticmethod
    def _facility_view(
        facility: HospitalFacility,
        capability: HospitalCapability,
        availability: HospitalAvailability | None,
    ) -> FacilityView:
        return FacilityView(
            **{
                key: getattr(facility, key)
                for key in (
                    "id",
                    "hfr_id",
                    "managed_by_user_id",
                    "name",
                    "address",
                    "city",
                    "state",
                    "latitude",
                    "longitude",
                    "emergency_phone",
                    "directions_url",
                    "data_source",
                    "source_updated_at",
                    "is_active",
                )
            },
            capabilities=CapabilityView.model_validate(capability),
            availability=(AvailabilityView.model_validate(availability) if availability else None),
        )

    @staticmethod
    def _require_admin(actor: User) -> None:
        if actor.role not in {
            UserRole.GOVERNMENT_ADMIN.value,
            UserRole.HOSPITAL_ADMIN.value,
        }:
            raise PermissionDeniedError

    @staticmethod
    def _require_facility_publisher(actor: User, facility: HospitalFacility) -> None:
        if actor.role == UserRole.GOVERNMENT_ADMIN.value:
            return
        if actor.role == UserRole.HOSPITAL_ADMIN.value and facility.managed_by_user_id == actor.id:
            return
        raise PermissionDeniedError

    @staticmethod
    def _clean(value: str | None) -> str | None:
        return value.strip() or None if value is not None else None
