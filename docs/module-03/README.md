# Module 3 — Patient Medical Passport

## Scope and safety boundary

Module 3 provides a patient-owned emergency medical profile containing a unique Health ID, a privacy-preserving Health ID QR, demographics, blood group, allergies, diseases/conditions, surgeries, current medicines, family history, insurance details, and emergency contacts. Insurance fields cover provider, plan, policy/member/group identifiers, validity date, and insurer emergency phone. Data is entered by the patient and displayed as **patient-reported**. The QR contains only a Health ID reference; medical information still requires authenticated, authorized access. This module provides no diagnosis, triage, treatment recommendation, clinical verification, AI summary, document upload, OCR, hospital workflow, or medical advice.

## Architecture and rationale

The feature follows the existing Clean Architecture boundary:

1. FastAPI routes validate transport contracts and resolve the authenticated actor.
2. `MedicalPassportService` enforces ownership, role, grant, expiry, and optimistic-version rules.
3. `SqlAlchemyMedicalPassportRepository` owns persistence and atomic transactions.
4. Normalized SQLAlchemy models preserve future provenance and timeline extensibility.
5. Flutter uses feature-local domain models, a Dio repository, Riverpod state, and Material 3 presentation.

Firebase remains identity-only. The local `users` row is authoritative for roles. Passport data never enters Firebase. PostgreSQL is the system of record because relational constraints, transactions, auditability, and controlled migrations are essential for sensitive health information.

## Authorization model

| Actor | Own passport | Another patient's passport | Modify passport | Manage grants |
|---|---:|---:|---:|---:|
| Patient | Read | No | Own only | Own only |
| Doctor | Read own if present | Only with active grant | Own only | Own only |
| Hospital administrator | Read own if present | Only with active grant | Own only | Own only |
| Government administrator | Read own if present | No blanket clinical access | Own only | Own only |

Access grants are read-only, revocable, and expire. Only doctor and hospital-administrator accounts can receive grants. Successful and denied non-owner access attempts are audited without storing medical payloads in logs.

## Database design

- `medical_passports`: one-to-one with `users`; unique Health ID, demographics, blood group, physical attributes, language, donor flag, insurance data, optimistic `version`, timestamps.
- `passport_allergies`: allergen, reaction, severity.
- `passport_conditions`: name, status, diagnosed date, notes.
- `passport_medications`: name, dosage, frequency, route, notes.
- `passport_emergency_contacts`: name, relationship, phone, priority.
- `passport_surgeries`: procedure, date, hospital, notes.
- `passport_family_history`: family relationship, condition, notes.
- `passport_access_grants`: patient, clinician, expiry, revocation.
- `passport_access_events`: actor, patient, action, outcome and request ID; never medical content.

Child snapshots are replaced atomically in one transaction and use bounded list sizes.

## API contracts

| Method | Path | Purpose |
|---|---|---|
| GET | `/api/v1/medical-passport/me` | Read or initialize the actor's passport |
| PUT | `/api/v1/medical-passport/me` | Replace the actor's snapshot using `version` |
| GET | `/api/v1/medical-passports/{patient_id}` | Read with ownership or active clinical grant |
| GET | `/api/v1/medical-passport/access-grants` | List grants issued by the actor |
| POST | `/api/v1/medical-passport/access-grants` | Grant time-limited clinician read access |
| DELETE | `/api/v1/medical-passport/access-grants/{grant_id}` | Revoke a grant |

Errors use the shared problem response. Conflicts return `409`; unauthorized access fails closed. Dates use ISO 8601 and timestamps use UTC.

## Validation and privacy

Bounded strings and collections limit abuse. Controlled enums cover blood group, sex, severity, and condition status. Dates cannot be future dates. Height and weight have plausible storage bounds but are not medically interpreted. Phone numbers and medical content are never logged. Production requires TLS, encrypted managed PostgreSQL and backups, secrets management, retention controls, audit monitoring, and applicable healthcare/privacy review.

## Deployment

Run `alembic upgrade head` as a release job before exposing the application. Back up PostgreSQL before migration, deploy the API, verify readiness, then publish Flutter. Production health data must never be destroyed without an approved retention and recovery procedure.

## Checklist

- [x] Architecture and rationale
- [x] Database and API design
- [x] Backend, migration, and authorization
- [x] Flutter UI and secure API integration
- [x] Unit and integration tests
- [x] Deployment and build verification
- [ ] Module 3 approval
