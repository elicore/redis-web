# Read-Only Policy Executor

Use this pattern when your host process must enforce no-write behavior globally.

## Use case

- Analytics or reporting endpoints should allow only read commands.
- You want policy enforcement in one place, independent of HTTP routes.

## Implementation snippet

```rust
use std::sync::Arc;
use webdis::{
    config::Config,
    executor::RedisCommandExecutor,
    interfaces::{CommandExecutionError, CommandExecutor, ExecutionFuture, RequestParser},
    pubsub::PubSubManager,
    redis,
    request::ParsedRequest,
    server::{self, ServerDependencies},
};

struct ReadOnlyExecutor {
    inner: Arc<dyn CommandExecutor>,
}

impl CommandExecutor for ReadOnlyExecutor {
    fn execute<'a>(&'a self, request: &'a ParsedRequest) -> ExecutionFuture<'a> {
        Box::pin(async move {
            let command = request.command_name.to_ascii_uppercase();
            let blocked = matches!(
                command.as_str(),
                "SET" | "DEL" | "MSET" | "INCR" | "DECR" | "FLUSHDB" | "FLUSHALL"
            );
            if blocked {
                return Err(CommandExecutionError::ExecutionFailed(
                    format!("command {} is disabled in read-only mode", command),
                ));
            }
            self.inner.execute(request).await
        })
    }
}

fn build_read_only_router(config: &Config) -> Result<axum::Router, Box<dyn std::error::Error>> {
    let pool = redis::create_pool(config)?;
    let pools = Arc::new(redis::DatabasePoolRegistry::new(config.clone(), pool));
    let pubsub_client = redis::create_pubsub_client(config)?;
    let pubsub = PubSubManager::new(pubsub_client);

    let base_executor: Arc<dyn CommandExecutor> =
        Arc::new(RedisCommandExecutor::new(pools.clone()));
    let read_only: Arc<dyn CommandExecutor> = Arc::new(ReadOnlyExecutor {
        inner: base_executor,
    });

    let deps = ServerDependencies {
        request_parser: Arc::new(webdis::request::WebdisRequestParser) as Arc<dyn RequestParser>,
        command_executor: read_only,
    };

    Ok(server::build_router_with_dependencies(
        config, deps, pools, pubsub,
    ))
}
```

## Instructions

1. Build the default Redis pool and pubsub manager.
2. Wrap `RedisCommandExecutor` in a policy executor.
3. Inject wrapped executor via `ServerDependencies`.
4. Mount resulting router into your host app.

## Notes

- This pattern keeps policy checks transport-agnostic.
- Extend `blocked` matching with your org-specific command policy.
