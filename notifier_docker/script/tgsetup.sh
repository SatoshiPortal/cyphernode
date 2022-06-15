#!/bin/sh

. ./colors.sh

# Cyphernode Telegram configuration
#
#
sql() {
  local select_id=${2}
  local response
  local inserted_id

  response=$(psql -qAtX -h postgres -U cyphernode -c "${1}")
  returncode=$?

  if [ -n "${select_id}" ]; then
    if [ "${returncode}" -eq "0" ]; then
      inserted_id=$(echo -e "${response}" | cut -d ' ' -f1)
    else
      inserted_id=$(psql -qAtX -h postgres -U cyphernode -c "${select_id}")
      returncode=$?
    fi
  fi

  return ${returncode}
}

# Ping the database an make sure it's UP
echo -e "\r\n$BIBlue"; echo -e "[TG Setup] Testing database before starting the configuration"

ping -c 1 postgres 2>&1 > /dev/null
rc=$?

if [ $rc != 0 ]; then
  echo -e "\r\n$BIRed"; echo -e "[TG Setup] Database is not up.  Make sure Cyphernode is running before setting up Telegram. Exiting\r\n"
  exit 1
else
  echo -e "\r\n$Green"; echo -e "[TG Setup] Database is alive"
fi

if [ -n "$TOR_TELEGRAM" ] && [ "$TOR_TELEGRAM" = "1" ]; then
  echo -e "[TG Setup] Sending Telegram messages usging tor\r\n"
else
  echo -e "[TG Setup] Sending Telegram messages usging clearnet\r\n"
fi

while true; do
  echo -e "\r\n$Green";
  read -p "[TG Setup] Do you wish to configure Telegram for Cyphernode? [yn] " -n 1 -r

  case $REPLY in
    [Yy]* ) break;;
    [Nn]* ) echo -e "\r\n[TG Setup] Got it!  You can always come back later"; exit;;
    * ) echo -e "[31mPlease answer yes or no.";;
  esac
done

# Set the base Telegram URL in DB
echo -e $Blue; echo -e "\r\n[TG Setup] Adding the Telegram base URL in database config table cyphernode_props\r\n"

TG_BASE_URL="https://api.telegram.org/bot"
sql "INSERT INTO cyphernode_props (category, property, value) VALUES ('notifier', 'tg_base_url', '$TG_BASE_URL') \
     ON CONFLICT (category, property) DO NOTHING"

echo -e ""
echo -e "[31m[TG Setup] Please go into your Telegram App and start chatting with the @BotFather[0m\r\n"
echo -e "\r\n$Blue";
echo -e "==> (Step 1) Enter @Botfather in the search tab and choose this bot"
echo -e "==> Note, official Telegram bots have a blue checkmark beside their name"
echo -e "==> (Step 2) Click “Start” to activate BotFather bot.  In response, you receive a list of commands to manage bots"
echo -e "==> (Step 3) Choose or type the /newbot command and send it"
echo -e "==> @BotFather replies: Alright, a new bot. How are we going to call it? Please choose a name for your bot"
echo -e "==> (Step 4) Choose a name for your bot.  And choose a username for your bot — the bot can be found by its username in searches. The username must be unique and end with the word 'bot'"
echo -e "==> After you choose a suitable name for your bot — the bot is created. You will receive a message with a link to your bot t.me/<bot_username>"
echo -e "==> Cyphernode needs the generated token to access the API: Copy the line below following the message 'Use this token to access the HTTP API' "
echo -e "\r\n\r\n"

