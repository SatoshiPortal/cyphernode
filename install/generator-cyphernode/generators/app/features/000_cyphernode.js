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
      type: 'confirm',
      name: 'cyphernode_rocks0',
      default: utils._getDefault( 'cyphernode_rocks0' ),
      message: 'Does cyphernode rock?'+'\n',
    },
    {
      type: 'confirm',
      name: 'cyphernode_rocks1',
      default: utils._getDefault( 'cyphernode_rocks1' ),
      message: 'Does cyphernode rock?'+'\n',
    }];
  },
  env: function( props ) {
    return 'VAR0=VALUE0\nVAR1=VALUE1'
  }
};