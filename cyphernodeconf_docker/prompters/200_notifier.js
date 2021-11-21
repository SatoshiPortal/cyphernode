const chalk = require('chalk');

const name = 'notifier';

const capitalise = function( txt ) {
  return txt.charAt(0).toUpperCase() + txt.substr(1);
};

const prefix = function() {
  return chalk.green(capitalise(name)+': ');
};

const featureCondition = function(props) {
  return props.features && props.features.indexOf( 'telegram' ) != -1;
};

module.exports = {
  name: function() {
    return name;
  },
  prompts: function( utils ) {
    return [
      {
        when: featureCondition,
        type: 'input',
        name: 'telegram_bot_url',
        default: utils.getDefault( 'telegram_bot_url' ),
        message: prefix()+'The Telegram bot URL.'+utils.getHelp('telegram_bot_url'),
        filter: utils.trimFilter,
        validate: utils.notEmptyValidator
      },
      {
        when: featureCondition,
        type: 'input',
        name: 'telegram_api_key',
        default: utils.getDefault( 'telegram_api_key' ),
        message: prefix()+'The Telegram API key.'+utils.getHelp('telegram_api_key'),
        filter: utils.trimFilter,
        validate: utils.notEmptyValidator
      },
      {
        when: featureCondition,
        type: 'input',
        name: 'telegram_chat_id',
        default: utils.getDefault( 'telegram_chat_id' ),
        message: prefix()+'The Telegram chat id.'+utils.getHelp('telegram_chat_id'),
        filter: utils.trimFilter,
        validate:  function( chat_id ) {
          return utils.notEmptyValidator( chat_id ) && !isNaN( parseInt(chat_id) )
        }
      }
    ];
  },
  templates: function( props ) {
    return [ 'notifier.env' ];
  }
};
