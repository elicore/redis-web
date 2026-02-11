//! Webdis Rust library modules.
//!
//! The binary in `main.rs` wires these modules into an HTTP/WebSocket gateway
//! that translates Webdis request paths into Redis commands.
//!
//! Notable behavior:
//! - HTTP command routing and output formatting live in `handler` and `format`.
//! - Redis connectivity and pooling, including lazy per-database pool routing
//!   for `/<db>/COMMAND/...` requests, live in `redis`.
//! - Pub/Sub streaming support spans `pubsub` and `websocket`.

pub mod acl;
pub mod config;
pub mod format;
pub mod handler;
pub mod logging;
pub mod pubsub;
pub mod redis;
pub mod resp;
pub mod websocket;
