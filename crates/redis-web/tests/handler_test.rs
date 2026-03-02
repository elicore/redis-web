use redis_web_runtime::handler::parse_info_output;
use serde_json::json;

#[test]
fn test_parse_info_output() {
    let input = "
# Server
redis_version:7.2.3
uptime_in_seconds:3600

# Clients
connected_clients:1
";
    let expected = json!({
        "redis_version": "7.2.3",
        "uptime_in_seconds": "3600",
        "connected_clients": "1"
    });
    assert_eq!(parse_info_output(input), expected);
}

#[test]
fn test_parse_info_output_empty() {
    assert_eq!(parse_info_output(""), json!({}));
}

#[test]
fn test_parse_info_output_no_colon() {
    let input = "invalid line\nkey:value";
    let expected = json!({"key": "value"});
    assert_eq!(parse_info_output(input), expected);
}
