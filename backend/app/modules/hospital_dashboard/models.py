from __future__ import annotations

from datetime import date, datetime
from typing import Any
from uuid import UUID

from sqlalchemy import (
    JSON,
    Date,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    String,
    Text,
    UniqueConstraint,
    text,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.infrastructure.database.base import Base, UUIDTimestampMixin


class HospitalClaimRequest(UUIDTimestampMixin, Base):
    __tablename__ = "hospital_claim_requests"
    __table_args__ = (
        Index("ix_hospital_claim_facility_status", "facility_id", "status"),
        Index(
            "uq_hospital_claim_pending_facility",
            "facility_id",
            unique=True,
            postgresql_where=text("status = 'pending'"),
            sqlite_where=text("status = 'pending'"),
        ),
    )

    facility_id: Mapped[UUID] = mapped_column(
        ForeignKey("hospital_facilities.id", ondelete="CASCADE"), index=True
    )
    requester_user_id: Mapped[UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    verification_method: Mapped[str] = mapped_column(String(40))
    evidence_reference: Mapped[str] = mapped_column(String(500))
    status: Mapped[str] = mapped_column(String(24), index=True)
    reviewer_user_id: Mapped[UUID | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), index=True
    )
    review_note: Mapped[str | None] = mapped_column(String(500))
    reviewed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


class AntivenomBox(UUIDTimestampMixin, Base):
    __tablename__ = "antivenom_boxes"
    __table_args__ = (
        UniqueConstraint("facility_id", "box_serial", name="uq_antivenom_box_facility_serial"),
        Index("ix_antivenom_box_facility_status_expiry", "facility_id", "status", "expiry_date"),
    )

    facility_id: Mapped[UUID] = mapped_column(
        ForeignKey("hospital_facilities.id", ondelete="CASCADE"), index=True
    )
    created_by_user_id: Mapped[UUID] = mapped_column(
        ForeignKey("users.id", ondelete="RESTRICT"), index=True
    )
    box_serial: Mapped[str] = mapped_column(String(120))
    product_name: Mapped[str] = mapped_column(String(240))
    manufacturer: Mapped[str] = mapped_column(String(240))
    batch_number: Mapped[str] = mapped_column(String(120), index=True)
    expiry_date: Mapped[date] = mapped_column(Date, index=True)
    initial_vials: Mapped[int] = mapped_column(Integer)
    available_vials: Mapped[int] = mapped_column(Integer)
    status: Mapped[str] = mapped_column(String(24), index=True)
    qr_token_hash: Mapped[str] = mapped_column(String(64), unique=True, index=True)
    depleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


class AntivenomDepletionRequest(UUIDTimestampMixin, Base):
    __tablename__ = "antivenom_depletion_requests"
    __table_args__ = (
        Index("ix_depletion_facility_status", "facility_id", "status"),
        Index(
            "uq_depletion_pending_box",
            "box_id",
            unique=True,
            postgresql_where=text("status = 'pending'"),
            sqlite_where=text("status = 'pending'"),
        ),
    )

    box_id: Mapped[UUID] = mapped_column(
        ForeignKey("antivenom_boxes.id", ondelete="CASCADE"), index=True
    )
    facility_id: Mapped[UUID] = mapped_column(
        ForeignKey("hospital_facilities.id", ondelete="CASCADE"), index=True
    )
    scanned_by_user_id: Mapped[UUID] = mapped_column(
        ForeignKey("users.id", ondelete="RESTRICT"), index=True
    )
    requested_used_vials: Mapped[int] = mapped_column(Integer)
    status: Mapped[str] = mapped_column(String(24), index=True)
    reviewer_user_id: Mapped[UUID | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), index=True
    )
    review_note: Mapped[str | None] = mapped_column(String(500))
    reviewed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


class HospitalAuditEvent(UUIDTimestampMixin, Base):
    __tablename__ = "hospital_audit_events"
    __table_args__ = (Index("ix_hospital_audit_facility_created", "facility_id", "created_at"),)

    facility_id: Mapped[UUID] = mapped_column(
        ForeignKey("hospital_facilities.id", ondelete="CASCADE"), index=True
    )
    actor_user_id: Mapped[UUID] = mapped_column(
        ForeignKey("users.id", ondelete="RESTRICT"), index=True
    )
    event_type: Mapped[str] = mapped_column(String(80), index=True)
    entity_id: Mapped[UUID | None] = mapped_column()
    details: Mapped[dict[str, Any]] = mapped_column(JSON, default=dict, nullable=False)
    note: Mapped[str | None] = mapped_column(Text)
