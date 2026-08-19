# Module 2 — Authentication and role-based access

## Architecture and rationale

Firebase Authentication proves identity through email/password, Google, or phone OTP. SnakeCare never receives or stores passwords. The mobile app exchanges a Firebase ID token for a short-lived SnakeCare access JWT and a one-time opaque refresh token. PostgreSQL remains authoritative for application roles and session revocation.

The module follows Clean Architecture:

```text
FastAPI routes / Flutter screens
            ↓
Auth application service and RBAC policies
            ↓
IdentityVerifier + AuthRepository + TokenIssuer ports
            ↑
Firebase Admin + SQLAlchemy + PyJWT adapters
```

This split prevents client-controlled Firebase custom claims from silently becoming SnakeCare authorization. New accounts receive `patient`; `doctor`, `hospital_admin`, and `government_admin` are assigned only by a Government Admin. A deployment-only email allowlist bootstraps the first Government Admin, and requires a verified Firebase email.

## Database design

### `users`

| Column | Purpose |
|---|---|
| `id` UUID | Internal stable identity |
| `firebase_uid` | Unique external identity reference |
| `email`, `phone_number`, `display_name` | Normalized verified profile attributes |
| `email_verified` | Firebase verification state |
| `role` | SnakeCare-owned role enum |
| `status` | Active or disabled |
| `last_login_at`, timestamps | Session/audit lifecycle |

### `refresh_sessions`

Stores only SHA-256 hashes of 256-bit opaque refresh tokens. Sessions are rotated on every refresh; replay of a revoked token is rejected. Expiry and revocation are explicit. Raw IP addresses and user agents are not stored; optional SHA-256 fingerprints support incident correlation without retaining those values.

### `auth_audit_events`

Append-only security events for sign-in, refresh, logout, role changes, and rejected authorization. Details are structured JSON and must never contain tokens, passwords, OTPs, or medical data.

## API contracts

| Method | Path | Authentication | Purpose |
|---|---|---|---|
| POST | `/api/v1/auth/session` | Firebase ID token | Create/update user and issue SnakeCare session |
| POST | `/api/v1/auth/refresh` | Refresh token body | Rotate session and issue new tokens |
| POST | `/api/v1/auth/logout` | Access JWT | Revoke the supplied refresh token/session |
| GET | `/api/v1/auth/me` | Access JWT | Return current identity and role |
| GET | `/api/v1/auth/users` | Government Admin | List accounts for role administration |
| PATCH | `/api/v1/auth/users/{user_id}/role` | Government Admin | Assign an application role |

Access JWTs use `sub`, `role`, `type=access`, `iat`, `exp`, `iss`, `aud`, and `jti`. API errors use the shared problem format. Authentication failures reveal no account-existence details.

## Threat model and controls

- Firebase ID tokens are verified server-side for issuer, audience, signature, expiry, and revocation.
- Access JWTs expire after 15 minutes by default; refresh tokens rotate and are stored only as hashes.
- Role values come from PostgreSQL, never request bodies during registration or client claims.
- Disabled users and revoked/expired sessions fail closed.
- Rate limiting is expected at the edge in production; Firebase also protects its identity endpoints.
- TLS, managed secrets, Firebase App Check, device attestation, and alerting are deployment requirements.

## UI design

Lovable project **SnakeCare Access** (`f81e2e3e-1784-4398-8f74-6897d0a116b2`) was used for bounded visual exploration. Flutter retains the existing feature-first structure, Material 3 theme, Riverpod state, GoRouter guards, Dio interceptors, secure token storage, and accessible loading/error states.

## Deployment

Create separate Firebase projects for development, staging, and production. Generate native/web configuration with FlutterFire; never commit service-account JSON or mobile secrets. Mount the Firebase service account through a secret manager, provide a 32+ character JWT secret, run Alembic as a release job, and restrict the bootstrap administrator allowlist after initial provisioning.

## Checklist

- [x] Architecture, rationale, database, API, and threat model documented
- [x] Backend implementation and migration
- [x] Flutter implementation
- [x] Unit and integration tests
- [x] Docker/runtime verification
- [x] Web and Android build verification
- [x] Module 2 approval (2026-08-06)
