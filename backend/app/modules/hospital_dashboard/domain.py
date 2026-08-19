from enum import StrEnum


class ClaimStatus(StrEnum):
    PENDING = "pending"
    APPROVED = "approved"
    REJECTED = "rejected"


class InventoryBoxStatus(StrEnum):
    ACTIVE = "active"
    DEPLETED = "depleted"
    QUARANTINED = "quarantined"


class DepletionStatus(StrEnum):
    PENDING = "pending"
    APPROVED = "approved"
    REJECTED = "rejected"


class HospitalDashboardError(Exception):
    status_code = 400
    title = "Hospital dashboard error"
    detail = "The hospital operation could not be completed."


class DashboardPermissionDenied(HospitalDashboardError):
    status_code = 403
    title = "Hospital access denied"
    detail = "This account is not authorized to manage the requested hospital."


class DashboardRecordNotFound(HospitalDashboardError):
    status_code = 404
    title = "Hospital record not found"
    detail = "The requested hospital dashboard record is unavailable."


class DashboardConflict(HospitalDashboardError):
    status_code = 409
    title = "Hospital workflow conflict"
    detail = "This operation has already been completed or conflicts with current state."


class InvalidInventoryToken(HospitalDashboardError):
    status_code = 404
    title = "Invalid antivenom box code"
    detail = "The antivenom box code is invalid or no longer active."


class InvalidDashboardRequest(HospitalDashboardError):
    status_code = 422
    title = "Invalid hospital operation"
    detail = "The submitted hospital operation is invalid."
