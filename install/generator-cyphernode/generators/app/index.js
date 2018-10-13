'use strict';
const Generator = require('yeoman-generator');
const chalk = require('chalk');
const fs = require('fs');
const wrap = require('wordwrap')(86);
const validator = require('validator');
const path = require("path");
const featureChoices = require(path.join(__dirname, "features.json"));
const coinstring = require('coinstring');

const uaCommentRegexp = /^[a-zA-Z0-9 \.,:_\-\?\/@]+$/; // TODO: look for spec of unsafe chars

const reset = '\u001B[u';
const clear = '\u001Bc';


let prompters = [];
fs.readdirSync(path.join(__dirname, "prompters")).forEach(function(file) {
  prompters.push(require(path.join(__dirname, "prompters",file)));
});

const sleep = function(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

const easeOutCubic = function(t, b, c, d) {
  return c*((t=t/d-1)*t*t+1)+b;
}

const splash = async function() {
    let frames = [];
    fs.readdirSync(path.join(__dirname,'splash')).forEach(function(file) {
      frames.push(fs.readFileSync(path.join(__dirname,'splash',file)));
    });

    const frame0 = frames[0];

    const frame0lines = frame0.toString().split('\n');
    const frame0lineCount = frame0lines.length;
    const steps = 10;

    process.stdout.write(clear);

    await sleep(150);

    for( let i=0; i<=steps; i++ ) {
      const pos = easeOutCubic( i, 0, frame0lineCount, steps ) | 0;
      process.stdout.write(reset);
      for( let l=frame0lineCount-pos; l<frame0lineCount; l++ ) {
        process.stdout.write( frame0lines[l]+'\n' );
      }
      await sleep(33);
    }

    await sleep(400);

    for( let frame of frames ) {
      process.stdout.write(reset);
      process.stdout.write(frame.toString());
      await sleep(33);
    }
    await sleep(400);
    process.stdout.write('\n');
}

module.exports = class extends Generator {

  constructor(args, opts) {
    super(args, opts);

    if( args.indexOf('recreate') !== -1 ) {
      this.recreate = true;
    }

    if( fs.existsSync(this.destinationPath('config.json')) ) {
      this.props = require(this.destinationPath('config.json'));
    } else {
      this.props = {
        'derivation_path': '0/n',
        'installer': 'docker',
        'devmode': false,
        'devregistry': false
      };
    }

    this.props.devmode = this.props.devmode || false;

    this.featureChoices = featureChoices;
    for( let c of this.featureChoices ) {
      c.checked = this._isChecked( 'features', c.value );
    }

  }

  async prompting() {
    if( this.recreate ) {
      // no prompts
      return;
    }

    await splash();
    
    let prompts = [];
    for( let m of prompters ) {
      prompts = prompts.concat(m.prompts(this));
    }

    return this.prompt(prompts).then(props => {
      this.props = Object.assign(this.props, props);
    });
  }

  writing() {
    fs.writeFileSync(this.destinationPath('config.json'), JSON.stringify(this.props, null, 2));

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

  _UACommentValidator( comment ) {
    if( !uaCommentRegexp.test( comment ) ) {
      throw new Error('Unsafe characters in UA comment. Please use only a-z, A-Z, 0-9, SPACE and .,:_?@');
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
