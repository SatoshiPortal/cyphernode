const Generator = require('yeoman-generator');
const chalk = require('chalk');
const wrap = require('wrap-ansi');
const html2ansi = require('./lib/html2ansi.js');
const fs = require('fs');
const validator = require('validator');
const path = require("path");
const coinstring = require('coinstring');
const name = require('./lib/name.js');
const Archive = require('./lib/archive.js');
const ApiKey = require('./lib/apikey.js');
const Cert = require('./lib/cert.js');

const featureChoices = require('./features.json');
const uaCommentRegexp = /^[a-zA-Z0-9 \.,:_\-\?\/@]+$/; // TODO: look for spec of unsafe chars
const userRegexp = /^[a-zA-Z0-9\._\-]+$/;
const reset = '\u001B8\u001B[u';
const clear = '\u001Bc';

const configFileVersion='0.1.0';

const defaultAPIProperties = `
# Watcher can:
action_watch=watcher
action_unwatch=watcher
action_watchxpub=watcher
action_unwatchxpubbyxpub=watcher
action_unwatchxpubbylabel=watcher
action_getactivewatchesbyxpub=watcher
action_getactivewatchesbylabel=watcher
action_getactivexpubwatches=watcher
action_watchtxid=watcher
action_getactivewatches=watcher
action_getbestblockhash=watcher
action_getbestblockinfo=watcher
action_getblockinfo=watcher
action_gettransaction=watcher
action_ln_getinfo=watcher
action_ln_create_invoice=watcher
action_ln_getconnectionstring=watcher
action_ln_decodebolt11=watcher

# Spender can do what the watcher can do, plus:
action_getbalance=spender
action_getbalancebyxpub=spender
action_getbalancebyxpublabel=spender
action_getnewaddress=spender
action_spend=spender
action_addtobatch=spender
action_batchspend=spender
action_deriveindex=spender
action_derivepubpath=spender
action_ln_pay=spender
action_ln_newaddr=spender
action_ots_stamp=spender
action_ots_getfile=spender
action_ln_getinvoice=spender
action_ln_decodebolt11=spender
action_ln_connectfund=spender

# Admin can do what the spender can do, plus:


# Should be called from inside the Docker network only:
action_conf=internal
action_newblock=internal
action_executecallbacks=internal
action_ots_backoffice=internal
`;

