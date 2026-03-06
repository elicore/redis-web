use libc::{c_char, c_int, c_void, size_t};

unsafe extern "C" {
    fn redisConnect(ip: *const c_char, port: c_int) -> *mut c_void;
    fn redisAsyncConnect(ip: *const c_char, port: c_int) -> *mut c_void;
    fn redisReaderCreate() -> *mut c_void;
    fn redisNetClose(ctx: *mut c_void);
    fn sdsnewlen(init: *const c_void, initlen: size_t) -> *mut c_char;
}

#[no_mangle]
pub extern "C" fn redisweb_hiredis_force_link_symbols() {
    unsafe {
        let _ = sdsnewlen(std::ptr::null(), 0);
        let _ = redisReaderCreate();
        let _ = redisConnect(std::ptr::null(), 0);
        let _ = redisAsyncConnect(std::ptr::null(), 0);
        redisNetClose(std::ptr::null_mut());
    }
}
