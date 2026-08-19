from __future__ import annotations

from dataclasses import dataclass
from datetime import UTC, datetime
from uuid import UUID

from app.modules.auth.domain import (
    AccountDisabledError,
    InvalidCredentialsError,
    PermissionDeniedError,
    RoleAssignmentConflictError,
    SessionExpiredError,
    UserRole,
    UserStatus,
)
from app.modules.auth.models import AuthAuditEvent, RefreshSession, User
from app.modules.auth.ports import IdentityVerifier
from app.modules.auth.repository import SqlAlchemyAuthRepository
from app.modules.auth.tokens import TokenService


@dataclass(frozen=True, slots=True)
class IssuedSession:
    user: User
    access_token: str
    refresh_token: str
    access_expires_at: datetime


class AuthService:
    def __init__(
        self,
        *,
        repository: SqlAlchemyAuthRepository,
        identity_verifier: IdentityVerifier,
        tokens: TokenService,
        bootstrap_admin_emails: set[str],
    ) -> None:
        self._repository = repository
        self._identity_verifier = identity_verifier
        self._tokens = tokens
        self._bootstrap_admin_emails = bootstrap_admin_emails

    async def exchange_firebase_token(
        self, firebase_id_token: str, *, request_id: str | None, fingerprint: str | None
    ) -> IssuedSession:
        identity = await self._identity_verifier.verify(firebase_id_token)
        bootstrap = bool(
            identity.email
            and identity.email_verified
            and identity.email.lower() in self._bootstrap_admin_emails
        )
        role = UserRole.GOVERNMENT_ADMIN if bootstrap else UserRole.PATIENT
        user = await self._repository.upsert_identity(identity, role)
        if user.role in {
            UserRole.AMBULANCE_CREW.value,
            UserRole.AMBULANCE_DISPATCHER.value,
        }:
            previous_role = user.role
            user.role = UserRole.PATIENT.value
            user.ambulance_employee_id = None
            self._audit(
                user.id,
                "retired_ambulance_role_migrated",
                "success",
                request_id,
                {"from": previous_role, "to": UserRole.PATIENT.value},
            )
        if bootstrap and user.role != UserRole.GOVERNMENT_ADMIN.value:
            previous_role = user.role
            user.role = UserRole.GOVERNMENT_ADMIN.value
            self._audit(
                user.id,
                "bootstrap_admin_promoted",
                "success",
                request_id,
                {"from": previous_role, "to": UserRole.GOVERNMENT_ADMIN.value},
            )
        self._ensure_active(user)
        issued = await self._issue_session(user, fingerprint)
        self._audit(user.id, "session_created", "success", request_id)
        await self._repository.commit()
        return issued

    async def refresh(
        self, refresh_token: str, *, request_id: str | None, fingerprint: str | None
    ) -> IssuedSession:
        now = datetime.now(UTC)
        token_hash = self._tokens.hash_token(refresh_token)
        stored = await self._repository.get_refresh_session(token_hash)
        if stored is None or stored.revoked_at is not None:
            raise SessionExpiredError
        expires_at = stored.expires_at
        if expires_at.tzinfo is None:
            expires_at = expires_at.replace(tzinfo=UTC)
        if expires_at <= now:
            raise SessionExpiredError
        user = await self._repository.get_user(stored.user_id)
        if user is None:
            raise InvalidCredentialsError
        self._ensure_active(user)
        raw = self._tokens.new_refresh_token()
        new_hash = self._tokens.hash_token(raw)
        stored.revoked_at = now
        stored.replaced_by_hash = new_hash
        access, access_expiry = self._tokens.issue_access_token(user.id, UserRole(user.role))
        await self._repository.add_refresh_session(
            RefreshSession(
                user_id=user.id,
                token_hash=new_hash,
                expires_at=now + self._tokens.refresh_lifetime,
                client_fingerprint=self._tokens.fingerprint(fingerprint),
            )
        )
        self._audit(user.id, "session_refreshed", "success", request_id)
        await self._repository.commit()
        return IssuedSession(user, access, raw, access_expiry)

    async def logout(self, refresh_token: str, *, user_id: UUID, request_id: str | None) -> None:
        stored = await self._repository.get_refresh_session(self._tokens.hash_token(refresh_token))
        if stored and stored.user_id == user_id and stored.revoked_at is None:
            stored.revoked_at = datetime.now(UTC)
        self._audit(user_id, "session_revoked", "success", request_id)
        await self._repository.commit()

    async def current_user(self, user_id: UUID) -> User:
        user = await self._repository.get_user(user_id)
        if user is None:
            raise InvalidCredentialsError
        self._ensure_active(user)
        return user

    async def list_users(self, actor: User) -> list[User]:
        self._require_government_admin(actor)
        return await self._repository.list_users()

    async def change_role(
        self,
        *,
        actor: User,
        target_user_id: UUID,
        new_role: UserRole,
        hospital_employee_id: str | None,
        request_id: str | None,
    ) -> User:
        self._require_government_admin(actor)
        target = await self._repository.get_user(target_user_id)
        if target is None:
            raise InvalidCredentialsError
        if target.id == actor.id and new_role != UserRole.GOVERNMENT_ADMIN:
            raise PermissionDeniedError("Government administrators cannot demote themselves")
        if new_role == UserRole.HOSPITAL_ADMIN:
            if not target.email_verified:
                raise PermissionDeniedError(
                    "Hospital employees must verify their email before role assignment"
                )
            if hospital_employee_id is None:
                raise RoleAssignmentConflictError("A hospital employee ID is required")
            existing = await self._repository.get_user_by_hospital_employee_id(hospital_employee_id)
            if existing is not None and existing.id != target.id:
                raise RoleAssignmentConflictError("The hospital employee ID is already assigned")
        if new_role in {UserRole.AMBULANCE_CREW, UserRole.AMBULANCE_DISPATCHER}:
            raise PermissionDeniedError(
                "Ambulance roles are no longer available; use emergency service 112"
            )
        old_role = target.role
        target.role = new_role.value
        target.hospital_employee_id = (
            hospital_employee_id if new_role == UserRole.HOSPITAL_ADMIN else None
        )
        target.ambulance_employee_id = None
        self._audit(
            target.id,
            "role_changed",
            "success",
            request_id,
            {
                "actor_user_id": str(actor.id),
                "from": old_role,
                "to": new_role.value,
                "hospital_employee_id_assigned": str(hospital_employee_id is not None).lower(),
            },
        )
        await self._repository.commit()
        return target

    async def _issue_session(self, user: User, fingerprint: str | None) -> IssuedSession:
        now = datetime.now(UTC)
        raw_refresh = self._tokens.new_refresh_token()
        access, access_expiry = self._tokens.issue_access_token(user.id, UserRole(user.role))
        await self._repository.add_refresh_session(
            RefreshSession(
                user_id=user.id,
                token_hash=self._tokens.hash_token(raw_refresh),
                expires_at=now + self._tokens.refresh_lifetime,
                client_fingerprint=self._tokens.fingerprint(fingerprint),
            )
        )
        return IssuedSession(user, access, raw_refresh, access_expiry)

    def _audit(
        self,
        user_id: UUID | None,
        event_type: str,
        outcome: str,
        request_id: str | None,
        details: dict[str, str] | None = None,
    ) -> None:
        self._repository.add_audit_event(
            AuthAuditEvent(
                user_id=user_id,
                event_type=event_type,
                outcome=outcome,
                request_id=request_id,
                details=details or {},
            )
        )

    @staticmethod
    def _ensure_active(user: User) -> None:
        if user.status != UserStatus.ACTIVE.value:
            raise AccountDisabledError

    @staticmethod
    def _require_government_admin(user: User) -> None:
        if user.role != UserRole.GOVERNMENT_ADMIN.value:
            raise PermissionDeniedError
