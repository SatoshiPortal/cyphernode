const fs = require('fs');
const spawn = require('child_process').spawn;
const defaultArgs = ['req', '-x509', '-newkey', 'rsa:4096', '-nodes'];
const path = require('path');
const tmp = require('tmp');

module.exports = class Cert {

	constructor( options ) {
		options = options || {};
		this.args = options.args || { subj: '/CN=localhost', days: 3650 };
	}

	async create() {

		let args = defaultArgs.slice();

		const certFileTmp = tmp.fileSync();
		const keyFileTmp = tmp.fileSync();

		args.push( '-out' );
		args.push( certFileTmp.name );
		args.push( '-keyout' );
		args.push( keyFileTmp.name );

		for( let k in this.args ) {
			args.push( '-'+k);
			args.push( this.args[k] );
		}

		const openssl = spawn('openssl', args,  { stdio: ['ignore','ignore','ignore'] } );
		
		let code = await new Promise( function(resolve, reject) {
			openssl.on('exit', (code) => {
				resolve(code);
			});
		});

		const cert = fs.readFileSync( certFileTmp.name );
		const key = fs.readFileSync( keyFileTmp.name );

		certFileTmp.removeCallback();
		keyFileTmp.removeCallback();

		return {
			code: code,
			key: key,
			cert: cert
		}
	}

	getFullPath() {
		return path.join( this.folder, this.filename );
	}

}
