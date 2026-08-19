from __future__ import annotations

from datetime import datetime
from typing import Any
from uuid import UUID

from sqlalchemy import JSON, Boolean, CheckConstraint, DateTime, ForeignKey, String, Text
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.infrastructure.database.base import Base, UUIDTimestampMixin
from app.modules.auth.domain import UserRole, UserStatus


class User(UUIDTimestampMixin, Base):
    __tablename__ = "users"
    __table_args__ = (
        CheckConstraint(
            "role IN ('patient','doctor','hospital_admin','ambulance_crew',"
            "'ambulance_dispatcher','government_admin')",
            name="ck_users_role",
        ),
        CheckConstraint(
            "hospital_employee_id IS NULL OR role = 'hospital_admin'",
            name="ck_users_hospital_employee_role",
        ),
        CheckConstraint(
            "ambulance_employee_id IS NULL OR role IN "
            "('ambulance_crew','ambulance_dispatcher')",
            name="ck_users_ambulance_employee_role",
        ),
        CheckConstraint("status IN ('active','disabled')", name="ck_users_status"),
    )

    firebase_uid: Mapped[str] = mapped_column(String(128), unique=True, index=True)
    email: Mapped[str | None] = mapped_column(String(320), unique=True, index=True)
    email_verified: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    phone_number: Mapped[str | None] = mapped_column(String(32), unique=True, index=True)
    display_name: Mapped[str | None] = mapped_column(String(160))
    hospital_employee_id: Mapped[str | None] = mapped_column(
        String(64), unique=True, index=True
    )
    ambulance_employee_id: Mapped[str | None] = mapped_column(
        String(64), unique=True, index=True
    )
    role: Mapped[str] = mapped_column(String(32), default=UserRole.PATIENT.value, nullable=False)
    status: Mapped[str] = mapped_column(String(16), default=UserStatus.ACTIVE.value, nullable=False)
    last_login_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    refresh_sessions: Mapped[list[RefreshSession]] = relationship(
        back_populates="user", cascade="all, delete-orphan"
    )


class RefreshSession(UUIDTimestampMixin, Base):
    __tablename__ = "refresh_sessions"

    user_id: Mapped[UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    token_hash: Mapped[str] = mapped_column(String(64), unique=True, index=True)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True)
    revoked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), index=True)
    replaced_by_hash: Mapped[str | None] = mapped_column(String(64))
    client_fingerprint: Mapped[str | None] = mapped_column(String(64))
    user: Mapped[User] = relationship(back_populates="refresh_sessions")


class AuthAuditEvent(UUIDTimestampMixin, Base):
    __tablename__ = "auth_audit_events"

    user_id: Mapped[UUID | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), index=True
    )
    event_type: Mapped[str] = mapped_column(String(64), index=True)
    outcome: Mapped[str] = mapped_column(String(16))
    request_id: Mapped[str | None] = mapped_column(String(128), index=True)
    details: Mapped[dict[str, Any]] = mapped_column(
        JSON().with_variant(JSONB, "postgresql"), default=dict, nullable=False
    )
    message: Mapped[str | None] = mapped_column(Text)
