# AGENTS.md

This file defines practical workflows and command shortcuts for contributors and coding agents working in `/Users/eli.cohen/dev/my/webdis`.

## Workflows

### 1) Local development loop
1. Build and check compile health.
2. Run fast tests first.
3. Run integration tests when local Redis and ephemeral ports are available.

Commands:
```bash
cargo build --release
cargo test --test config_test
cargo test --test integration_test
```

### 2) Run redis-web locally
Use this when iterating on server behavior with a local config.

```bash
cargo run -p redis-web --release --bin redis-web -- redis-web.json
```

Optional: scaffold a default config file (non-overwriting).
```bash
cargo run -p redis-web -- --write-default-config --config ./redis-web.generated.json
```

### 3) Docker-based smoke workflow
Use this when validating runtime behavior in the compose stack.

```bash
./scripts/compose-smoke.sh
```

Manual alternative:
```bash
docker compose -f docker-compose.dev.yml up --build -d
curl -sS http://127.0.0.1:7379/GET/health
docker compose -f docker-compose.dev.yml down -v
```

### 4) Performance and full test pass
Run before larger merges or release prep.

```bash
make test
make perftest
```

## Command Reference

### Build and cleanup
```bash
make build
make clean
```

### Test targets
```bash
make test
make test_all
cargo test --test config_test
cargo test --test integration_process_boot_test
```

### Helpful scripts
```bash
./scripts/start-redis-web.sh --mode dev
./scripts/start-redis-web.sh --mode run --tag redis-web:dev --config redis-web.json
./scripts/generate-certs.sh
./scripts/import-rdb.sh /absolute/path/to/dump.rdb
./scripts/validate-image.sh --image ghcr.io/elicore/redis-web:latest --method cosign
```

## Contribution Notes

- Prefer fast feedback: `config_test` before full integration tests.
- Keep `redis-web.schema.json` and sample configs aligned when introducing config keys.
- Avoid committing local runtime artifacts such as `redis-web.log`.
