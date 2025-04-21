use boltz_client::{
    network::{Chain, LiquidChain},
    swaps::{
        boltz::{BoltzApiClientV2, CreateReverseRequest, BOLTZ_MAINNET_URL_V2, BOLTZ_TESTNET_URL_V2},
        magic_routing::{check_for_mrh, sign_address},
    },
    util::{secrets::{Preimage, SwapKey}},
    PublicKey
};

use clap::Parser;

#[derive(Parser, Debug)]
#[command(author, version, about, long_about = None)]
struct Args {
    /// Network to use (mainnet or testnet)
    #[arg(short, long, default_value = "mainnet")]
    network: String,

    /// Claim address for the swap
    #[arg(short, long)]
    claim_address: String,

    /// Invoice amount in satoshis
    #[arg(short, long, default_value = "1000")]
    invoice_amount: u64,
}

#[tokio::main]
async fn main() {
    let args = Args::parse();
    create_reverse_swap(&args.network, &args.claim_address, args.invoice_amount).await;
}

async fn create_reverse_swap(network: &str, claim_address: &str, invoice_amount: u64) {
    let (chain, boltz_api_v2) = match network {
        "testnet" => {
            (Chain::Liquid(LiquidChain::LiquidTestnet), BoltzApiClientV2::new(BOLTZ_TESTNET_URL_V2))
        }
        "mainnet" => {
            (Chain::Liquid(LiquidChain::Liquid), BoltzApiClientV2::new(BOLTZ_MAINNET_URL_V2))
        }
        _ => {
            panic!("Invalid network specified. Use 'testnet' or 'mainnet'.");
        }
    };

    let mnemonic: &str = "bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon";
    let swapkey = SwapKey::from_reverse_account(mnemonic, "", chain.clone(), 0).unwrap();
    let our_keys = swapkey.keypair;
    let claim_public_key = PublicKey {
        compressed: true,
        inner: our_keys.public_key(),
    };
    let preimage = Preimage::new();

    let addrs_sig = sign_address(claim_address, &our_keys).unwrap();

    let create_reverse_req = CreateReverseRequest {
        invoice_amount,
        from: "BTC".to_string(),
        to: "L-BTC".to_string(),
        preimage_hash: preimage.sha256,
        description: None,
        description_hash: None,
        address_signature: Some(addrs_sig.to_string()),
        address: Some(claim_address.to_string()),
        claim_public_key,
        referral_id: None,
        webhook: None,
    };

    let reverse_resp = boltz_api_v2
        .post_reverse_req(create_reverse_req)
        .await
        .unwrap();
    reverse_resp
        .validate(&preimage, &claim_public_key, chain)
        .unwrap();
    println!("VALIDATED RESPONSE!");
    println!("REVERSE SWAP ID: {}", reverse_resp.id);
    println!("INVOICE: {}", reverse_resp.invoice);
}