while true; do
  echo -e "\r\n$Green";

  # 46 characters 1234567890:ABCrWd1mHlWzGM-2ovbxRnOF_g3V2-csY4E
  # matching '^[0-9]{10}:.{35}$'
  read -p "[TG Setup] Enter the token here: " -n 46 -r
  
  if [[ ${#REPLY} -gt 0 ]] && [[ $REPLY =~ ^[0-9]{10}:.{35}$ ]]; then
    # Token is good - continue
    break
  else
    echo -e "$BIRed"
    echo -e "[TG Setup] Oooops, it doesn't seem to be a valid token."
    echo -e "[TG Setup] The token should be a string with this format 1234567890:ABCrWd1mHlWzGM-2ovbxRnOF_g3V2-csY4E."
    echo -e "[TG Setup] Please enter the token again - 10 digits:35 characters"
  fi
done

# Now let's ping Telegram while we ask the user to type a message in Telegram

echo -e "\r\n$Green";
echo -e "\r\n[TG Setup] Telegram Setup will now try to obtain the chat ID from the Telgram server.\r\n"

echo -e "To make this happen, please go into the Telegram App and send a message to the new bot"
echo -e "Click on the link in the @BotFather's answer : Congratulations on your new bot. You will find it at t.me/your-new-bot."

#
# The server will return something like below after the user sends a message
# '{"ok":true,"result":[{"update_id":846048856,
# "message":{"message_id":1,"from":{"id":6666666666,"is_bot":false,"first_name":"Phil","last_name":"","username":"phil","language_code":"en"},"chat":{"id":6666666666,"first_name":"Phil","last_name":"","username":"phil","type":"private"},"date":1649860823,"text":"/start","entities":[{"offset":0,"length":6,"type":"bot_command"}]}},{"update_id":666048857,
# "message":{"message_id":2,"from":{"id":6666666666,"is_bot":false,"first_name":"Phil","last_name":"","username":"phil","language_code":"en"},"chat":{"id":6666666666,"first_name":"Phil","last_name":"","username":"phil","type":"private"},"date":1649860826,"text":"hello"}}]}'
#

while true; do
  echo -e "Trying to contact Telegram server..."
  httpStatusCode=$(curl -o /dev/null -s -w '%{http_code}' $TG_BASE_URL$REPLY/getUpdates)

  if [[ $httpStatusCode == 200 ]]; then
    TG_API_KEY=$REPLY
    sql "INSERT INTO cyphernode_props (category, property, value) VALUES ('notifier', 'tg_api_key', '$TG_API_KEY') \
         ON CONFLICT (category, property) DO UPDATE SET value='$TG_API_KEY'"

    loop=1
    while [ $loop -le 10 ]; do
      response=$(curl -s $TG_BASE_URL$TG_API_KEY/getUpdates)
      isOk=$(echo -e $response | jq '.ok')
      if [ "$isOk" = "true" ]; then
        # get the chat id from the last message
        TG_CHAT_ID=$(echo -e $response | jq '.result[-1].message.chat.id')

        if [[ -z $TG_CHAT_ID || "$TG_CHAT_ID" == "null" ]]; then
          echo -e $Yellow; echo -e "[$loop] [TG Setup] Received positive answer from Telegram without a chat id - Waiting for$IRed YOU$Yellow to send a message in the chat..."
          sleep 10
          loop=$(( $loop + 1 ))
        else
          # Save the TG_CHAT_ID
          today=`date -u`
          sql "INSERT INTO cyphernode_props (category, property, value) VALUES ('notifier', 'tg_chat_id', '$TG_CHAT_ID') \
               ON CONFLICT (category, property) DO UPDATE SET value=$TG_CHAT_ID"

          echo -e "$Green"
          echo -e "[TG Setup] Reloading configs\r\n"

          response=$(mosquitto_rr -h broker -W 15 -t notifier -e "response/$$" -m "{\"response-topic\":\"response/$$\",\"cmd\":\"reloadConfig\"}")

          echo -e ""
          echo -e "[TG Setup] Sending message to Telegram [$today]"

          if [ "${TOR_TELEGRAM}" = "true" ]; then
            body=$(echo -e "{\"text\":\"Hello from Cyphernode [$today] using tor - setup is complete\"}" | base64 | tr -d '\n')
            response=$(mosquitto_rr -h broker -W 15 -t notifier -e "response/$$" -m "{\"response-topic\":\"response/$$\",\"cmd\":\"sendToTelegramGroup\",\"body\":\"${body}\",\"tor\":true}")
          else
            body=$(echo -e "{\"text\":\"Hello from Cyphernode [$today] using clearnet - setup is complete\"}" | base64 | tr -d '\n')
            response=$(mosquitto_rr -h broker -W 15 -t notifier -e "response/$$" -m "{\"response-topic\":\"response/$$\",\"cmd\":\"sendToTelegramGroup\",\"body\":\"${body}\"}")
          fi
          
          echo -e "$BBlue"
          echo -e "\r\n[TG Setup] Ok. Done."
          exit
        fi
      else
        echo -e "\r\n[31m[TG Setup] Server returned an error [$response] - exiting[0m"; exit
      fi
    done
    echo -e "\r\n[31m[TG Setup] No message found. Please go into the Telegram App and send a message to the new bot - exiting[0m"; exit
  else
    echo -e "\r\n[31m[TG Setup] Server returned a HTTP error code [$httpStatusCode] - exiting[0m"; break
  fi
done
