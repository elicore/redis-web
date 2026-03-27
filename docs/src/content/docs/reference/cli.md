---
title: CLI
description: Main and compatibility binaries.
---

## Binaries

- `redis-web` (canonical)
- `webdis` (compatibility alias)

Both binaries accept the same flags and config file format. Prefer `redis-web`
for new deployments and scripts.

The main `redis-web` binary runs in the foreground and logs to stderr. Let your
process supervisor handle daemonization and log capture.

## Common commands

```bash
redis-web redis-web.min.json
redis-web --config redis-web.json
redis-web --write-minimal-config
redis-web --write-default-config
```

Alias binary:

```bash
webdis webdis.json
```

The alias is temporary and emits a deprecation message.
