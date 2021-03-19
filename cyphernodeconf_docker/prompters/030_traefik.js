const chalk = require('chalk');

const name = 'traefik';

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
        type: 'input',
        name: 'traefik_http_port',
        default: utils.getDefault( 'traefik_http_port' ),
        message: prefix()+'The HTTP port your apps will be accessible to the internet on.'+utils.getHelp('traefik_http_port'),
        filter: utils.trimFilter,
        validate: function( port ) {
          return utils.notEmptyValidator( port ) && !isNaN( parseInt(port) )
        }
      },
      {
        type: 'input',
        name: 'traefik_https_port',
        default: utils.getDefault( 'traefik_https_port' ),
        message: prefix()+'The HTTPS port your apps will be accessible to the internet on.'+utils.getHelp('traefik_https_port'),
        filter: utils.trimFilter,
        validate: function( port ) {
          return utils.notEmptyValidator( port ) && !isNaN( parseInt(port) )
        }
      },
      {
        type: 'confirm',
        name: 'traefik_use_letsencrypt',
        default: utils.getDefault( 'traefik_use_letsencrypt' ),
        message: prefix()+'Use letsencrypt to create TLS certificates automatically.'+utils.getHelp('traefik_use_letsencrypt')
      },
      {
        when: function( props ) {
          return !!props.traefik_use_letsencrypt;
        },
        type: 'input',
        name: 'traefik_external_hostname',
        default: utils.getDefault( 'traefik_external_hostname' ),
        message: prefix()+'The hostname your cyphernode will be reachable by.'+utils.getHelp('traefik_external_hostname'),
        filter: utils.trimFilter
      },
      {
        when: function( props ) {
          return !!props.traefik_use_letsencrypt;
        },
        type: 'input',
        name: 'traefik_letsencrypt_email',
        default: utils.getDefault( 'traefik_letsencrypt_email' ),
        message: prefix()+'The email used to create new TLS certificates'+utils.getHelp('traefik_letsencrypt_email'),
        filter: utils.trimFilter
      }
    ];
  },
  templates: function( props ) {
    return [ 'acme.json', 'traefik.toml', 'htpasswd' ];
  }
};
