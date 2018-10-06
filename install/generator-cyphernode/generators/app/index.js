'use strict';
const Generator = require('yeoman-generator');
const chalk = require('chalk');
const fs = require('fs');
const wrap = require('wordwrap')(86);
const validator = require('validator');

module.exports = class extends Generator {

  constructor(args, opts) {
    super(args, opts);
    if( fs.existsSync('/data/props.json') ) {
      this.props = require('/data/props.json');
    } else {
      this.props = {};
    }

    console.log( this.props );
  }

  /* values */
  _isChecked( name, value ) {
    return this.props && this.props[name].indexOf(value) != -1 ;
  }

  _getDefault( name ) {
    return this.props && this.props[name];
  }

  /* validators */
  _ipValidator( ip ) {
    return validator.isIP((ip+"").trim());
  }

  /* filters */

  _trimFilter( input ) {
    return (input+"").trim();
  } 

  /* prompts */
  _configureFeatures() {
    return [{
      // https://github.com/SBoudrias/Inquirer.js#question
      // input, confirm, list, rawlist, expand, checkbox, password, editor
      type: 'checkbox',
      name: 'features',
      message: wrap('What features do you want to add to your cyphernode?')+'\n',
      choices: [
        {
          name: 'Bitcoin full node',
          value: 'bitcoin',
          checked: this._isChecked( 'features', 'bitcoin' )
        },
        {
          name: 'Lightning node',
          value: 'lightning',
          checked: this._isChecked( 'features', 'lightning' )

        },
        {
          name: 'Open timestamps client',
          value: 'ots',
          checked: this._isChecked( 'features', 'ots' )
        },
        {
          name: 'Electrum server',
          value: 'electrum',
          checked: this._isChecked( 'features', 'electrum' )
        }

      ]
    }];
  }

  _configureBitcoinFullNode() {
    return [{
      when: function(answers) {
        return answers.features && 
          answers.features.indexOf( 'bitcoin' ) != -1;
      },
      type: 'confirm',
      name: 'bitcoin_prune',
      default: this._getDefault( 'bitcoin_prune' ),
      message: wrap('Run bitcoin node in prune mode?')+'\n',
    },
    {
      when: function(answers) {
        return answers.features && 
          answers.features.indexOf( 'bitcoin' ) != -1;
      },
      type: 'input',
      name: 'bitcoin_external_ip',
      default: this._getDefault( 'bitcoin_external_ip' ),
      validate: this._ipValidator,
      message: wrap('What external ip does your bitcoin full node have?')+'\n',
    }];
  }

  _configureLightningImplementation() {
    return [{
      when: function(answers) {
        return answers.features && 
          answers.features.indexOf( 'lightning' ) != -1;
      },
      type: 'list',
      name: 'lightning_implementation',
      default: this._getDefault( 'lightning_implementation' ),
      message: wrap('What lightning implementation do you want to use?')+'\n',
      choices: [
        {
          name: 'C-lightning',
          value: 'c-lightning'
        },
        {
          name: 'LND',
          value: 'lnd'
        }
      ]
    }];
  }

  _configureElectrumImplementation() {
    return [{
      when: function(answers) {
        return answers.features && 
          answers.features.indexOf( 'electrum' ) != -1;
      },
      type: 'list',
      name: 'electrum_implementation',
      default: this._getDefault( 'electrum_implementation' ),
      message: wrap('What electrum implementation do you want to use?')+'\n',
      choices: [
        {
          name: 'Electrum personal server',
          value: 'eps'
        },
        {
          name: 'Electrumx server',
          value: 'elx'
        }
      ]
    }];
  }

  _configureCLightning() {
    return [{}];
  }

  _configureLND() {
    return [{}];
  }

  prompting() {
    const splash = fs.readFileSync(this.templatePath('splash.txt'));
    this.log(splash.toString());

    var prompts = 
      this._configureFeatures()
      .concat(this._configureBitcoinFullNode())
      .concat(this._configureLightningImplementation())
      .concat(this._configureElectrumImplementation())
      //.concat(this._configureCLightning())
      //.concat(this._configureLND())

    return this.prompt(prompts).then(props => {
      this.props = Object.assign(this.props, props);
    });
  }

  writing() {
    fs.writeFileSync('/data/props.json', JSON.stringify(this.props, null, 2));
    /*
    this.fs.copy(
      this.templatePath('dummyfile.txt'),
      this.destinationPath('dummyfile.txt')
    );
    */
  }

  install() {
  }
};
