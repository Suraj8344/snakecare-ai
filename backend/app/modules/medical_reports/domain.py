from enum import StrEnum


class ReportCategory(StrEnum):
    LAB_RESULT = "lab_result"
    PRESCRIPTION = "prescription"
    IMAGING = "imaging"
    DISCHARGE_SUMMARY = "discharge_summary"
    VACCINATION = "vaccination"
    INSURANCE = "insurance"
    SURGERY = "surgery"
    OTHER = "other"


class ReportStatus(StrEnum):
    PROCESSING = "processing"
    READY = "ready"
    FAILED = "failed"


class ReportError(Exception):
    status_code = 400
    title = "Medical Report request failed"
    detail = "The Medical Report request could not be completed."


class ReportNotFound(ReportError):
    status_code = 404
    title = "Medical Report not found"
    detail = "The requested Medical Report was not found."


class InvalidReportUpload(ReportError):
    status_code = 422
    title = "Invalid Medical Report"
    detail = "Upload a valid PDF, PNG, or JPEG file within the configured size limit."


class ReportStorageFailure(ReportError):
    status_code = 500
    title = "Medical Report storage failed"
    detail = "The Medical Report could not be stored safely."
