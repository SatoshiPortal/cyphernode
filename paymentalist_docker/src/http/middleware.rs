use axum::body::Body;
use axum::http::Request;
use axum::middleware::Next;
use axum::response::IntoResponse;
use std::time::Instant;
use tracing::info;

pub async fn log_request_response(req: Request<Body>, next: Next) -> impl IntoResponse {
    let method = req.method().clone();
    let uri = req.uri().clone();
    let version = req.version();

    info!("Request: {} {} {:?}", method, uri, version);

    let start = Instant::now();
    let res = next.run(req).await;

    let status = res.status();
    let duration = start.elapsed();
    info!("Response: {:?}\nDuration: {:?}", status, duration);

    res
}
