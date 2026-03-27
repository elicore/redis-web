fn main() {
    redis_web::run_grpc(redis_web_compat::InvocationKind::Canonical);
}
