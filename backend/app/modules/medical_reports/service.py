from __future__ import annotations

import asyncio
from datetime import UTC, date, datetime
from hashlib import sha256
from pathlib import Path
from uuid import UUID

from app.modules.auth.models import User
from app.modules.medical_reports.domain import (
    InvalidReportUpload,
    ReportCategory,
    ReportNotFound,
    ReportStatus,
)
from app.modules.medical_reports.models import MedicalReport
from app.modules.medical_reports.processor import ReportProcessor
from app.modules.medical_reports.repository import SqlAlchemyMedicalReportRepository
from app.modules.medical_reports.storage import LocalReportStorage


class MedicalReportService:
    def __init__(
        self,
        repository: SqlAlchemyMedicalReportRepository,
        storage: LocalReportStorage,
        processor: ReportProcessor,
        max_upload_bytes: int,
    ) -> None:
        self.repository = repository
        self.storage = storage
        self.processor = processor
        self.max_upload_bytes = max_upload_bytes

    async def upload(
        self,
        actor: User,
        *,
        title: str,
        report_date: date | None,
        provider_name: str | None,
        notes: str | None,
        category: ReportCategory | None,
        filename: str,
        content: bytes,
    ) -> MedicalReport:
        if not content or len(content) > self.max_upload_bytes:
            raise InvalidReportUpload
        content_type, extension = self._detect_type(content)
        safe_filename = filename.replace("\\", "/").rsplit("/", 1)[-1][:255]
        safe_filename = safe_filename or f"report{extension}"
        storage_key = await asyncio.to_thread(self.storage.save, content, extension)
        report = MedicalReport(
            owner_user_id=actor.id,
            title=title.strip(),
            report_date=report_date,
            provider_name=provider_name.strip() if provider_name else None,
            notes=notes.strip() if notes else None,
            category=(category or ReportCategory.OTHER).value,
            original_filename=safe_filename,
            storage_key=storage_key,
            content_type=content_type,
            size_bytes=len(content),
            sha256=sha256(content).hexdigest(),
            status=ReportStatus.PROCESSING.value,
        )
        try:
            result = await asyncio.to_thread(
                self.processor.process,
                content,
                content_type,
                safe_filename,
                category,
            )
            report.category = result.category.value
            report.extracted_text = result.text or None
            report.ocr_engine = result.engine
            report.ocr_confidence = result.confidence
            report.automated_summary = result.summary
            report.summary_method = "local-extractive-v1"
            report.summary_generated_at = datetime.now(UTC)
            report.status = ReportStatus.READY.value
        except InvalidReportUpload:
            await asyncio.to_thread(self.storage.delete, storage_key)
            raise
        except Exception:
            report.status = ReportStatus.FAILED.value
            report.processing_error = (
                "Text processing failed; the original file is still available."
            )
        self.repository.add(report)
        await self.repository.commit()
        await self.repository.refresh(report)
        return report

    async def get(self, actor: User, report_id: UUID) -> MedicalReport:
        report = await self.repository.get_owned(report_id, actor.id)
        if report is None:
            raise ReportNotFound
        return report

    async def file_path(self, actor: User, report_id: UUID) -> tuple[MedicalReport, Path]:
        report = await self.get(actor, report_id)
        path = await asyncio.to_thread(self.storage.path_for, report.storage_key)
        return report, path

    async def search(
        self,
        actor: User,
        *,
        query: str | None,
        category: ReportCategory | None,
        status: ReportStatus | None,
        content_type: str | None,
        date_from: date | None,
        date_to: date | None,
        page: int,
        page_size: int,
    ) -> tuple[list[MedicalReport], int]:
        return await self.repository.search(
            actor.id,
            query=query,
            category=category,
            status=status,
            content_type=content_type,
            date_from=date_from,
            date_to=date_to,
            page=page,
            page_size=page_size,
        )

    async def timeline(self, actor: User) -> list[MedicalReport]:
        return await self.repository.timeline(actor.id)

    async def delete(self, actor: User, report_id: UUID) -> None:
        report = await self.get(actor, report_id)
        storage_key = report.storage_key
        await self.repository.delete(report)
        await asyncio.to_thread(self.storage.delete, storage_key)

    @staticmethod
    def _detect_type(content: bytes) -> tuple[str, str]:
        if content.startswith(b"%PDF-"):
            return "application/pdf", ".pdf"
        if content.startswith(b"\x89PNG\r\n\x1a\n"):
            return "image/png", ".png"
        if content.startswith(b"\xff\xd8\xff"):
            return "image/jpeg", ".jpg"
        raise InvalidReportUpload
