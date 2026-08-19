from enum import StrEnum


class BiologicalSex(StrEnum):
    FEMALE = "female"
    MALE = "male"
    INTERSEX = "intersex"
    UNKNOWN = "unknown"
    NOT_DISCLOSED = "not_disclosed"


class BloodGroup(StrEnum):
    A_POSITIVE = "A+"
    A_NEGATIVE = "A-"
    B_POSITIVE = "B+"
    B_NEGATIVE = "B-"
    AB_POSITIVE = "AB+"
    AB_NEGATIVE = "AB-"
    O_POSITIVE = "O+"
    O_NEGATIVE = "O-"
    UNKNOWN = "unknown"


class AllergySeverity(StrEnum):
    MILD = "mild"
    MODERATE = "moderate"
    SEVERE = "severe"
    UNKNOWN = "unknown"


class ConditionStatus(StrEnum):
    ACTIVE = "active"
    RESOLVED = "resolved"
    UNKNOWN = "unknown"


class PassportError(Exception):
    status_code = 400
    title = "Medical Passport request failed"
    detail = "The Medical Passport request could not be completed."


class PassportPermissionDenied(PassportError):
    status_code = 403
    title = "Medical Passport access denied"
    detail = "Access to this Medical Passport is not permitted."


class PassportNotFound(PassportError):
    status_code = 404
    title = "Medical Passport not found"
    detail = "The requested Medical Passport was not found."


class PassportConflict(PassportError):
    status_code = 409
    title = "Medical Passport changed"
    detail = "This Medical Passport changed on another device. Reload and try again."


class InvalidGrant(PassportError):
    status_code = 422
    title = "Invalid access grant"
    detail = "Access can only be granted to an eligible clinician account."
