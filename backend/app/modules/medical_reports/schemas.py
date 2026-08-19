from datetime import date, datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field

from app.modules.medical_reports.domain import ReportCategory, ReportStatus


class ReportView(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    title: str
    category: ReportCategory
    report_date: date | None
    provider_name: str | None
    notes: str | None
    original_filename: str
    content_type: str
    size_bytes: int
    sha256: str
    status: ReportStatus
    extracted_text: str | None
    ocr_engine: str | None
    ocr_confidence: str | None
    automated_summary: str | None
    summary_method: str | None
    summary_generated_at: datetime | None
    processing_error: str | None
    created_at: datetime
    updated_at: datetime


class ReportList(BaseModel):
    items: list[ReportView]
    total: int
    page: int = Field(ge=1)
    page_size: int = Field(ge=1, le=100)


class TimelineGroup(BaseModel):
    date: date
    reports: list[ReportView]
