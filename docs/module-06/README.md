# Module 6 — Hospital Recommendation and Coordination

## Architecture and rationale

Module 6 connects a patient-owned snakebite emergency case to registered health
facilities without claiming that a recommendation is medical advice or a
confirmed admission. FastAPI owns facility data, timestamped capability and
availability records, transparent ranking, consented pre-alerts, and expiring
resource-readiness requests. Flutter shows the source, age, reasons, warnings,
phone, directions, and sharing controls.

Hospital identity, capability, and live availability are deliberately separate.
A facility may remain registered while its antivenom, bed, ICU, or ventilator
snapshot expires. Expired or absent data is displayed as unknown and never
scored as currently available. Pune map-listed identities may be imported from
OpenStreetMap, but they remain explicitly unverified and contain no inferred
emergency capability or availability claims.

## Safety basis

- WHO says suspected venomous snakebite requires transport to a health facility
  without delay and that early access to trained staff, antivenom, and emergency
  resources is essential.
- WHO notes that distance, transport, cold chain, and stock shortages create
  barriers to timely antivenom access.
- India’s standard treatment guideline recommends referral to the highest level
  of care readily available for severe envenoming.
- ABDM’s Health Facility Registry is the national foundation for verified public
  and private facility identity. HFR identity does not prove current antivenom or
  bed availability, so SnakeCare records those separately.

Official references:

- [WHO snakebite treatment](https://www.who.int/teams/control-of-neglected-tropical-diseases/snakebite-envenoming/treatment)
- [WHO South-East Asia snakebite guidelines](https://www.who.int/southeastasia/publications/i/item/9789290225300)
- [Government of India Standard Treatment Guidelines](https://www.clinicalestablishments.mohfw.gov.in/sites/default/files/standard-treatment-guidelines/3941.pdf)
- [ABDM Health Facility Registry](https://abdm.gov.in/health-facilities)

## Database

- `hospital_facilities`: facility identity, HFR ID, location, contact details,
  source, source timestamp, and active state.
- `hospital_capabilities`: 24/7 emergency, trained staff, antivenom administration,
  ICU, ventilator, dialysis, blood bank, source, and verification time.
- `hospital_availability_snapshots`: expiring antivenom, bed, ICU, and ventilator
  reports.
- `hospital_recommendations`: auditable rank, distance, exact score components,
  reasons, warnings, ruleset, and availability timestamp.
- `hospital_pre_alerts`: patient owner, emergency, hospital, explicitly shared
  payload, pending state, expiry, and safety notice.
- `hospital_resource_requests`: requested readiness categories, state, expiry,
  and later hospital response.

## API

- `GET /api/v1/hospital-coordination/facilities` provides an authenticated,
  paginated directory with source attribution and a safety notice.

- `POST /api/v1/hospital-coordination/facilities` — government/hospital admin
  facility publishing.
- `POST /api/v1/hospital-coordination/facilities/{id}/availability` — timestamped
  availability publishing.
- `POST /api/v1/hospital-coordination/recommendations` — owner-scoped explainable
  recommendations for a snakebite emergency.
- `POST|GET /api/v1/hospital-coordination/pre-alerts` — patient consent and status.
- `POST|GET /api/v1/hospital-coordination/resource-requests` — expiring readiness
  requests and status.

Ranking combines a bounded distance contribution with explicit points for
reported emergency capabilities and a non-expired antivenom snapshot. A current
out-of-stock report applies a penalty. Critical cases receive additional ICU and
ventilator readiness points. Every component is returned to the UI; no opaque
model or diagnosis is used.

## Frontend

The Module 6 landing page displays the imported Pune registry count and up to 50
facility identities. Each imported entry is labelled unverified with live
readiness unavailable.

After saving a Module 5 emergency assessment, the result screen offers **Find
prepared hospitals**. The Module 6 screen supports location refresh, source and
freshness labels, capability chips, antivenom status, explanation and warnings,
call, directions, patient-selected data sharing, pre-alert, and resource
readiness request. It keeps emergency-call and no-delay notices visible.

## Deployment

Apply Alembic migrations `20260808_0008` and `20260808_0009`. In production, facility identity should
be reconciled with ABDM HFR where available. Capability and stock feeds require
authenticated publishers, audit trails, rate limiting, alerting for stale feeds,
and operational service-level agreements. Directions links are external and no
continuous location tracking is implemented. Module 7 will add the hospital
staff dashboard that accepts or rejects pending requests.

### Pune registry synchronization

```powershell
cd backend
..\.venv\Scripts\python.exe -m app.operations.import_pune_hospitals
```

The repeatable importer uses Pune urban search bounds and OpenStreetMap data
under ODbL 1.0, deduplicated by stable map identity. Public map data is not
guaranteed complete or current. Failed map tiles are reported. An imported
record becomes verified only through the authorized HFR, government, or
hospital-management workflow.

## Checklist

- [x] Architecture, rationale, safety research, database, and API design
- [x] Backend implementation
- [x] Flutter implementation
- [x] Unit and integration tests
- [x] Docker and migration verification
- [x] README and roadmap
- [ ] User approval
