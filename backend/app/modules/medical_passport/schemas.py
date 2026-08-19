from __future__ import annotations

from datetime import UTC, date, datetime
from decimal import Decimal
from typing import Any
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

from app.modules.medical_passport.domain import (
    AllergySeverity,
    BiologicalSex,
    BloodGroup,
    ConditionStatus,
)


class AllergyInput(BaseModel):
    allergen: str = Field(min_length=1, max_length=120)
    reaction: str | None = Field(default=None, max_length=250)
    severity: AllergySeverity = AllergySeverity.UNKNOWN


class ConditionInput(BaseModel):
    name: str = Field(min_length=1, max_length=160)
    status: ConditionStatus = ConditionStatus.ACTIVE
    diagnosed_on: date | None = None
    notes: str | None = Field(default=None, max_length=1000)

    @field_validator("diagnosed_on")
    @classmethod
    def date_not_future(cls, value: date | None) -> date | None:
        if value and value > date.today():
            raise ValueError("diagnosed_on cannot be in the future")
        return value


class MedicationInput(BaseModel):
    name: str = Field(min_length=1, max_length=160)
    dosage: str | None = Field(default=None, max_length=80)
    frequency: str | None = Field(default=None, max_length=80)
    route: str | None = Field(default=None, max_length=60)
    notes: str | None = Field(default=None, max_length=1000)


class EmergencyContactInput(BaseModel):
    name: str = Field(min_length=1, max_length=160)
    relationship: str = Field(min_length=1, max_length=80)
    phone_number: str = Field(pattern=r"^\+?[0-9 ()-]{7,32}$")
    priority: int = Field(default=1, ge=1, le=5)


class SurgeryInput(BaseModel):
    procedure: str = Field(min_length=1, max_length=160)
    performed_on: date | None = None
    hospital: str | None = Field(default=None, max_length=160)
    notes: str | None = Field(default=None, max_length=1000)

    @field_validator("performed_on")
    @classmethod
    def surgery_date_not_future(cls, value: date | None) -> date | None:
        if value and value > date.today():
            raise ValueError("performed_on cannot be in the future")
        return value


class FamilyHistoryInput(BaseModel):
    relationship: str = Field(min_length=1, max_length=80)
    condition: str = Field(min_length=1, max_length=160)
    notes: str | None = Field(default=None, max_length=1000)


class PassportUpdate(BaseModel):
    version: int = Field(ge=1)
    full_name: str | None = Field(default=None, max_length=160)
    date_of_birth: date | None = None
    biological_sex: BiologicalSex = BiologicalSex.NOT_DISCLOSED
    blood_group: BloodGroup = BloodGroup.UNKNOWN
    height_cm: Decimal | None = Field(default=None, ge=30, le=275, decimal_places=2)
    weight_kg: Decimal | None = Field(default=None, ge=1, le=700, decimal_places=2)
    preferred_language: str | None = Field(default=None, max_length=50)
    organ_donor: bool = False
    insurance_provider: str | None = Field(default=None, max_length=160)
    insurance_policy_number: str | None = Field(default=None, max_length=120)
    insurance_member_id: str | None = Field(default=None, max_length=120)
    insurance_group_number: str | None = Field(default=None, max_length=120)
    insurance_plan_name: str | None = Field(default=None, max_length=160)
    insurance_valid_through: date | None = None
    insurance_emergency_phone: str | None = Field(default=None, pattern=r"^\+?[0-9 ()-]{7,32}$")
    allergies: list[AllergyInput] = Field(default_factory=list, max_length=30)
    conditions: list[ConditionInput] = Field(default_factory=list, max_length=50)
    medications: list[MedicationInput] = Field(default_factory=list, max_length=50)
    emergency_contacts: list[EmergencyContactInput] = Field(default_factory=list, max_length=5)
    surgeries: list[SurgeryInput] = Field(default_factory=list, max_length=50)
    family_history: list[FamilyHistoryInput] = Field(default_factory=list, max_length=50)

    @field_validator("date_of_birth")
    @classmethod
    def birth_date_not_future(cls, value: date | None) -> date | None:
        if value and value > date.today():
            raise ValueError("date_of_birth cannot be in the future")
        return value


class AllergyView(AllergyInput):
    model_config = ConfigDict(from_attributes=True)
    id: UUID


class ConditionView(ConditionInput):
    model_config = ConfigDict(from_attributes=True)
    id: UUID


class MedicationView(MedicationInput):
    model_config = ConfigDict(from_attributes=True)
    id: UUID


class EmergencyContactView(EmergencyContactInput):
    model_config = ConfigDict(from_attributes=True)
    id: UUID

    @model_validator(mode="before")
    @classmethod
    def map_relationship(cls, value: Any) -> Any:
        if hasattr(value, "relationship_name"):
            return {
                "id": value.id,
                "name": value.name,
                "relationship": value.relationship_name,
                "phone_number": value.phone_number,
                "priority": value.priority,
            }
        return value


class SurgeryView(SurgeryInput):
    model_config = ConfigDict(from_attributes=True)
    id: UUID


class FamilyHistoryView(FamilyHistoryInput):
    model_config = ConfigDict(from_attributes=True)
    id: UUID

    @model_validator(mode="before")
    @classmethod
    def map_relationship(cls, value: Any) -> Any:
        if hasattr(value, "relationship_name"):
            return {
                "id": value.id,
                "relationship": value.relationship_name,
                "condition": value.condition,
                "notes": value.notes,
            }
        return value


class PassportView(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
    user_id: UUID
    health_id: UUID
    full_name: str | None
    date_of_birth: date | None
    biological_sex: BiologicalSex
    blood_group: BloodGroup
    height_cm: Decimal | None
    weight_kg: Decimal | None
    preferred_language: str | None
    organ_donor: bool
    insurance_provider: str | None
    insurance_policy_number: str | None
    insurance_member_id: str | None
    insurance_group_number: str | None
    insurance_plan_name: str | None
    insurance_valid_through: date | None
    insurance_emergency_phone: str | None
    version: int
    allergies: list[AllergyView]
    conditions: list[ConditionView]
    medications: list[MedicationView]
    emergency_contacts: list[EmergencyContactView]
    surgeries: list[SurgeryView]
    family_history: list[FamilyHistoryView]
    updated_at: datetime
    data_provenance: str = "patient_reported"


class GrantCreate(BaseModel):
    grantee_user_id: UUID | None = None
    grantee_email: str | None = Field(default=None, min_length=3, max_length=320)
    expires_at: datetime

    @model_validator(mode="after")
    def exactly_one_clinician_identifier(self) -> GrantCreate:
        if (self.grantee_user_id is None) == (self.grantee_email is None):
            raise ValueError("Provide exactly one clinician user ID or email address")
        if self.grantee_email is not None:
            normalized = self.grantee_email.strip().lower()
            if "@" not in normalized:
                raise ValueError("grantee_email must be a valid email address")
            self.grantee_email = normalized
        return self

    @field_validator("expires_at")
    @classmethod
    def expiry_must_be_future(cls, value: datetime) -> datetime:
        normalized = value if value.tzinfo else value.replace(tzinfo=UTC)
        if normalized <= datetime.now(UTC):
            raise ValueError("expires_at must be in the future")
        return normalized


class GrantView(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
    grantee_user_id: UUID
    expires_at: datetime
    revoked_at: datetime | None
    created_at: datetime
