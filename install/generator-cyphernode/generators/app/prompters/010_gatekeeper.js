const chalk = require('chalk');

const name = 'gatekeeper';

const capitalise = function( txt ) {
  return txt.charAt(0).toUpperCase() + txt.substr(1);
};

const prefix = function() {
  return chalk.green(capitalise(name)+': ');
};

const hasAuthKeys = function( props ) {
  return props &&
    props.gatekeeper_keys &&
    props.gatekeeper_keys.configEntries &&
    props.gatekeeper_keys.configEntries.length > 0;
}

const hasCert = function( props ) {
  return props &&
    props.gatekeeper_sslkey &&
    props.gatekeeper_sslcert
}

let password = '';

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
      when: function( props ) {
        // hacky hack
        password = props.gatekeeper_clientkeyspassword;
        return true;
      },
      type: 'password',
      name: 'gatekeeper_clientkeyspassword_c',
      default: utils._getDefault( 'gatekeeper_clientkeyspassword_c' ),
      message: prefix()+'Confirm your client keys password.'+utils._getHelp('gatekeeper_clientkeyspassword_c'),
      filter: utils._trimFilter,
      validate: function( input ) {
        if(input !== password) {
          throw new Error( 'Client keys passwords do not match' );
        }
        return true;
      }
    },
    {
      type: 'input',
      name: 'gatekeeper_port',
      default: utils._getDefault( 'gatekeeper_port' ),
      message: prefix()+'The port gatekeeper will listen on for requests'+utils._getHelp('gatekeeper_port'),
      filter: utils._trimFilter,
      validate: function( port ) {
        return utils._notEmptyValidator( port ) && !isNaN( parseInt(port) )
      }
    },
    {
      when: function() { return hasAuthKeys( utils.props ); },
      type: 'confirm',
      name: 'gatekeeper_recreatekeys',
      default: false,
      message: prefix()+'Recreate gatekeeper keys?'+utils._getHelp('gatekeeper_recreatekeys')
    },
    {
      when: function() { return hasCert( utils.props ); },
      type: 'confirm',
      name: 'gatekeeper_recreatecert',
      default: false,
      message: prefix()+'Recreate gatekeeper certificate?'+utils._getHelp('gatekeeper_recreatecert')
    },
    {
      when: function(props) { return !hasCert( utils.props ) || props.gatekeeper_recreatecert },
      type: 'input',
      name: 'gatekeeper_cns',
      default: utils._getDefault( 'gatekeeper_cns' ),
      message: prefix()+'Gatekeeper cert CNS (ips, domains, wildcard domains seperated by comma)?'+utils._getHelp('gatekeeper_cns')
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
    return [ 'keys.properties', 'api.properties', 'cert.pem', 'key.pem', 'htpasswd' ];
  }
};