const prefix = function() {
  return chalk.green('Cyphernode')+': ';
};

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

    this.featureChoices = featureChoices;

    if( fs.existsSync(path.join('/data', 'exitStatus.sh')) ) {
      fs.unlinkSync(path.join('/data', 'exitStatus.sh'));
    }

  }

  async _initConfig() {
    this.defaultDataDirBase = process.env.DEFAULT_DATADIR_BASE;
    this.setupDir = process.env.SETUP_DIR;
    const versionOverride = process.env.VERSION_OVERRIDE==='true';
    if( fs.existsSync(this.destinationPath('config.7z')) ) {
      let r = {};

      if( process.env.CFG_PASSWORD ) {
        this.configurationPassword = process.env.CFG_PASSWORD;
      } else {
        process.stdout.write(reset);
        while( !r.password ) {
          r = await this.prompt([{
            type: 'password',
            name: 'password',
            message: prefix()+chalk.bold.blue('Enter your configuration password?'),
            filter: this._trimFilter
          }]);
        }
        this.configurationPassword = r.password;
      }

      const archive = new Archive( this.destinationPath('config.7z'), this.configurationPassword );

      r = await archive.readEntry('config.json');

      if( r.error ) {
        console.log(chalk.bold.red('Password is wrong. Have a nice day.'));
        process.exit(1);
      }

      if( !r.value ) {
        console.log(chalk.bold.red('config archive is corrupt.'));
        process.exit(1);
      }

      try {
        this.props = JSON.parse(r.value);
        this.props.__version = this.props.__version || configFileVersion;
      } catch( err ) {
        console.log(chalk.bold.red('config archive is corrupt.'));
        process.exit(1);
      }

    } else {
      let r = {};
      process.stdout.write(clear+reset);
      while( !r.password0 || !r.password1 || r.password0 !== r.password1 ) {

        if( r.password0 && r.password1 && r.password0 !== r.password1 ) {
          console.log(chalk.bold.red('Passwords do not match')+'\n');
        }

        r = await this.prompt([{
          type: 'password',
          name: 'password0',
          message: prefix()+chalk.bold.blue('Choose your configuration password'),
          filter: this._trimFilter
        },
        {
          type: 'password',
          name: 'password1',
          message: prefix()+chalk.bold.blue('Confirm your configuration password'),
          filter: this._trimFilter
        }]);
      }

      this.configurationPassword = r.password0;
      this.props = {
        __version: configFileVersion
      };

    }

    if( this.props.__version !== configFileVersion ) {
      // migrate here
    }

    this.props.gatekeeper_statuspw = await new Cert().passwd(this.configurationPassword);

    if( versionOverride ) {
      delete this.props.gatekeeper_version;
      delete this.props.proxy_version;
      delete this.props.proxycron_version;
      delete this.props.pycoin_version;
      delete this.props.otsclient_version;
      delete this.props.bitcoin_version;
      delete this.props.lightning_version;
      delete this.props.sparkwallet_version;
      delete this.props.grafana_version;
    }

    this._resolveConfigConflicts();
    this._assignConfigDefaults();

    for( let c of this.featureChoices ) {
      c.checked = this._isChecked( 'features', c.value );
    }



  }

  async prompting() {

    await this._initConfig();
    await sleep(1000);
    await splash();

    if( this.recreate ) {
      // no prompts
      return;
    }

    // save gatekeeper key password to check if it changed
    this.gatekeeper_clientkeyspassword = this.props.gatekeeper_clientkeyspassword;

    let r = await this.prompt([{
      type: 'confirm',
      name: 'enablehelp',
      message: prefix()+'Enable help?',
      default: this._getDefault( 'enablehelp' ),
    }]);

    this.props.enablehelp = r.enablehelp;

    if( this.props.enablehelp ) {
      this.help = require('./help.json');
    }

    let prompts = [];
    for( let m of prompters ) {
      prompts = prompts.concat(m.prompts(this));
    }

    return this.prompt(prompts).then(props => {
      this.props = Object.assign(this.props, props);
    });
  }


  async configuring() {
    if( this.props.gatekeeper_recreatekeys ||
        this.props.gatekeeper_keys.configEntries.length===0 ) {
      const apikey = new ApiKey();

      let configEntries = [];
      let clientInformation = [];

      apikey.setId('001');
      apikey.setGroups(['watcher']);
      await apikey.randomiseKey();
      configEntries.push(apikey.getConfigEntry());
      clientInformation.push(apikey.getClientInformation());

      apikey.setId('002');
      apikey.setGroups(['watcher','spender']);
      await apikey.randomiseKey();
      configEntries.push(apikey.getConfigEntry());
      clientInformation.push(apikey.getClientInformation());

      apikey.setId('003');
      apikey.setGroups(['watcher','spender','admin']);
      await apikey.randomiseKey();
      configEntries.push(apikey.getConfigEntry());
      clientInformation.push(apikey.getClientInformation());

      this.props.gatekeeper_keys = {
        configEntries: configEntries,
        clientInformation: clientInformation
      }
    }

    if( this.props.gatekeeper_recreatecert ||
        !this.props.gatekeeper_sslcert ||
        !this.props.gatekeeper_sslkey ) {
      delete this.props.gatekeeper_recreatecert;
      const cert = new Cert();
      console.log(chalk.bold.green( '☕ Generating gatekeeper cert. This may take a while ☕' ));
      try {
        const cns = (this.props.gatekeeper_cns||'').split(',').map(e=>e.trim().toLowerCase()).filter(e=>!!e);
        const result = await cert.create(cns);
        if( result.code === 0 ) {
          this.props.gatekeeper_sslkey = result.key.toString();
          this.props.gatekeeper_sslcert = result.cert.toString();

          // Total array of cns, used to create Cyphernode's URLs
          this.props.cns = []
          result.cns.forEach(e => {
            this.props.cns.push(e)
          })
        } else {
          console.log(chalk.bold.red( 'error! Gatekeeper cert was not created' ));
        }
      } catch( err ) {
        console.log(chalk.bold.red( 'error! Gatekeeper cert was not created' ));
      }
    }

    delete this.props.gatekeeper_recreatekeys;

  }

  async writing() {
    this._resolveConfigConflicts()

    const configJsonString = JSON.stringify(this.props, null, 4);
    const archive = new Archive( this.destinationPath('config.7z'), this.configurationPassword );

    if( !await archive.writeEntry( 'config.json', configJsonString ) ) {
      console.log(chalk.bold.red( 'error! Config archive was not written' ));
    }

    const pathProps = [
      'gatekeeper_datapath',
      'proxy_datapath',
      'bitcoin_datapath',
      'lightning_datapath',
      'otsclient_datapath'
    ];

    for( let pathProp of pathProps ) {
      if( this.props[pathProp] === '_custom' ) {
        this.props[pathProp] = this.props[pathProp+'_custom'] || '';
      }
    }

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

    if( this.props.gatekeeper_keys && this.props.gatekeeper_keys.clientInformation ) {

      if( this.gatekeeper_clientkeyspassword !== this.props.gatekeeper_clientkeyspassword &&
          fs.existsSync(this.destinationPath('client.7z')) ) {
        fs.unlinkSync( this.destinationPath('client.7z') );
      }

      const archive = new Archive( this.destinationPath('client.7z'), this.props.gatekeeper_clientkeyspassword );
      if( !await archive.writeEntry( 'keys.txt', this.props.gatekeeper_keys.clientInformation.join('\n') ) ) {
        console.log(chalk.bold.red( 'error! Client gatekeeper key archive was not written' ));
      }
      if( !await archive.writeEntry( 'cacert.pem', this.props.gatekeeper_sslcert ) ) {
        console.log(chalk.bold.red( 'error! Client gatekeeper key archive was not written' ));
      }
    }

    fs.writeFileSync(path.join('/data', 'exitStatus.sh'), 'EXIT_STATUS=0');


  }

  install() {
  }

  /* some utils */

  _resolveConfigConflicts() {
    if( this.props.features && this.props.features.length && this.props.features.indexOf('lightning') !== -1 ) {
      this.props.bitcoin_prune = false;
      delete this.props.bitcoin_prune_size;
    }
  }

  _assignConfigDefaults() {
    this.props = Object.assign( {
      features: [],
      enablehelp: true,
      net: 'testnet',
      xpub: '',
      derivation_path: '0/n',
      installer_mode: 'docker',
      devmode: false,
      devregistry: false,
      run_as_different_user: true,
      username: 'cyphernode',
      docker_mode: 'compose',
      bitcoin_rpcuser: 'bitcoin',
      bitcoin_rpcpassword: 'CHANGEME',
      bitcoin_uacomment: '',
      bitcoin_prune: false,
      bitcoin_prune_size: 550,
      bitcoin_datapath: '',
      bitcoin_node_ip: '',
      bitcoin_mode: 'internal',
      bitcoin_expose: false,
      lightning_expose: true,
      gatekeeper_port: 443,
      gatekeeper_apiproperties: defaultAPIProperties,
      gatekeeper_ipwhitelist: '',
      gatekeeper_keys: { configEntries: [], clientInformation: [] },
      gatekeeper_sslcert: '',
      gatekeeper_sslkey: '',
      gatekeeper_cns: process.env['DEFAULT_CERT_HOSTNAME'] || '',
      proxy_datapath: '',
      lightning_implementation: 'c-lightning',
      lightning_external_ip: '',
      lightning_datapath: '',
      lightning_nodename: name.generate(),
      lightning_nodecolor: '',
      otsclient_datapath: '',
      installer_cleanup: false,
      default_username: process.env.DEFAULT_USER || '',
      gatekeeper_version: process.env.GATEKEEPER_VERSION || 'latest',
      proxy_version: process.env.PROXY_VERSION || 'latest',
      proxycron_version: process.env.PROXYCRON_VERSION || 'latest',
      pycoin_version: process.env.PYCOIN_VERSION || 'latest',
      otsclient_version: process.env.OTSCLIENT_VERSION || 'latest',
      bitcoin_version: process.env.BITCOIN_VERSION || 'latest',
      lightning_version: process.env.LIGHTNING_VERSION || 'latest',
      sparkwallet_version: process.env.SPARKWALLET_VERSION || 'standalone'
    }, this.props );
  }

  _isChecked( name, value ) {
    return this.props && this.props[name] && this.props[name].indexOf(value) != -1 ;
  }

  _getDefault( name ) {
    return this.props && this.props[name];
  }

  _optional(input,validator) {
    if( input === undefined ||
        input === null ||
        input === '' ) {
      return true;
    }
    return validator(input);
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

  _lightningNodeNameValidator(name) {
    if( !name || name.length > 32 ) {
      throw new Error('Please enter anything shorter than 32 characters');
    }
    return true;
  }

  _notEmptyValidator( path ) {
    if( !path ) {
      throw new Error('Please enter something');
    }
    return true;
  }

  _usernameValidator( user ) {
     if( !userRegexp.test( user ) ) {
      throw new Error('Choose a valid username');
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

  _featureChoices() {
    return this.featureChoices;
  }

  _getHelp( topic ) {
    if( !this.props.enablehelp || !this.help ) {
      return '';
    }

    const helpText = this.help[topic] || this.help['__default__'];

    if( !helpText ||helpText === '' ) {
      return '';
    }

    return "\n\n"+wrap( html2ansi(helpText),82 )+"\n\n";
  }

};
