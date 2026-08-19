from __future__ import annotations

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, model_validator

from app.modules.snakebite_emergency.domain import BiteSite, Consciousness, Symptom, Urgency


class VitalsInput(BaseModel):
    pulse_bpm: int | None = Field(default=None, ge=20, le=250)
    respiratory_rate: int | None = Field(default=None, ge=4, le=80)
    oxygen_saturation: int | None = Field(default=None, ge=50, le=100)
    systolic_bp: int | None = Field(default=None, ge=40, le=260)
    diastolic_bp: int | None = Field(default=None, ge=20, le=180)
    temperature_c: float | None = Field(default=None, ge=30, le=45)
    consciousness: Consciousness = Consciousness.ALERT


class EmergencyCreate(BaseModel):
    occurred_at: datetime | None = None
    patient_age_years: int | None = Field(default=None, ge=0, le=120)
    bite_site: BiteSite = BiteSite.UNKNOWN
    symptoms: list[Symptom] = Field(min_length=1, max_length=15)
    symptom_notes: str | None = Field(default=None, max_length=2000)
    voice_transcript: str | None = Field(default=None, max_length=2000)
    latitude: float | None = Field(default=None, ge=-90, le=90)
    longitude: float | None = Field(default=None, ge=-180, le=180)
    location_accuracy_m: float | None = Field(default=None, ge=0, le=100_000)
    location_label: str | None = Field(default=None, max_length=300)
    vitals: VitalsInput = Field(default_factory=VitalsInput)

    @model_validator(mode="after")
    def validate_symptoms_and_location(self) -> EmergencyCreate:
        unique = list(dict.fromkeys(self.symptoms))
        if Symptom.NONE_OBSERVED in unique and len(unique) > 1:
            raise ValueError("none_observed cannot be combined with other symptoms")
        self.symptoms = unique
        if (self.latitude is None) != (self.longitude is None):
            raise ValueError("latitude and longitude must be supplied together")
        return self


class EmergencyView(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    owner_user_id: UUID
    occurred_at: datetime | None
    patient_age_years: int | None
    bite_site: BiteSite
    symptoms: list[Symptom]
    symptom_notes: str | None
    voice_transcript: str | None
    latitude: float | None
    longitude: float | None
    location_accuracy_m: float | None
    location_label: str | None
    pulse_bpm: int | None
    respiratory_rate: int | None
    oxygen_saturation: int | None
    systolic_bp: int | None
    diastolic_bp: int | None
    temperature_c: float | None
    consciousness: Consciousness
    photo_available: bool
    photo_content_type: str | None
    urgency: Urgency
    explanation: list[str]
    immediate_actions: list[str]
    first_aid_steps: list[str]
    actions_to_avoid: list[str]
    ruleset_version: str
    guidance_version: str
    assessment_notice: str
    created_at: datetime
    updated_at: datetime


class EmergencyList(BaseModel):
    items: list[EmergencyView]
    total: int
