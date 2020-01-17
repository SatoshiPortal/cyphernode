const fs = require('fs');
const path = require('path');
const ansi = require( './ansi.js' );
const lunicode = require('lunicode');

const easeOutCubic = (t, b, c, d) => {
  return c*((t=t/d-1)*t*t+1)+b;
};

lunicode.tools.creepify.options.top = true; 	// add diacritics on top. Default: true
lunicode.tools.creepify.options.middle = true;	// add diacritics in the middle. Default: true
lunicode.tools.creepify.options.bottom = true;	// add diacritics on the bottom. Default: true
lunicode.tools.creepify.options.maxHeight = 15; // How many diacritic marks shall we put on top/bottom? Default: 15
lunicode.tools.creepify.options.randomization = 100; // 0-100%. maxHeight 100 and randomization 20%: the height goes from 80 to 100. randomization 70%: height goes from 30 to 100. Default: 100

const fortunes = [
  'Cause fuck central banking',
  'Not your keys, not your bitcoin',
  'Don\'t trust, verify',
  'Craig Wright is a fraud',
  'HODL!'
];

module.exports = class SplashScreen {

  constructor( options ) {
    options = options || {};

    if( !options.frameDir ) {
      throw "no frame directory to load"
    }

    this.width = options.width || 82;
    this.fortuneEnabled = !!options.enableFortune;
    this.fortuneSpacing = options.fortuneSpacing || 0;
    this.fortuneChalk = options.fortuneChalk;

    this.loadFramesFromDir( options.frameDir );

    if( this.fortuneEnabled ) {

      let fortune = this.fortune();
      if( fortune.length > this.width-2 ) {
        fortune = fortune.substr(0,this.width-2);
      }
      fortune =  this.center(fortune);

      let fortuneLines = [];




      fortuneLines.push( this.creepify(fortune) )+'\n';




      for( let i=0; i<this.frames.length; i++ ) {
        for( let j=0; j<fortuneLines.length; j++ ) {
          this.frames[i] += fortuneLines[j];
        }
      }

    }
  }

  loadFramesFromDir( frameDir ) {
    this.frames = [];
    fs.readdirSync(frameDir).forEach((file) => {
      this.frames.push(fs.readFileSync(path.join(__dirname,'..','splash',file)));
    });
  }

  sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
  }

  fortune() {
    return fortunes[ Math.random()*fortunes.length << 0 ];
  }

  creepify( string ) {
    if( this.fortuneChalk ) {
      return this.fortuneChalk(lunicode.tools.creepify.encode( string ));
    }
    return lunicode.tools.creepify.encode( string );
  }

  center( string ) {
    const offset = ((this.width - string.length)*0.5) << 0;
    for( let i=0; i<offset; i++ ) {
      string =  ' '+string+' ';
    }

    return string;
  }

  async show() {

    const frame0 = this.frames[0];

    const frame0lines = frame0.toString().split('\n');
    const frame0lineCount = frame0lines.length;
    const steps = 10;

    await this.sleep(250);

    process.stdout.write(ansi.clear);

    await this.sleep(150);

    for( let i=0; i<=steps; i++ ) {
      const pos = easeOutCubic( i, 0, frame0lineCount, steps ) | 0;
      process.stdout.write(ansi.reset);
      for( let l=frame0lineCount-pos; l<frame0lineCount; l++ ) {
        process.stdout.write( frame0lines[l]+'\n' );
      }
      await this.sleep(33);
    }

    if( this.frames.length > 1 ) {
      await this.sleep(400);

      for( let frame of this.frames ) {
        process.stdout.write(ansi.reset);
        process.stdout.write(frame.toString());
        await this.sleep(33);
      }
    }

    await this.sleep(400);
    process.stdout.write('\n');
  }

};