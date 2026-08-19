# ADR 0002: Firebase identity with SnakeCare-owned authorization

- Status: Accepted
- Date: 2026-08-06

## Decision

Use Firebase Authentication only to prove user identity. Exchange verified Firebase ID tokens for SnakeCare access and refresh tokens. Store roles and account status in PostgreSQL and enforce them through backend policies.

## Consequences

Google, phone OTP, and email authentication remain managed and replaceable behind an identity-verifier port. Role changes take effect on the next access-token refresh, refresh sessions can be revoked centrally, and a compromised client cannot grant itself a privileged role. The system must operate Firebase projects and securely rotate both Firebase service credentials and the SnakeCare JWT secret.

