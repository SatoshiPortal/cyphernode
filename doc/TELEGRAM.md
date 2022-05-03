# Telegram integration in Cyphernode.

Build and setup Cyphernode - Choose to enable Telegram.  The first time you run Cyphernode, you will get an error concerning Telegram beacause Telegram has to be setup with the next few steps.

==> START CYPHERNODE running /dist/start.sh

In directory cyphernode/notifier_docker/scripts, you will find the script start-tg-setup.sh to start the Telegram setup.  It runs inside the notifier container with this command : 
      docker exec -it $(docker ps -q -f "name=cyphernode_notifier") ./tgsetup.sh 

Follow the steps of the installer - example output follows:

In directory notifier_docker/script, run ** ./start-tg-setup.sh **

Testing database before starting the configuration
Database is alive

Do you wish to configure Telegram for Cyphernode? [yn] yA

dding the Telegram base URL in database config table cyphernode_props
[sql] psql -qAtX -h postgres -U cyphernode -c "INSERT INTO ...."


Please go into your Telegram App and start chatting with the @BotFather

==> (Step 1) Enter @Botfather in the search tab and choose this bot

==> Note, official Telegram bots have a blue checkmark beside their name

==> (Step 2) Click “Start” to activate BotFather bot.  In response, you receive a list of commands to manage bots

==> (Step 3) Choose or type the /newbot command and send it

==> @BotFather replies: Alright, a new bot. How are we going to call it? Please choose a name for your bot

==> (Step 4) Choose a name for your bot.  And choose a username for your bot — the bot can be found by its username in searches. The username must be unique and end with the word 'bot'

==> After you choose a suitable name for your bot — the bot is created. You will receive a message with a link to your bot t.me/<bot_username>

==> Cyphernode needs the generated token to access the API: Copy the line below following the message 'Use this token to access the HTTP API' 

Enter the token here: 5172851233:AAHkpd4T1ILyhXyqDelNnOTgFE4hl-AQSVM

Telegram Setup will now try to obtain the chat ID from the Telgram server.

To make this happen, please go into the Telegram App and send a message to the new bot

Click on the link in the @BotFather's answer : Congratulations on your new bot. You will find it at t.me/your-new-bot.

Trying to contact Telegram server...

Reloading configs

Sending message to Telegram [Tue May  3 16:29:03 UTC 2022]
Ok. Done.



===============================================================
How it works :

calling Telegram API
  example :
   https://api.telegram.org/bot+TELEGRAM_API_KEY/your-action 
   https://api.telegram.org/botTELEGRAM_API_KEY/getMe
 returns:
   {"ok":true,"result":{"id":2084591315,"is_bot":true,"first_name":"Roger-logger","username":"RogerLoggerBot","can_join_groups":true,"can_read_all_group_messages":false,"supports_inline_queries":false}}

  Add your Bot to a group and then get updates to get the chat.ID in order to send messages to this group afterwards.
  Below, the chat.id is chat.id:-TELEGRAM_CHAT_ID

 https://api.telegram.org/botTELEGRAM_API_KEY/getUpdates

            {"ok":true,"result":[{"update_id":701180871,
            #"my_chat_member":{"chat":{"id":-TELEGRAM_CHAT_ID,"title":"Logging","type":"group","all_members_are_administrators":false},"from":{"id":1609436204,"is_bot":false,"first_name":"Roger","last_name":"Brulotte","username":"RogerBrulotte","language_code":"en"},"date":1635877254,"old_chat_member":{"user":{"id":2084591315,"is_bot":true,"first_name":"Roger-logger","username":"RogerLoggerBot"},"status":"member"},"new_chat_member":{"user":{"id":2084591315,"is_bot":true,"first_name":"Roger-logger","username":"RogerLoggerBot"},"status":"left"}}},{"update_id":701180872,
            #"message":{"message_id":7,"from":{"id":1609436204,"is_bot":false,"first_name":"Roger","last_name":"Brulotte","username":"RogerBrulotte","language_code":"en"},"chat":{"id":-TELEGRAM_CHAT_ID,"title":"Logging","type":"group","all_members_are_administrators":true},"date":1635877254,"left_chat_participant":{"id":2084591315,"is_bot":true,"first_name":"Roger-logger","username":"RogerLoggerBot"},"left_chat_member":{"id":2084591315,"is_bot":true,"first_name":"Roger-logger","username":"RogerLoggerBot"}}},{"update_id":701180873,
            #"my_chat_member":{"chat":{"id":-TELEGRAM_CHAT_ID,"title":"Logging","type":"group","all_members_are_administrators":true},"from":{"id":1609436204,"is_bot":false,"first_name":"Roger","last_name":"Brulotte","username":"RogerBrulotte","language_code":"en"},"date":1635877290,"old_chat_member":{"user":{"id":2084591315,"is_bot":true,"first_name":"Roger-logger","username":"RogerLoggerBot"},"status":"left"},"new_chat_member":{"user":{"id":2084591315,"is_bot":true,"first_name":"Roger-logger","username":"RogerLoggerBot"},"status":"member"}}},{"update_id":701180874,
            #"message":{"message_id":8,"from":{"id":1609436204,"is_bot":false,"first_name":"Roger","last_name":"Brulotte","username":"RogerBrulotte","language_code":"en"},"chat":{"id":-TELEGRAM_CHAT_ID,"title":"Logging","type":"group","all_members_are_administrators":true},"date":1635877290,"new_chat_participant":{"id":2084591315,"is_bot":true,"first_name":"Roger-logger","username":"RogerLoggerBot"},"new_chat_member":{"id":2084591315,"is_bot":true,"first_name":"Roger-logger","username":"RogerLoggerBot"},"new_chat_members":[{"id":2084591315,"is_bot":true,"first_name":"Roger-logger","username":"RogerLoggerBot"}]}}]}

Bot says Hello World using the chat id returned previously
 https://api.telegram.org/botTOKEN/sendMessage?chat_id=CHAT-ID&text=Hello+World
 https://api.telegram.org/botTELEGRAM_API_KEY/sendMessage?chat_id=-TELEGRAM_CHAT_ID&text=Hello+World

 returns:
            {"ok":true,"result":{"message_id":9,"from":{"id":2084591315,"is_bot":true,"first_name":"Roger-logger","username":"RogerLoggerBot"},"chat":{"id":-TELEGRAM_CHAT_ID,"title":"Logging","type":"group","all_members_are_administrators":true},"date":1635877783,"text":"Hello World"}} 
            


curl POST example
 curl -X POST https://api.telegram.org/botTELEGRAM_API_KEY/sendMessage?chat_id=TELEGRAM_CHAT_ID -H 'Content-Type: application/json' -d '{"text":"text in POST data"}'
