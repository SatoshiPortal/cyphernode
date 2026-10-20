const chalk = require('chalk');

const name = 'elements';

const capitalise = function( txt ) {
  return txt.charAt(0).toUpperCase() + txt.substr(1);
};

const prefix = function() {
  return chalk.green(capitalise(name)+': ');
};

module.exports = {
  name: function() {
    return name;
  },
  prompts: function( utils ) {
    return [
      {
        when: function(props) { return props.features.indexOf('elements') !== -1 },
        type: 'input',
        name: 'liquid_explorer_url',
        default: utils.getDefault( 'liquid_explorer_url' ),
        message: prefix()+'Liquid explorer base URL?'+utils.getHelp('liquid_explorer_url'),
        filter: utils.trimFilter,
      }
    ];
  },
  env: function( props ) {
    return 'VAR0=VALUE0\nVAR1=VALUE1'
  },
  templates: function( props ) {
    return ['elements.conf', 'entrypoint.sh', 'createWallets.sh', 'walletnotify.sh', 'blocknotify.sh']
  }
};