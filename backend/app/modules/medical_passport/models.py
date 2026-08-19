from __future__ import annotations

from datetime import date, datetime
from decimal import Decimal
from uuid import UUID, uuid4

from sqlalchemy import (
    Boolean,
    CheckConstraint,
    Date,
    DateTime,
    ForeignKey,
    Integer,
    Numeric,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.infrastructure.database.base import Base, UUIDTimestampMixin


class MedicalPassport(UUIDTimestampMixin, Base):
    __tablename__ = "medical_passports"
    __table_args__ = (
        CheckConstraint("version >= 1", name="ck_medical_passports_version"),
        CheckConstraint(
            "height_cm IS NULL OR (height_cm >= 30 AND height_cm <= 275)",
            name="ck_medical_passports_height",
        ),
        CheckConstraint(
            "weight_kg IS NULL OR (weight_kg >= 1 AND weight_kg <= 700)",
            name="ck_medical_passports_weight",
        ),
    )

    user_id: Mapped[UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), unique=True, index=True
    )
    health_id: Mapped[UUID] = mapped_column(default=uuid4, unique=True, index=True)
    full_name: Mapped[str | None] = mapped_column(String(160))
    date_of_birth: Mapped[date | None] = mapped_column(Date)
    biological_sex: Mapped[str] = mapped_column(String(20), default="not_disclosed", nullable=False)
    blood_group: Mapped[str] = mapped_column(String(10), default="unknown", nullable=False)
    height_cm: Mapped[Decimal | None] = mapped_column(Numeric(5, 2))
    weight_kg: Mapped[Decimal | None] = mapped_column(Numeric(6, 2))
    preferred_language: Mapped[str | None] = mapped_column(String(50))
    organ_donor: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    insurance_provider: Mapped[str | None] = mapped_column(String(160))
    insurance_policy_number: Mapped[str | None] = mapped_column(String(120))
    insurance_member_id: Mapped[str | None] = mapped_column(String(120))
    insurance_group_number: Mapped[str | None] = mapped_column(String(120))
    insurance_plan_name: Mapped[str | None] = mapped_column(String(160))
    insurance_valid_through: Mapped[date | None] = mapped_column(Date)
    insurance_emergency_phone: Mapped[str | None] = mapped_column(String(32))
    version: Mapped[int] = mapped_column(Integer, default=1, nullable=False)
    allergies: Mapped[list[PassportAllergy]] = relationship(
        cascade="all, delete-orphan", lazy="selectin"
    )
    conditions: Mapped[list[PassportCondition]] = relationship(
        cascade="all, delete-orphan", lazy="selectin"
    )
    medications: Mapped[list[PassportMedication]] = relationship(
        cascade="all, delete-orphan", lazy="selectin"
    )
    emergency_contacts: Mapped[list[PassportEmergencyContact]] = relationship(
        cascade="all, delete-orphan", lazy="selectin"
    )
    surgeries: Mapped[list[PassportSurgery]] = relationship(
        cascade="all, delete-orphan", lazy="selectin"
    )
    family_history: Mapped[list[PassportFamilyHistory]] = relationship(
        cascade="all, delete-orphan", lazy="selectin"
    )


class PassportAllergy(UUIDTimestampMixin, Base):
    __tablename__ = "passport_allergies"
    passport_id: Mapped[UUID] = mapped_column(
        ForeignKey("medical_passports.id", ondelete="CASCADE"), index=True
    )
    allergen: Mapped[str] = mapped_column(String(120))
    reaction: Mapped[str | None] = mapped_column(String(250))
    severity: Mapped[str] = mapped_column(String(16), default="unknown", nullable=False)


class PassportCondition(UUIDTimestampMixin, Base):
    __tablename__ = "passport_conditions"
    passport_id: Mapped[UUID] = mapped_column(
        ForeignKey("medical_passports.id", ondelete="CASCADE"), index=True
    )
    name: Mapped[str] = mapped_column(String(160))
    status: Mapped[str] = mapped_column(String(16), default="active", nullable=False)
    diagnosed_on: Mapped[date | None] = mapped_column(Date)
    notes: Mapped[str | None] = mapped_column(Text)


class PassportMedication(UUIDTimestampMixin, Base):
    __tablename__ = "passport_medications"
    passport_id: Mapped[UUID] = mapped_column(
        ForeignKey("medical_passports.id", ondelete="CASCADE"), index=True
    )
    name: Mapped[str] = mapped_column(String(160))
    dosage: Mapped[str | None] = mapped_column(String(80))
    frequency: Mapped[str | None] = mapped_column(String(80))
    route: Mapped[str | None] = mapped_column(String(60))
    notes: Mapped[str | None] = mapped_column(Text)


class PassportEmergencyContact(UUIDTimestampMixin, Base):
    __tablename__ = "passport_emergency_contacts"
    passport_id: Mapped[UUID] = mapped_column(
        ForeignKey("medical_passports.id", ondelete="CASCADE"), index=True
    )
    name: Mapped[str] = mapped_column(String(160))
    relationship_name: Mapped[str] = mapped_column("relationship", String(80))
    phone_number: Mapped[str] = mapped_column(String(32))
    priority: Mapped[int] = mapped_column(Integer, default=1, nullable=False)


class PassportSurgery(UUIDTimestampMixin, Base):
    __tablename__ = "passport_surgeries"
    passport_id: Mapped[UUID] = mapped_column(
        ForeignKey("medical_passports.id", ondelete="CASCADE"), index=True
    )
    procedure: Mapped[str] = mapped_column(String(160))
    performed_on: Mapped[date | None] = mapped_column(Date)
    hospital: Mapped[str | None] = mapped_column(String(160))
    notes: Mapped[str | None] = mapped_column(Text)


class PassportFamilyHistory(UUIDTimestampMixin, Base):
    __tablename__ = "passport_family_history"
    passport_id: Mapped[UUID] = mapped_column(
        ForeignKey("medical_passports.id", ondelete="CASCADE"), index=True
    )
    relationship_name: Mapped[str] = mapped_column("relationship", String(80))
    condition: Mapped[str] = mapped_column(String(160))
    notes: Mapped[str | None] = mapped_column(Text)


class PassportAccessGrant(UUIDTimestampMixin, Base):
    __tablename__ = "passport_access_grants"
    __table_args__ = (
        UniqueConstraint("patient_user_id", "grantee_user_id", name="uq_passport_grant_pair"),
    )
    patient_user_id: Mapped[UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    grantee_user_id: Mapped[UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True)
    revoked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), index=True)


class PassportAccessEvent(UUIDTimestampMixin, Base):
    __tablename__ = "passport_access_events"
    actor_user_id: Mapped[UUID | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), index=True
    )
    patient_user_id: Mapped[UUID | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), index=True
    )
    action: Mapped[str] = mapped_column(String(40), index=True)
    outcome: Mapped[str] = mapped_column(String(16))
    request_id: Mapped[str | None] = mapped_column(String(128), index=True)
