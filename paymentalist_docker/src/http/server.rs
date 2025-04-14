use crate::config::Config;
use axum::Router;
use tracing::info;

pub async fn start_server(app: Router, config: Config) -> std::io::Result<()> {
    let listener = tokio::net::TcpListener::bind(format!("{}:{}", config.host, config.port))
        .await
        .unwrap();
    info!("Listening on {}", listener.local_addr().unwrap());

    axum::serve(listener, app)
        .await
        .map_err(|e| std::io::Error::new(std::io::ErrorKind::Other, e))
}
