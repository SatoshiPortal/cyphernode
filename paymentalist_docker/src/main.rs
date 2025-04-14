use crate::api::lightning::check_bolt11_mrh;
use crate::config::Config;
use axum::{routing::post, Router};
use http::server::start_server;
use std::io;
use tracing::{error, info};
use tracing_subscriber::{fmt, layer::SubscriberExt, util::SubscriberInitExt, EnvFilter};

mod api;
mod config;
mod http;

#[tokio::main]
#[allow(dead_code)]
async fn main() {
    let fmt_layer = fmt::layer().with_writer(io::stdout).with_ansi(false);

    // Set up environment filter with a default that's very permissive
    let env_filter = EnvFilter::try_from_default_env()
        .unwrap_or_else(|_| EnvFilter::new("info,paymentalist=debug,tower_http=debug"));

    // Register both layers
    tracing_subscriber::registry()
        .with(env_filter)
        .with(fmt_layer)
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
