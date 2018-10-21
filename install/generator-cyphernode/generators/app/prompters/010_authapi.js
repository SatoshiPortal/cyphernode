const chalk = require('chalk');

const name = 'authentication';

const capitalise = function( txt ) {
  return txt.charAt(0).toUpperCase() + txt.substr(1);
};

const prefix = function() {
  return chalk.bold.red(capitalise(name)+': ');
};

module.exports = {
  name: function() { 
    return name;
  },
  prompts: function( utils ) {
    // TODO: delete clientKeys archive when password chnages
    return [{
      type: 'password',
      name: 'auth_clientkeyspassword',
      default: utils._getDefault( 'auth_clientkeyspassword' ),
      message: prefix()+'Enter a password to protect your client keys with'+'\n',
      filter: utils._trimFilter,
      validate: utils._notEmptyValidator
    },
    {
      type: 'confirm',
      name: 'auth_recreatekeys',
      default: false,
      message: prefix()+'Recreate auth keys?'+'\n'
    }];
  },
  templates: function( props ) {
    return [ 'keys.properties' ];
  }
};