'use strict';
const Generator = require('yeoman-generator');
const chalk = require('chalk');
const fs = require('fs');
const wrap = require('wordwrap')(86);

module.exports = class extends Generator {

  constructor(args, opts) {
    super(args, opts);

    this.props = {
      name: 'supercollider-project',
      type: 'simple',
      description: ''
    };
  }

  /*
  prompting() {

    const prompts = [
      {
        type: 'confirm',
        name: 'someAnswer',
        message: 'Would you like to enable this option?',
        default: true
      }
    ];

    return this.prompt(prompts).then(props => {
      // To access props later use this.props.someAnswer;
      this.props = props;
    });
  }
  */

//  fountainPrompting() {
  prompting() {
    const splash = fs.readFileSync(this.templatePath('splash.txt'));
    this.log(splash.toString());

    var prompts = [
      {
        // https://github.com/SBoudrias/Inquirer.js#question
        // input, confirm, list, rawlist, expand, checkbox, password, editor
        type: 'checkbox',
        name: 'features',
        message: wrap('What features do you want to add to your cyphernode?')+'\n',
        choices: [
          {
            name: 'Bitcoin full node',
            value: 'bitcoin'
          },
          {
            name: 'Lightning node',
            value: 'lightning'
          },
          {
            name: 'Open timestamps server',
            value: 'ots'
          }

        ]
      },
      {
        when: function(answers) {
          return answers.features && 
            answers.features.indexOf( 'bitcoin' ) != -1;
        },
        type: 'confirm',
        default: false,
        name: 'lightning_implementation',
        message: wrap('Run bitcoin node in prune mode?')+'\n',
      },
      {
        when: function(answers) {
          return answers.features && 
            answers.features.indexOf( 'lightning' ) != -1;
        },
        type: 'list',
        name: 'lightning_implementation',
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
      }
    ];

    return this.prompt(prompts).then(props => {
      this.props = Object.assign(this.props, props);
    });
  }

  writing() {
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
