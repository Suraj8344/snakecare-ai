# Module 1 — Project foundation

## Scope and dependencies

This module establishes the repository, Clean Architecture boundaries, environment configuration, PostgreSQL/Alembic foundation, operational API, Material 3 Flutter shell, test harnesses, Docker development stack, CI, Git strategy, and standards. It depends only on the selected toolchains and external PostgreSQL. Redis and Firebase are configuration-ready but not activated.

## Backend

FastAPI uses an application factory, lifespan-managed async SQLAlchemy engine, centralized settings, correlation IDs, structured JSON logging, validation, and problem responses. Dependency providers isolate database sessions. `system_metadata` is a migration-owned operational table, not a healthcare-domain shortcut.

## Frontend

The Flutter shell provides Material 3 light/dark themes, Riverpod dependency injection, GoRouter navigation, a configured Dio client, secure-storage provider, responsive accessible status UI, and loading/error states. It calls only Module 1 health endpoints. Firebase packages are declared; run `flutterfire configure` when real environment projects exist rather than committing invented credentials.

## Tests

Backend unit tests validate settings and health behavior; integration tests exercise readiness against a real PostgreSQL service when `TEST_DATABASE_URL` is set. Flutter tests cover the status screen and API model parsing. CI runs Python lint/type/test and Flutter analyze/test independently.

## Deployment

Local orchestration is in `compose.yaml`. Build the API image with `docker build -f backend/Dockerfile .`. In production, inject secrets, run `alembic upgrade head` once as a release step, deploy at least two API replicas behind HTTPS, and configure `/health` for liveness and `/ready` for readiness. Redis remains off unless a later module defines a cache or queue need.

## Completion checklist

- [x] Architecture and rationale documented
- [x] Initial database rules, model, and migration defined
- [x] Operational API contract defined
- [x] FastAPI backend initialized
- [x] Flutter Material 3 app initialized
- [x] Unit/integration test foundations added
- [x] Docker and CI/CD added
- [x] Git strategy and coding guidelines added
- [x] README and roadmap updated
- [x] Module 2 not started

