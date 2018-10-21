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
      when: utils._hasAuthKeys,
      type: 'confirm',
      name: 'auth_recreatekeys',
      default: false,
      message: prefix()+'Recreate auth keys?'
    },
    {
      type: 'confirm',
      name: 'auth_edit_ipwhitelist',
      default: false,
      message: prefix()+'Edit IP whitelist?'
    },
    {
      when: function( props ) { 
        const r = props.auth_edit_ipwhitelist;
        delete props.auth_edit_ipwhitelist;
        return r;
      },
      type: 'editor',
      name: 'auth_ipwhitelist',
      message: 'IP whitelist',
      default: utils._getDefault( 'auth_ipwhitelist' )
    },
    {
      type: 'confirm',
      name: 'auth_edit_apiproperties',
      default: false,
      message: prefix()+'Edit API properties?'
    },
    {
      when: function( props ) { 
        const r = props.auth_edit_apiproperties;
        delete props.auth_edit_apiproperties;
        return r;
      },
      type: 'editor',
      name: 'auth_apiproperties',
      message: 'API properties',
      default: utils._getDefault( 'auth_apiproperties' )
    }];
  },
  templates: function( props ) {
    return [ 'keys.properties', 'api.properties', 'ip-whitelist.conf' ];
  }
};