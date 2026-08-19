# ADR 0001: Begin with a modular monolith

- Status: Accepted
- Date: 2026-08-06

## Decision

Use a modular monolith with enforced Clean Architecture boundaries and an async FastAPI process. Extract services only when scaling, ownership, reliability, or regulatory isolation provides measured value.

## Consequences

Deployment and local development stay simple, transactions remain reliable, and module seams are testable. The team must prevent cross-module table access and framework leakage through review and tests.

