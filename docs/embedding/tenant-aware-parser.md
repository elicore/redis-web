# Tenant-Aware Parser Routing

Use this pattern when request paths encode tenant identity and each tenant maps to a Redis DB.

## Use case

- Multi-tenant API with paths like `/tenant/acme/GET/key`.
- Need centralized tenant-to-DB mapping before command execution.

## Implementation snippet

```rust
use std::collections::HashMap;
use webdis::{
    interfaces::{ParseRequestInput, RequestParser},
    request::{ParsedRequest, RequestParseError, WebdisRequestParser},
};

struct TenantParser {
    tenant_db: HashMap<String, u8>,
    fallback: WebdisRequestParser,
}

impl RequestParser for TenantParser {
    fn parse(&self, input: ParseRequestInput<'_>) -> Result<ParsedRequest, RequestParseError> {
        let mut parts = input.command_path.splitn(3, '/');
        let head = parts.next().unwrap_or_default();
        let tenant = parts.next().unwrap_or_default();
        let remainder = parts.next().unwrap_or_default();

        if head != "tenant" || tenant.is_empty() || remainder.is_empty() {
            return Err(RequestParseError::InvalidCommand(
                "expected /tenant/<tenant-id>/<command...>".to_string(),
            ));
        }

        let Some(database) = self.tenant_db.get(tenant) else {
            return Err(RequestParseError::InvalidCommand(format!(
                "unknown tenant {}",
                tenant
            )));
        };

        let mut parsed = self.fallback.parse(ParseRequestInput {
            command_path: remainder,
            params: input.params,
            default_database: *database,
            body: input.body,
            etag_enabled: input.etag_enabled,
        })?;

        parsed.target_database = *database;
        Ok(parsed)
    }
}
```

## Instructions

1. Add tenant map loading from your own config source.
2. Register `TenantParser` in `ServerDependencies`.
3. Keep `RedisCommandExecutor` unchanged unless tenant-specific policies differ.
4. Validate with requests like `/tenant/acme/GET/some-key`.

## Notes

- This parser keeps tenant routing outside HTTP handler logic.
- You can replace the in-memory map with a cached lookup service.
