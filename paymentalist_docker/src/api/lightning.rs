use std::str::FromStr;

use ark::bitcoin::secp256k1::PublicKey;
use ark::lightning::{Bolt11Invoice, Bolt11InvoiceExt};
use axum::{http::StatusCode, Json};
use boltz_client::{
    boltz, network::BitcoinChain, network::Chain, swaps::magic_routing::check_for_mrh,
};
use serde::{Deserialize, Serialize};

#[derive(Deserialize)]
pub struct InvoiceRequest {
    invoice: String,
    network: Option<String>, // Optional, will default to Bitcoin
    // Optional: only report an Ark address of the Ark server with this public key
    ark_server_pubkey: Option<String>,
}

#[derive(Serialize)]
pub struct ErrorResponse {
    error: String,
}

#[derive(Serialize)]
pub struct InvoiceData {
    liquid_address: Option<String>,
    ark_address: Option<String>,
    amount_sats: Option<u64>,
    original_invoice: String,
}

/// The Ark address in the invoice's route hints and the invoice amount, if
/// the invoice asks to be paid on an Ark address of `server`.
fn ark_route_hint(invoice: &str, server: Option<PublicKey>) -> Option<(String, Option<u64>)> {
    let invoice = Bolt11Invoice::from_str(invoice).ok()?;
    let address = invoice.ark_address()?;
    if server.is_some_and(|server| !address.is_for_server(server)) {
        return None;
    }
    let amount = invoice.amount_milli_satoshis().map(|msat| msat.div_ceil(1000));
    Some((address.to_string(), amount))
}

#[derive(Serialize)]
pub struct InvoiceResponse {
    result: InvoiceData,
}

#[allow(dead_code)]
pub async fn check_bolt11_mrh(
    Json(payload): Json<InvoiceRequest>,
) -> Result<Json<InvoiceResponse>, (StatusCode, Json<ErrorResponse>)> {
    let ark_server = match payload.ark_server_pubkey.as_deref().map(PublicKey::from_str) {
        Some(Ok(server)) => Some(server),
        Some(Err(e)) => {
            return Err((
                StatusCode::BAD_REQUEST,
                Json(ErrorResponse {
                    error: format!("invalid ark_server_pubkey: {}", e),
                }),
            ));
        }
        None => None,
    };

    // An Ark address is read from the invoice itself, without asking Boltz.
    if let Some((address, amount_sats)) = ark_route_hint(&payload.invoice, ark_server) {
        return Ok(Json(InvoiceResponse {
            result: InvoiceData {
                liquid_address: None,
                ark_address: Some(address),
                amount_sats,
                original_invoice: payload.invoice,
            },
        }));
    }

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
            ark_address: None,
            amount_sats: Some(amount.to_sat()),
            original_invoice: payload.invoice,
        },
        None => InvoiceData {
            liquid_address: None,
            ark_address: None,
            amount_sats: None,
            original_invoice: payload.invoice,
        },
    };

    let response = InvoiceResponse { result: data };

    Ok(Json(response))
}

#[cfg(test)]
mod test {
    use super::*;

    use ark::bitcoin::hashes::{sha256, Hash};
    use ark::bitcoin::secp256k1::{Keypair, Secp256k1, SecretKey};
    use ark::lightning::ark_address_route_hints;
    use ark::mailbox::MailboxIdentifier;
    use ark::Address;
    use lightning_invoice::{
        Currency, InvoiceBuilder, PaymentSecret, RouteHint, RouteHintHop, RoutingFees,
    };

    fn pubkey(byte: u8) -> PublicKey {
        PublicKey::from_secret_key(&Secp256k1::new(), &SecretKey::from_slice(&[byte; 32]).unwrap())
    }

    /// A signet invoice of 1000.5 sat carrying the given route hints.
    fn invoice_with_hints(hints: &[(PublicKey, u64)]) -> String {
        let secp = Secp256k1::new();
        let node_key = SecretKey::from_slice(&[1; 32]).unwrap();
        let mut builder = InvoiceBuilder::new(Currency::Signet)
            .description("test".into())
            .payment_hash(sha256::Hash::hash(&[0; 32]))
            .payment_secret(PaymentSecret([0; 32]))
            .duration_since_epoch(std::time::Duration::from_secs(1_700_000_000))
            .min_final_cltv_expiry_delta(144)
            .amount_milli_satoshis(1_000_500);
        for (src_node_id, short_channel_id) in hints {
            builder = builder.private_route(RouteHint(vec![RouteHintHop {
                src_node_id: *src_node_id,
                short_channel_id: *short_channel_id,
                fees: RoutingFees { base_msat: 0, proportional_millionths: 0 },
                cltv_expiry_delta: 0,
                htlc_minimum_msat: None,
                htlc_maximum_msat: None,
            }]));
        }
        builder
            .build_signed(|hash| secp.sign_ecdsa_recoverable(hash, &node_key))
            .unwrap()
            .to_string()
    }

    /// An Ark address of the server with key 3.
    fn hint_address() -> Address {
        let secp = Secp256k1::new();
        let vtxo_key = Keypair::from_secret_key(&secp, &SecretKey::from_slice(&[2; 32]).unwrap());
        Address::builder()
            .testnet(true)
            .server_pubkey(pubkey(3))
            .pubkey_policy(vtxo_key.public_key())
            .mailbox(pubkey(4), MailboxIdentifier::from_pubkey(pubkey(5)), &vtxo_key)
            .unwrap()
            .into_address()
            .unwrap()
    }

    #[test]
    fn ark_route_hint_is_reported_for_its_server_only() {
        let address = hint_address();
        let invoice = invoice_with_hints(&ark_address_route_hints(&address).unwrap());
        let found = Some((address.to_string(), Some(1001)));

        assert_eq!(ark_route_hint(&invoice, None), found);
        assert_eq!(ark_route_hint(&invoice, Some(pubkey(3))), found);
        assert_eq!(ark_route_hint(&invoice, Some(pubkey(6))), None);
    }

    #[test]
    fn invoice_without_ark_route_hint_has_no_ark_address() {
        assert_eq!(ark_route_hint(&invoice_with_hints(&[]), None), None);
        assert_eq!(ark_route_hint(&invoice_with_hints(&[(pubkey(7), 42)]), None), None);
        assert_eq!(ark_route_hint("not an invoice", None), None);
    }
}
