---
title: Deprecated Features
description: Compatibility-only knobs and legacy entrypoints that stay documented for reference.
---

Use this page as the short ledger for features that remain in the tree for
compatibility, but are no longer part of the simple foreground-first runtime
path.

## Process-manager knobs

These config keys are still parsed so older configs keep loading, but the main
`redis-web` binary ignores them:

- `daemonize`
- `pidfile`
- `user`
- `group`
- `logfile`
- `log_fsync`

Keep using your service manager, container runtime, or shell redirection for
daemonization, PID tracking, privilege separation, and log handling.

## Legacy names kept for transition

These names are still accepted to keep migrations smooth:

- `webdis` alias binary
- `webdis.json`
- `webdis.prod.json`
- `webdis.schema.json`
- `webdis.legacy.json`
- `threads` config alias
- `pool_size` config alias

Prefer the `redis-web` names for new deployments and scripts.

## Related references

- [Configuration](/reference/configuration/)
- [CLI](/reference/cli/)
- [Webdis Compatibility and Migration](/compatibility/webdis-compatibility/)
