from typing import cast
from uuid import UUID

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.snakebite_emergency.models import SnakebiteEmergency


class SqlAlchemySnakebiteEmergencyRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    def add(self, emergency: SnakebiteEmergency) -> None:
        self.session.add(emergency)

    async def commit(self) -> None:
        await self.session.commit()

    async def rollback(self) -> None:
        await self.session.rollback()

    async def refresh(self, emergency: SnakebiteEmergency) -> None:
        await self.session.refresh(emergency)

    async def get_owned(self, emergency_id: UUID, owner_id: UUID) -> SnakebiteEmergency | None:
        return cast(
            SnakebiteEmergency | None,
            await self.session.scalar(
                select(SnakebiteEmergency).where(
                    SnakebiteEmergency.id == emergency_id,
                    SnakebiteEmergency.owner_user_id == owner_id,
                )
            ),
        )

    async def list_owned(
        self, owner_id: UUID, *, limit: int = 50
    ) -> tuple[list[SnakebiteEmergency], int]:
        total = int(
            await self.session.scalar(
                select(func.count())
                .select_from(SnakebiteEmergency)
                .where(SnakebiteEmergency.owner_user_id == owner_id)
            )
            or 0
        )
        rows = await self.session.scalars(
            select(SnakebiteEmergency)
            .where(SnakebiteEmergency.owner_user_id == owner_id)
            .order_by(SnakebiteEmergency.created_at.desc())
            .limit(limit)
        )
        return list(rows), total
