const name = 'proxy';

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
      type: 'list',
      name: 'net',
      default: utils._getDefault( 'net' ),
      message: 'What net do you want to run on?'+'\n',
      choices: [{
        name: "Testnet",
        value: "testnet"
      },{
        name: "Mainnet",
        value: "mainnet"
      }]
    },
    {
      type: 'input',
      name: 'xpub',
      default: utils._getDefault( 'xpub' ),
      message: 'What is your xpub to watch?'+'\n',
      validate: utils._xkeyValidator
    },
    {
      type: 'input',
      name: 'derivation_path',
      default: utils._getDefault( 'derivation_path' ),
      message: 'What is your address derivation path?'+'\n',
      validate: utils._derivationPathValidator
    }];
  },
  templates: function( props ) {
    return [ 'env.properties' ];
  }
};