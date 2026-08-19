from __future__ import annotations

from datetime import datetime
from typing import Any
from uuid import UUID

from sqlalchemy import JSON, Boolean, DateTime, ForeignKey, Index, Integer, String, Text
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.infrastructure.database.base import Base, UUIDTimestampMixin
from app.modules.emergency_handoff.domain import HandoffStatus, ResponseStatus


class EmergencyHandoff(UUIDTimestampMixin, Base):
    __tablename__ = "emergency_handoffs"
    __table_args__ = (
        Index("ix_emergency_handoffs_owner_created", "owner_user_id", "created_at"),
    )

    owner_user_id: Mapped[UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    emergency_id: Mapped[UUID] = mapped_column(
        ForeignKey("snakebite_emergencies.id", ondelete="CASCADE"), index=True
    )
    simulation_only: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    status: Mapped[str] = mapped_column(
        String(32), default=HandoffStatus.PREPARED.value, nullable=False, index=True
    )
    response_status: Mapped[str] = mapped_column(
        String(24), default=ResponseStatus.UNKNOWN.value, nullable=False
    )
    countdown_seconds: Mapped[int] = mapped_column(Integer, default=15, nullable=False)
    consent_identity: Mapped[bool] = mapped_column(Boolean, nullable=False)
    consent_location: Mapped[bool] = mapped_column(Boolean, nullable=False)
    consent_emergency_summary: Mapped[bool] = mapped_column(Boolean, nullable=False)
    consent_medical_passport: Mapped[bool] = mapped_column(Boolean, nullable=False)
    consent_voice_assistance: Mapped[bool] = mapped_column(Boolean, nullable=False)
    structured_summary: Mapped[dict[str, Any]] = mapped_column(
        JSON().with_variant(JSONB, "postgresql"), nullable=False
    )
    countdown_started_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    cancelled_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    manual_call_requested_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    events: Mapped[list[EmergencyHandoffEvent]] = relationship(
        cascade="all, delete-orphan", lazy="selectin", order_by="EmergencyHandoffEvent.created_at"
    )


class EmergencyHandoffEvent(UUIDTimestampMixin, Base):
    __tablename__ = "emergency_handoff_events"
    __table_args__ = (
        Index("ix_emergency_handoff_events_handoff_created", "handoff_id", "created_at"),
    )

    handoff_id: Mapped[UUID] = mapped_column(
        ForeignKey("emergency_handoffs.id", ondelete="CASCADE"), index=True
    )
    actor_user_id: Mapped[UUID | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), index=True
    )
    event_type: Mapped[str] = mapped_column(String(64), index=True)
    outcome: Mapped[str] = mapped_column(String(24), nullable=False)
    safe_details: Mapped[dict[str, Any]] = mapped_column(
        JSON().with_variant(JSONB, "postgresql"), default=dict, nullable=False
    )
    message: Mapped[str | None] = mapped_column(Text)
