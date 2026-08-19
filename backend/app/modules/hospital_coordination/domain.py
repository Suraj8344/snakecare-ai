from enum import StrEnum


class FacilityDataSource(StrEnum):
    HFR_VERIFIED = "hfr_verified"
    GOVERNMENT_VERIFIED = "government_verified"
    HOSPITAL_REPORTED = "hospital_reported"
    UNVERIFIED = "unverified"


class StockStatus(StrEnum):
    AVAILABLE = "available"
    LOW = "low"
    OUT_OF_STOCK = "out_of_stock"
    UNKNOWN = "unknown"


class CoordinationStatus(StrEnum):
    PENDING = "pending"
    ACCEPTED = "accepted"
    REJECTED = "rejected"
    EXPIRED = "expired"
    CANCELLED = "cancelled"


class CoordinationError(Exception):
    status_code = 400
    title = "Hospital coordination error"
    detail = "The hospital coordination request could not be completed."


class FacilityNotFound(CoordinationError):
    status_code = 404
    title = "Hospital not found"
    detail = "The requested hospital is unavailable."


class EmergencyNotEligible(CoordinationError):
    status_code = 404
    title = "Emergency case not found"
    detail = "The emergency case is unavailable for this account."


class InvalidCoordinationRequest(CoordinationError):
    status_code = 422
    title = "Invalid coordination request"
    detail = "Select valid information or resources for this request."


class PreAlertNotFound(CoordinationError):
    status_code = 404
    title = "Pre-alert not found"
    detail = "The hospital pre-alert is unavailable for this account."
