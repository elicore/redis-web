# Embedding Webdis

Use these pages when running Webdis as a library inside another process.

- [Interface reference](./interface-reference.md)
- [Sidecar router in Axum](./sidecar-axum.md)
- [Read-only policy executor](./read-only-policy-executor.md)
- [Tenant-aware parser routing](./tenant-aware-parser.md)
- [Stub executor for tests](./stub-executor-testing.md)

## Choose a pattern

- Use `sidecar-axum` when you want to mount Webdis under an existing API.
- Use `read-only-policy-executor` when writes must be blocked centrally.
- Use `tenant-aware-parser` when request paths should map to DB prefixes.
- Use `stub-executor-testing` when integration tests should avoid Redis.

## Shared prerequisites

1. Add `webdis` as a dependency in your host app crate.
2. Use a Tokio runtime in the host process.
3. Provide a `webdis::config::Config` from file or in-memory JSON.
