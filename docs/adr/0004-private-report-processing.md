# ADR 0004: Private report storage and replaceable processing pipeline

## Decision

Store report metadata and derived content in PostgreSQL, keep original binaries
in private storage, and access OCR/categorization/summary logic through a
replaceable processor interface.

## Why

Binary files have different scaling, encryption, lifecycle, and delivery needs
than transactional metadata. A replaceable boundary supports local development
today and encrypted object storage plus queued workers in production. Derived
text and summaries remain traceable to an immutable file digest.

## Consequences

All file reads require application authorization. Deployments must back up both
database and object storage consistently. Processing failure does not destroy
the original upload and is represented explicitly in report state.
