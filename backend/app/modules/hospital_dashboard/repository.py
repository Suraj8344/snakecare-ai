from __future__ import annotations

from datetime import date
from typing import cast
from uuid import UUID

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.auth.models import User
from app.modules.hospital_coordination.models import (
    HospitalFacility,
    HospitalPreAlert,
    HospitalResourceRequest,
)
from app.modules.hospital_dashboard.domain import (
    ClaimStatus,
    DepletionStatus,
    InventoryBoxStatus,
)
from app.modules.hospital_dashboard.models import (
    AntivenomBox,
    AntivenomDepletionRequest,
    HospitalClaimRequest,
)


class SqlAlchemyHospitalDashboardRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    def add(self, value: object) -> None:
        self.session.add(value)

    async def flush(self) -> None:
        await self.session.flush()

    async def commit(self) -> None:
        await self.session.commit()

    async def refresh(self, value: object) -> None:
        await self.session.refresh(value)

    async def rollback(self) -> None:
        await self.session.rollback()

    async def facility(self, facility_id: UUID, *, lock: bool = False) -> HospitalFacility | None:
        query = select(HospitalFacility).where(
            HospitalFacility.id == facility_id,
            HospitalFacility.is_active.is_(True),
        )
        if lock:
            query = query.with_for_update()
        return cast(HospitalFacility | None, await self.session.scalar(query))

    async def managed_facility(self, user_id: UUID) -> HospitalFacility | None:
        return cast(
            HospitalFacility | None,
            await self.session.scalar(
                select(HospitalFacility)
                .where(
                    HospitalFacility.managed_by_user_id == user_id,
                    HospitalFacility.is_active.is_(True),
                )
                .order_by(HospitalFacility.name)
                .limit(1)
            ),
        )

    async def user(self, user_id: UUID) -> User | None:
        return cast(
            User | None,
            await self.session.scalar(select(User).where(User.id == user_id)),
        )

    async def pending_claim_for_facility(self, facility_id: UUID) -> HospitalClaimRequest | None:
        return cast(
            HospitalClaimRequest | None,
            await self.session.scalar(
                select(HospitalClaimRequest).where(
                    HospitalClaimRequest.facility_id == facility_id,
                    HospitalClaimRequest.status == ClaimStatus.PENDING.value,
                )
            ),
        )

    async def claims_for_user(self, user_id: UUID) -> list[HospitalClaimRequest]:
        return list(
            await self.session.scalars(
                select(HospitalClaimRequest)
                .where(HospitalClaimRequest.requester_user_id == user_id)
                .order_by(HospitalClaimRequest.created_at.desc())
            )
        )

    async def pending_claims(self) -> list[HospitalClaimRequest]:
        return list(
            await self.session.scalars(
                select(HospitalClaimRequest)
                .where(HospitalClaimRequest.status == ClaimStatus.PENDING.value)
                .order_by(HospitalClaimRequest.created_at)
            )
        )

    async def claim(self, claim_id: UUID, *, lock: bool = False) -> HospitalClaimRequest | None:
        query = select(HospitalClaimRequest).where(HospitalClaimRequest.id == claim_id)
        if lock:
            query = query.with_for_update()
        return cast(HospitalClaimRequest | None, await self.session.scalar(query))

    async def pre_alerts(self, facility_id: UUID) -> list[HospitalPreAlert]:
        return list(
            await self.session.scalars(
                select(HospitalPreAlert)
                .where(HospitalPreAlert.hospital_id == facility_id)
                .order_by(HospitalPreAlert.created_at.desc())
                .limit(100)
            )
        )

    async def resource_requests(self, facility_id: UUID) -> list[HospitalResourceRequest]:
        return list(
            await self.session.scalars(
                select(HospitalResourceRequest)
                .where(HospitalResourceRequest.hospital_id == facility_id)
                .order_by(HospitalResourceRequest.created_at.desc())
                .limit(100)
            )
        )

    async def pre_alert(self, value_id: UUID, *, lock: bool = False) -> HospitalPreAlert | None:
        query = select(HospitalPreAlert).where(HospitalPreAlert.id == value_id)
        if lock:
            query = query.with_for_update()
        return cast(HospitalPreAlert | None, await self.session.scalar(query))

    async def resource_request(
        self, value_id: UUID, *, lock: bool = False
    ) -> HospitalResourceRequest | None:
        query = select(HospitalResourceRequest).where(HospitalResourceRequest.id == value_id)
        if lock:
            query = query.with_for_update()
        return cast(HospitalResourceRequest | None, await self.session.scalar(query))

    async def boxes(self, facility_id: UUID) -> list[AntivenomBox]:
        return list(
            await self.session.scalars(
                select(AntivenomBox)
                .where(AntivenomBox.facility_id == facility_id)
                .order_by(AntivenomBox.expiry_date, AntivenomBox.created_at)
            )
        )

    async def box_by_hash(self, token_hash: str, *, lock: bool = False) -> AntivenomBox | None:
        query = select(AntivenomBox).where(AntivenomBox.qr_token_hash == token_hash)
        if lock:
            query = query.with_for_update()
        return cast(AntivenomBox | None, await self.session.scalar(query))

    async def box(self, box_id: UUID, *, lock: bool = False) -> AntivenomBox | None:
        query = select(AntivenomBox).where(AntivenomBox.id == box_id)
        if lock:
            query = query.with_for_update()
        return cast(AntivenomBox | None, await self.session.scalar(query))

    async def pending_depletion(self, box_id: UUID) -> AntivenomDepletionRequest | None:
        return cast(
            AntivenomDepletionRequest | None,
            await self.session.scalar(
                select(AntivenomDepletionRequest).where(
                    AntivenomDepletionRequest.box_id == box_id,
                    AntivenomDepletionRequest.status == DepletionStatus.PENDING.value,
                )
            ),
        )

    async def depletion_requests(self, facility_id: UUID) -> list[AntivenomDepletionRequest]:
        return list(
            await self.session.scalars(
                select(AntivenomDepletionRequest)
                .where(AntivenomDepletionRequest.facility_id == facility_id)
                .order_by(AntivenomDepletionRequest.created_at.desc())
            )
        )

    async def depletion_request(
        self, request_id: UUID, *, lock: bool = False
    ) -> AntivenomDepletionRequest | None:
        query = select(AntivenomDepletionRequest).where(AntivenomDepletionRequest.id == request_id)
        if lock:
            query = query.with_for_update()
        return cast(AntivenomDepletionRequest | None, await self.session.scalar(query))

    async def active_vials(self, facility_id: UUID, today: date) -> int:
        value = await self.session.scalar(
            select(func.sum(AntivenomBox.available_vials)).where(
                AntivenomBox.facility_id == facility_id,
                AntivenomBox.status == InventoryBoxStatus.ACTIVE.value,
                AntivenomBox.expiry_date >= today,
            )
        )
        return int(value or 0)
