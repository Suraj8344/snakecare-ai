# Contributing

## Git strategy

Use trunk-based development with a protected `main` branch and short-lived branches named `feature/<issue>-description`, `fix/<issue>-description`, or `docs/<description>`. Rebase or merge the latest `main`, open a pull request, and require CI plus one review. Prefer squash merges and Conventional Commit messages (`feat:`, `fix:`, `docs:`, `test:`, `refactor:`, `chore:`). Releases use annotated semantic-version tags.

## Definition of done

- Architecture boundaries and API contracts remain explicit.
- Formatting, linting, type checks, unit tests, and integration tests pass.
- Security/privacy impact and migrations are reviewed.
- Public behavior and environment variables are documented.
- Clinical content includes provenance and never blends extracted facts with generated content.

## Coding guidelines

Keep domain code framework-independent. Depend inward through interfaces; inject infrastructure at application boundaries. Use repositories only for persistence, services/use cases for orchestration, Pydantic schemas at HTTP boundaries, immutable/value-oriented models where practical, structured logs without PHI, and typed errors mapped centrally to safe responses. Never commit secrets, Firebase files, tokens, or patient data.

