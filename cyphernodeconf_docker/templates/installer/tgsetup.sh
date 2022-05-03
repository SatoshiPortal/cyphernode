#!/bin/sh

# Cyphernode Telegram configuration
#
#
echo "Telegram setup.  Installing components..."
apk add --update --no-cache curl jq postgresql > /dev/null

sql() {
  local select_id=${2}
  local response
  local inserted_id

  echo "[sql] psql -qAtX -h postgres -U cyphernode -c \"${1}\""
  response=$(psql -qAtX -h postgres -U cyphernode -c "${1}")
  returncode=$?
  echo ${returncode}

  if [ -n "${select_id}" ]; then
    if [ "${returncode}" -eq "0" ]; then
      inserted_id=$(echo "${response}" | cut -d ' ' -f1)
    else
      echo "[sql] psql -qAtX -h postgres -U cyphernode -c \"${select_id}\""
      inserted_id=$(psql -qAtX -h postgres -U cyphernode -c "${select_id}")
      returncode=$?
      echo ${returncode}
    fi
    echo -n "${inserted_id}"
  else
    echo -n "${response}"
  fi

  return ${returncode}
}

# Ping the database an make sure it's UP
echo "Testing database before starting the configuration"

ping -c 1 postgres 2>&1 > /dev/null
rc=$?

if [ $rc != 0 ]; then
  echo "Database is not up.  Make sure Cyphernode is running before setting up Telegram"
  exit
else
  echo "Database is alive"
fi

while true; do
  read -p "Do you wish to configure Telegram for Cyphernode? [yn] " -n 1 -r

  case $REPLY in
    [Yy]* ) break;;
    [Nn]* ) echo ""; echo "Got it!  You can always come back later"; exit;;
    * ) echo "[31mPlease answer yes or no.[0m";;
  esac
done

# Set the base Telegram URL in DB
echo "Adding the Telegram base URL in database config table cyphernode_props"

TG_BASE_URL="https://api.telegram.org/bot"
sql "INSERT INTO cyphernode_props (category, property, value) VALUES ('notifier', 'tg_base_url', '$TG_BASE_URL') \
     ON CONFLICT (category, property) DO NOTHING"

echo ""
echo "[31mPlease go into your Telegram App and start chatting with the @BotFather[0m"
echo ""
echo "==> (Step 1) Enter @Botfather in the search tab and choose this bot"
echo "==> Note, official Telegram bots have a blue checkmark beside their name"
echo "==> (Step 2) Click “Start” to activate BotFather bot.  In response, you receive a list of commands to manage bots"
echo "==> (Step 3) Choose or type the /newbot command and send it"
echo "==> @BotFather replies: Alright, a new bot. How are we going to call it? Please choose a name for your bot"
echo "==> (Step 4) Choose a name for your bot.  And choose a username for your bot — the bot can be found by its username in searches. The username must be unique and end with the word 'bot'"
echo "==> After you choose a suitable name for your bot — the bot is created. You will receive a message with a link to your bot t.me/<bot_username>"
echo "==> Cyphernode needs the generated token to access the API: Copy the line below following the message 'Use this token to access the HTTP API' "

while true; do
  # 46 characters 1234567890:ABCrWd1mHlWzGM-2ovbxRnOF_g3V2-csY4E
  # matching '^[0-9]{10}:.{35}$'
  read -p "Enter the token here: " -n 46 -r
  
  if [[ $REPLY =~ ^[0-9]{10}:.{35}$ ]]; then
    # Token is good - continue
    break
  else
    echo ""
    echo "[31mOooops, it doesn't seem to be a valid token.[0m"
    echo "The token should be a string with this format 1234567890:ABCrWd1mHlWzGM-2ovbxRnOF_g3V2-csY4E."
    echo "Please enter the token again - 10 digits:35 characters"
  fi
done

# Now let's ping Telegram while we ask the user to type a message in Telegram

echo "[32mTelegram Setup will now try to obtain the chat ID from the Telgram server.[0m"
echo "To make this happen, please go into the Telegram App and send a message to the new bot"
echo "Click on the link in the @BotFather's answer : Congratulations on your new bot. You will find it at t.me/your-new-bot."

#
# The server will return something like below after the user sends a message
# '{"ok":true,"result":[{"update_id":846048856,
# "message":{"message_id":1,"from":{"id":6666666666,"is_bot":false,"first_name":"Phil","last_name":"","username":"phil","language_code":"en"},"chat":{"id":6666666666,"first_name":"Phil","last_name":"","username":"phil","type":"private"},"date":1649860823,"text":"/start","entities":[{"offset":0,"length":6,"type":"bot_command"}]}},{"update_id":666048857,
# "message":{"message_id":2,"from":{"id":6666666666,"is_bot":false,"first_name":"Phil","last_name":"","username":"phil","language_code":"en"},"chat":{"id":6666666666,"first_name":"Phil","last_name":"","username":"phil","type":"private"},"date":1649860826,"text":"hello"}}]}'
#

while true; do
  echo "Trying to contact Telegram server..."
  httpStatusCode=$(curl -o /dev/null -s -w '%{http_code}' $TG_BASE_URL$REPLY/getUpdates)

  if [[ $httpStatusCode == 200 ]]; then
    TG_API_KEY=$REPLY
    sql "INSERT INTO cyphernode_props (category, property, value) VALUES ('notifier', 'tg_api_key', '$TG_API_KEY') \
         ON CONFLICT (category, property) DO UPDATE SET value='$TG_API_KEY'"

    loop=1
    while [ $loop -le 10 ]; do
      response=$(curl -s $TG_BASE_URL$TG_API_KEY/getUpdates)
      isOk=$(echo $response | jq '.ok')
      if [ "$isOk" = "true" ]; then
        # get the chat id from the last message
        TG_CHAT_ID=$(echo $response | jq '.result[-1].message.chat.id')

        if [[ -z $TG_CHAT_ID || "$TG_CHAT_ID" == "null" ]]; then
          echo "[$loop] Received positive answer from Telegram without a chat id - Waiting for YOU to send a message in the chat..."
          sleep 10
          loop=$(( $loop + 1 ))
        else
          # Save the TG_CHAT_ID
          today=`date -u`
          sql "INSERT INTO cyphernode_props (category, property, value) VALUES ('notifier', 'tg_chat_id', '$TG_CHAT_ID') \
               ON CONFLICT (category, property) DO UPDATE SET value=$TG_CHAT_ID"

          echo ""
          echo "Reloading notifier configs"
          response=$(mosquitto_rr -h broker -W 15 -t notifier -e "response/$$" -m "{\"response-topic\":\"response/$$\",\"cmd\":\"reloadConfig\",\"tor\":false}")

          echo ""
          echo "Sending message to Telegram [$today]"
          body=$(echo "{\"text\":\"Hello from Cyphernode 2[$today] - setup is complete\"}" | base64 | tr -d '\n')
          response=$(mosquitto_rr -h broker -W 15 -t notifier -e "response/$$" -m "{\"response-topic\":\"response/$$\",\"cmd\":\"sendToTelegramGroup\",\"body\":\"${body}\"}")

          echo "Ok. Done."
          exit
        fi
      else
        echo "[31mServer returned an error [$response] - exiting[0m"; exit
      fi
    done
    echo "[31mNo message found. Please go into the Telegram App and send a message to the new bot - exiting[0m"; exit
  else
    echo "[31mServer returned a HTTP error code [$httpStatusCode] - exiting[0m"; break
  fi
done
