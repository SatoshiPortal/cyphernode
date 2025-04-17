use axum::{http::StatusCode, Json};
use boltz_client::{
    boltz, network::BitcoinChain, network::Chain, swaps::magic_routing::check_for_mrh,
};
use serde::{Deserialize, Serialize};

#[derive(Deserialize)]
pub struct InvoiceRequest {
    invoice: String,
    network: Option<String>, // Optional, will default to Bitcoin
}

#[derive(Serialize)]
pub struct ErrorResponse {
    error: String,
}

#[derive(Serialize)]
pub struct InvoiceData {
    liquid_address: Option<String>,
    amount_sats: Option<u64>,
    original_invoice: String,
}

#[derive(Serialize)]
pub struct InvoiceResponse {
    result: InvoiceData,
}

#[allow(dead_code)]
pub async fn check_bolt11_mrh(
    Json(payload): Json<InvoiceRequest>,
) -> Result<Json<InvoiceResponse>, (StatusCode, Json<ErrorResponse>)> {
    // Determine the network
    let (network, is_testnet) = match payload.network.as_deref() {
        Some("testnet") => (Chain::Bitcoin(BitcoinChain::BitcoinTestnet), true),
        _ => (Chain::Bitcoin(BitcoinChain::Bitcoin), false),
    };

    let boltz_api_url = if is_testnet {
        boltz::BOLTZ_TESTNET_URL_V2
    } else {
        boltz::BOLTZ_MAINNET_URL_V2
    };

    let boltz_client = boltz::BoltzApiClientV2::new(boltz_api_url);

    // Check for magic routing hint
    let check_result = match check_for_mrh(&boltz_client, &payload.invoice, network).await {
        Ok(result) => result,
        Err(e) => {
            return Err((
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(ErrorResponse {
                    error: format!("{:?}", e),
                }),
            ));
        }
    };

    // Prepare response
    let data = match check_result {
        Some((address, amount)) => InvoiceData {
            liquid_address: Some(address),
            amount_sats: Some(amount.to_sat()),
            original_invoice: payload.invoice,
        },
        None => InvoiceData {
            liquid_address: None,
            amount_sats: None,
            original_invoice: payload.invoice,
        },
    };

    let response = InvoiceResponse { result: data };

    Ok(Json(response))
}
