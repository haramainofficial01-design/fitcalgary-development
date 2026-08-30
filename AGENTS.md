# Repository working agreement

- Preserve the single-source-of-truth architecture: clients consume the production Go API in `services/api-go`; they never grant roles, approvals, or ranks.
- Flutter/Dart is the primary shared app/frontend stack. Go is required for production backend and integration services. Do not extend the frozen TypeScript API prototype.
- Do not add a second identity provider. V1 uses Keycloak through OIDC/OAuth 2.0; keep provider-specific code behind the auth adapter.
- Treat evidence as private and short-lived. Never expose permanent object URLs or log signed URLs/tokens.
- Keep Calgary as data (`region`, `city`) and FitCalgary as brand configuration.
- Keep demo data explicit and disabled in production.
- Update `docs/IMPLEMENTATION_STATUS.md`, `docs/BLOCKERS.md`, and `docs/TEST_MATRIX.md` when verification state changes.
- Use migrations for every schema change and preserve audit history.
- Before claiming completion, run the proportionate build/test/security gates and record exact evidence.
