from __future__ import annotations

from datetime import datetime
from typing import Any
from uuid import UUID

from sqlalchemy import JSON, Boolean, DateTime, Float, ForeignKey, Index, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.infrastructure.database.base import Base, UUIDTimestampMixin


class HospitalFacility(UUIDTimestampMixin, Base):
    __tablename__ = "hospital_facilities"
    __table_args__ = (
        Index("ix_hospital_facilities_location", "latitude", "longitude"),
        Index("ix_hospital_facilities_active_name", "is_active", "name"),
    )

    hfr_id: Mapped[str | None] = mapped_column(String(100), unique=True, index=True)
    managed_by_user_id: Mapped[UUID | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), index=True
    )
    name: Mapped[str] = mapped_column(String(240), index=True)
    address: Mapped[str] = mapped_column(Text)
    city: Mapped[str | None] = mapped_column(String(120), index=True)
    state: Mapped[str | None] = mapped_column(String(120), index=True)
    latitude: Mapped[float] = mapped_column(Float)
    longitude: Mapped[float] = mapped_column(Float)
    emergency_phone: Mapped[str | None] = mapped_column(String(32))
    directions_url: Mapped[str | None] = mapped_column(String(500))
    data_source: Mapped[str] = mapped_column(String(40))
    source_updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)


class HospitalCapability(UUIDTimestampMixin, Base):
    __tablename__ = "hospital_capabilities"

    hospital_id: Mapped[UUID] = mapped_column(
        ForeignKey("hospital_facilities.id", ondelete="CASCADE"), unique=True, index=True
    )
    emergency_24x7: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    snakebite_trained_staff: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    can_administer_antivenom: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    icu: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    ventilator: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    dialysis: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    blood_bank: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    data_source: Mapped[str] = mapped_column(String(40))
    verified_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))


class HospitalAvailability(UUIDTimestampMixin, Base):
    __tablename__ = "hospital_availability_snapshots"
    __table_args__ = (Index("ix_hospital_availability_recent", "hospital_id", "recorded_at"),)

    hospital_id: Mapped[UUID] = mapped_column(
        ForeignKey("hospital_facilities.id", ondelete="CASCADE"), index=True
    )
    antivenom_status: Mapped[str] = mapped_column(String(32))
    antivenom_vials: Mapped[int | None] = mapped_column(Integer)
    emergency_beds: Mapped[int | None] = mapped_column(Integer)
    icu_beds: Mapped[int | None] = mapped_column(Integer)
    ventilators: Mapped[int | None] = mapped_column(Integer)
    data_source: Mapped[str] = mapped_column(String(40))
    recorded_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True)


class HospitalRecommendation(UUIDTimestampMixin, Base):
    __tablename__ = "hospital_recommendations"
    __table_args__ = (
        Index("ix_hospital_recommendations_owner_created", "owner_user_id", "created_at"),
    )

    owner_user_id: Mapped[UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    emergency_id: Mapped[UUID] = mapped_column(
        ForeignKey("snakebite_emergencies.id", ondelete="CASCADE"), index=True
    )
    hospital_id: Mapped[UUID] = mapped_column(
        ForeignKey("hospital_facilities.id", ondelete="CASCADE"), index=True
    )
    rank: Mapped[int] = mapped_column(Integer)
    distance_km: Mapped[float] = mapped_column(Float)
    score: Mapped[float] = mapped_column(Float)
    score_components: Mapped[dict[str, float]] = mapped_column(JSON)
    reasons: Mapped[list[str]] = mapped_column(JSON)
    warnings: Mapped[list[str]] = mapped_column(JSON)
    ruleset_version: Mapped[str] = mapped_column(String(80))
    availability_recorded_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


class HospitalPreAlert(UUIDTimestampMixin, Base):
    __tablename__ = "hospital_pre_alerts"
    __table_args__ = (Index("ix_hospital_pre_alerts_hospital_status", "hospital_id", "status"),)

    owner_user_id: Mapped[UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    emergency_id: Mapped[UUID] = mapped_column(
        ForeignKey("snakebite_emergencies.id", ondelete="CASCADE"), index=True
    )
    hospital_id: Mapped[UUID] = mapped_column(
        ForeignKey("hospital_facilities.id", ondelete="CASCADE"), index=True
    )
    shared_payload: Mapped[dict[str, Any]] = mapped_column(JSON)
    status: Mapped[str] = mapped_column(String(24), index=True)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True)
    notice: Mapped[str] = mapped_column(String(500))
    response_note: Mapped[str | None] = mapped_column(String(500))
    responded_by_user_id: Mapped[UUID | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), index=True
    )
    responded_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


class HospitalResourceRequest(UUIDTimestampMixin, Base):
    __tablename__ = "hospital_resource_requests"
    __table_args__ = (Index("ix_resource_requests_hospital_status", "hospital_id", "status"),)

    owner_user_id: Mapped[UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    pre_alert_id: Mapped[UUID] = mapped_column(
        ForeignKey("hospital_pre_alerts.id", ondelete="CASCADE"), index=True
    )
    hospital_id: Mapped[UUID] = mapped_column(
        ForeignKey("hospital_facilities.id", ondelete="CASCADE"), index=True
    )
    antivenom_readiness: Mapped[bool] = mapped_column(Boolean, nullable=False)
    emergency_bed: Mapped[bool] = mapped_column(Boolean, nullable=False)
    icu_readiness: Mapped[bool] = mapped_column(Boolean, nullable=False)
    ventilator_readiness: Mapped[bool] = mapped_column(Boolean, nullable=False)
    status: Mapped[str] = mapped_column(String(24), index=True)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True)
    response_note: Mapped[str | None] = mapped_column(String(500))
    responded_by_user_id: Mapped[UUID | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), index=True
    )
    responded_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
