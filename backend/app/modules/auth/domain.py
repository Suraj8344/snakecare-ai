from __future__ import annotations

from dataclasses import dataclass
from enum import StrEnum


class UserRole(StrEnum):
    PATIENT = "patient"
    DOCTOR = "doctor"
    HOSPITAL_ADMIN = "hospital_admin"
    AMBULANCE_CREW = "ambulance_crew"
    AMBULANCE_DISPATCHER = "ambulance_dispatcher"
    GOVERNMENT_ADMIN = "government_admin"


class UserStatus(StrEnum):
    ACTIVE = "active"
    DISABLED = "disabled"


@dataclass(frozen=True, slots=True)
class VerifiedIdentity:
    firebase_uid: str
    email: str | None
    email_verified: bool
    phone_number: str | None
    display_name: str | None


class AuthError(Exception):
    status_code = 401
    title = "Authentication failed"


class InvalidCredentialsError(AuthError):
    pass


class AccountDisabledError(AuthError):
    status_code = 403
    title = "Account disabled"


class PermissionDeniedError(AuthError):
    status_code = 403
    title = "Permission denied"


class RoleAssignmentConflictError(AuthError):
    status_code = 409
    title = "Role assignment conflict"


class SessionExpiredError(AuthError):
    pass
