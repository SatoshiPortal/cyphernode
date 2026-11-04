const chalk = require('chalk');

const name = 'ark';

const capitalise = function( txt ) {
  return txt.charAt(0).toUpperCase() + txt.substr(1);
};

const prefix = function() {
  return chalk.green(capitalise(name)+': ');
};

const featureCondition = function(props) {
  return props.features && props.features.indexOf( name ) != -1;
};

const urlValidator = function( input ) {
  if( /^https?:\/\/[^\s/]+(:[0-9]+)?(\/.*)?$/.test( input ) ) {
    return true;
  }
  return 'Enter the Ark server URL, for example https://ark.example.com';
};

module.exports = {
  name: function() {
    return name;
  },
  prompts: function( utils ) {
    return [
    {
      when: featureCondition,
      type: 'input',
      name: 'ark_server_url',
      default: utils.getDefault( 'ark_server_url' ),
      filter: utils.trimFilter,
      validate: urlValidator,
      message: prefix()+'What is the URL of your Ark server (captaind)?'+utils.getHelp('ark_server_url'),
    }
    ];
  },
  templates: function( props ) {
    return featureCondition(props)?['barkd.env']:[];
  }
};
