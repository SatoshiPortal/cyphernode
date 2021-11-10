# Get your Telegram API Key by chating with the @BotFather
# Details here https://core.telegram.org/bots
#
# calling Telegram API
# example :
#   https://api.telegram.org/bot+TELEGRAM_API_KEY/your-action 
#   https://api.telegram.org/botTELEGRAM_API_KEY/getMe
# returns:
#   {"ok":true,"result":{"id":2084591315,"is_bot":true,"first_name":"Roger-logger","username":"RogerLoggerBot","can_join_groups":true,"can_read_all_group_messages":false,"supports_inline_queries":false}}
#
#  Add your Bot to a group and then get updates to get the chat.ID in order to send messages to this group afterwards.
#  Below, the chat.id is chat.id:-TELEGRAM_CHAT_ID
#
# https://api.telegram.org/botTELEGRAM_API_KEY/getUpdates
#
# {"ok":true,"result":[{"update_id":701180871,
#"my_chat_member":{"chat":{"id":-TELEGRAM_CHAT_ID,"title":"Logging","type":"group","all_members_are_administrators":false},"from":{"id":1609436204,"is_bot":false,"first_name":"Roger","last_name":"Brulotte","username":"RogerBrulotte","language_code":"en"},"date":1635877254,"old_chat_member":{"user":{"id":2084591315,"is_bot":true,"first_name":"Roger-logger","username":"RogerLoggerBot"},"status":"member"},"new_chat_member":{"user":{"id":2084591315,"is_bot":true,"first_name":"Roger-logger","username":"RogerLoggerBot"},"status":"left"}}},{"update_id":701180872,
#"message":{"message_id":7,"from":{"id":1609436204,"is_bot":false,"first_name":"Roger","last_name":"Brulotte","username":"RogerBrulotte","language_code":"en"},"chat":{"id":-TELEGRAM_CHAT_ID,"title":"Logging","type":"group","all_members_are_administrators":true},"date":1635877254,"left_chat_participant":{"id":2084591315,"is_bot":true,"first_name":"Roger-logger","username":"RogerLoggerBot"},"left_chat_member":{"id":2084591315,"is_bot":true,"first_name":"Roger-logger","username":"RogerLoggerBot"}}},{"update_id":701180873,
#"my_chat_member":{"chat":{"id":-TELEGRAM_CHAT_ID,"title":"Logging","type":"group","all_members_are_administrators":true},"from":{"id":1609436204,"is_bot":false,"first_name":"Roger","last_name":"Brulotte","username":"RogerBrulotte","language_code":"en"},"date":1635877290,"old_chat_member":{"user":{"id":2084591315,"is_bot":true,"first_name":"Roger-logger","username":"RogerLoggerBot"},"status":"left"},"new_chat_member":{"user":{"id":2084591315,"is_bot":true,"first_name":"Roger-logger","username":"RogerLoggerBot"},"status":"member"}}},{"update_id":701180874,
#"message":{"message_id":8,"from":{"id":1609436204,"is_bot":false,"first_name":"Roger","last_name":"Brulotte","username":"RogerBrulotte","language_code":"en"},"chat":{"id":-TELEGRAM_CHAT_ID,"title":"Logging","type":"group","all_members_are_administrators":true},"date":1635877290,"new_chat_participant":{"id":2084591315,"is_bot":true,"first_name":"Roger-logger","username":"RogerLoggerBot"},"new_chat_member":{"id":2084591315,"is_bot":true,"first_name":"Roger-logger","username":"RogerLoggerBot"},"new_chat_members":[{"id":2084591315,"is_bot":true,"first_name":"Roger-logger","username":"RogerLoggerBot"}]}}]}
#
# Bot says Hello World using the chat id returned previously
# https://api.telegram.org/botTOKEN/sendMessage?chat_id=CHAT-ID&text=Hello+World
# https://api.telegram.org/botTELEGRAM_API_KEY/sendMessage?chat_id=-TELEGRAM_CHAT_ID&text=Hello+World
#
# returns:
# {"ok":true,"result":{"message_id":9,"from":{"id":2084591315,"is_bot":true,"first_name":"Roger-logger","username":"RogerLoggerBot"},"chat":{"id":-TELEGRAM_CHAT_ID,"title":"Logging","type":"group","all_members_are_administrators":true},"date":1635877783,"text":"Hello World"}} 
#
#
#
# curl POST
# curl -X POST https://api.telegram.org/botTELEGRAM_API_KEY/sendMessage?chat_id=TELEGRAM_CHAT_ID -H 'Content-Type: application/json' -d '{"text":"text in POST data"}'
#
TELEGRAM_BOT_URL=https://api.telegram.org/bot
TELEGRAM_API_KEY=TELEGRAM_API_KEY
TELEGRAM_CHAT_ID=-TELEGRAM_CHAT_ID

# Add those keys to /script/config.sh