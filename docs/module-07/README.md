# Module 7 — Hospital dashboard and approved antivenom QR workflow

Module 7 connects reviewed hospital accounts to operational coordination and inventory. It does not verify a hospital merely because it appears on a map, does not replace the manufacturer barcode, and does not allow a QR scan to change stock automatically.

## 1. Architecture

The module is a vertical Clean Architecture slice:

- FastAPI routes validate role-scoped requests.
- The service layer enforces claim, inbox, inventory, approval, and audit invariants.
- SQLAlchemy repositories isolate PostgreSQL queries and row locks.
- Flutter uses a typed repository and role-aware Material 3 screen.
- Existing Module 6 hospital availability snapshots remain the patient-facing source; Module 7 writes new hospital-reported snapshots after authorized operations.

Flow:

1. A government administrator selects a verified SnakeCare user, assigns a unique hospital employee ID, and grants the hospital-admin role.
2. The hospital-admin account searches the Pune directory and submits a facility claim with an HFR or official evidence reference.
3. A government-admin account approves or rejects the connection.
4. The connected hospital receives pre-alerts and resource requests and can publish expiring resource data.
5. The hospital registers an antivenom box with its manufacturer, batch/lot, expiry, serial, and vial count.
6. SnakeCare returns a one-time random token rendered as an internal QR label.
7. Scanning creates a pending stock-change request.
8. An authorized manager approves or rejects it.
9. Approval updates the box and publishes a fresh aggregate availability snapshot.

## 2. Why this design

- Scan and approval are separate, so accidental or copied QR scans cannot change emergency stock.
- Raw QR tokens are returned only when the label is created; the database stores a hash.
- Database row locks and partial unique indexes protect against repeated or simultaneous actions.
- HFR evidence and SnakeCare connection status are kept separate from clinical-capability verification.
- Inventory snapshots expire, preventing old resource reports from appearing current forever.
- Audit events preserve who did what and when.

GS1 specifies GS1 DataMatrix for healthcare product identification and says custom QR should not replace it. SnakeCare therefore treats its QR only as a workflow pointer.

## 3. Database foundation

Migrations: `20260808_0010_hospital_dashboard_inventory.py` and `20260809_0011_hospital_employee_identity.py`

- `users.hospital_employee_id`: unique, server-controlled hospital staff identifier; valid only with the hospital-admin role.
- `hospital_claim_requests`: facility, requester, evidence method/reference, status, reviewer, note, timestamps.
- `antivenom_boxes`: facility, internal serial, product, manufacturer, batch/lot, expiry, vial counts, token hash, lifecycle status.
- `antivenom_depletion_requests`: scanned box, proposed vial use, scanner, pending/approved/rejected state, reviewer, note.
- `hospital_audit_events`: facility, actor, event type, related entity, safe details, note.
- `hospital_pre_alerts` and `hospital_resource_requests`: responder identity, response note, response timestamp.

No patient data is encoded in a box QR.

## 4. API foundation

All endpoints require a valid Firebase-backed SnakeCare access token.

Government user management:

- `GET /api/v1/auth/users`
- `PATCH /api/v1/auth/users/{id}/role` with `hospital_employee_id` when assigning `hospital_admin`

Hospital claim:

- `POST /api/v1/hospital-dashboard/claims`
- `GET /api/v1/hospital-dashboard/claims/me`
- `GET /api/v1/hospital-dashboard/claims/pending` — government admin
- `POST /api/v1/hospital-dashboard/claims/{id}/decision` — government admin

Hospital operations:

- `GET /api/v1/hospital-dashboard/me`
- `POST /api/v1/hospital-dashboard/pre-alerts/{id}/decision`
- `POST /api/v1/hospital-dashboard/resource-requests/{id}/decision`
- `POST /api/v1/hospital-dashboard/availability`

Inventory:

- `POST /api/v1/hospital-dashboard/antivenom-boxes`
- `POST /api/v1/hospital-dashboard/antivenom-scans`
- `POST /api/v1/hospital-dashboard/antivenom-depletions/{id}/decision`

The Module 6 facility directory also accepts `search=` so an administrator can find one of the Pune facilities before claiming it.

## 5. Backend

Backend code is in `backend/app/modules/hospital_dashboard`. It provides dependency injection, typed Pydantic contracts, service-layer authorization, transaction-safe repository methods, structured errors, and audit records. Approval recomputes non-expired active vial totals rather than trusting a client-supplied aggregate.

## 6. Flutter frontend

Open `http://localhost:8080/?module=7`.

- Government admin home: open **Manage Users & Hospital Staff**, select a verified user, enter the hospital-issued employee ID, and grant access.
- Hospital admin without a connection: search and submit claim.
- Government admin: review pending facility claims.
- Connected hospital admin: resource metrics, emergency inbox, availability publication, box inventory, QR generation, scan intake, and approval/rejection.

For a QR scanned by another phone, build with a reachable HTTPS URL:

```powershell
flutter build web `
  --dart-define=FIREBASE_ENABLED=true `
  --dart-define=API_BASE_URL=https://api.example.org `
  --dart-define=PUBLIC_APP_URL=https://app.example.org
```

`localhost` QR links work only on the same computer. They do not point another phone back to the laptop.

## 7. Tests

Backend integration tests cover validated hospital employee identity assignment, hospital-admin role assignment, claim approval, box registration, pending scans with unchanged stock, approved depletion, fresh out-of-stock publication, and replay rejection. Flutter tests cover the government staff-management entry, QR URL privacy, connected hospital inventory/approval UI, and government claim-review UI.

Verified on 2026-08-08:

- Ruff: passed
- MyPy strict: passed
- Backend: 24 passed; PostgreSQL readiness: passed
- Flutter analyzer: passed
- Flutter tests: 21 passed
- Alembic: `20260808_0010 (head)`
- API, PostgreSQL, and web containers: healthy/running

## 8. Deployment

```powershell
docker compose build api
docker compose run --rm api alembic upgrade head
docker compose up -d api

cd mobile
flutter build web `
  --dart-define=FIREBASE_ENABLED=true `
  --dart-define=API_BASE_URL=http://localhost:8000 `
  --dart-define=PUBLIC_APP_URL=http://localhost:8080
```

Production must use HTTPS, protected secrets, backups, monitoring, a reachable public app URL, a verified claim-review process, and hospital training. Stock remains hospital-reported and must be confirmed during an emergency.

## 9. Module checklist

- [x] Architecture and rationale
- [x] Database migration and constraints
- [x] API contracts and documentation
- [x] FastAPI service/repository/dependency implementation
- [x] Hospital claim and government review workflow
- [x] Government user management and verified hospital employee IDs
- [x] Hospital emergency inbox and resource updates
- [x] Antivenom box register/QR/scan/pending/approve/reject workflow
- [x] Audit events, token hashing, locking, replay protection
- [x] Flutter role-based interface
- [x] Unit/widget/integration tests
- [x] PostgreSQL migration and container verification
- [x] Deployment instructions
- [ ] User approval to begin Module 8

Module 8 has not been started.
