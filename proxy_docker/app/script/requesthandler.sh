#!/bin/sh
#
#
#
#

. ./db/config.sh
. ./sendtobitcoinnode.sh
. ./callbacks_job.sh
. ./watchrequest.sh
. ./unwatchrequest.sh
. ./getactivewatches.sh
. ./confirmation.sh
. ./blockchainrpc.sh
. ./responsetoclient.sh
. ./trace.sh
. ./manage_missed_conf.sh
. ./walletoperations.sh
. ./bitcoin.sh
. ./call_lightningd.sh
. ./ots.sh
. ./newblock.sh
. ./wasabi.sh

main() {
  trace "Entering main()..."

  local step=0
  local cmd
  local http_method
  local line
  local content_length
  local response
  local returncode

  while read line; do
    line=$(echo "${line}" | tr -d '\r\n')
    trace "[main] line=${line}"

    if [ "${cmd}" = "" ]; then
      # First line!
      # Looking for something like:
      # GET /cmd/params HTTP/1.1
      # POST / HTTP/1.1
      cmd=$(echo "${line}" | cut -d '/' -f2 | cut -d ' ' -f1)
      trace "[main] cmd=${cmd}"
      http_method=$(echo "${line}" | cut -d ' ' -f1)
      trace "[main] http_method=${http_method}"
      if [ "${http_method}" = "GET" ]; then
        step=1
      fi
    fi
    if [ "${line}" = "" ]; then
      trace "[main] empty line"
      if [ ${step} -eq 1 ]; then
        trace "[main] body part finished, disconnecting"
        break
      else
        trace "[main] headers part finished, body incoming"
        step=1
      fi
    fi
    # line=content-length: 406
    case "${line}" in *[cC][oO][nN][tT][eE][nN][tT]-[lL][eE][nN][gG][tT][hH]*)
      content_length=$(echo "${line}" | cut -d ':' -f2)
      trace "[main] content_length=${content_length}";
      ;;
    esac
    if [ ${step} -eq 1 ]; then
      trace "[main] step=${step}"
      if [ "${http_method}" = "POST" ] && [ "${content_length}" -gt "0" ]; then
        read -rd '' -n ${content_length} line
        line=$(echo "${line}" | jq -c)
        trace "[main] line=${line}"
      fi
      case "${cmd}" in
        helloworld)
          # GET http://192.168.111.152:8080/helloworld
          response_to_client "Hello, world!" 0
          break
          ;;
        installation_info)
          # GET http://192.168.111.152:8080/info
          if [ -f "$DB_PATH/info.json" ]; then
            response=$(cat "$DB_PATH/info.json")
          else
            response='{ "error": "missing installation data" }'
          fi
          response_to_client "${response}" ${?}
          break
          ;;
        watch)
          # POST http://192.168.111.152:8080/watch
          # BODY {"address":"2N8DcqzfkYi8CkYzvNNS5amoq3SbAcQNXKp","unconfirmedCallbackURL":"192.168.111.233:1111/callback0conf","confirmedCallbackURL":"192.168.111.233:1111/callback1conf"}
          # BODY {"address":"2N8DcqzfkYi8CkYzvNNS5amoq3SbAcQNXKp","confirmedCallbackURL":"192.168.111.233:1111/callback1conf","eventMessage":"eyJib3VuY2VfYWRkcmVzcyI6IjJNdkEzeHIzOHIxNXRRZWhGblBKMVhBdXJDUFR2ZTZOamNGIiwibmJfY29uZiI6MH0K"}

          response=$(watchrequest "${line}")
          response_to_client "${response}" ${?}
          break
          ;;
        unwatch)
          # curl (GET) 192.168.111.152:8080/unwatch/2N8DcqzfkYi8CkYzvNNS5amoq3SbAcQNXKp

          response=$(unwatchrequest "${line}")
          response_to_client "${response}" ${?}
          break
          ;;
        watchxpub)
          # POST http://192.168.111.152:8080/watchxpub
          # BODY {"label":"4421","pub32":"tpubD6NzVbkrYhZ4YR3QK2tyfMMvBghAvqtNaNK1LTyDWcRHLcMUm3ZN2cGm5BS3MhCRCeCkXQkTXXjiJgqxpqXK7PeUSp86DTTgkLpcjMtpKWk","path":"0/n","nstart":0,"unconfirmedCallbackURL":"192.168.111.233:1111/callback0conf","confirmedCallbackURL":"192.168.111.233:1111/callback1conf"}
          # curl -H "Content-Type: application/json" -d '{"label":"2219","pub32":"upub5GtUcgGed1aGH4HKQ3vMYrsmLXwmHhS1AeX33ZvDgZiyvkGhNTvGd2TA5Lr4v239Fzjj4ZY48t6wTtXUy2yRgapf37QHgt6KWEZ6bgsCLpb","path":"0/1/n","nstart":55,"unconfirmedCallbackURL":"192.168.111.233:1111/callback0conf","confirmedCallbackURL":"192.168.111.233:1111/callback1conf"}' proxy:8888/watchxpub

          response=$(watchpub32request "${line}")
          response_to_client "${response}" ${?}
          break
          ;;
        unwatchxpubbyxpub)
          # GET http://192.168.111.152:8080/unwatchxpubbyxpub/tpubD6NzVbkrYhZ4YR3QK2tyfMMvBghAvqtNaNK1LTyDWcRHLcMUm3ZN2cGm5BS3MhCRCeCkXQkTXXjiJgqxpqXK7PeUSp86DTTgkLpcjMtpKWk

          response=$(unwatchpub32request "${line}")
          response_to_client "${response}" ${?}
          break
          ;;
        unwatchxpubbylabel)
          # GET http://192.168.111.152:8080/unwatchxpubbylabel/4421

          response=$(unwatchpub32labelrequest "${line}")
          response_to_client "${response}" ${?}
          break
          ;;
        getactivewatchesbyxpub)
          # GET http://192.168.111.152:8080/getactivewatchesbyxpub/tpubD6NzVbkrYhZ4YR3QK2tyfMMvBghAvqtNaNK1LTyDWcRHLcMUm3ZN2cGm5BS3MhCRCeCkXQkTXXjiJgqxpqXK7PeUSp86DTTgkLpcjMtpKWk

          response=$(getactivewatchesbyxpub $(echo "${line}" | cut -d ' ' -f2 | cut -d '/' -f3))
          response_to_client "${response}" ${?}
          break
          ;;
        getactivewatchesbylabel)
          # GET http://192.168.111.152:8080/getactivewatchesbylabel/4421

          response=$(getactivewatchesbylabel $(echo "${line}" | cut -d ' ' -f2 | cut -d '/' -f3))
          response_to_client "${response}" ${?}
          break
          ;;
        getactivexpubwatches)
          # GET http://192.168.111.152:8080/getactivexpubwatches

          response=$(getactivexpubwatches)
          response_to_client "${response}" ${?}
          break
          ;;
        watchtxid)
          # POST http://192.168.111.152:8080/watchtxid
          # BODY {"txid":"b081ca7724386f549cf0c16f71db6affeb52ff7a0d9b606fb2e5c43faffd3387","confirmedCallbackURL":"192.168.111.233:1111/callback1conf","xconfCallbackURL":"192.168.111.233:1111/callbackXconf","nbxconf":6}
          # curl -H "Content-Type: application/json" -d '{"txid":"b081ca7724386f549cf0c16f71db6affeb52ff7a0d9b606fb2e5c43faffd3387","confirmedCallbackURL":"192.168.111.233:1111/callback1conf","xconfCallbackURL":"192.168.111.233:1111/callbackXconf","nbxconf":6}' proxy:8888/watchtxid

          response=$(watchtxidrequest "${line}")
          response_to_client "${response}" ${?}
          break
          ;;
        getactivewatches)
          # curl (GET) 192.168.111.152:8080/getactivewatches

          response=$(getactivewatches)
          response_to_client "${response}" ${?}
          break
          ;;
        get_txns_by_watchlabel)
          # curl (GET) 192.168.111.152:8080/get_txns_by_watchlabel/<label>/<count>
          response=$(get_txns_by_watchlabel $(echo "${line}" | cut -d ' ' -f2 | cut -d '/' -f3) $(echo "${line}" | cut -d ' ' -f2 | cut -d '/' -f4))
          response_to_client "${response}" ${?}
          break
          ;;
        get_unused_addresses_by_watchlabel)
          # curl (GET) 192.168.111.152:8080/get_unused_addresses_by_watchlabel/<label>/<count>
          response=$(get_unused_addresses_by_watchlabel $(echo "${line}" | cut -d ' ' -f2 | cut -d '/' -f3) $(echo "${line}" | cut -d ' ' -f2 | cut -d '/' -f4))
          response_to_client "${response}" ${?}
          break
          ;;
        conf)
          # curl (GET) 192.168.111.152:8080/conf/b081ca7724386f549cf0c16f71db6affeb52ff7a0d9b606fb2e5c43faffd3387

          response=$(confirmation_request "${line}")
          response_to_client "${response}" ${?}
          break
          ;;
        newblock)
          # curl (GET) 192.168.111.152:8080/newblock/000000000000005c987120f3b6f995c95749977ef1a109c89aa74ce4bba97c1f

          response=$(newblock "${line}")
          response_to_client "${response}" ${?}
          break
          ;;
        getbestblockhash)
          # curl (GET) http://192.168.111.152:8080/getbestblockhash

          response=$(get_best_block_hash)
          response_to_client "${response}" ${?}
          break
          ;;
        getblockhash)
          # curl (GET) http://192.168.111.152:8080/getblockhash/522322

          response=$(get_blockhash $(echo "${line}" | cut -d ' ' -f2 | cut -d '/' -f3))
          response_to_client "${response}" ${?}
          break
          ;;
        getblockinfo)
          # curl (GET) http://192.168.111.152:8080/getblockinfo/000000006f82a384c208ecfa04d05beea02d420f3f398ddda5c7f900de5718ea

          response=$(get_block_info $(echo "${line}" | cut -d ' ' -f2 | cut -d '/' -f3))
          response_to_client "${response}" ${?}
          break
          ;;
        getblockchaininfo)
          # http://192.168.111.152:8080/getblockchaininfo

          response=$(get_blockchain_info)
          response_to_client "${response}" ${?}
          ;;
        gettransaction)
          # curl (GET) http://192.168.111.152:8080/gettransaction/af867c86000da76df7ddb1054b273ca9e034e8c89d049b5b2795f9f590f67648

          response=$(get_rawtransaction $(echo "${line}" | cut -d ' ' -f2 | cut -d '/' -f3))
          response_to_client "${response}" ${?}
          break
          ;;
        getbestblockinfo)
          # curl (GET) http://192.168.111.152:8080/getbestblockinfo

          response=$(get_best_block_info)
          response_to_client "${response}" ${?}
          break
          ;;
        executecallbacks)
          # curl (GET) http://192.168.111.152:8080/executecallbacks

          manage_not_imported
          manage_missed_conf
          response=$(do_callbacks)
          response_to_client "${response}" ${?}
          break
          ;;
        get_txns_spending)
          # curl (GET) http://192.168.111.152:8080/get_txns_spending/20/10

          response=$(get_txns_spending $(echo "${line}" | cut -d ' ' -f2 | cut -d '/' -f3) $(echo "${line}" | cut -d ' ' -f2 | cut -d '/' -f4))
          response_to_client "${response}" ${?}
          break
          ;;
        getbalance)
          # curl (GET) http://192.168.111.152:8080/getbalance

          response=$(getbalance)
          response_to_client "${response}" ${?}
          break
          ;;
        getbalances)
          # curl (GET) http://192.168.111.152:8080/getbalances

          response=$(getbalances)
          response_to_client "${response}" ${?}
          break
          ;;
        getbalancebyxpub)
          # curl (GET) http://192.168.111.152:8080/getbalancebyxpub/upub5GtUcgGed1aGH4HKQ3vMYrsmLXwmHhS1AeX33ZvDgZiyvkGhNTvGd2TA5Lr4v239Fzjj4ZY48t6wTtXUy2yRgapf37QHgt6KWEZ6bgsCLpb

          response=$(getbalancebyxpub $(echo "${line}" | cut -d ' ' -f2 | cut -d '/' -f3))
          response_to_client "${response}" ${?}
          break
          ;;
        getbalancebyxpublabel)
          # curl (GET) http://192.168.111.152:8080/getbalancebyxpublabel/2219

          response=$(getbalancebyxpublabel $(echo "${line}" | cut -d ' ' -f2 | cut -d '/' -f3))
          response_to_client "${response}" ${?}
          break
          ;;
        getnewaddress)
          # curl (GET) http://192.168.111.152:8080/getnewaddress
          # curl (GET) http://192.168.111.152:8080/getnewaddress/bech32

          response=$(getnewaddress $(echo "${line}" | cut -d ' ' -f2 | cut -d '/' -f3))
          response_to_client "${response}" ${?}
          break
          ;;
        spend)
          # POST http://192.168.111.152:8080/spend
          # BODY {"address":"2N8DcqzfkYi8CkYzvNNS5amoq3SbAcQNXKp","amount":0.00233,"eventMessage":"eyJ3aGF0ZXZlciI6MTIzfQo=","confTarget":6,"replaceable":true,"subtractfeefromamount":false}

          response=$(spend "${line}")
          response_to_client "${response}" ${?}
          break
          ;;
        bumpfee)
          # POST http://192.168.111.152:8080/bumpfee
          # BODY {"txid":"af867c86000da76df7ddb1054b273ca9e034e8c89d049b5b2795f9f590f67648","confTarget":4}
          # BODY {"txid":"af867c86000da76df7ddb1054b273ca9e034e8c89d049b5b2795f9f590f67648"}

          response=$(bumpfee "${line}")
          response_to_client "${response}" ${?}
          break
          ;;
        addtobatch)
          # POST http://192.168.111.152:8080/addtobatch
          # BODY {"address":"2N8DcqzfkYi8CkYzvNNS5amoq3SbAcQNXKp","amount":0.00233}

          response=$(addtobatching $(echo "${line}" | jq -r ".address") $(echo "${line}" | jq ".amount"))
          response_to_client "${response}" ${?}
          break
          ;;
        batchspend)
          # GET http://192.168.111.152:8080/batchspend

          response=$(batchspend "${line}")
          response_to_client "${response}" ${?}
          break
          ;;
        deriveindex)
          # curl GET http://192.168.111.152:8080/deriveindex/25-30
          # curl GET http://192.168.111.152:8080/deriveindex/34

          response=$(deriveindex $(echo "${line}" | cut -d ' ' -f2 | cut -d '/' -f3))
          response_to_client "${response}" ${?}
          break
          ;;
        derivepubpath)
          # POST http://192.168.111.152:8080/derivepubpath
          # BODY {"pub32":"tpubD6NzVbkrYhZ4YR3QK2tyfMMvBghAvqtNaNK1LTyDWcRHLcMUm3ZN2cGm5BS3MhCRCeCkXQkTXXjiJgqxpqXK7PeUSp86DTTgkLpcjMtpKWk","path":"0/25-30"}
          # BODY {"pub32":"upub5GtUcgGed1aGH4HKQ3vMYrsmLXwmHhS1AeX33ZvDgZiyvkGhNTvGd2TA5Lr4v239Fzjj4ZY48t6wTtXUy2yRgapf37QHgt6KWEZ6bgsCLpb","path":"0/25-30"}
          # BODY {"pub32":"vpub5SLqN2bLY4WeZF3kL4VqiWF1itbf3A6oRrq9aPf16AZMVWYCuN9TxpAZwCzVgW94TNzZPNc9XAHD4As6pdnExBtCDGYRmNJrcJ4eV9hNqcv","path":"0/25-30"}

          response=$(derivepubpath "${line}")
          response_to_client "${response}" ${?}
          break
          ;;
        getmempoolinfo)
          # curl GET http://192.168.111.152:8080/getmempoolinfo

          response=$(get_mempool_info)
          response_to_client "${response}" ${?}
          break
          ;;
        ln_getinfo)
          # GET http://192.168.111.152:8080/ln_getinfo

          response=$(ln_getinfo)
          response_to_client "${response}" ${?}
          break
          ;;
        ln_getconnectionstring)
          # GET http://192.168.111.152:8080/ln_getconnectionstring

          response=$(ln_get_connection_string)
          response_to_client "${response}" ${?}
          break
          ;;
        ln_create_invoice)
          # POST http://192.168.111.152:8080/ln_create_invoice
          # BODY {"msatoshi":"10000","label":"koNCcrSvhX3dmyFhW","description":"Bylls order #10649","expiry":"900","callback_url":"http://192.168.122.159"}

          response=$(ln_create_invoice "${line}")
          response_to_client "${response}" ${?}
          break
          ;;
        ln_pay)
          # POST http://192.168.111.152:8080/ln_pay
          # BODY {"bolt11":"lntb1pdca82tpp5gv8mn5jqlj6xztpnt4r472zcyrwf3y2c3cvm4uzg2gqcnj90f83qdp2gf5hgcm0d9hzqnm4w3kx2apqdaexgetjyq3nwvpcxgcqp2g3d86wwdfvyxcz7kce7d3n26d2rw3wf5tzpm2m5fl2z3mm8msa3xk8nv2y32gmzlhwjved980mcmkgq83u9wafq9n4w28amnmwzujgqpmapcr3","expected_msatoshi":"10000","expected_description":"Bitcoin Outlet order #7082"}

          response=$(ln_pay "${line}")
          response_to_client "${response}" ${?}
          break
          ;;
        ln_newaddr)
          # GET http://192.168.111.152:8080/ln_newaddr

          response=$(ln_newaddr)
          response_to_client "${response}" ${?}
          break
          ;;
        ln_connectfund)
          # POST http://192.168.111.152:8080/ln_connectfund
          # BODY {"peer":"nodeId@ip:port","msatoshi":"100000","callbackUrl":"https://callbackUrl/?channelReady=f3y2c3cvm4uzg2gq"}
          # curl -H "Content-Type: application/json" -d '{"peer":"nodeId@ip:port","msatoshi":"100000","callbackUrl":"https://callbackUrl/?channelReady=f3y2c3cvm4uzg2gq"}' proxy:8888/ln_connectfund

          response=$(ln_connectfund "${line}")
          response_to_client "${response}" ${?}
          break
          ;;
        ln_getinvoice)
          # GET http://192.168.111.152:8080/ln_getinvoice/label
          # GET http://192.168.111.152:8080/ln_getinvoice/koNCcrSvhX3dmyFhW

          response=$(ln_getinvoice $(echo "${line}" | cut -d ' ' -f2 | cut -d '/' -f3))
          response_to_client "${response}" ${?}
          break
          ;;
        ln_delinvoice)
          # GET http://192.168.111.152:8080/ln_delinvoice/label
          # GET http://192.168.111.152:8080/ln_delinvoice/koNCcrSvhX3dmyFhW

          response=$(ln_delinvoice $(echo "${line}" | cut -d ' ' -f2 | cut -d '/' -f3))
          response_to_client "${response}" ${?}
          break
          ;;
        ln_decodebolt11)
          # GET http://192.168.111.152:8080/ln_decodebolt11/bolt11
          # GET http://192.168.111.152:8080/ln_decodebolt11/lntb1pdca82tpp5gv8mn5jqlj6xztpnt4r472zcyrwf3y2c3cvm4uzg2gqcnj90f83qdp2gf5hgcm0d9hzqnm4w3kx2apqdaexgetjyq3nwvpcxgcqp2g3d86wwdfvyxcz7kce7d3n26d2rw3wf5tzpm2m5fl2z3mm8msa3xk8nv2y32gmzlhwjved980mcmkgq83u9wafq9n4w28amnmwzujgqpmapcr3

          response=$(ln_decodebolt11 $(echo "${line}" | cut -d ' ' -f2 | cut -d '/' -f3))
          response_to_client "${response}" ${?}
          break
          ;;
        ln_listpeers)
          # GET http://192.168.111.152:8080/ln_listpeers

          response=$(ln_listpeers)
          response_to_client "${response}" ${?}
          break
          ;;
        ln_listfunds)
          # GET http://192.168.111.152:8080/ln_listfunds
          response=$(ln_listfunds)
          response_to_client "${response}" ${?}
          break
          ;;
        ln_listpays)
          # GET http://192.168.111.152:8080/ln_listpays
          response=$(ln_listpays)
          response_to_client "${response}" ${?}
          break
          ;;
        ln_getroute)
          # GET http://192.168.111.152:8080/ln_getroute/<node_id>/<msatoshi>/<riskfactor>
          response=$(ln_getroute $(echo "${line}" | cut -d ' ' -f2 | cut -d '/' -f3) $(echo "${line}" | cut -d ' ' -f2 | cut -d '/' -f4) $(echo "${line}" | cut -d ' ' -f2 | cut -d '/' -f5))
          response_to_client "${response}" ${?}
          break
          ;;
        ln_withdraw)
          # POST http://192.168.111.152:8080/ln_withdraw
          # BODY {"destination":"segwitAddress","satoshi":"100000","feerate":0,all: false}
          response=$(ln_withdraw "${line}")
          response_to_client "${response}" ${?}
          break
          ;;
        ots_stamp)
          # POST http://192.168.111.152:8080/ots_stamp
          # BODY {"hash":"1ddfb769eb0b8876bc570e25580e6a53afcf973362ee1ee4b54a807da2e5eed7","callbackUrl":"192.168.111.233:1111/callbackUrl"}

          # curl -v -d "{\"hash\":\"a6ea81a46fec3d02d40815b8667b388351edecedc1cc9f97aab55b566db7aac8\"}" localhost:8888/ots_stamp

          response=$(serve_ots_stamp "${line}")
          response_to_client "${response}" ${?}
          break
          ;;
        ots_backoffice)
          # curl (GET) http://192.168.111.152:8080/ots_upgradeandcallback

          response=$(serve_ots_backoffice)
          response_to_client "${response}" ${?}
          break
          ;;
        ots_getfile)
          # curl (GET) http://192.168.111.152:8080/ots_getfile/1ddfb769eb0b8876bc570e25580e6a53afcf973362ee1ee4b54a807da2e5eed7

          serve_ots_getfile $(echo "${line}" | cut -d ' ' -f2 | cut -d '/' -f3)
          break
          ;;
        ots_verify)
          # POST http://192.168.111.152:8080/ots_verify
          # BODY {"hash":"1ddfb769eb0b8876bc570e25580e6a53afcf973362ee1ee4b54a807da2e5eed7"}
          # BODY {"hash":"1ddfb769eb0b8876bc570e25580e6a53afcf973362ee1ee4b54a807da2e5eed7","base64otsfile":"AE9wZW5UaW1lc3RhbXBzAABQcm9vZ...gABYiWDXPXGQEDxNch"}

          # curl -v -d "{\"hash\":\"a6ea81a46fec3d02d40815b8667b388351edecedc1cc9f97aab55b566db7aac8\"}" localhost:8888/ots_verify
          # curl -v -d "{\"hash\":\"a6ea81a46fec3d02d40815b8667b388351edecedc1cc9f97aab55b566db7aac8\",\"base64otsfile\":\"$(cat a6ea81a46fec3d02d40815b8667b388351edecedc1cc9f97aab55b566db7aac8.ots | base64 | tr -d '\n')\"}" localhost:8888/ots_verify

          response=$(serve_ots_verify "${line}")
          response_to_client "${response}" ${?}
          break
          ;;
        ots_info)
          # POST http://192.168.111.152:8080/ots_info
          # BODY {"hash":"1ddfb769eb0b8876bc570e25580e6a53afcf973362ee1ee4b54a807da2e5eed7"}
          # BODY {"base64otsfile":"AE9wZW5UaW1lc3RhbXBzAABQcm9vZ...gABYiWDXPXGQEDxNch"}
          # BODY {"hash":"1ddfb769eb0b8876bc570e25580e6a53afcf973362ee1ee4b54a807da2e5eed7","base64otsfile":"AE9wZW5UaW1lc3RhbXBzAABQcm9vZ...gABYiWDXPXGQEDxNch"}

          # curl -v -d "{\"hash\":\"a6ea81a46fec3d02d40815b8667b388351edecedc1cc9f97aab55b566db7aac8\"}" localhost:8888/ots_info
          # curl -v -d "{\"base64otsfile\":\"$(cat a6ea81a46fec3d02d40815b8667b388351edecedc1cc9f97aab55b566db7aac8.ots | base64 | tr -d '\n')\"}" localhost:8888/ots_info
          # curl -v -d "{\"hash\":\"a6ea81a46fec3d02d40815b8667b388351edecedc1cc9f97aab55b566db7aac8\",\"base64otsfile\":\"$(cat a6ea81a46fec3d02d40815b8667b388351edecedc1cc9f97aab55b566db7aac8.ots | base64 | tr -d '\n')\"}" localhost:8888/ots_info

          response=$(serve_ots_info "${line}")
          response_to_client "${response}" ${?}
          break
          ;;
        wasabi_getnewaddress)
          # queries random instance for a new bech32 address
          # POST http://192.168.111.152:8080/wasabi_getnewaddress
          # BODY {"label":"Pay #12 for 2018"}
          # BODY {}
          # Empty BODY: Label will be "unknown"

          response=$(wasabi_newaddr "${line}")
          response_to_client "${response}" ${?}
          break
          ;;
        wasabi_getbalances)
          # GET http://192.168.111.152:8080/wasabi_getbalances/{anonset}
          # GET http://192.168.111.152:8080/wasabi_getbalances/87
          response=$(wasabi_getbalances $(echo "${line}" | cut -d ' ' -f2 | cut -d '/' -f3))
          response_to_client "${response}" ${?}
          break
          ;;
        wasabi_spend)
          # args:
          # - instanceId: integer, optional
          # - private: boolean, optional, default=false
          # - address: string, required
          # - amount: number, required
          # - minanonset: number, optional
          # - label: number, string
          #
          # POST http://192.168.111.152:8080/wasabi_spend
          # BODY {"instanceId":1,"private":true,"amount":0.00103440,"address":"2N8DcqzfkYi8CkYzvNNS5amoq3SbAcQNXKp", label: "my super private coins", minanonset: 90}
          # BODY {"amount":0.00103440,"address":"2N8DcqzfkYi8CkYzvNNS5amoq3SbAcQNXKp"}

          response=$(wasabi_spend "${line}")
          response_to_client "${response}" ${?}
          break
          ;;
        wasabi_getunspentcoins)
          # args:
          # - instanceId: integer, optional
          # return all unspent coins of either one wasabi instance
          # or all instances, depending on the instanceId parameter

          # Using new listunspentcoins
          response=$(wasabi_getunspentcoins "${line}")
          response_to_client "${response}" ${?}
          break
          ;;
        wasabi_gettransactions)
          # args:
          # - instanceId: integer, optional
          # return all transactions of either one wasabi instance
          # or all instances, depending on the instanceId parameter

          # Using new gethistory
          response=$(wasabi_gettransactions "${line}")
          response_to_client "${response}" ${?}
          break
          ;;
        wasabi_spendprivate)
          # GET http://192.168.111.152:8080/wasabi_spendprivate
          # Useful to manually trigger an auto-spend

          response=$(wasabi_batchprivatetospender)
          response_to_client "${response}" ${?}
          break
          ;;
      esac
      break
    fi
  done
  trace "[main] exiting"
  return 0
}

export NODE_RPC_URL=$BTC_NODE_RPC_URL
export TRACING
export DB_PATH
export DB_FILE

main
trace "[requesthandler] exiting"
exit $?
