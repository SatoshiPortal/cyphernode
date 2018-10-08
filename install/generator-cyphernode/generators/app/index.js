'use strict';
const Generator = require('yeoman-generator');
const chalk = require('chalk');
const fs = require('fs');
const wrap = require('wordwrap')(86);
const validator = require('validator');
const path = require("path");
const featureChoices = require(path.join(__dirname, "features.json"));
const coinstring = require('coinstring');

let prompters = [];
const normalizedPath = path.join(__dirname, "prompters");
fs.readdirSync(normalizedPath).forEach(function(file) {
  prompters.push(require(path.join(normalizedPath,file)));
});

module.exports = class extends Generator {

  constructor(args, opts) {
    super(args, opts);

    if( args.indexOf('recreate') !== -1 ) {
      this.recreate = true;
    }

    if( fs.existsSync(this.destinationPath('props.json')) ) {
      this.props = require(this.destinationPath('props.json'));
    } else {
      this.props = {
        'derivation_path': '0/n',
        'installer': 'docker'
      };
    }

    this.featureChoices = featureChoices;
    for( let c of this.featureChoices ) {
      c.checked = this._isChecked( 'features', c.value );
    }

  }

  prompting() {
    if( this.recreate ) {
      // no prompts
      return;
    }
    const splash = fs.readFileSync(this.templatePath('splash.txt'));
    this.log(splash.toString());
    
    let prompts = [];

    for( let m of prompters ) {
      prompts = prompts.concat(m.prompts(this));
    }

    return this.prompt(prompts).then(props => {
      this.props = Object.assign(this.props, props);
    });
  }

  writing() {
    fs.writeFileSync(this.destinationPath('props.json'), JSON.stringify(this.props, null, 2));

    for( let m of prompters ) {
      const name = m.name();      
      for( let t of m.templates(this.props) ) {
        const p = path.join(name,t);
        this.fs.copyTpl(
          this.templatePath(p),
          this.destinationPath(p),
          this.props
        );
      } 
    }
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

  _pathValidator( p ) {
    return true;
  }

  _derivationPathValidator( path ) {
    return true;
  }

  _colorValidator(color) {
    if( !validator.isHexadecimal(color) ) {
      throw new Error('Not a hex color.');
    }
    return true;
  }

  _notEmptyValidator( path ) {
    if( !path ) {
      throw new Error('Please enter something');
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
