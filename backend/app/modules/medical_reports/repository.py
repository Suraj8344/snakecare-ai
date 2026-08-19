from __future__ import annotations

from datetime import date
from typing import cast
from uuid import UUID

from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.medical_reports.domain import ReportCategory, ReportStatus
from app.modules.medical_reports.models import MedicalReport


class SqlAlchemyMedicalReportRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    def add(self, report: MedicalReport) -> None:
        self.session.add(report)

    async def get_owned(self, report_id: UUID, owner_id: UUID) -> MedicalReport | None:
        return cast(
            MedicalReport | None,
            await self.session.scalar(
                select(MedicalReport).where(
                    MedicalReport.id == report_id,
                    MedicalReport.owner_user_id == owner_id,
                )
            ),
        )

    async def search(
        self,
        owner_id: UUID,
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
        filters = [MedicalReport.owner_user_id == owner_id]
        if query:
            pattern = f"%{query.strip()}%"
            filters.append(
                or_(
                    MedicalReport.title.ilike(pattern),
                    MedicalReport.provider_name.ilike(pattern),
                    MedicalReport.original_filename.ilike(pattern),
                    MedicalReport.extracted_text.ilike(pattern),
                    MedicalReport.automated_summary.ilike(pattern),
                )
            )
        if category:
            filters.append(MedicalReport.category == category.value)
        if status:
            filters.append(MedicalReport.status == status.value)
        if content_type:
            filters.append(MedicalReport.content_type == content_type)
        if date_from:
            filters.append(MedicalReport.report_date >= date_from)
        if date_to:
            filters.append(MedicalReport.report_date <= date_to)

        total = int(
            await self.session.scalar(
                select(func.count()).select_from(MedicalReport).where(*filters)
            )
            or 0
        )
        rows = await self.session.scalars(
            select(MedicalReport)
            .where(*filters)
            .order_by(
                MedicalReport.report_date.desc().nullslast(),
                MedicalReport.created_at.desc(),
            )
            .offset((page - 1) * page_size)
            .limit(page_size)
        )
        return list(rows), total

    async def timeline(self, owner_id: UUID, limit: int = 200) -> list[MedicalReport]:
        rows = await self.session.scalars(
            select(MedicalReport)
            .where(MedicalReport.owner_user_id == owner_id)
            .order_by(
                MedicalReport.report_date.desc().nullslast(),
                MedicalReport.created_at.desc(),
            )
            .limit(limit)
        )
        return list(rows)

    async def commit(self) -> None:
        await self.session.commit()

    async def refresh(self, report: MedicalReport) -> None:
        await self.session.refresh(report)

    async def delete(self, report: MedicalReport) -> None:
        await self.session.delete(report)
        await self.session.commit()
