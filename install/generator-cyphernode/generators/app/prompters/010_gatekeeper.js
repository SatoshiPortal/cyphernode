const chalk = require('chalk');

const name = 'gatekeeper';

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
      name: 'gatekeeper_clientkeyspassword',
      default: utils._getDefault( 'gatekeeper_clientkeyspassword' ),
      message: prefix()+'Enter a password to protect your client keys with'+utils._getHelp('gatekeeper_clientkeyspassword'),
      filter: utils._trimFilter,
      validate: utils._notEmptyValidator
    },
    {
      when: utils._hasAuthKeys,
      type: 'confirm',
      name: 'gatekeeper_recreatekeys',
      default: false,
      message: prefix()+'Recreate gatekeeper keys?'+utils._getHelp('gatekeeper_recreatekeys')
    },
    {
      when: utils._hasCert,
      type: 'confirm',
      name: 'gatekeeper_recreatecert',
      default: false,
      message: prefix()+'Recreate gatekeeper ssl cert?'+utils._getHelp('gatekeeper_recreatecert')
    },
    {
      type: 'confirm',
      name: 'gatekeeper_edit_ipwhitelist',
      default: false,
      message: prefix()+'Edit IP whitelist?'+utils._getHelp('gatekeeper_edit_ipwhitelist')
    },
    {
      when: function( props ) { 
        const r = props.gatekeeper_edit_ipwhitelist;
        delete props.gatekeeper_edit_ipwhitelist;
        return r;
      },
      type: 'editor',
      name: 'gatekeeper_ipwhitelist',
      message: utils._getHelp('gatekeeper_ipwhitelist')||' ',
      default: utils._getDefault( 'gatekeeper_ipwhitelist' )
    },
    {
      type: 'confirm',
      name: 'gatekeeper_edit_apiproperties',
      default: false,
      message: prefix()+'Edit API properties?'+utils._getHelp('gatekeeper_edit_apiproperties')
    },
    {
      when: function( props ) { 
        const r = props.gatekeeper_edit_apiproperties;
        delete props.gatekeeper_edit_apiproperties;
        return r;
      },
      type: 'editor',
      name: 'gatekeeper_apiproperties',
      message: utils._getHelp('gatekeeper_apiproperties')||' ',
      default: utils._getDefault( 'gatekeeper_apiproperties' )
    }];
  },
  templates: function( props ) {
    return [ 'keys.properties', 'api.properties', 'ip-whitelist.conf', 'cert.pem', 'key.pem' ];
  }
};