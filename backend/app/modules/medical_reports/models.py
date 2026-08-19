from __future__ import annotations

from datetime import date, datetime
from uuid import UUID

from sqlalchemy import BigInteger, Date, DateTime, ForeignKey, Index, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.infrastructure.database.base import Base, UUIDTimestampMixin


class MedicalReport(UUIDTimestampMixin, Base):
    __tablename__ = "medical_reports"
    __table_args__ = (
        Index("ix_medical_reports_owner_date", "owner_user_id", "report_date"),
        Index("ix_medical_reports_owner_category", "owner_user_id", "category"),
        Index("ix_medical_reports_owner_status", "owner_user_id", "status"),
    )

    owner_user_id: Mapped[UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    title: Mapped[str] = mapped_column(String(200))
    category: Mapped[str] = mapped_column(String(40), default="other", index=True)
    report_date: Mapped[date | None] = mapped_column(Date, index=True)
    provider_name: Mapped[str | None] = mapped_column(String(200))
    notes: Mapped[str | None] = mapped_column(Text)
    original_filename: Mapped[str] = mapped_column(String(255))
    storage_key: Mapped[str] = mapped_column(String(160), unique=True)
    content_type: Mapped[str] = mapped_column(String(80), index=True)
    size_bytes: Mapped[int] = mapped_column(BigInteger)
    sha256: Mapped[str] = mapped_column(String(64), index=True)
    status: Mapped[str] = mapped_column(String(24), default="processing", index=True)
    extracted_text: Mapped[str | None] = mapped_column(Text)
    ocr_engine: Mapped[str | None] = mapped_column(String(80))
    ocr_confidence: Mapped[str | None] = mapped_column(String(24))
    automated_summary: Mapped[str | None] = mapped_column(Text)
    summary_method: Mapped[str | None] = mapped_column(String(80))
    summary_generated_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    processing_error: Mapped[str | None] = mapped_column(String(500))
