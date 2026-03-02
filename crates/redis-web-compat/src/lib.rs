use std::path::Path;

pub const CANONICAL_BINARY_NAME: &str = "redis-web";
pub const LEGACY_BINARY_NAME: &str = "webdis";
pub const CANONICAL_CONFIG_NAME: &str = "redis-web.json";
pub const LEGACY_CONFIG_NAME: &str = "webdis.json";
pub const CANONICAL_SCHEMA_PATH: &str = "./redis-web.schema.json";
pub const LEGACY_SCHEMA_PATH: &str = "./webdis.schema.json";

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum InvocationKind {
    Canonical,
    LegacyAlias,
}

impl InvocationKind {
    pub fn default_config_name(self) -> &'static str {
        match self {
            Self::Canonical => CANONICAL_CONFIG_NAME,
            Self::LegacyAlias => LEGACY_CONFIG_NAME,
        }
    }

    pub fn default_schema_path(self) -> &'static str {
        match self {
            Self::Canonical => CANONICAL_SCHEMA_PATH,
            Self::LegacyAlias => LEGACY_SCHEMA_PATH,
        }
    }
}

pub fn resolve_default_config(kind: InvocationKind) -> String {
    match kind {
        InvocationKind::Canonical => {
            if Path::new(CANONICAL_CONFIG_NAME).exists() {
                CANONICAL_CONFIG_NAME.to_string()
            } else if Path::new(LEGACY_CONFIG_NAME).exists() {
                LEGACY_CONFIG_NAME.to_string()
            } else {
                CANONICAL_CONFIG_NAME.to_string()
            }
        }
        InvocationKind::LegacyAlias => LEGACY_CONFIG_NAME.to_string(),
    }
}

pub fn legacy_alias_notice() -> &'static str {
    "[deprecated] `webdis` is an alias for `redis-web` and will be removed in a future release."
}
