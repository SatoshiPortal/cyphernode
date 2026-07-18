use axum::body::to_bytes;
use axum::body::Body;
use axum::http::Request;
use axum::http::Response;
use axum::middleware::Next;
use axum::response::IntoResponse;
use std::time::Instant;
use tracing::info;

const MAX_BODY_SIZE: usize = 10 * 1024; // 10KB

pub async fn log_request_response(req: Request<Body>, next: Next) -> impl IntoResponse {
    let method = req.method().clone();
    let uri = req.uri().clone();
    let version = req.version();

    // Log request
    let (parts, body) = req.into_parts();
    let bytes = to_bytes(body, MAX_BODY_SIZE).await.unwrap_or_default();
    let body_str = String::from_utf8_lossy(&bytes);
    info!(
        "Request: {} {} {:?}\nBody: {}",
        method, uri, version, body_str
    );

    // Reconstruct request
    let req = Request::from_parts(parts, Body::from(bytes));
    let start = Instant::now();
    let res = next.run(req).await;

    // Log response
    let (parts, body) = res.into_parts();
    let bytes = to_bytes(body, MAX_BODY_SIZE).await.unwrap_or_default();
    let body_str = String::from_utf8_lossy(&bytes);
    let duration = start.elapsed();
    info!(
        "Response: {:?}\nDuration: {:?}\nBody: {}",
        parts.status, duration, body_str
    );

    // Reconstruct response
    Response::from_parts(parts, Body::from(bytes))
}
