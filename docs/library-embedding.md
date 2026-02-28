# Library Embedding Guide

Webdis can run as either:

- CLI service (current `src/main.rs`).
- Embedded library router inside another host process.

For embedding patterns and interface-specific examples, use the dedicated pages:

- [Embedding index](./embedding/README.md)
- [Interface reference](./embedding/interface-reference.md)
- [Sidecar router in Axum](./embedding/sidecar-axum.md)
- [Read-only policy executor](./embedding/read-only-policy-executor.md)
- [Tenant-aware parser routing](./embedding/tenant-aware-parser.md)
- [Stub executor for tests](./embedding/stub-executor-testing.md)
