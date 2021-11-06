const chalk = require('chalk');

const name = 'postgres';

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
      type: 'password',
      name: 'postgres_password',
      default: utils.getDefault( 'postgres_password' ),
      message: prefix()+'Password of Postgres cyphernode user?'+utils.getHelp('postgres_password'),
      filter: utils.trimFilter,
    }];
  },
  templates: function( props ) {
    return ['pgpass'];
  }
};