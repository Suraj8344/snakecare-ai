from __future__ import annotations

from typing import Any, cast
from uuid import UUID

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.hospital_coordination.models import (
    HospitalAvailability,
    HospitalCapability,
    HospitalFacility,
    HospitalPreAlert,
    HospitalResourceRequest,
)


class SqlAlchemyHospitalCoordinationRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    def add(self, value: object) -> None:
        self.session.add(value)

    async def commit(self) -> None:
        await self.session.commit()

    async def flush(self) -> None:
        await self.session.flush()

    async def refresh(self, value: object) -> None:
        await self.session.refresh(value)

    async def facility(self, hospital_id: UUID) -> HospitalFacility | None:
        return cast(
            HospitalFacility | None,
            await self.session.scalar(
                select(HospitalFacility).where(
                    HospitalFacility.id == hospital_id,
                    HospitalFacility.is_active.is_(True),
                )
            ),
        )

    async def facilities_with_status(
        self,
    ) -> list[tuple[HospitalFacility, HospitalCapability, HospitalAvailability | None]]:
        facilities = list(
            await self.session.scalars(
                select(HospitalFacility)
                .where(HospitalFacility.is_active.is_(True))
                .order_by(HospitalFacility.name)
            )
        )
        result: list[tuple[HospitalFacility, HospitalCapability, HospitalAvailability | None]] = []
        for facility in facilities:
            capability = await self.session.scalar(
                select(HospitalCapability).where(HospitalCapability.hospital_id == facility.id)
            )
            if capability is None:
                continue
            availability = await self.latest_availability(facility.id)
            result.append((facility, capability, availability))
        return result

    async def facility_directory(
        self, *, city: str, search: str | None, limit: int, offset: int
    ) -> tuple[
        int,
        list[tuple[HospitalFacility, HospitalCapability, HospitalAvailability | None]],
    ]:
        filters: list[Any] = [
            HospitalFacility.is_active.is_(True),
            func.lower(HospitalFacility.city) == city.lower(),
        ]
        if search:
            term = f"%{search.lower()}%"
            filters.append(
                func.lower(HospitalFacility.name).like(term)
                | func.lower(HospitalFacility.address).like(term)
            )
        total = int(
            await self.session.scalar(
                select(func.count()).select_from(HospitalFacility).where(*filters)
            )
            or 0
        )
        facilities = list(
            await self.session.scalars(
                select(HospitalFacility)
                .where(*filters)
                .order_by(HospitalFacility.name)
                .offset(offset)
                .limit(limit)
            )
        )
        result: list[tuple[HospitalFacility, HospitalCapability, HospitalAvailability | None]] = []
        for facility in facilities:
            capability = await self.capability(facility.id)
            if capability is None:
                continue
            result.append((facility, capability, await self.latest_availability(facility.id)))
        return total, result

    async def capability(self, hospital_id: UUID) -> HospitalCapability | None:
        return cast(
            HospitalCapability | None,
            await self.session.scalar(
                select(HospitalCapability).where(HospitalCapability.hospital_id == hospital_id)
            ),
        )

    async def latest_availability(self, hospital_id: UUID) -> HospitalAvailability | None:
        return cast(
            HospitalAvailability | None,
            await self.session.scalar(
                select(HospitalAvailability)
                .where(HospitalAvailability.hospital_id == hospital_id)
                .order_by(HospitalAvailability.recorded_at.desc())
                .limit(1)
            ),
        )

    async def owned_pre_alert(self, pre_alert_id: UUID, owner_id: UUID) -> HospitalPreAlert | None:
        return cast(
            HospitalPreAlert | None,
            await self.session.scalar(
                select(HospitalPreAlert).where(
                    HospitalPreAlert.id == pre_alert_id,
                    HospitalPreAlert.owner_user_id == owner_id,
                )
            ),
        )

    async def list_pre_alerts(self, owner_id: UUID) -> list[HospitalPreAlert]:
        return list(
            await self.session.scalars(
                select(HospitalPreAlert)
                .where(HospitalPreAlert.owner_user_id == owner_id)
                .order_by(HospitalPreAlert.created_at.desc())
            )
        )

    async def list_resource_requests(self, owner_id: UUID) -> list[HospitalResourceRequest]:
        return list(
            await self.session.scalars(
                select(HospitalResourceRequest)
                .where(HospitalResourceRequest.owner_user_id == owner_id)
                .order_by(HospitalResourceRequest.created_at.desc())
            )
        )
