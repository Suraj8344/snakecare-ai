from typing import Annotated

from fastapi import Depends, Request

from app.api.dependencies import DatabaseSession
from app.modules.medical_reports.processor import ReportProcessor
from app.modules.medical_reports.repository import SqlAlchemyMedicalReportRepository
from app.modules.medical_reports.service import MedicalReportService
from app.modules.medical_reports.storage import LocalReportStorage


def get_medical_report_service(request: Request, session: DatabaseSession) -> MedicalReportService:
    settings = request.app.state.settings
    return MedicalReportService(
        repository=SqlAlchemyMedicalReportRepository(session),
        storage=LocalReportStorage(settings.report_storage_path),
        processor=ReportProcessor(settings.report_max_pdf_pages),
        max_upload_bytes=settings.report_max_upload_bytes,
    )


MedicalReportServiceDependency = Annotated[
    MedicalReportService, Depends(get_medical_report_service)
]
