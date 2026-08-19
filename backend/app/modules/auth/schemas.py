from __future__ import annotations

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

from app.modules.auth.domain import UserRole


class SessionExchangeRequest(BaseModel):
    firebase_id_token: str = Field(min_length=20, max_length=8192)


class RefreshRequest(BaseModel):
    refresh_token: str = Field(min_length=32, max_length=512)


class LogoutRequest(RefreshRequest):
    pass


class UserView(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    email: str | None
    phone_number: str | None
    display_name: str | None
    hospital_employee_id: str | None
    email_verified: bool
    role: UserRole
    status: str
    created_at: datetime


class SessionResponse(BaseModel):
    token_type: str = "bearer"
    access_token: str
    refresh_token: str
    access_expires_at: datetime
    user: UserView


class RoleUpdateRequest(BaseModel):
    role: UserRole
    hospital_employee_id: str | None = Field(
        default=None,
        min_length=3,
        max_length=64,
        pattern=r"^[A-Z0-9][A-Z0-9._/-]*$",
    )

    @field_validator("hospital_employee_id", mode="before")
    @classmethod
    def normalize_hospital_employee_id(cls, value: object) -> object:
        if isinstance(value, str):
            return value.strip().upper()
        return value

    @model_validator(mode="after")
    def validate_hospital_identity(self) -> RoleUpdateRequest:
        if self.role == UserRole.HOSPITAL_ADMIN and self.hospital_employee_id is None:
            raise ValueError("hospital_employee_id is required for hospital administrators")
        if self.role != UserRole.HOSPITAL_ADMIN and self.hospital_employee_id is not None:
            raise ValueError("hospital_employee_id is only valid for hospital administrators")
        if self.role in {UserRole.AMBULANCE_CREW, UserRole.AMBULANCE_DISPATCHER}:
            raise ValueError("ambulance roles are no longer available; use emergency service 112")
        return self
