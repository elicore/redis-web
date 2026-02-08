use deadpool_redis::redis::Value;
use std::io::{BufRead, Cursor, Read};

#[derive(Debug)]
pub enum RespError {
    InvalidFormat,
    Incomplete,
    Io(std::io::Error),
}

pub fn value_to_resp(v: &Value) -> Vec<u8> {
    match v {
        Value::Nil => b"$-1\r\n".to_vec(),
        Value::Int(i) => format!(":{}\r\n", i).into_bytes(),
        Value::Data(bytes) => {
            let mut res = format!("${}\r\n", bytes.len()).into_bytes();
            res.extend_from_slice(bytes);
            res.extend_from_slice(b"\r\n");
            res
        }
        Value::Bulk(items) => {
            let mut res = format!("*{}\r\n", items.len()).into_bytes();
            for item in items {
                res.extend_from_slice(&value_to_resp(item));
            }
            res
        }
        Value::Status(s) => format!("+{}\r\n", s).into_bytes(),
        Value::Okay => b"+OK\r\n".to_vec(),
    }
}

pub fn parse_command(buffer: &[u8]) -> Result<Option<(Vec<Vec<u8>>, usize)>, RespError> {
    let mut cursor = Cursor::new(buffer);
    let mut line = String::new();

    if cursor.read_line(&mut line).map_err(RespError::Io)? == 0 {
        return Ok(None);
    }

    if !line.starts_with('*') {
        // Simple command parsing (inline) - optional, Webdis usually expects RESP
        // But let's stick to RESP for /.raw
        return Err(RespError::InvalidFormat);
    }

    let count: usize = line[1..]
        .trim()
        .parse()
        .map_err(|_| RespError::InvalidFormat)?;
    let mut args = Vec::with_capacity(count);

    for _ in 0..count {
        line.clear();
        if cursor.read_line(&mut line).map_err(RespError::Io)? == 0 {
            return Ok(None);
        }
        if !line.starts_with('$') {
            return Err(RespError::InvalidFormat);
        }
        let len: usize = line[1..]
            .trim()
            .parse()
            .map_err(|_| RespError::InvalidFormat)?;

        let mut arg = vec![0u8; len];
        if cursor.read_exact(&mut arg).is_err() {
            return Ok(None);
        }

        let mut crlf = [0u8; 2];
        if cursor.read_exact(&mut crlf).is_err() {
            return Ok(None);
        }
        if &crlf != b"\r\n" {
            return Err(RespError::InvalidFormat);
        }

        args.push(arg);
    }

    Ok(Some((args, cursor.position() as usize)))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_value_to_resp() {
        assert_eq!(value_to_resp(&Value::Okay), b"+OK\r\n");
        assert_eq!(value_to_resp(&Value::Int(42)), b":42\r\n");
        assert_eq!(
            value_to_resp(&Value::Data(b"hello".to_vec())),
            b"$5\r\nhello\r\n"
        );
        assert_eq!(
            value_to_resp(&Value::Bulk(vec![Value::Int(1), Value::Okay])),
            b"*2\r\n:1\r\n+OK\r\n"
        );
    }

    #[test]
    fn test_parse_command() {
        let input = b"*2\r\n$3\r\nGET\r\n$4\r\nNAME\r\n";
        let (args, consumed) = parse_command(input).unwrap().unwrap();
        assert_eq!(args, vec![b"GET".to_vec(), b"NAME".to_vec()]);
        assert_eq!(consumed, input.len());
    }

    #[test]
    fn test_parse_incomplete() {
        let input = b"*2\r\n$3\r\nGET\r\n";
        assert!(parse_command(input).unwrap().is_none());
    }
}
