# Development guide

This repository contains one continuous FitCalgary production codebase. The
Flutter applications, web application, Go service, PostgreSQL schema, Keycloak
configuration, and watchOS companion evolve together against the documented API
contract.

## Engineering boundaries

- Flutter/Dart is the primary shared application stack. Production backend and
  integration services are implemented in `services/api-go`.
- The TypeScript API under `services/api` is a frozen migration reference and is
  not part of the deployment topology.
- V1 identity uses Keycloak through OIDC/OAuth 2.0. Provider-specific behavior
  stays behind the authentication adapter so the provider can be replaced.
- Clients never grant roles, approve submissions, or publish rankings. Those
  decisions are enforced by the Go service.
- Evidence is private and short-lived. Permanent object URLs, signed URLs, and
  tokens must not be exposed in logs or public responses.
- Calgary remains configurable location data and FitCalgary remains brand
  configuration.
- Development seed data must be explicit and disabled in production.

## Change discipline

- Use migrations for every database schema change and preserve audit history.
- Keep secrets outside source control and maintain reproducible placeholders in
  `.env.example`.
- Update `IMPLEMENTATION_STATUS.md`, `BLOCKERS.md`, and `TEST_MATRIX.md` whenever
  implementation or verification status changes.
- Before recording a milestone, run the proportionate build, test, security, and
  platform checks and record exact evidence without treating simulator results as
  physical-device verification.

See [Architecture](ARCHITECTURE.md), [API contract](API_CONTRACT.md),
[Security baseline](SECURITY_BASELINE.md), and the root [README](../README.md) for
setup and system details.
