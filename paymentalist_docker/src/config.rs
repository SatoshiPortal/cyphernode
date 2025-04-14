use serde::Deserialize;
use std::error::Error;
use tracing::{debug, error, info};

#[derive(Debug, Deserialize)]
pub struct Config {
    pub host: String,
    pub port: String,
}

impl Config {
    pub fn from_file(path: &str) -> Result<Self, Box<dyn Error>> {
        debug!("Loading config from path: {}", path);
        let config_str = std::fs::read_to_string(path)?;
        debug!("Config file content: {}", config_str);

        match toml::de::from_str::<Config>(&config_str) {
            Ok(config) => {
                info!("Successfully parsed config");
                Ok(config)
            }
            Err(e) => {
                error!("Failed to parse config: {:?}", e);
                Err(e.into())
            }
        }
    }
}
