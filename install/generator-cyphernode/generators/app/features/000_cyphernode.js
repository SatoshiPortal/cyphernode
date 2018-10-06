const name = 'cyphernode';

module.exports = {
  name: function() { 
    return name;
  },
  prompts: function( utils ) {
    return [{
      // https://github.com/SBoudrias/Inquirer.js#question
      // input, confirm, list, rawlist, expand, checkbox, password, editor
      type: 'checkbox',
      name: 'features',
      message: 'What features do you want to add to your cyphernode?'+'\n',
      choices: utils._featureChoices()
    },
    {
      type: 'input',
      name: 'cyphernode_xpub',
      default: utils._getDefault( 'cyphernode_xpub' ),
      message: 'What is your xpub to watch?'+'\n',
      validate: utils._xkeyValidator
    }];
  },
  env: function( props ) {
    return 'VAR0=VALUE0\nVAR1=VALUE1'
  }
};