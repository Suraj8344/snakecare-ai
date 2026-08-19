from __future__ import annotations

from datetime import datetime
from uuid import UUID

from sqlalchemy import (
    JSON,
    BigInteger,
    DateTime,
    Float,
    ForeignKey,
    Index,
    Integer,
    String,
    Text,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.infrastructure.database.base import Base, UUIDTimestampMixin


class SnakebiteEmergency(UUIDTimestampMixin, Base):
    __tablename__ = "snakebite_emergencies"
    __table_args__ = (
        Index("ix_snakebite_emergencies_owner_created", "owner_user_id", "created_at"),
        Index("ix_snakebite_emergencies_owner_urgency", "owner_user_id", "urgency"),
    )

    owner_user_id: Mapped[UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    occurred_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), index=True)
    patient_age_years: Mapped[int | None] = mapped_column(Integer)
    bite_site: Mapped[str] = mapped_column(String(32))
    symptoms: Mapped[list[str]] = mapped_column(JSON)
    symptom_notes: Mapped[str | None] = mapped_column(Text)
    voice_transcript: Mapped[str | None] = mapped_column(Text)
    latitude: Mapped[float | None] = mapped_column(Float)
    longitude: Mapped[float | None] = mapped_column(Float)
    location_accuracy_m: Mapped[float | None] = mapped_column(Float)
    location_label: Mapped[str | None] = mapped_column(String(300))
    pulse_bpm: Mapped[int | None] = mapped_column(Integer)
    respiratory_rate: Mapped[int | None] = mapped_column(Integer)
    oxygen_saturation: Mapped[int | None] = mapped_column(Integer)
    systolic_bp: Mapped[int | None] = mapped_column(Integer)
    diastolic_bp: Mapped[int | None] = mapped_column(Integer)
    temperature_c: Mapped[float | None] = mapped_column(Float)
    consciousness: Mapped[str] = mapped_column(String(32))
    photo_storage_key: Mapped[str | None] = mapped_column(String(160), unique=True)
    photo_original_filename: Mapped[str | None] = mapped_column(String(255))
    photo_content_type: Mapped[str | None] = mapped_column(String(80))
    photo_size_bytes: Mapped[int | None] = mapped_column(BigInteger)
    photo_sha256: Mapped[str | None] = mapped_column(String(64))
    urgency: Mapped[str] = mapped_column(String(32), index=True)
    explanation: Mapped[list[str]] = mapped_column(JSON)
    immediate_actions: Mapped[list[str]] = mapped_column(JSON)
    first_aid_steps: Mapped[list[str]] = mapped_column(JSON)
    actions_to_avoid: Mapped[list[str]] = mapped_column(JSON)
    ruleset_version: Mapped[str] = mapped_column(String(80))
    guidance_version: Mapped[str] = mapped_column(String(80))
    assessment_notice: Mapped[str] = mapped_column(String(500))

    @property
    def photo_available(self) -> bool:
        return self.photo_storage_key is not None
