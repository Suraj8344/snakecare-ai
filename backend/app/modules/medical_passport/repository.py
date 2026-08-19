from __future__ import annotations

from typing import cast
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.modules.auth.models import User
from app.modules.medical_passport.models import (
    MedicalPassport,
    PassportAccessEvent,
    PassportAccessGrant,
)


class SqlAlchemyMedicalPassportRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def get_passport_by_user(self, user_id: UUID) -> MedicalPassport | None:
        return cast(
            MedicalPassport | None,
            await self.session.scalar(
                select(MedicalPassport)
                .where(MedicalPassport.user_id == user_id)
                .options(
                    selectinload(MedicalPassport.allergies),
                    selectinload(MedicalPassport.conditions),
                    selectinload(MedicalPassport.medications),
                    selectinload(MedicalPassport.emergency_contacts),
                    selectinload(MedicalPassport.surgeries),
                    selectinload(MedicalPassport.family_history),
                )
            ),
        )

    async def get_user(self, user_id: UUID) -> User | None:
        return await self.session.get(User, user_id)

    async def get_user_by_email(self, email: str) -> User | None:
        return cast(
            User | None,
            await self.session.scalar(select(User).where(User.email == email.lower())),
        )

    async def get_grant(self, patient_id: UUID, grantee_id: UUID) -> PassportAccessGrant | None:
        return cast(
            PassportAccessGrant | None,
            await self.session.scalar(
                select(PassportAccessGrant).where(
                    PassportAccessGrant.patient_user_id == patient_id,
                    PassportAccessGrant.grantee_user_id == grantee_id,
                )
            ),
        )

    async def get_grant_by_id(self, grant_id: UUID) -> PassportAccessGrant | None:
        return await self.session.get(PassportAccessGrant, grant_id)

    async def list_grants(self, patient_id: UUID) -> list[PassportAccessGrant]:
        rows = await self.session.scalars(
            select(PassportAccessGrant)
            .where(PassportAccessGrant.patient_user_id == patient_id)
            .order_by(PassportAccessGrant.created_at.desc())
        )
        return list(rows)

    def add(self, entity: object) -> None:
        self.session.add(entity)

    def audit(self, event: PassportAccessEvent) -> None:
        self.session.add(event)

    async def flush(self) -> None:
        await self.session.flush()

    async def commit(self) -> None:
        await self.session.commit()

    async def refresh(self, passport: MedicalPassport) -> None:
        await self.session.refresh(passport)
