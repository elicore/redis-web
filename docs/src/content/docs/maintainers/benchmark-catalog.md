---
title: Benchmark Catalog
description: Realistic redis-web deployment use cases, runnable config variants, and the next workload suites to add.
---

Use this catalog when you want benchmark cases that reflect application
requirements instead of synthetic transport-only comparisons.

The current `redis-web-bench` runner can measure three capability groups:

- `common_commands`: REST and gRPC unary command latency/throughput
- `websocket_commands`: REST variants with `websockets = true`
- `streaming_pubsub`: REST SSE and gRPC subscribe delivery

Those suites are enough to benchmark transport choice, worker count, pool
sizing, loopback-vs-service exposure, and realtime connection behavior. They do
not yet model hot-key contention, queue control planes, or sorted-set heavy
reads. Those gaps are listed at the end of this page.

## Runnable Use Cases

Each use case below maps to one or more concrete config variants in
`docs/examples/config/redis-web.use-cases.bench.yaml`.

### 1. Public Edge API Gateway

Application shape:

- Browser and mobile clients hit REST endpoints through a load balancer.
- Requests are mostly small key/value reads and writes.
- Tail latency matters more than absolute throughput.

Relevant data structures:

- Strings
- Hashes
- Small JSON blobs stored as strings
- Counters

Config variants:

- `edge-rest-8-workers`
  - Higher worker count and Redis pool sizing for a moderately loaded edge pod.
- `edge-rest-16-workers`
  - Larger worker and pool footprint to test whether added parallelism helps or
    just increases coordination cost.

What the current runner measures:

- `common_commands`
- `streaming_pubsub` over SSE for fallback browser push

### 2. Browser Realtime Fan-Out

Application shape:

- A web UI receives notifications, presence updates, or live dashboard events.
- The server maintains long-lived browser connections.
- The interesting tradeoff is SSE versus WebSocket behavior under the same Redis
  backend.

Relevant data structures:

- Pub/Sub channels
- Session-state hashes
- Lists or streams for downstream buffering

Config variants:

- `browser-realtime-ws`
  - Enables WebSockets on the REST surface.
- `browser-realtime-sse`
  - Keeps plain REST/SSE and uses higher worker count to compare against the
    WebSocket case.

What the current runner measures:

- `websocket_commands`
- `streaming_pubsub` over SSE

### 3. Internal Service Mesh RPC

Application shape:

- Backend services call `redis-web` inside a cluster or VPC.
- The transport is chosen for service-to-service efficiency, not browser
  compatibility.
- Unary command traffic is mixed with some subscription usage.

Relevant data structures:

- Strings
- Hashes
- Sets
- Sorted sets

Config variants:

- `grpc-mesh-4-workers`
  - Lower-footprint gRPC deployment for a typical service pod.
- `grpc-mesh-8-workers`
  - Higher worker count and larger Redis pool for a busier internal service.
- `grpc-debuggable`
  - Same general shape, but with reflection enabled for local debugging and
    operator tooling.

What the current runner measures:

- `common_commands` over gRPC
- `streaming_pubsub` over gRPC subscribe

### 4. Local Sidecar for Legacy or Monolith Processes

Application shape:

- An application instance talks to a colocated `redis-web` process on loopback.
- The goal is minimal proxy overhead and strong process-level isolation.
- This is common during modernization where direct Redis usage is being wrapped.

Relevant data structures:

- Mixed legacy strings and hashes
- Short-lived counters
- Some Pub/Sub notifications

Config variants:

- `sidecar-loopback`
  - Loopback bind, low worker count, and smaller pool sizing to reflect a
    per-instance sidecar footprint.

What the current runner measures:

- `common_commands`
- `streaming_pubsub`

### 5. Telemetry / Event Ingest Gateway

Application shape:

- Producers emit many small updates.
- Traffic is write-heavy and often bursty.
- The interesting question is how far worker count and pool sizing can be
  pushed before overhead dominates.

Relevant data structures:

- Counters
- Hashes
- Lists
- Streams or append-style event keys

Config variants:

- `ingest-rest-high-pool`
  - Higher `http_threads` and pool sizing for write-heavy REST ingestion.
- `grpc-ingest-8-workers`
  - Equivalent internal-gateway shape over gRPC.

What the current runner measures:

- `common_commands`
- `streaming_pubsub`

Note:

- The current runner does not yet include a write-heavy `INCR`/`HSET`/append
  suite, so this case is still approximated by the generic command mix.

### 6. Analytics or Leaderboard Read Service

Application shape:

- A service reads cached aggregates or leaderboard materialized views for APIs.
- Reads dominate and hot keys are common.
- Sorted-set access and repeated reads of the same keys matter.

Relevant data structures:

- Sorted sets
- Hashes
- Strings

Config variants:

- `edge-rest-8-workers`
- `grpc-mesh-8-workers`

What the current runner measures:

- `common_commands`

Note:

- This is only partially covered today. A sorted-set or hot-key read suite is
  still needed to benchmark leaderboard-heavy applications properly.

## Runnable Spec

The repository includes a runnable spec for the use cases above:

- `docs/examples/config/redis-web.use-cases.bench.yaml`

Run it with:

```bash
make bench_config_compare SPEC=docs/examples/config/redis-web.use-cases.bench.yaml
```

## Next Workload Suites

These are the next suites worth implementing because they unlock realistic
application-specific comparisons that the current v1 runner cannot make.

### 1. Read-Heavy Cache Suite

Operations:

- `GET`
- `MGET`
- `HGET`
- `HMGET`

Why:

- Covers edge cache and metadata-service traffic better than `PING` plus generic
  `SET/GET`.

### 2. Write-Heavy Ingest Suite

Operations:

- `INCR`
- `HSET`
- `LPUSH`
- `XADD` or append-style writes when supported

Why:

- Represents telemetry, counters, and producer-heavy systems.

### 3. Hot-Key Contention Suite

Operations:

- Repeated access to a narrow key set under high concurrency

Why:

- Models rate-limit keys, tenant-global flags, and leaderboard hot spots.

### 4. Queue Control Plane Suite

Operations:

- Push/pop loops
- Ack/retry emulation
- Heartbeat updates

Why:

- Covers worker fleets and job-processing systems.

### 5. Leaderboard / Sorted-Set Suite

Operations:

- `ZADD`
- `ZRANGE`
- `ZREVRANGE`
- `ZSCORE`

Why:

- Necessary for analytics and ranking services where sorted-set behavior drives
  user-facing latency.
