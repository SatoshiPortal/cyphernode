'use strict';
const Generator = require('yeoman-generator');
const chalk = require('chalk');
const fs = require('fs');
const wrap = require('wordwrap')(86);
const validator = require('validator');
const path = require("path");
const featureChoices = require(path.join(__dirname, "features.json"));
const coinstring = require('coinstring');

let featurePromptModules = [];
const normalizedPath = path.join(__dirname, "features");
fs.readdirSync(normalizedPath).forEach(function(file) {
  featurePromptModules.push(require(path.join(normalizedPath,file)));
});

module.exports = class extends Generator {

  constructor(args, opts) {
    super(args, opts);

    if( fs.existsSync('/data/props.json') ) {
      this.props = require('/data/props.json');
    } else {
      this.props = {};
    }

    this.featureChoices = featureChoices;
    for( let c of this.featureChoices ) {
      c.checked = this._isChecked( 'features', c.value );
    }

  }

  prompting() {
    const splash = fs.readFileSync(this.templatePath('splash.txt'));
    this.log(splash.toString());
    
    let prompts = [];

    for( let m of featurePromptModules ) {
      prompts = prompts.concat(m.prompts(this));
    }

    return this.prompt(prompts).then(props => {
      this.props = Object.assign(this.props, props);
    });
  }

  writing() {
    fs.writeFileSync('/data/props.json', JSON.stringify(this.props, null, 2));

    for( let m of featurePromptModules ) {
      fs.writeFileSync('/data/'+m.name(), m.env());
    }
    /*
    this.fs.copy(
      this.templatePath('dummyfile.txt'),
      this.destinationPath('dummyfile.txt')
    );
    */
  }

  install() {
  }

  /* some utils */
  _isChecked( name, value ) {
    return this.props && this.props[name] && this.props[name].indexOf(value) != -1 ;
  }

  _getDefault( name ) {
    return this.props && this.props[name];
  }

  _ipOrFQDNValidator( host ) {
    host = (host+"").trim();

    if( !(validator.isIP(host) || 
      validator.isFQDN(host)) ) {
      throw new Error( 'No IP address or fully qualified domain name' )
    }

    return true;
  }

  _xkeyValidator( xpub ) {
    // TOOD: check for version
    if( !coinstring.isValid( xpub ) ) {
      throw new Error('Not an extended key.');
    }

    return true;
  }


  _trimFilter( input ) {
    return (input+"").trim();
  }

  _wrap(text) {
    return wrap(text);
  }

  _featureChoices() {
    return this.featureChoices;
  }

};
