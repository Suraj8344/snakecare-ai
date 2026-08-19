# ADR 0005: Explainable snakebite emergency decision support

## Status

Accepted for Module 5.

## Decision

Use a deterministic, versioned, conservative rules engine for pre-hospital
urgency support. Persist the exact user-reported inputs, triggered rules,
recommended action, and ruleset version. Treat voice as a device speech-service input
method and store only the confirmed transcript. Treat photos as private
evidence and never infer a snake species from them in Module 5.

## Consequences

Results are auditable, reproducible, and explainable. The workflow cannot
claim clinical diagnosis or learn from new data automatically. Changing any
threshold or clinical rule requires a new version, tests, documentation, and
clinical review. Later validated AI may complement this engine but must not
silently replace its safety floor.
