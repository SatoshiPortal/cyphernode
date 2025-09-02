use crate::api::lightning::check_bolt11_mrh;
use crate::config::Config;
use axum::{routing::post, Router};
use http::server::start_server;
use std::io;
use std::fs;
use std::os::unix::fs::PermissionsExt;
use tracing::{error, info};
use tracing_subscriber::{fmt, layer::SubscriberExt, util::SubscriberInitExt, EnvFilter};

mod api;
mod config;
mod http;

#[tokio::main]
#[allow(dead_code)]
async fn main() {
    // Set up stdout logging
    let stdout_layer = fmt::layer()
        .with_writer(io::stdout)
        .with_ansi(false);

    // Set up file logging
    let log_path = "/cnlogs/paymentalist.log";
    let file_appender = tracing_appender::rolling::never("/cnlogs", "paymentalist.log");
    let file_layer = fmt::layer()
        .with_writer(file_appender)
        .with_ansi(false);

    // Set file permissions to 600 (rw for owner only)
    if let Ok(metadata) = fs::metadata(log_path) {
        let mut permissions = metadata.permissions();
        permissions.set_mode(0o600); // Set to rw------- (600)
        fs::set_permissions(log_path, permissions).expect("Failed to set log file permissions");
    }

    // Set up environment filter with a default that's very permissive
    let env_filter = EnvFilter::try_from_default_env()
        .unwrap_or_else(|_| EnvFilter::new("info,paymentalist=debug,tower_http=debug"));

    // Register all layers
    tracing_subscriber::registry()
        .with(env_filter)
        .with(stdout_layer)
        .with(file_layer)
        .init();

    info!("Starting Paymentalist service");

    match Config::from_file("config/settings.toml") {
        Ok(config) => {
            info!("Config loaded: {:?}", config);

            let app = Router::new().route("/check_bolt11_mrh", post(check_bolt11_mrh));

            info!("Starting server...");

            if let Err(e) = start_server(app, config).await {
                error!("Failed to start server: {}", e);
                std::process::exit(1);
            }

            info!("Server started successfully");
        }
        Err(e) => {
            error!("Failed to load config: {}", e);
            std::process::exit(1);
        }
    }
}
