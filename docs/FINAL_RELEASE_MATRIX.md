# Final release matrix

| Surface | Source complete | Tested | Build pass | Production config ready | Signed | Deployed | Physical-device verified | Store ready | External blocker |
|---|---|---|---|---|---|---|---|---|---|
| Responsive web | PASS | PASS | PASS | PASS | NOT_APPLICABLE | BLOCKED_EXTERNAL | NOT_APPLICABLE | BLOCKED_EXTERNAL | Hosting/domain/TLS |
| Admin web | PASS | PASS | PASS | PASS | NOT_APPLICABLE | BLOCKED_EXTERNAL | NOT_APPLICABLE | NOT_APPLICABLE | Hosting/domain/TLS |
| Go API | PASS | PASS | PASS | PASS | NOT_APPLICABLE | BLOCKED_EXTERNAL | NOT_APPLICABLE | NOT_APPLICABLE | Hosting/database/secrets |
| PostgreSQL | PASS | PASS | PASS | PASS | NOT_APPLICABLE | BLOCKED_EXTERNAL | NOT_APPLICABLE | NOT_APPLICABLE | Managed database/backups |
| iOS | PASS | PASS | PASS | PASS | BLOCKED_EXTERNAL | BLOCKED_EXTERNAL | BLOCKED_EXTERNAL | BLOCKED_EXTERNAL | Apple team/signing/store access |
| Android | PASS | PASS | PASS | PASS | BLOCKED_EXTERNAL | BLOCKED_EXTERNAL | BLOCKED_EXTERNAL | BLOCKED_EXTERNAL | Play account/upload key |
| Apple Watch | PASS | PASS | PASS | PASS | BLOCKED_EXTERNAL | BLOCKED_EXTERNAL | BLOCKED_EXTERNAL | BLOCKED_EXTERNAL | Apple team/watch hardware |

`PASS` reflects source and local build/test evidence; `BLOCKED_EXTERNAL` is used
only where an account, credential, hosting service, or physical device is still
required. Simulator and emulator results are never physical-device verification.
