# Sidecar Router In Axum

Use this pattern when Webdis should run beside other HTTP services in one process.

## Use case

- Existing Axum API needs Redis-over-HTTP endpoints.
- Shared runtime, observability, and deployment unit.

## Implementation snippet

```rust
use axum::{routing::get, Router};
use webdis::{config::Config, server};

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let webdis_config = Config::new("webdis.json")?;
    let webdis_router = server::build_router(&webdis_config)?;

    let app = Router::new()
        .route("/healthz", get(|| async { "ok" }))
        .nest("/redis", webdis_router);

    let listener = tokio::net::TcpListener::bind("127.0.0.1:8080").await?;
    axum::serve(listener, app).await?;
    Ok(())
}
```

## Instructions

1. Put Webdis config in `webdis.json` (or deserialize from in-memory JSON).
2. Build the Webdis router once at startup.
3. Mount it under a prefix like `/redis` to avoid route collisions.
4. Run your host app as usual.

## Notes

- CLI-only features like daemonization are intentionally not used here.
- Use `build_router_with_dependencies` when you need custom parser/executor behavior.
