from __future__ import annotations

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, HttpUrl, model_validator

from app.modules.hospital_coordination.domain import (
    CoordinationStatus,
    FacilityDataSource,
    StockStatus,
)


class CapabilityInput(BaseModel):
    emergency_24x7: bool = False
    snakebite_trained_staff: bool = False
    can_administer_antivenom: bool = False
    icu: bool = False
    ventilator: bool = False
    dialysis: bool = False
    blood_bank: bool = False
    data_source: FacilityDataSource
    verified_at: datetime


class FacilityCreate(BaseModel):
    hfr_id: str | None = Field(default=None, max_length=100)
    name: str = Field(min_length=2, max_length=240)
    address: str = Field(min_length=4, max_length=1000)
    city: str | None = Field(default=None, max_length=120)
    state: str | None = Field(default=None, max_length=120)
    latitude: float = Field(ge=-90, le=90)
    longitude: float = Field(ge=-180, le=180)
    emergency_phone: str | None = Field(default=None, max_length=32)
    directions_url: HttpUrl | None = None
    data_source: FacilityDataSource
    source_updated_at: datetime
    capabilities: CapabilityInput


class AvailabilityCreate(BaseModel):
    antivenom_status: StockStatus
    antivenom_vials: int | None = Field(default=None, ge=0, le=100_000)
    emergency_beds: int | None = Field(default=None, ge=0, le=100_000)
    icu_beds: int | None = Field(default=None, ge=0, le=100_000)
    ventilators: int | None = Field(default=None, ge=0, le=100_000)
    data_source: FacilityDataSource
    recorded_at: datetime
    expires_at: datetime

    @model_validator(mode="after")
    def validate_expiry(self) -> AvailabilityCreate:
        if self.expires_at <= self.recorded_at:
            raise ValueError("expires_at must be after recorded_at")
        return self


class CapabilityView(CapabilityInput):
    model_config = ConfigDict(from_attributes=True)


class AvailabilityView(AvailabilityCreate):
    model_config = ConfigDict(from_attributes=True)
    id: UUID


class FacilityView(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    hfr_id: str | None
    managed_by_user_id: UUID | None
    name: str
    address: str
    city: str | None
    state: str | None
    latitude: float
    longitude: float
    emergency_phone: str | None
    directions_url: str | None
    data_source: FacilityDataSource
    source_updated_at: datetime
    is_active: bool
    capabilities: CapabilityView
    availability: AvailabilityView | None = None


class FacilityDirectoryResponse(BaseModel):
    items: list[FacilityView]
    total: int
    source_attribution: str
    notice: str


class RecommendationCreate(BaseModel):
    emergency_id: UUID
    latitude: float | None = Field(default=None, ge=-90, le=90)
    longitude: float | None = Field(default=None, ge=-180, le=180)
    max_distance_km: float = Field(default=250, gt=0, le=1000)
    limit: int = Field(default=5, ge=1, le=10)

    @model_validator(mode="after")
    def validate_location(self) -> RecommendationCreate:
        if (self.latitude is None) != (self.longitude is None):
            raise ValueError("latitude and longitude must be supplied together")
        return self


class RecommendationView(BaseModel):
    hospital: FacilityView
    rank: int
    distance_km: float
    score: float
    score_components: dict[str, float]
    reasons: list[str]
    warnings: list[str]
    ruleset_version: str


class RecommendationResponse(BaseModel):
    items: list[RecommendationView]
    generated_at: datetime
    notice: str


class PreAlertCreate(BaseModel):
    emergency_id: UUID
    hospital_id: UUID
    share_symptoms: bool = True
    share_vitals: bool = True
    share_location: bool = True
    share_notes: bool = False

    @model_validator(mode="after")
    def require_shared_data(self) -> PreAlertCreate:
        if not any((self.share_symptoms, self.share_vitals, self.share_location, self.share_notes)):
            raise ValueError("select at least one information category")
        return self


class PreAlertView(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    emergency_id: UUID
    hospital_id: UUID
    shared_payload: dict[str, object]
    status: CoordinationStatus
    expires_at: datetime
    notice: str
    response_note: str | None
    responded_by_user_id: UUID | None
    responded_at: datetime | None
    created_at: datetime


class ResourceRequestCreate(BaseModel):
    pre_alert_id: UUID
    antivenom_readiness: bool = True
    emergency_bed: bool = True
    icu_readiness: bool = False
    ventilator_readiness: bool = False

    @model_validator(mode="after")
    def require_resource(self) -> ResourceRequestCreate:
        if not any(
            (
                self.antivenom_readiness,
                self.emergency_bed,
                self.icu_readiness,
                self.ventilator_readiness,
            )
        ):
            raise ValueError("select at least one resource")
        return self


class ResourceRequestView(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    pre_alert_id: UUID
    hospital_id: UUID
    antivenom_readiness: bool
    emergency_bed: bool
    icu_readiness: bool
    ventilator_readiness: bool
    status: CoordinationStatus
    expires_at: datetime
    response_note: str | None
    responded_by_user_id: UUID | None
    responded_at: datetime | None
    created_at: datetime
