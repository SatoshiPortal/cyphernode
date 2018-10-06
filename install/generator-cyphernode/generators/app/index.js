'use strict';
const Generator = require('yeoman-generator');
const chalk = require('chalk');
const fs = require('fs');
const wrap = require('wordwrap')(86);
const validator = require('validator');

module.exports = class extends Generator {

  constructor(args, opts) {
    super(args, opts);

    this.props = {

    };
  }

  /* values */

  _isChecked( name, value ) {
    return value=='bitcoin';
  }

  _getConfirmDefault( name ) {
    return true;
  }

  _getListDefault( name ) {
    return 'lnd';
  }

  _getInputDefault( name ) {
    return '';
  }

  /* validators */
  _ipValidator( ip ) {
    return validator.isIP((ip+"").trim());
  }

  /* filters */

  _trimFilter( input ) {
    return input.trim();
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
          name: 'Open timestamps server',
          value: 'ots',
          checked: this._isChecked( 'features', 'ots' )
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
      default: this._getConfirmDefault( 'bitcoin_prune' ),
      message: wrap('Run bitcoin node in prune mode?')+'\n',
    },
    {
      when: function(answers) {
        return answers.features && 
          answers.features.indexOf( 'bitcoin' ) != -1;
      },
      type: 'input',
      name: 'bitcoin_external_ip',
      default: this._getInputDefault( 'bitcoin_external_ip' ),
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
      default: this._getListDefault( 'lightning_implementation' ),
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
      //.concat(this._configureCLightning())
      //.concat(this._configureLND())

    return this.prompt(prompts).then(props => {
      this.props = Object.assign(this.props, props);
    });
  }

  writing() {
    console.log( JSON.stringify(this.props, null, 2));
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
