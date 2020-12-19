/* eslint-disable camelcase */
const spawn = require('child_process').spawn;
const configEntryRegexp = /^kapi_id="(\w+)";kapi_key="(\w+)";kapi_groups="(.+)";(.+)$/;

module.exports = class ApiKey {
  constructor( id, groups, key, script ) {
    this.setId(id || '000');
    this.setGroups(groups || ['stats'] );
    this.setScript(script || 'eval ugroups_${kapi_id}=${kapi_groups};eval ukey_${kapi_id}=${kapi_key}' );
    this.setKey(key);
  }

  setFromConfigEntry(configEntry ) {
    const match = configEntryRegexp.exec( configEntry );
    if ( match ) {
      this.setId( match[1] );
      this.setKey( match[2] );
      this.setGroups( match[3].split(',').map( (e)=>e.trim() ) );
      this.setScript( match[4] );
    }
  }

  setGroups( groups ) {
    this.groups = groups;
  }

  setId( id ) {
    this.id = id;
  }

  setScript( script ) {
    this.script = script;
  }

  setKey( key ) {
    this.key = key;
  }

  async randomiseKey() {

    //const dd = spawn('/bin/dd if=/dev/urandom bs=32 count=1 | /usr/bin/xxd -pc 32');
    const dd = spawn('dd if=/dev/urandom bs=32 count=1 | xxd -pc32', [], {
      stdio: ['ignore', 'pipe', 'ignore' ], shell: true
    } );

    const result = await new Promise( function(resolve, reject ) {

      let result = '';
      dd.stdout.on('data', function( a ) {
        let chunk = a.toString().trim();
        result += chunk;
      });

      dd.stdout.on('end', function() {
        result = result.replace(/[^a-zA-Z0-9]/, '');
        resolve(result);
      });

      dd.stdout.on('error', function(err) {
        reject(err);
      });
    });
    this.key = result;

  }

  getKey() {
    return this.key;
  }

  getConfigEntry() {
    if ( !this.key ) {
      return;
    }
    return `kapi_id="${this.id}";kapi_key="${this.key}";kapi_groups="${this.groups.join(',')}";${this.script}`;
  }

  getClientInformation() {
    return `${this.id}=${this.key}`;
  }

};
