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
      default: utils.getDefault( 'gatekeeper_clientkeyspassword' ),
      message: prefix()+'Enter a password to protect your client keys with'+utils.getHelp('gatekeeper_clientkeyspassword'),
      filter: utils.trimFilter,
      validate: utils.notEmptyValidator
    },
    {
      when: function( props ) {
        // hacky hack
        password = props.gatekeeper_clientkeyspassword;
        return true;
      },
      type: 'password',
      name: 'gatekeeper_clientkeyspassword_c',
      default: utils.getDefault( 'gatekeeper_clientkeyspassword_c' ),
      message: prefix()+'Confirm your client keys password.'+utils.getHelp('gatekeeper_clientkeyspassword_c'),
      filter: utils.trimFilter,
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
      default: utils.getDefault( 'gatekeeper_port' ),
      message: prefix()+'The port gatekeeper will listen on for requests'+utils.getHelp('gatekeeper_port'),
      filter: utils.trimFilter,
      validate: function( port ) {
        return utils.notEmptyValidator( port ) && !isNaN( parseInt(port) )
      }
    },
    {
      when: function() { return hasAuthKeys( utils.props ); },
      type: 'confirm',
      name: 'gatekeeper_recreatekeys',
      default: false,
      message: prefix()+'Recreate gatekeeper keys?'+utils.getHelp('gatekeeper_recreatekeys')
    },
    {
      when: function() { return hasCert( utils.props ); },
      type: 'confirm',
      name: 'gatekeeper_recreatecert',
      default: false,
      message: prefix()+'Recreate gatekeeper certificate?'+utils.getHelp('gatekeeper_recreatecert')
    },
    {
      when: function(props) { return !hasCert( utils.props ) || props.gatekeeper_recreatecert },
      type: 'input',
      name: 'gatekeeper_cns',
      default: utils.getDefault( 'gatekeeper_cns' ),
      message: prefix()+'Gatekeeper cert CNS (ips, domains, wildcard domains seperated by comma)?'+utils.getHelp('gatekeeper_cns')
    }];
  },
  templates: function( props ) {
    return [ 'keys.properties', 'api.properties', 'cert.pem', 'key.pem', 'default.conf' ];
  }
};
