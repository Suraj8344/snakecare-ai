from __future__ import annotations

from datetime import date, datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, model_validator

from app.modules.hospital_coordination.schemas import AvailabilityView, FacilityView
from app.modules.hospital_dashboard.domain import ClaimStatus, DepletionStatus, InventoryBoxStatus


class ClaimCreate(BaseModel):
    facility_id: UUID
    verification_method: str = Field(min_length=2, max_length=40)
    evidence_reference: str = Field(min_length=3, max_length=500)


class DecisionInput(BaseModel):
    approve: bool
    note: str | None = Field(default=None, max_length=500)


class ClaimView(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
    facility_id: UUID
    requester_user_id: UUID
    verification_method: str
    evidence_reference: str
    status: ClaimStatus
    reviewer_user_id: UUID | None
    review_note: str | None
    reviewed_at: datetime | None
    created_at: datetime
    facility_name: str = ""
    requester_email: str | None = None


class AntivenomBoxCreate(BaseModel):
    box_serial: str = Field(min_length=1, max_length=120)
    product_name: str = Field(min_length=2, max_length=240)
    manufacturer: str = Field(min_length=2, max_length=240)
    batch_number: str = Field(min_length=1, max_length=120)
    expiry_date: date
    initial_vials: int = Field(ge=1, le=10_000)


class AntivenomBoxView(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
    facility_id: UUID
    box_serial: str
    product_name: str
    manufacturer: str
    batch_number: str
    expiry_date: date
    initial_vials: int
    available_vials: int
    status: InventoryBoxStatus
    depleted_at: datetime | None
    created_at: datetime


class AntivenomBoxCreated(AntivenomBoxView):
    qr_token: str
    qr_notice: str


class DepletionScanCreate(BaseModel):
    qr_token: str = Field(min_length=32, max_length=256)
    used_vials: int | None = Field(default=None, ge=1, le=10_000)


class DepletionRequestView(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
    box_id: UUID
    facility_id: UUID
    scanned_by_user_id: UUID
    requested_used_vials: int
    status: DepletionStatus
    reviewer_user_id: UUID | None
    review_note: str | None
    reviewed_at: datetime | None
    created_at: datetime


class AvailabilityPublish(BaseModel):
    emergency_beds: int | None = Field(default=None, ge=0, le=100_000)
    icu_beds: int | None = Field(default=None, ge=0, le=100_000)
    ventilators: int | None = Field(default=None, ge=0, le=100_000)
    expires_in_minutes: int = Field(default=30, ge=5, le=240)


class InboxDecision(BaseModel):
    status: str
    note: str | None = Field(default=None, max_length=500)

    @model_validator(mode="after")
    def valid_status(self) -> InboxDecision:
        if self.status not in {"accepted", "rejected"}:
            raise ValueError("status must be accepted or rejected")
        return self


class DashboardInbox(BaseModel):
    facility: FacilityView
    availability: AvailabilityView | None
    pre_alerts: list[dict[str, object]]
    resource_requests: list[dict[str, object]]
    boxes: list[AntivenomBoxView]
    depletion_requests: list[DepletionRequestView]
