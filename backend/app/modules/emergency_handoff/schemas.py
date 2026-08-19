from __future__ import annotations

from datetime import datetime
from typing import Any
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, model_validator

from app.modules.emergency_handoff.domain import OperatorQuestion


class HandoffCreate(BaseModel):
    emergency_id: UUID
    countdown_seconds: int = Field(default=15, ge=10, le=30)
    consent_identity: bool
    consent_location: bool
    consent_emergency_summary: bool
    consent_medical_passport: bool
    consent_voice_assistance: bool

    @model_validator(mode="after")
    def require_explicit_simulation_consent(self) -> HandoffCreate:
        flags = (
            self.consent_identity,
            self.consent_location,
            self.consent_emergency_summary,
            self.consent_medical_passport,
            self.consent_voice_assistance,
        )
        if not all(flags):
            raise ValueError("all simulation disclosures require explicit consent")
        return self


class HandoffEventView(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
    event_type: str
    outcome: str
    safe_details: dict[str, Any]
    message: str | None
    created_at: datetime


class HandoffView(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
    emergency_id: UUID
    simulation_only: bool
    status: str
    response_status: str
    countdown_seconds: int
    consent_identity: bool
    consent_location: bool
    consent_emergency_summary: bool
    consent_medical_passport: bool
    consent_voice_assistance: bool
    structured_summary: dict[str, Any]
    countdown_started_at: datetime | None
    cancelled_at: datetime | None
    manual_call_requested_at: datetime | None
    created_at: datetime
    updated_at: datetime
    events: list[HandoffEventView] = Field(default_factory=list)


class HandoffList(BaseModel):
    items: list[HandoffView]
    total: int


class SimulatedQuestion(BaseModel):
    question: OperatorQuestion


class SimulatedAnswer(BaseModel):
    question: OperatorQuestion
    answer: str
    source: str
    missing: bool
    simulation_only: bool = True
    safety_notice: str = "Simulation only. No information was sent to 112 or ERSS."


class VoiceAssistantQuestion(BaseModel):
    transcript: str = Field(min_length=2, max_length=500)


class VoiceAssistantAnswer(SimulatedAnswer):
    confidence: float = Field(ge=0.0, le=1.0)
    model: str
    ai_scope: str = "intent_classification_only"
    audio_base64: str | None = None
    audio_mime_type: str | None = None
    audio_model: str | None = None
