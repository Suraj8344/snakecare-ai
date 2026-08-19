# ADR 0007: Approved antivenom inventory events

Status: Accepted for Module 7

## Context

A QR scan is convenient but is not sufficient evidence that antivenom stock was consumed. A copied, repeated, or accidental scan must not immediately change the availability shown to patients. Pharmaceutical product identification must also remain tied to the manufacturer label and regulatory data.

## Decision

- SnakeCare generates a random internal workflow token and stores only its SHA-256 hash.
- The SnakeCare QR is not a pharmaceutical product identifier. The manufacturer label, GS1 DataMatrix, product, manufacturer, batch/lot, expiry, and storage requirements remain authoritative.
- A scan creates a pending depletion request and does not mutate vial count.
- A hospital administrator for the connected facility explicitly approves or rejects that request.
- Approval locks the request and box, prevents replay, subtracts the approved vial count, and creates a fresh hospital availability snapshot.
- Partial unique indexes prevent multiple pending claims for one facility and multiple pending depletion requests for one box.
- Every claim, scan, decision, inventory registration, and availability publication creates an audit event.
- QR links contain no patient, batch, expiry, or stock data.

## Consequences

This adds one confirmation step but prevents a scan alone from publishing incorrect emergency stock. Module 7 supports one connected hospital-manager account per facility. Separation between scanner and approver can be added later when hospital staff memberships and delegated permissions are introduced.
