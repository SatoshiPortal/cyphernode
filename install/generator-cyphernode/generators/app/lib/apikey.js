const spawn = require('child_process').spawn;

module.exports = class ApiKey {
  constructor( id, groups, key, script ) {
    this.setId(id || '001');
    this.setGroups(groups || ['admin'] );
    this.setScript(script || 'eval ugroups_${kapi_id}=${kapi_groups};eval ukey_${kapi_id}=${kapi_key}' );
    this.setKey(key);
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

  async randomiseKey() {
    try {

      //const dd = spawn('/bin/dd if=/dev/urandom bs=32 count=1 | /usr/bin/xxd -pc 32');
      const dd = spawn("dd if=/dev/urandom bs=32 count=1 | xxd -pc32", [], {stdio: ['ignore', 'pipe', 'ignore' ], shell: true} );

      const result = await new Promise( function(resolve, reject ) {

        let result = '';
        dd.stdout.on('data', function( a,b,c) {
          let chunk = a.toString().trim();
          result += chunk;
        });

        dd.stdout.on('end', function() {
          result = result.replace(/[^a-zA-Z0-9]/,'');
          resolve(result);
        });

        dd.stdout.on('error', function(err) {
          console.log(err);
          reject(err);
        })
      });
      this.key = result;

    } catch( err ) {
      console.log( err );
      return;
    }
  }

  getKey() {
    return this.key;
  }

  getConfigEntry() {
    if( !this.key ) {
      return;
    }
    return `kapi_id="${this.id}";kapi_key="${this.key}";kapi_groups="${this.groups.join(',')}";${this.script}`;
  }

  getClientInformation() {
    return `${this.id}=${this.key}`;
  }

}

//dd if=/dev/urandom bs=32 count=1 2> /dev/null | xxd -pc 32