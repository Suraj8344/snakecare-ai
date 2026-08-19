from datetime import date
from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, File, Form, Query, UploadFile, status
from fastapi.responses import FileResponse

from app.modules.auth.dependencies import CurrentUser
from app.modules.medical_reports.dependencies import MedicalReportServiceDependency
from app.modules.medical_reports.domain import ReportCategory, ReportStatus
from app.modules.medical_reports.schemas import ReportList, ReportView

router = APIRouter(prefix="/medical-reports", tags=["medical-reports"])


@router.post("", response_model=ReportView, status_code=status.HTTP_201_CREATED)
async def upload_report(
    service: MedicalReportServiceDependency,
    current_user: CurrentUser,
    file: Annotated[UploadFile, File()],
    title: Annotated[str, Form(min_length=1, max_length=200)],
    report_date: Annotated[date | None, Form()] = None,
    provider_name: Annotated[str | None, Form(max_length=200)] = None,
    notes: Annotated[str | None, Form(max_length=2000)] = None,
    category: Annotated[ReportCategory | None, Form()] = None,
) -> ReportView:
    content = await file.read()
    report = await service.upload(
        current_user,
        title=title,
        report_date=report_date,
        provider_name=provider_name,
        notes=notes,
        category=category,
        filename=file.filename or "report",
        content=content,
    )
    return ReportView.model_validate(report)


@router.get("", response_model=ReportList)
async def search_reports(
    service: MedicalReportServiceDependency,
    current_user: CurrentUser,
    q: str | None = Query(default=None, max_length=200),
    category: ReportCategory | None = None,
    processing_status: ReportStatus | None = None,
    content_type: str | None = Query(default=None, max_length=80),
    date_from: date | None = None,
    date_to: date | None = None,
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100),
) -> ReportList:
    reports, total = await service.search(
        current_user,
        query=q,
        category=category,
        status=processing_status,
        content_type=content_type,
        date_from=date_from,
        date_to=date_to,
        page=page,
        page_size=page_size,
    )
    return ReportList(
        items=[ReportView.model_validate(report) for report in reports],
        total=total,
        page=page,
        page_size=page_size,
    )


@router.get("/timeline", response_model=list[ReportView])
async def report_timeline(
    service: MedicalReportServiceDependency, current_user: CurrentUser
) -> list[ReportView]:
    return [ReportView.model_validate(report) for report in await service.timeline(current_user)]


@router.get("/{report_id}", response_model=ReportView)
async def get_report(
    report_id: UUID,
    service: MedicalReportServiceDependency,
    current_user: CurrentUser,
) -> ReportView:
    return ReportView.model_validate(await service.get(current_user, report_id))


@router.get("/{report_id}/file", response_class=FileResponse)
async def download_report_file(
    report_id: UUID,
    service: MedicalReportServiceDependency,
    current_user: CurrentUser,
) -> FileResponse:
    report, path = await service.file_path(current_user, report_id)
    return FileResponse(
        path,
        media_type=report.content_type,
        filename=report.original_filename,
    )


@router.delete("/{report_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_report(
    report_id: UUID,
    service: MedicalReportServiceDependency,
    current_user: CurrentUser,
) -> None:
    await service.delete(current_user, report_id)
