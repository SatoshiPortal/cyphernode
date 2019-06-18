const Ajv = require('ajv');
const fs = require('fs');
const Archive = require('./archive.js');
const ApiKey = require('./apikey.js');
const name = require('./name.js');
const colorsys = require( 'colorsys');

const latestSchemaVersion='0.2.0';
const defaultSchemaVersion='0.1.0';

const schemas = {
  '0.1.0': require('../schema/config-v0.1.0.json'),
  '0.2.0': require('../schema/config-v0.2.0.json'),
};

module.exports = class Config {

  constructor( options ) {

    options = options || {};
    this.setup_version = options.setup_version;
    this.docker_versions = options.docker_versions;

    const ajv = new Ajv({
      removeAdditional: true,
      useDefaults: true,
      coerceTypes: true,
      allErrors: true
    });

    this.validators = {};

    for( let v in schemas ) {
      this.validators[v]=ajv.compile(schemas[v]);
    }


    this.migrationPaths = {
      '0.1.0|0.2.0': [ this.migrate_0_1_0_to_0_2_0 ]
    };

    this.setData( { schema_version: latestSchemaVersion } );
    this.isLoaded = false;
  }

  setData( data ) {
    if( !data ) {
      return;
    }
    this.data = data;
    this.data.schema_version = this.data.schema_version || this.__version || defaultSchemaVersion;
    this.data.setup_version = this.data.setup_version || this.setup_version;
    this.data.docker_versions = this.data.docker_versions || this.docker_versions;
    this.validate();
  }

  async serialize( path, password ) {
    this.resolveConfigConflicts();
    this.validate();
    const configJsonString = JSON.stringify(this.data, null, 4);
    const archive = new Archive( path, password );
    return await archive.writeEntry( 'config.json', configJsonString );
  }

  async deserialize( path, password ) {

    if( fs.existsSync(path) ) {

      const archive = new Archive( path, password );

      const r = await archive.readEntry('config.json');

      if( r.error ) {
        throw( 'Password is wrong. Have a nice day.' );
      }

      if( !r.value ) {
        throw('config archive is corrupt.');
      }

      this.setData( JSON.parse(r.value) );
      this.isLoaded = true;
    }

    //this.resolveConfigConflicts();
    const version = this.data.schema_version || this.data.__version || defaultSchemaVersion;
    if( version !== latestSchemaVersion ) {
      // migrate here
      // create a copy of the old config
      fs.copyFileSync( path, path+'-'+version );
      await this.migrate(version, latestSchemaVersion );
      // validate again to strip all illegal properties from config with latest version
      this.validate();
    }
  }

  resolveConfigConflicts() {
    // TODO solve this in config schema
    if( this.data.features && this.data.features.length && this.data.features.indexOf('lightning') !== -1 ) {
      this.data.bitcoin_prune = false;
      delete this.data.bitcoin_prune_size;
    }
  }

  validate() {
    const version = this.data.schema_version || this.data.__version;

    if( !version || !this.validators[version] || Object.keys( schemas ).indexOf( version ) == -1 ) {
      throw "Unknown version in data"
    }

    // this will assign default values from the schema
    this.valid = this.validators[version]( this.data );
    this.validateErrors = this.validators[version].errors;

  }

  async migrate(sourceVersion, targetVersion) {
    const migrations = this.migrationPaths[sourceVersion+'|'+targetVersion];

    if( !migrations ) {
      return;
    }

    for( let migration of migrations ) {
      await migration.apply(this);
    }
  }

  async migrate_0_1_0_to_0_2_0() {
    const currentVersion = this.data.schema_version || this.data.__version;
    if( currentVersion != '0.1.0' ) {
      return;
    }

    this.data.schema_version = '0.2.0';

    // rewrite specific properties with incompatible content

    // gatekeeper_keys: add stats group to all keys and add a label containing only
    // the stats group

    const gatekeeper_keys = this.data.gatekeeper_keys;

    for( let i=0; i<gatekeeper_keys.configEntries.length; i++ ) {
      const apiKey = new ApiKey();
      apiKey.setFromConfigEntry(gatekeeper_keys.configEntries[i]);
      apiKey.groups.unshift('stats');
      gatekeeper_keys.configEntries[i]=apiKey.getConfigEntry();
      gatekeeper_keys.clientInformation[i]=apiKey.getClientInformation();
    }

    const apiKeyStatsOnly = new ApiKey('000',['stats']);
    await apiKeyStatsOnly.randomiseKey();
    gatekeeper_keys.configEntries.unshift( apiKeyStatsOnly.getConfigEntry() );
    gatekeeper_keys.clientInformation.unshift( apiKeyStatsOnly.getClientInformation() );

    // remove all empty props to generate proper errors
    for( let k in this.data ) {
      if( !this.data.hasOwnProperty(k) ) {
        continue;
      }

      if( this.data[k] === '' ) {
        delete this.data[k];
      }

    }
    // lightning_nodecolor
    if( !this.data.lightning_nodecolor ) {
      this.data.lightning_nodecolor =
        colorsys.hslToHex( { h: (Math.random()*360)<<0, s: 50, l: 50 } ).substr(1);
    }

    // lightning_nodename
    if( !this.data.lightning_nodename ) {
      this.data.lightning_nodename = name.generate();
    }

    // xpub && use_xpub
    if( !this.data.xpub ) {
      this.data.use_xpub = false;
    }

  }

};
