//! redis-web core modules.
//!
//! Shared protocol, parsing, formatting, config, ACL, and logging primitives
//! used by runtime and compatibility layers.

pub mod acl;
pub mod config;
pub mod format;
pub mod interfaces;
pub mod logging;
pub mod request;
pub mod resp;
