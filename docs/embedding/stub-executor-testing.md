# Stub Executor For Testing

Use this pattern when host-app integration tests should not depend on a real Redis instance.

## Use case

- CI tests where deterministic responses are enough.
- Contract tests for routing, auth, and response formatting.

## Implementation snippet

```rust
use std::{collections::HashMap, sync::Arc};
use tokio::sync::RwLock;
use webdis::{
    interfaces::{CommandExecutionError, CommandExecutor, ExecutionFuture},
    request::ParsedRequest,
};

struct MemoryStubExecutor {
    values: Arc<RwLock<HashMap<String, Vec<u8>>>>,
}

impl CommandExecutor for MemoryStubExecutor {
    fn execute<'a>(&'a self, request: &'a ParsedRequest) -> ExecutionFuture<'a> {
        Box::pin(async move {
            let cmd = request.command_name.to_ascii_uppercase();
            match cmd.as_str() {
                "GET" => {
                    let key = request.args.first().cloned().unwrap_or_default();
                    let map = self.values.read().await;
                    let value = map.get(&key).cloned().unwrap_or_default();
                    Ok(redis::Value::BulkString(value))
                }
                "SET" => {
                    let key = request.args.first().cloned().unwrap_or_default();
                    let value = request
                        .args
                        .get(1)
                        .map(|v| v.as_bytes().to_vec())
                        .or_else(|| request.body_arg.clone())
                        .unwrap_or_default();
                    let mut map = self.values.write().await;
                    map.insert(key, value);
                    Ok(redis::Value::Okay)
                }
                _ => Err(CommandExecutionError::ExecutionFailed(format!(
                    "stub does not implement {}",
                    cmd
                ))),
            }
        })
    }
}
```

## Instructions

1. Instantiate `MemoryStubExecutor` in your test setup.
2. Inject it with `build_router_with_dependencies`.
3. Run HTTP-level tests against your host app.
4. Assert status/body/content-type without provisioning Redis.

## Notes

- Keep this stub minimal and deterministic.
- Add only commands your tests actually need.
