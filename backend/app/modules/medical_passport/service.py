from __future__ import annotations

from datetime import UTC, datetime
from uuid import UUID

from app.modules.auth.domain import UserRole
from app.modules.auth.models import User
from app.modules.medical_passport.domain import (
    InvalidGrant,
    PassportConflict,
    PassportNotFound,
    PassportPermissionDenied,
)
from app.modules.medical_passport.models import (
    MedicalPassport,
    PassportAccessEvent,
    PassportAccessGrant,
    PassportAllergy,
    PassportCondition,
    PassportEmergencyContact,
    PassportFamilyHistory,
    PassportMedication,
    PassportSurgery,
)
from app.modules.medical_passport.repository import SqlAlchemyMedicalPassportRepository
from app.modules.medical_passport.schemas import GrantCreate, PassportUpdate


class MedicalPassportService:
    def __init__(self, repository: SqlAlchemyMedicalPassportRepository) -> None:
        self.repository = repository

    async def get_own(self, actor: User) -> MedicalPassport:
        passport = await self.repository.get_passport_by_user(actor.id)
        if passport is None:
            passport = MedicalPassport(
                user_id=actor.id,
                full_name=actor.display_name,
                allergies=[],
                conditions=[],
                medications=[],
                emergency_contacts=[],
                surgeries=[],
                family_history=[],
            )
            self.repository.add(passport)
            await self.repository.commit()
            passport = await self.repository.get_passport_by_user(actor.id)
        if passport is None:
            raise PassportNotFound
        return passport

    async def update_own(self, actor: User, payload: PassportUpdate) -> MedicalPassport:
        passport = await self.get_own(actor)
        if passport.version != payload.version:
            raise PassportConflict
        passport.full_name = payload.full_name
        passport.date_of_birth = payload.date_of_birth
        passport.biological_sex = payload.biological_sex.value
        passport.blood_group = payload.blood_group.value
        passport.height_cm = payload.height_cm
        passport.weight_kg = payload.weight_kg
        passport.preferred_language = payload.preferred_language
        passport.organ_donor = payload.organ_donor
        passport.insurance_provider = payload.insurance_provider
        passport.insurance_policy_number = payload.insurance_policy_number
        passport.insurance_member_id = payload.insurance_member_id
        passport.insurance_group_number = payload.insurance_group_number
        passport.insurance_plan_name = payload.insurance_plan_name
        passport.insurance_valid_through = payload.insurance_valid_through
        passport.insurance_emergency_phone = payload.insurance_emergency_phone
        passport.version += 1
        passport.allergies = [
            PassportAllergy(
                allergen=item.allergen.strip(),
                reaction=item.reaction,
                severity=item.severity.value,
            )
            for item in payload.allergies
        ]
        passport.conditions = [
            PassportCondition(
                name=item.name.strip(),
                status=item.status.value,
                diagnosed_on=item.diagnosed_on,
                notes=item.notes,
            )
            for item in payload.conditions
        ]
        passport.medications = [
            PassportMedication(
                name=item.name.strip(),
                dosage=item.dosage,
                frequency=item.frequency,
                route=item.route,
                notes=item.notes,
            )
            for item in payload.medications
        ]
        passport.emergency_contacts = [
            PassportEmergencyContact(
                name=item.name.strip(),
                relationship_name=item.relationship.strip(),
                phone_number=item.phone_number.strip(),
                priority=item.priority,
            )
            for item in payload.emergency_contacts
        ]
        passport.surgeries = [
            PassportSurgery(
                procedure=item.procedure.strip(),
                performed_on=item.performed_on,
                hospital=item.hospital,
                notes=item.notes,
            )
            for item in payload.surgeries
        ]
        passport.family_history = [
            PassportFamilyHistory(
                relationship_name=item.relationship.strip(),
                condition=item.condition.strip(),
                notes=item.notes,
            )
            for item in payload.family_history
        ]
        await self.repository.commit()
        refreshed = await self.repository.get_passport_by_user(actor.id)
        if refreshed is None:
            raise PassportNotFound
        return refreshed

    async def read_patient(
        self, actor: User, patient_id: UUID, request_id: str | None
    ) -> MedicalPassport:
        if actor.id != patient_id:
            allowed_roles = {UserRole.DOCTOR.value, UserRole.HOSPITAL_ADMIN.value}
            grant = await self.repository.get_grant(patient_id, actor.id)
            now = datetime.now(UTC)
            expiry = grant.expires_at if grant else None
            if expiry is not None and expiry.tzinfo is None:
                expiry = expiry.replace(tzinfo=UTC)
            allowed = bool(
                actor.role in allowed_roles
                and grant
                and grant.revoked_at is None
                and expiry
                and expiry > now
            )
            if not allowed:
                self._audit(actor.id, patient_id, "read", "denied", request_id)
                await self.repository.commit()
                raise PassportPermissionDenied
        passport = await self.repository.get_passport_by_user(patient_id)
        if passport is None:
            raise PassportNotFound
        self._audit(actor.id, patient_id, "read", "success", request_id)
        await self.repository.commit()
        return passport

    async def list_grants(self, actor: User) -> list[PassportAccessGrant]:
        return await self.repository.list_grants(actor.id)

    async def grant_access(
        self, actor: User, payload: GrantCreate, request_id: str | None
    ) -> PassportAccessGrant:
        grantee = (
            await self.repository.get_user(payload.grantee_user_id)
            if payload.grantee_user_id is not None
            else await self.repository.get_user_by_email(payload.grantee_email or "")
        )
        if grantee is None or grantee.id == actor.id:
            raise InvalidGrant
        if grantee.role not in {
            UserRole.DOCTOR.value,
            UserRole.HOSPITAL_ADMIN.value,
        }:
            raise InvalidGrant
        grant = await self.repository.get_grant(actor.id, grantee.id)
        if grant is None:
            grant = PassportAccessGrant(
                patient_user_id=actor.id,
                grantee_user_id=grantee.id,
                expires_at=payload.expires_at,
            )
            self.repository.add(grant)
        else:
            grant.expires_at = payload.expires_at
            grant.revoked_at = None
        self._audit(actor.id, actor.id, "grant_created", "success", request_id)
        await self.repository.commit()
        return grant

    async def revoke_grant(self, actor: User, grant_id: UUID, request_id: str | None) -> None:
        grant = await self.repository.get_grant_by_id(grant_id)
        if grant is None or grant.patient_user_id != actor.id:
            raise PassportNotFound
        grant.revoked_at = datetime.now(UTC)
        self._audit(actor.id, actor.id, "grant_revoked", "success", request_id)
        await self.repository.commit()

    def _audit(
        self,
        actor_id: UUID,
        patient_id: UUID,
        action: str,
        outcome: str,
        request_id: str | None,
    ) -> None:
        self.repository.audit(
            PassportAccessEvent(
                actor_user_id=actor_id,
                patient_user_id=patient_id,
                action=action,
                outcome=outcome,
                request_id=request_id,
            )
        )
