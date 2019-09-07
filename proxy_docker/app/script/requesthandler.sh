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
. ./blockchainrpc.sh
. ./responsetoclient.sh
. ./trace.sh
. ./manage_missed_conf.sh
. ./walletoperations.sh
. ./bitcoin.sh
. ./call_lightningd.sh
. ./ots.sh
. ./batching.sh
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
      content_length=$(echo "${line}" | cut -d ' ' -f2)
      trace "[main] content_length=${content_length}";
      ;;
    esac
    if [ ${step} -eq 1 ]; then
      trace "[main] step=${step}"
      if [ "${http_method}" = "POST" ] && [ "${content_length}" -gt "0" ]; then
#        read -rd '' -n ${content_length} line
        line=$(dd bs=1 count=${content_length} 2>/dev/null)
        line=$(echo "${line}" | jq -c)
        trace "[main] line=${line}"
      fi
      case "${cmd}" in
        helloworld)
          # GET http://192.168.111.152:8080/helloworld
          response='{"hello":"world"}'
          returncode=0
          # response_to_client "Hello, world!" 0
          # break
          ;;
        installation_info)
          # GET http://192.168.111.152:8080/info
          if [ -f "$DB_PATH/info.json" ]; then
            response=$(cat "$DB_PATH/info.json")
          else
            response='{ "error": "missing installation data" }'
          fi
          returncode=$?
          ;;
        watch)
          # POST http://192.168.111.152:8080/watch
          # BODY {"address":"2N8DcqzfkYi8CkYzvNNS5amoq3SbAcQNXKp","unconfirmedCallbackURL":"192.168.111.233:1111/callback0conf","confirmedCallbackURL":"192.168.111.233:1111/callback1conf"}
          # BODY {"address":"2N8DcqzfkYi8CkYzvNNS5amoq3SbAcQNXKp","confirmedCallbackURL":"192.168.111.233:1111/callback1conf","eventMessage":"eyJib3VuY2VfYWRkcmVzcyI6IjJNdkEzeHIzOHIxNXRRZWhGblBKMVhBdXJDUFR2ZTZOamNGIiwibmJfY29uZiI6MH0K"}
          # BODY {"address":"2N8DcqzfkYi8CkYzvNNS5amoq3SbAcQNXKp","confirmedCallbackURL":"192.168.111.233:1111/callback1conf","eventMessage":"eyJib3VuY2VfYWRkcmVzcyI6IjJNdkEzeHIzOHIxNXRRZWhGblBKMVhBdXJDUFR2ZTZOamNGIiwibmJfY29uZiI6MH0K","label":"myLabel"}

          response=$(watchrequest "${line}")
          returncode=$?
          ;;
        unwatch)
          # curl (GET) 192.168.111.152:8080/unwatch/2N8DcqzfkYi8CkYzvNNS5amoq3SbAcQNXKp
          # or
          # POST http://192.168.111.152:8080/unwatch
          # BODY {"address":"2N8DcqzfkYi8CkYzvNNS5amoq3SbAcQNXKp","unconfirmedCallbackURL":"192.168.111.233:1111/callback0conf","confirmedCallbackURL":"192.168.111.233:1111/callback1conf"}
          # or
          # BODY {"id":3124}

          # args:
          # - address: string, required
          # - unconfirmedCallbackURL: string, optional
          # - confirmedCallbackURL: string, optional
          # or
          # - id: the id returned by the watch

          local address="null"
          local unconfirmedCallbackURL="null"
          local confirmedCallbackURL="null"
          local watchid="null"

          # Let's make it work even for a GET request (equivalent to a POST with empty json object body)
          if [ "$http_method" = "POST" ]; then
            address=$(echo "${line}" | jq -r ".address")
            unconfirmedCallbackURL=$(echo "${line}" | jq -r ".unconfirmedCallbackURL")
            confirmedCallbackURL=$(echo "${line}" | jq -r ".confirmedCallbackURL")
            watchid=$(echo "${line}" | jq ".id")
          else
            address=$(echo "${line}" | cut -d ' ' -f2 | cut -d '/' -f3)
          fi

          response=$(unwatchrequest "${watchid}" "${address}" "${unconfirmedCallbackURL}" "${confirmedCallbackURL}")
          returncode=$?
          ;;
        watchxpub)
          # POST http://192.168.111.152:8080/watchxpub
          # BODY {"label":"4421","pub32":"tpubD6NzVbkrYhZ4YR3QK2tyfMMvBghAvqtNaNK1LTyDWcRHLcMUm3ZN2cGm5BS3MhCRCeCkXQkTXXjiJgqxpqXK7PeUSp86DTTgkLpcjMtpKWk","path":"0/n","nstart":0,"unconfirmedCallbackURL":"192.168.111.233:1111/callback0conf","confirmedCallbackURL":"192.168.111.233:1111/callback1conf"}
          # curl -H "Content-Type: application/json" -d '{"label":"2219","pub32":"upub5GtUcgGed1aGH4HKQ3vMYrsmLXwmHhS1AeX33ZvDgZiyvkGhNTvGd2TA5Lr4v239Fzjj4ZY48t6wTtXUy2yRgapf37QHgt6KWEZ6bgsCLpb","path":"0/1/n","nstart":55,"unconfirmedCallbackURL":"192.168.111.233:1111/callback0conf","confirmedCallbackURL":"192.168.111.233:1111/callback1conf"}' proxy:8888/watchxpub

          response=$(watchpub32request "${line}")
          returncode=$?
          ;;
        unwatchxpubbyxpub)
          # GET http://192.168.111.152:8080/unwatchxpubbyxpub/tpubD6NzVbkrYhZ4YR3QK2tyfMMvBghAvqtNaNK1LTyDWcRHLcMUm3ZN2cGm5BS3MhCRCeCkXQkTXXjiJgqxpqXK7PeUSp86DTTgkLpcjMtpKWk

          response=$(unwatchpub32request "${line}")
          returncode=$?
          ;;
        unwatchxpubbylabel)
          # GET http://192.168.111.152:8080/unwatchxpubbylabel/4421

          response=$(unwatchpub32labelrequest "${line}")
          returncode=$?
          ;;
        getactivewatchesbyxpub)
          # GET http://192.168.111.152:8080/getactivewatchesbyxpub/tpubD6NzVbkrYhZ4YR3QK2tyfMMvBghAvqtNaNK1LTyDWcRHLcMUm3ZN2cGm5BS3MhCRCeCkXQkTXXjiJgqxpqXK7PeUSp86DTTgkLpcjMtpKWk

          response=$(getactivewatchesbyxpub "$(echo "${line}" | cut -d ' ' -f2 | cut -d '/' -f3)")
          returncode=$?
          ;;
        getactivewatchesbylabel)
          # GET http://192.168.111.152:8080/getactivewatchesbylabel/4421

          response=$(getactivewatchesbylabel "$(echo "${line}" | cut -d ' ' -f2 | cut -d '/' -f3)")
          returncode=$?
          ;;
        getactivexpubwatches)
          # GET http://192.168.111.152:8080/getactivexpubwatches

          response=$(getactivexpubwatches)
          returncode=$?
          ;;
        watchtxid)
          # POST http://192.168.111.152:8080/watchtxid
          # BODY {"txid":"b081ca7724386f549cf0c16f71db6affeb52ff7a0d9b606fb2e5c43faffd3387","confirmedCallbackURL":"192.168.111.233:1111/callback1conf","xconfCallbackURL":"192.168.111.233:1111/callbackXconf","nbxconf":6}
          # curl -H "Content-Type: application/json" -d '{"txid":"b081ca7724386f549cf0c16f71db6affeb52ff7a0d9b606fb2e5c43faffd3387","confirmedCallbackURL":"192.168.111.233:1111/callback1conf","xconfCallbackURL":"192.168.111.233:1111/callbackXconf","nbxconf":6}' proxy:8888/watchtxid

          response=$(watchtxidrequest "${line}")
          returncode=$?
          ;;
        unwatchtxid)
          # POST http://192.168.111.152:8080/unwatchtxid
          # BODY {"txid":"b081ca7724386f549cf0c16f71db6affeb52ff7a0d9b606fb2e5c43faffd3387","unconfirmedCallbackURL":"192.168.111.233:1111/callback0conf","confirmedCallbackURL":"192.168.111.233:1111/callback1conf"}
          # or
          # BODY {"id":3124}

          # args:
          # - txid: string, required
          # - unconfirmedCallbackURL: string, optional
          # - confirmedCallbackURL: string, optional
          # or
          # - id: the id returned by watchtxid

          local txid=$(echo "${line}" | jq -r ".txid")
          local unconfirmedCallbackURL=$(echo "${line}" | jq -r ".unconfirmedCallbackURL")
          local confirmedCallbackURL=$(echo "${line}" | jq -r ".confirmedCallbackURL")
          local watchid=$(echo "${line}" | jq ".id")

          response=$(unwatchtxidrequest "${watchid}" "${txid}" "${unconfirmedCallbackURL}" "${confirmedCallbackURL}")
          returncode=$?
          ;;
        getactivewatches)
          # curl (GET) 192.168.111.152:8080/getactivewatches

          response=$(getactivewatches)
          returncode=$?
          ;;
        get_txns_by_watchlabel)
          # curl (GET) 192.168.111.152:8080/get_txns_by_watchlabel/<label>/<count>
          response=$(get_txns_by_watchlabel "$(echo "${line}" | cut -d ' ' -f2 | cut -d '/' -f3)" "$(echo "${line}" | cut -d ' ' -f2 | cut -d '/' -f4)")
          returncode=$?
          ;;
        get_unused_addresses_by_watchlabel)
          # curl (GET) 192.168.111.152:8080/get_unused_addresses_by_watchlabel/<label>/<count>
          response=$(get_unused_addresses_by_watchlabel "$(echo "${line}" | cut -d ' ' -f2 | cut -d '/' -f3)" "$(echo "${line}" | cut -d ' ' -f2 | cut -d '/' -f4)")
          returncode=$?
          ;;
        getbestblockhash)
          # curl (GET) http://192.168.111.152:8080/getbestblockhash

          response=$(get_best_block_hash)
          returncode=$?
          ;;
        getblockhash)
          # curl (GET) http://192.168.111.152:8080/getblockhash/522322

          response=$(get_blockhash "$(echo "${line}" | cut -d ' ' -f2 | cut -d '/' -f3)")
          returncode=$?
          ;;
        getblockinfo)
          # curl (GET) http://192.168.111.152:8080/getblockinfo/000000006f82a384c208ecfa04d05beea02d420f3f398ddda5c7f900de5718ea

          response=$(get_block_info "$(echo "${line}" | cut -d ' ' -f2 | cut -d '/' -f3)")
          returncode=$?
          ;;
        getblockchaininfo)
          # http://192.168.111.152:8080/getblockchaininfo

          response=$(get_blockchain_info)
          returncode=$?
          ;;
        gettransaction)
          # curl (GET) http://192.168.111.152:8080/gettransaction/af867c86000da76df7ddb1054b273ca9e034e8c89d049b5b2795f9f590f67648

          response=$(get_rawtransaction "$(echo "${line}" | cut -d ' ' -f2 | cut -d '/' -f3)")
          returncode=$?
          ;;
        getbestblockinfo)
          # curl (GET) http://192.168.111.152:8080/getbestblockinfo

          response=$(get_best_block_info)
          returncode=$?
          ;;
        executecallbacks)
          # curl (GET) http://192.168.111.152:8080/executecallbacks

          response=$(manage_not_imported)
          response=$(manage_missed_conf)
          response=$(do_callbacks)
          returncode=$?
          ;;
        get_txns_spending)
          # curl (GET) http://192.168.111.152:8080/get_txns_spending/20/10

          response=$(get_txns_spending "$(echo "${line}" | cut -d ' ' -f2 | cut -d '/' -f3)" "$(echo "${line}" | cut -d ' ' -f2 | cut -d '/' -f4)")
          returncode=$?
          ;;
        getbalance)
          # curl (GET) http://192.168.111.152:8080/getbalance

          response=$(getbalance)
          returncode=$?
          ;;
        getbalances)
          # curl (GET) http://192.168.111.152:8080/getbalances

          response=$(getbalances)
          returncode=$?
          ;;
        getbalancebyxpub)
          # curl (GET) http://192.168.111.152:8080/getbalancebyxpub/upub5GtUcgGed1aGH4HKQ3vMYrsmLXwmHhS1AeX33ZvDgZiyvkGhNTvGd2TA5Lr4v239Fzjj4ZY48t6wTtXUy2yRgapf37QHgt6KWEZ6bgsCLpb

          response=$(getbalancebyxpub "$(echo "${line}" | cut -d ' ' -f2 | cut -d '/' -f3)")
          returncode=$?
          ;;
        getbalancebyxpublabel)
          # curl (GET) http://192.168.111.152:8080/getbalancebyxpublabel/2219

          response=$(getbalancebyxpublabel "$(echo "${line}" | cut -d ' ' -f2 | cut -d '/' -f3)")
          returncode=$?
          ;;
        getnewaddress)
          # curl (GET) http://192.168.111.152:8080/getnewaddress
          # curl (GET) http://192.168.111.152:8080/getnewaddress/bech32
          #
          # or...
          # POST http://192.168.111.152:8080/getnewaddress
          # BODY {"addressType":"bech32","label":"myLabel"}
          # BODY {"label":"myLabel"}
          # BODY {"addressType":"p2sh-segwit"}
          # BODY {}

          # Let's make it work even for a GET request (equivalent to a POST with empty json object body)
          if [ "$http_method" = "POST" ]; then
            address_type=$(echo "${line}" | jq -er ".addressType // empty")
            label=$(echo "${line}" | jq -er ".label // empty")
          else
            address_type=$(echo "${line}" | cut -d ' ' -f2 | cut -d '/' -f3)
          fi

          response=$(getnewaddress "${address_type}" "${label}")
          returncode=$?
          ;;
        validateaddress)
          # GET http://192.168.111.152:8080/validateaddress/tb1p5cyxnuxmeuwuvkwfem96lqzszd02n6xdcjrs20cac6yqjjwudpxqp3mvzv

          response=$(validateaddress "$(echo "${line}" | cut -d ' ' -f2 | cut -d '/' -f3)")
          returncode=$?
          ;;
        spend)
          # POST http://192.168.111.152:8080/spend
          # BODY {"address":"2N8DcqzfkYi8CkYzvNNS5amoq3SbAcQNXKp","amount":0.00233,"eventMessage":"eyJ3aGF0ZXZlciI6MTIzfQo=","confTarget":6,"replaceable":true,"subtractfeefromamount":false}

          response=$(spend "${line}")
          returncode=$?
          ;;
        bumpfee)
          # POST http://192.168.111.152:8080/bumpfee
          # BODY {"txid":"af867c86000da76df7ddb1054b273ca9e034e8c89d049b5b2795f9f590f67648","confTarget":4}
          # BODY {"txid":"af867c86000da76df7ddb1054b273ca9e034e8c89d049b5b2795f9f590f67648"}

          response=$(bumpfee "${line}")
          returncode=$?
          ;;
        createbatcher)
          # POST http://192.168.111.152:8080/createbatcher
          #
          # args:
          # - batcherLabel, optional, id can be used to reference the batcher
          # - confTarget, optional, overriden by batchspend's confTarget, default Bitcoin Core conf_target will be used if not supplied
          # NOTYET - feeRate, sat/vB, optional, overrides confTarget if supplied, overriden by batchspend's feeRate, default Bitcoin Core fee policy will be used if not supplied
          #
          # response:
          # - batcherId, the batcher id
          #
          # BODY {"batcherLabel":"lowfees","confTarget":32}
          # NOTYET BODY {"batcherLabel":"highfees","feeRate":231.8}

          response=$(createbatcher "${line}")
          returncode=$?
          ;;
        updatebatcher)
          # POST http://192.168.111.152:8080/updatebatcher
          #
          # args:
          # - batcherId, optional, batcher id to update, will update default batcher if not supplied
          # - batcherLabel, optional, id can be used to reference the batcher, will update default batcher if not supplied, if id is present then change the label with supplied text
          # - confTarget, optional, new confirmation target for the batcher
          # NOTYET - feeRate, sat/vB, optional, new feerate for the batcher
          #
          # response:
          # - batcherId, the batcher id
          # - batcherLabel, the batcher label
          # - confTarget, the batcher default confirmation target
          # NOTYET - feeRate, the batcher default feerate
          #
          # BODY {"batcherId":5,"confTarget":12}
          # NOTYET BODY {"batcherLabel":"highfees","feeRate":400}
          # NOTYET BODY {"batcherId":3,"label":"ultrahighfees","feeRate":800}
          # BODY {"batcherLabel":"fast","confTarget":2}

          response=$(updatebatcher "${line}")
          returncode=$?
          ;;
        addtobatch)
          # POST http://192.168.111.152:8080/addtobatch
          #
          # args:
          # - address, required, desination address
          # - amount, required, amount to send to the destination address
          # - outputLabel, optional, if you want to reference this output
          # - batcherId, optional, the id of the batcher to which the output will be added, default batcher if not supplied, overrides batcherLabel
          # - batcherLabel, optional, the label of the batcher to which the output will be added, default batcher if not supplied
          # - webhookUrl, optional, the webhook to call when the batch is broadcast
          #
          # response:
          # - batcherId, the id of the batcher
          # - outputId, the id of the added output
          # - nbOutputs, the number of outputs currently in the batch
          # - oldest, the timestamp of the oldest output in the batch
          # - total, the current sum of the batch's output amounts
          #
          # BODY {"address":"2N8DcqzfkYi8CkYzvNNS5amoq3SbAcQNXKp","amount":0.00233}
          # BODY {"address":"2N8DcqzfkYi8CkYzvNNS5amoq3SbAcQNXKp","amount":0.00233,"batcherId":34,"webhookUrl":"https://myCypherApp:3000/batchExecuted"}
          # BODY {"address":"2N8DcqzfkYi8CkYzvNNS5amoq3SbAcQNXKp","amount":0.00233,"batcherLabel":"lowfees","webhookUrl":"https://myCypherApp:3000/batchExecuted"}
          # BODY {"address":"2N8DcqzfkYi8CkYzvNNS5amoq3SbAcQNXKp","amount":0.00233,"batcherId":34,"webhookUrl":"https://myCypherApp:3000/batchExecuted"}

          response=$(addtobatch "${line}")
          returncode=$?
          ;;
        removefrombatch)
          # POST http://192.168.111.152:8080/removefrombatch
          #
          # args:
          # - outputId, required, id of the output to remove
          #
          # response:
          # - batcherId, the id of the batcher
          # - outputId, the id of the removed output if found
          # - nbOutputs, the number of outputs currently in the batch
          # - oldest, the timestamp of the oldest output in the batch
          # - total, the current sum of the batch's output amounts
          #
          # BODY {"outputId":72}

          response=$(removefrombatch "${line}")
          returncode=$?
          ;;
        batchspend)
          # POST http://192.168.111.152:8080/batchspend
          #
          # args:
          # - batcherId, optional, id of the batcher to execute, overrides batcherLabel, default batcher will be spent if not supplied
          # - batcherLabel, optional, label of the batcher to execute, default batcher will be executed if not supplied
          # - confTarget, optional, overrides default value of createbatcher, default to value of createbatcher, default Bitcoin Core conf_target will be used if not supplied
          # NOTYET - feeRate, optional, overrides confTarget if supplied, overrides default value of createbatcher, default to value of createbatcher, default Bitcoin Core value will be used if not supplied
          #
          # response:
          # - batcherId, id of the executed batcher
          # - confTarget, conf_target used for the spend
          # - nbOutputs, the number of outputs spent in the batch
          # - oldest, the timestamp of the oldest output in the spent batch
          # - total, the sum of the spent batch's output amounts
          # - txid, the batch transaction id
          # - hash, the transaction hash
          # - tx details: firstseen, size, vsize, replaceable, fee
          # - outputs
          #
          # {"result":{
          #    "batcherId":34,
          #    "confTarget":6,
          #    "nbOutputs":83,
          #    "oldest":123123,
          #    "total":10.86990143,
          #    "txid":"af867c86000da76df7ddb1054b273ca9e034e8c89d049b5b2795f9f590f67648",
          #    "hash":"af867c86000da76df7ddb1054b273ca9e034e8c89d049b5b2795f9f590f67648",
          #    "details":{
          #      "firstseen":123123,
          #      "size":424,
          #      "vsize":371,
          #      "replaceable":yes,
          #      "fee":0.00004112
          #    },
          #    "outputs":{
          #      "1abc":0.12,
          #      "3abc":0.66,
          #      "bc1abc":2.848,
          #      ...
          #    }
          #  }
          # },"error":null}
          #
          # BODY {}
          # BODY {"batcherId":34,"confTarget":12}
          # NOTYET BODY {"batcherLabel":"highfees","feeRate":233.7}
          # BODY {"batcherId":411,"confTarget":6}

          response=$(batchspend "${line}")
          returncode=$?
          ;;
        getbatcher)
          # POST (GET) http://192.168.111.152:8080/getbatcher
          #
          # args:
          # - batcherId, optional, id of the batcher, overrides batcherLabel, default batcher will be used if not supplied
          # - batcherLabel, optional, label of the batcher, default batcher will be used if not supplied
          #
          # response:
          # {"result":{"batcherId":1,"batcherLabel":"default","confTarget":6,"nbOutputs":12,"oldest":123123,"total":0.86990143},"error":null}
          #
          # BODY {}
          # BODY {"batcherId":34}

          if [ "$http_method" = "GET" ]; then
            line='{}'
          fi

          response=$(getbatcher "${line}")
          returncode=$?
          ;;
        getbatchdetails)
          # POST (GET) http://192.168.111.152:8080/getbatchdetails
          #
          # args:
          # - batcherId, optional, id of the batcher, overrides batcherLabel, default batcher will be used if not supplied
          # - batcherLabel, optional, label of the batcher, default batcher will be used if not supplied
          # - txid, optional, if you want the details of an executed batch, supply the batch txid, will return current pending batch
          #     if not supplied
          #
          # response:
          # {"result":{
          #    "batcherId":34,
          #    "batcherLabel":"Special batcher for a special client",
          #    "confTarget":6,
          #    "nbOutputs":83,
          #    "oldest":123123,
          #    "total":10.86990143,
          #    "txid":"af867c86000da76df7ddb1054b273ca9e034e8c89d049b5b2795f9f590f67648",
          #    "hash":"af867c86000da76df7ddb1054b273ca9e034e8c89d049b5b2795f9f590f67648",
          #    "details":{
          #      "firstseen":123123,
          #      "size":424,
          #      "vsize":371,
          #      "replaceable":yes,
          #      "fee":0.00004112
          #    },
          #    "outputs":[
          #      "1abc":0.12,
          #      "3abc":0.66,
          #      "bc1abc":2.848,
          #      ...
          #    ]
          #  }
          # },"error":null}
          #
          # BODY {}
          # BODY {"batcherId":34}

          response=$(getbatchdetails "${line}")
          returncode=$?
          ;;
        listbatchers)
          # curl (GET) http://192.168.111.152:8080/listbatchers
          #
          # response:
          # {"result":[
          #   {"batcherId":1,"batcherLabel":"default","confTarget":6,"nbOutputs":12,"oldest":123123,"total":0.86990143},
          #   {"batcherId":2,"batcherLabel":"lowfee","confTarget":32,"nbOutputs":44,"oldest":123123,"total":0.49827387},
          #   {"batcherId":3,"batcherLabel":"highfee","confTarget":2,"nbOutputs":7,"oldest":123123,"total":4.16843782}
          #  ],
          #  "error":null}

          response=$(listbatchers)
          returncode=$?
          ;;
        bitcoin_estimatesmartfee)
          # POST http://192.168.111.152:8080/bitcoin_estimatesmartfee
          # BODY {"confTarget":2}

          response=$(bitcoin_estimatesmartfee "$(echo "${line}" | jq -r ".confTarget")")
          returncode=$?
          ;;
        bitcoin_generatetoaddress)
          # GET with no parameters ==> http://192.168.111.152:8080/bitcoin_generatetoaddress
          # POST http://192.168.111.152:8080/bitcoin_generatetoaddress
          # BODY {"nbblocks":1, "address":"hex", "maxtries":123}

          if [ "$http_method" = "POST" ]; then
            response=$(bitcoin_generatetoaddress "${line}")
          else
            response=$(bitcoin_generatetoaddress "{}")
          fi
          returncode=$?
          ;;
        bitcoin_gettxoutproof)
          # POST http://192.168.111.152:8080/bitcoin_gettxoutproof
          # BODY
          # {
	        #   "txids": "[\"3bdb32c04e10b6c399bd3657ef8b0300649189e90d7cb79c4f997dea8fb532cb\",\"....\"]",
	        #   "blockhash": "0000000000000000007962066dcd6675830883516bcf40047d42740a85eb2919"
          # }
          response=$(bitcoin_gettxoutproof "$(echo "${line}" | jq -r ".txids")" "$(echo ${line} | jq -r ".blockhash // empty")")
          returncode=$?
          ;;
        deriveindex)
          # curl GET http://192.168.111.152:8080/deriveindex/25-30
          # curl GET http://192.168.111.152:8080/deriveindex/34

          response=$(deriveindex "$(echo "${line}" | cut -d ' ' -f2 | cut -d '/' -f3)")
          returncode=$?
          ;;
        derivepubpath)
          # POST http://192.168.111.152:8080/derivepubpath
          # BODY {"pub32":"tpubD6NzVbkrYhZ4YR3QK2tyfMMvBghAvqtNaNK1LTyDWcRHLcMUm3ZN2cGm5BS3MhCRCeCkXQkTXXjiJgqxpqXK7PeUSp86DTTgkLpcjMtpKWk","path":"0/25-30"}
          # BODY {"pub32":"upub5GtUcgGed1aGH4HKQ3vMYrsmLXwmHhS1AeX33ZvDgZiyvkGhNTvGd2TA5Lr4v239Fzjj4ZY48t6wTtXUy2yRgapf37QHgt6KWEZ6bgsCLpb","path":"0/25-30"}
          # BODY {"pub32":"vpub5SLqN2bLY4WeZF3kL4VqiWF1itbf3A6oRrq9aPf16AZMVWYCuN9TxpAZwCzVgW94TNzZPNc9XAHD4As6pdnExBtCDGYRmNJrcJ4eV9hNqcv","path":"0/25-30"}

          response=$(derivepubpath "${line}")
          returncode=$?
          ;;
        deriveindex_bitcoind)
          # curl GET http://192.168.111.152:8080/deriveindex_bitcoind/25-30
          # curl GET http://192.168.111.152:8080/deriveindex_bitcoind/34

          response=$(deriveindex_bitcoind "$(echo "${line}" | cut -d ' ' -f2 | cut -d '/' -f3)")
          returncode=$?
          ;;
        derivepubpath_bitcoind)
          # POST http://192.168.111.152:8080/derivepubpath_bitcoind
          # BODY {"pub32":"tpubD6NzVbkrYhZ4YR3QK2tyfMMvBghAvqtNaNK1LTyDWcRHLcMUm3ZN2cGm5BS3MhCRCeCkXQkTXXjiJgqxpqXK7PeUSp86DTTgkLpcjMtpKWk","path":"0/25-30"}
          # BODY {"pub32":"upub5GtUcgGed1aGH4HKQ3vMYrsmLXwmHhS1AeX33ZvDgZiyvkGhNTvGd2TA5Lr4v239Fzjj4ZY48t6wTtXUy2yRgapf37QHgt6KWEZ6bgsCLpb","path":"0/25-30"}
          # BODY {"pub32":"vpub5SLqN2bLY4WeZF3kL4VqiWF1itbf3A6oRrq9aPf16AZMVWYCuN9TxpAZwCzVgW94TNzZPNc9XAHD4As6pdnExBtCDGYRmNJrcJ4eV9hNqcv","path":"0/25-30"}

          response=$(derivepubpath_bitcoind "${line}")
          returncode=$?
          ;;
        getmempoolinfo)
          # curl GET http://192.168.111.152:8080/getmempoolinfo

          response=$(get_mempool_info)
          returncode=$?
          ;;
        ln_getinfo)
          # GET http://192.168.111.152:8080/ln_getinfo

          response=$(ln_getinfo)
          returncode=$?
          ;;
        ln_getconnectionstring)
          # GET http://192.168.111.152:8080/ln_getconnectionstring

          response=$(ln_get_connection_string)
          returncode=$?
          ;;
        ln_create_invoice)
          # POST http://192.168.111.152:8080/ln_create_invoice
          # BODY {"msatoshi":"10000","label":"koNCcrSvhX3dmyFhW","description":"Bylls order #10649","expiry":"900","callback_url":"http://192.168.122.159"}

          response=$(ln_create_invoice "${line}")
          returncode=$?
          ;;
        ln_pay)
          # POST http://192.168.111.152:8080/ln_pay
          # BODY {"bolt11":"lntb1pdca82tpp5gv8mn5jqlj6xztpnt4r472zcyrwf3y2c3cvm4uzg2gqcnj90f83qdp2gf5hgcm0d9hzqnm4w3kx2apqdaexgetjyq3nwvpcxgcqp2g3d86wwdfvyxcz7kce7d3n26d2rw3wf5tzpm2m5fl2z3mm8msa3xk8nv2y32gmzlhwjved980mcmkgq83u9wafq9n4w28amnmwzujgqpmapcr3","expected_msatoshi":"10000","expected_description":"Bitcoin Outlet order #7082"}

          response=$(ln_pay "${line}")
          returncode=$?
          ;;
        ln_listpays)
          # GET http://192.168.111.152:8080/ln_listpays
          # POST http://192.168.111.152:8080/ln_listpays
          # BODY {"bolt11":"lntb1pdca82tpp5gv8mn5jqlj6xztpnt4r472zcyrwf3y2c3cvm4uzg2gqcnj90f83qdp2gf5hgcm0d9hzqnm4w3kx2apqdaexgetjyq3nwvpcxgcqp2g3d86wwdfvyxcz7kce7d3n26d2rw3wf5tzpm2m5fl2z3mm8msa3xk8nv2y32gmzlhwjved980mcmkgq83u9wafq9n4w28amnmwzujgqpmapcr3"}
          # BODY {}

          # Let's make it work even for a GET request (equivalent to a POST with empty json object body)
          if [ "$http_method" = "POST" ]; then
            bolt11=$(echo "${line}" | jq -r ".bolt11 // empty")
          else
            bolt11=
          fi

          response=$(ln_listpays "${bolt11}")
          returncode=$?
          ;;
        ln_paystatus)
          # GET http://192.168.111.152:8080/ln_paystatus
          # POST http://192.168.111.152:8080/ln_paystatus
          # BODY {"bolt11":"lntb1pdca82tpp5gv8mn5jqlj6xztpnt4r472zcyrwf3y2c3cvm4uzg2gqcnj90f83qdp2gf5hgcm0d9hzqnm4w3kx2apqdaexgetjyq3nwvpcxgcqp2g3d86wwdfvyxcz7kce7d3n26d2rw3wf5tzpm2m5fl2z3mm8msa3xk8nv2y32gmzlhwjved980mcmkgq83u9wafq9n4w28amnmwzujgqpmapcr3"}
          # BODY {}

          # Let's make it work even for a GET request (equivalent to a POST with empty json object body)
          if [ "$http_method" = "POST" ]; then
            bolt11=$(echo "${line}" | jq -r ".bolt11 // empty")
          else
            bolt11=
          fi

          response=$(ln_paystatus "${bolt11}")
          returncode=$?
          ;;
        ln_newaddr)
          # GET http://192.168.111.152:8080/ln_newaddr

          response=$(ln_newaddr)
          returncode=$?
          ;;
        ln_connectfund)
          # POST http://192.168.111.152:8080/ln_connectfund
          # BODY {"peer":"nodeId@ip:port","msatoshi":"100000","callbackUrl":"https://callbackUrl/?channelReady=f3y2c3cvm4uzg2gq"}
          # curl -H "Content-Type: application/json" -d '{"peer":"nodeId@ip:port","msatoshi":"100000","callbackUrl":"https://callbackUrl/?channelReady=f3y2c3cvm4uzg2gq"}' proxy:8888/ln_connectfund

          response=$(ln_connectfund "${line}")
          returncode=$?
          ;;
        ln_getinvoice)
          # GET http://192.168.111.152:8080/ln_getinvoice/label
          # GET http://192.168.111.152:8080/ln_getinvoice/koNCcrSvhX3dmyFhW

          response=$(ln_getinvoice "$(echo "${line}" | cut -d ' ' -f2 | cut -d '/' -f3)")
          returncode=$?
          ;;
        ln_delinvoice)
          # GET http://192.168.111.152:8080/ln_delinvoice/label
          # GET http://192.168.111.152:8080/ln_delinvoice/koNCcrSvhX3dmyFhW

          response=$(ln_delinvoice "$(echo "${line}" | cut -d ' ' -f2 | cut -d '/' -f3)")
          returncode=$?
          ;;
        ln_decodebolt11)
          # GET http://192.168.111.152:8080/ln_decodebolt11/bolt11
          # GET http://192.168.111.152:8080/ln_decodebolt11/lntb1pdca82tpp5gv8mn5jqlj6xztpnt4r472zcyrwf3y2c3cvm4uzg2gqcnj90f83qdp2gf5hgcm0d9hzqnm4w3kx2apqdaexgetjyq3nwvpcxgcqp2g3d86wwdfvyxcz7kce7d3n26d2rw3wf5tzpm2m5fl2z3mm8msa3xk8nv2y32gmzlhwjved980mcmkgq83u9wafq9n4w28amnmwzujgqpmapcr3

          response=$(ln_decodebolt11 "$(echo "${line}" | cut -d ' ' -f2 | cut -d '/' -f3)")
          returncode=$?
          ;;
        ln_listpeers)
          # GET http://192.168.111.152:8080/ln_listpeers

          response=$(ln_listpeers)
          returncode=$?
          ;;
        ln_listfunds)
          # GET http://192.168.111.152:8080/ln_listfunds
          response=$(ln_listfunds)
          returncode=$?
          ;;
        ln_getroute)
          # GET http://192.168.111.152:8080/ln_getroute/<node_id>/<msatoshi>/<riskfactor>
          response=$(ln_getroute "$(echo "${line}" | cut -d ' ' -f2 | cut -d '/' -f3)" "$(echo "${line}" | cut -d ' ' -f2 | cut -d '/' -f4)" "$(echo "${line}" | cut -d ' ' -f2 | cut -d '/' -f5)")
          returncode=$?
          ;;
        ln_withdraw)
          # POST http://192.168.111.152:8080/ln_withdraw
          # BODY {"destination":"segwitAddress","satoshi":"100000","feerate":0,all: false}
          response=$(ln_withdraw "${line}")
          returncode=$?
          ;;
        ots_stamp)
          # POST http://192.168.111.152:8080/ots_stamp
          # BODY {"hash":"1ddfb769eb0b8876bc570e25580e6a53afcf973362ee1ee4b54a807da2e5eed7","callbackUrl":"192.168.111.233:1111/callbackUrl"}

          # curl -v -d "{\"hash\":\"a6ea81a46fec3d02d40815b8667b388351edecedc1cc9f97aab55b566db7aac8\"}" localhost:8888/ots_stamp

          response=$(serve_ots_stamp "${line}")
          returncode=$?
          ;;
        ots_backoffice)
          # curl (GET) http://192.168.111.152:8080/ots_upgradeandcallback

          response=$(serve_ots_backoffice)
          returncode=$?
          ;;
        ots_getfile)
          # curl (GET) http://192.168.111.152:8080/ots_getfile/1ddfb769eb0b8876bc570e25580e6a53afcf973362ee1ee4b54a807da2e5eed7

          serve_ots_getfile "$(echo "${line}" | cut -d ' ' -f2 | cut -d '/' -f3)"
          break
          ;;
        ots_verify)
          # POST http://192.168.111.152:8080/ots_verify
          # BODY {"hash":"1ddfb769eb0b8876bc570e25580e6a53afcf973362ee1ee4b54a807da2e5eed7"}
          # BODY {"hash":"1ddfb769eb0b8876bc570e25580e6a53afcf973362ee1ee4b54a807da2e5eed7","base64otsfile":"AE9wZW5UaW1lc3RhbXBzAABQcm9vZ...gABYiWDXPXGQEDxNch"}

          # curl -v -d "{\"hash\":\"a6ea81a46fec3d02d40815b8667b388351edecedc1cc9f97aab55b566db7aac8\"}" localhost:8888/ots_verify
          # curl -v -d "{\"hash\":\"a6ea81a46fec3d02d40815b8667b388351edecedc1cc9f97aab55b566db7aac8\",\"base64otsfile\":\"$(cat a6ea81a46fec3d02d40815b8667b388351edecedc1cc9f97aab55b566db7aac8.ots | base64 | tr -d '\n')\"}" localhost:8888/ots_verify

          response=$(serve_ots_verify "${line}")
          returncode=$?
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
          returncode=$?
          ;;
        *)
          response='{"error": {"code": -32601, "message": "Method not found"}, "id": "1"}'
          returncode=1
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
        wasabi_getbalance)
          # args:
          # - id: integer, optional
          # - private: boolean, optional, default=false
          # returns the total balance of either
          # - all wasabi instances
          # - a single instance, when provide with an id
          # takes a 'private' flag. if 'private' flag is set
          # the balance will only return the unspent outputs
          # which have an anon set of at least what is configured.
          # if id is defined, it will return the balance of
          # the wasabi instance with id <id>, else it will
          # return the balance of all instances
          # POST http://192.168.111.152:8080/wasabi_getbalance
          # BODY {"id":1,"private":true}
          # BODY {"private":true}
          # Empty BODY: all instances, not private
          response=$(wasabi_get_balance "${line}")
          response_to_client "${response}" ${?}
          break
          ;;
        wasabi_spend)
          # args:
          # - id: integer, required
          # - private: boolean, optional, default=false
          # - address: string, required
          # - amount: number, required
          break
          ;;
        wasabi_get_transactions)
          # args:
          # - id: integer, optional
          # return all transactions of either one wasabi instance
          # or all instances, depending on the id parameter
      esac
      response=$(echo "${response}" | jq -Mc)
      response_to_client "${response}" ${returncode}
      break
    fi
  done
  trace "[main] exiting"
  return ${returncode}
}

main
returncode=$?
trace "[requesthandler] exiting"
exit ${returncode}
