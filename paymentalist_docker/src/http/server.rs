use crate::config::Config;
use axum::Router;
use tower_http::trace::DefaultMakeSpan;
use tower_http::trace::DefaultOnFailure;
use tower_http::trace::DefaultOnRequest;
use tower_http::trace::DefaultOnResponse;
use tower_http::trace::TraceLayer;
use tracing::info;

use super::middleware;

pub async fn start_server(app: Router, config: Config) -> std::io::Result<()> {
    let listener = tokio::net::TcpListener::bind(format!("{}:{}", config.host, config.port))
        .await
        .unwrap();
    info!("Listening on {}", listener.local_addr().unwrap());

    // Add logging middleware
    let app = app
        .layer(
            TraceLayer::new_for_http()
                .make_span_with(DefaultMakeSpan::new().level(tracing::Level::INFO))
                .on_request(DefaultOnRequest::new().level(tracing::Level::INFO))
                .on_response(DefaultOnResponse::new().level(tracing::Level::INFO))
                .on_failure(DefaultOnFailure::new().level(tracing::Level::ERROR)),
        )
        .layer(axum::middleware::from_fn(middleware::log_request_response));

    axum::serve(listener, app)
        .await
        .map_err(std::io::Error::other)
}
