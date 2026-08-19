# ADR 0006: Separate facility identity from expiring availability

## Status

Accepted for Module 6.

## Decision

Store facility identity, clinical capability, and resource availability as
separate records with provenance timestamps. Rank facilities with a deterministic
and fully returned score breakdown. Treat missing or expired availability as
unknown. Create patient-consented pre-alerts and resource-readiness requests with
short expiries and a mandatory no-delay notice.

## Consequences

The platform cannot silently turn an old stock report into a current claim, and
recommendations remain auditable. Hospital staff must maintain availability and
respond through the Module 7 workflow. The patient interface may safely return
no live recommendations when verified data is absent.

