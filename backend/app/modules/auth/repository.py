from __future__ import annotations

from datetime import UTC, datetime
from typing import cast
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.auth.domain import UserRole, VerifiedIdentity
from app.modules.auth.models import AuthAuditEvent, RefreshSession, User


class SqlAlchemyAuthRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def get_user(self, user_id: UUID) -> User | None:
        return cast(User | None, await self._session.get(User, user_id))

    async def get_user_by_firebase_uid(self, firebase_uid: str) -> User | None:
        return cast(
            User | None,
            await self._session.scalar(select(User).where(User.firebase_uid == firebase_uid)),
        )

    async def get_user_by_hospital_employee_id(self, employee_id: str) -> User | None:
        return cast(
            User | None,
            await self._session.scalar(
                select(User).where(User.hospital_employee_id == employee_id)
            ),
        )

    async def upsert_identity(self, identity: VerifiedIdentity, initial_role: UserRole) -> User:
        user = await self.get_user_by_firebase_uid(identity.firebase_uid)
        now = datetime.now(UTC)
        if user is None:
            user = User(firebase_uid=identity.firebase_uid, role=initial_role.value)
            self._session.add(user)
        user.email = identity.email.lower() if identity.email else None
        user.email_verified = identity.email_verified
        user.phone_number = identity.phone_number
        user.display_name = identity.display_name
        user.last_login_at = now
        await self._session.flush()
        return user

    async def list_users(self) -> list[User]:
        result = await self._session.scalars(select(User).order_by(User.created_at))
        return list(result)

    async def add_refresh_session(self, refresh_session: RefreshSession) -> None:
        self._session.add(refresh_session)
        await self._session.flush()

    async def get_refresh_session(self, token_hash: str) -> RefreshSession | None:
        return cast(
            RefreshSession | None,
            await self._session.scalar(
                select(RefreshSession).where(RefreshSession.token_hash == token_hash)
            ),
        )

    def add_audit_event(self, event: AuthAuditEvent) -> None:
        self._session.add(event)

    async def commit(self) -> None:
        await self._session.commit()
