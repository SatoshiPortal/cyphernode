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
      }
    ];
  },
  templates: function( props ) {
    return [ 'acme.json', 'traefik.toml', 'htpasswd' ];
  }
};
