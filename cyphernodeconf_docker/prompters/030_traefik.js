const chalk = require('chalk');

const name = 'traefik';

module.exports = {
  name: function() {
    return name;
  },
  prompts: function( utils ) {
    return [];
  },
  templates: function( props ) {
    return [ 'acme.json', 'traefik.toml', 'htpasswd' ];
  }
};
