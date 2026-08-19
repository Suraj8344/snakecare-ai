from typing import cast
from uuid import UUID

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.modules.emergency_handoff.models import EmergencyHandoff, EmergencyHandoffEvent
from app.modules.medical_passport.models import MedicalPassport
from app.modules.snakebite_emergency.models import SnakebiteEmergency


class SqlAlchemyEmergencyHandoffRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    def add(self, entity: EmergencyHandoff | EmergencyHandoffEvent) -> None:
        self.session.add(entity)

    async def commit(self) -> None:
        await self.session.commit()

    async def rollback(self) -> None:
        await self.session.rollback()

    async def refresh(self, entity: EmergencyHandoff) -> None:
        await self.session.refresh(entity, attribute_names=["events"])

    async def get_emergency_owned(
        self, emergency_id: UUID, owner_id: UUID
    ) -> SnakebiteEmergency | None:
        return cast(
            SnakebiteEmergency | None,
            await self.session.scalar(
                select(SnakebiteEmergency).where(
                    SnakebiteEmergency.id == emergency_id,
                    SnakebiteEmergency.owner_user_id == owner_id,
                )
            ),
        )

    async def get_passport(self, owner_id: UUID) -> MedicalPassport | None:
        return cast(
            MedicalPassport | None,
            await self.session.scalar(
                select(MedicalPassport).where(MedicalPassport.user_id == owner_id)
            ),
        )

    async def get_owned(self, handoff_id: UUID, owner_id: UUID) -> EmergencyHandoff | None:
        return cast(
            EmergencyHandoff | None,
            await self.session.scalar(
                select(EmergencyHandoff)
                .options(selectinload(EmergencyHandoff.events))
                .where(
                    EmergencyHandoff.id == handoff_id,
                    EmergencyHandoff.owner_user_id == owner_id,
                )
            ),
        )

    async def list_owned(
        self, owner_id: UUID, *, limit: int = 50
    ) -> tuple[list[EmergencyHandoff], int]:
        total = int(
            await self.session.scalar(
                select(func.count())
                .select_from(EmergencyHandoff)
                .where(EmergencyHandoff.owner_user_id == owner_id)
            )
            or 0
        )
        rows = await self.session.scalars(
            select(EmergencyHandoff)
            .options(selectinload(EmergencyHandoff.events))
            .where(EmergencyHandoff.owner_user_id == owner_id)
            .order_by(EmergencyHandoff.created_at.desc())
            .limit(limit)
        )
        return list(rows.unique()), total
