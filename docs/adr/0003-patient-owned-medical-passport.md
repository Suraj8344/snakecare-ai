# ADR 0003: Patient-owned normalized Medical Passport

- Status: Accepted for Module 3
- Date: 2026-08-06

## Decision

The Medical Passport is owned by exactly one patient account. Demographics and emergency attributes live in a versioned passport row; allergies, conditions, medications, and emergency contacts use normalized child tables. The patient may grant time-limited read access to a doctor or hospital administrator. Every non-owner read is audited.

Module 3 stores patient-entered facts only. It does not label those facts as clinically verified, infer diagnoses, generate AI summaries, upload reports, perform OCR, expose emergency QR codes, or provide treatment guidance.

## Consequences

- Atomic snapshot updates avoid partially saved emergency information.
- Optimistic version checks prevent silent overwrites from multiple devices.
- Normalized records support later timelines and provenance without embedding clinical arrays in JSON.
- Application authorization remains enforced by PostgreSQL roles and grants, independent of Firebase identity claims.
