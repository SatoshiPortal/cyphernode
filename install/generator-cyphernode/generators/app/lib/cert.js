const fs = require('fs');
const spawn = require('child_process').spawn;
const defaultArgs = ['req', '-x509', '-newkey', 'rsa:4096', '-nodes'];
const path = require('path');
const tmp = require('tmp');
const validator = require('validator');

const confTmpl = `
[req]
distinguished_name = req_distinguished_name
x509_extensions = v3_ca
prompt = no
[req_distinguished_name]
CN = %PRIMARY_CN%
[v3_ca]
subjectAltName = @alt_names
[alt_names]
%ALT_DOMAINS%
%ALT_IPS%
`;

const domainTmpl = 'DNS.%#% = %DOMAIN%';
const ipTmpl = 'IP.%#% = %IP%'

module.exports = class Cert {

	constructor( options ) {
		options = options || {};
		this.args = options.args || { days: 3650 };
	}

	buildConfig( cns ) {

		let ips = [];
		let domains = [];

		for( let cn of cns ) {
			if( validator.isIP(cn) ) {
				ips.push( cn );
			} else {
				domains.push( cn );
			}
		}

		let conf = confTmpl;

		if( !domains.length ) {
			domains.push('localhost');
		}

		conf = conf.replace( '%PRIMARY_CN%', domains[0] )

		let domainCount = 0;
		domains = domains.map( d => domainTmpl.replace( '%#%', ++domainCount ).replace('%DOMAIN%', d) );
		conf = conf.replace( '%ALT_DOMAINS%', domains.join('\n') || '' )

		let ipCount = 0;
		ips = ips.map( ip => ipTmpl.replace( '%#%', ++ipCount ).replace('%IP%', ip) );
		conf = conf.replace( '%ALT_IPS%', ips.join('\n') || '' )

		return conf;
	}

	async create( cns ) {
		cns = cns || [];

		cns = cns.concat(['127.0.0.1','localhost','gatekeeper']);

		let args = defaultArgs.slice();

		const certFileTmp = tmp.fileSync();
		const keyFileTmp = tmp.fileSync();
		const confFileTmp = tmp.fileSync();

		args.push( '-out' );
		args.push( certFileTmp.name );
		args.push( '-keyout' );
		args.push( keyFileTmp.name );
		args.push( '-config' );
		args.push( confFileTmp.name );

		for( let k in this.args ) {
			args.push( '-'+k);
			args.push( this.args[k] );
		}

		const conf = this.buildConfig( cns );
		fs.writeFileSync( confFileTmp.name, conf );

		const openssl = spawn('openssl', args,  { stdio: ['ignore', 'ignore', 'ignore'] } );

		let code = await new Promise( function(resolve, reject) {
			openssl.on('exit', (code) => {
				resolve(code);
			});
		});

		const cert = fs.readFileSync( certFileTmp.name );
		const key = fs.readFileSync( keyFileTmp.name );

		certFileTmp.removeCallback();
		keyFileTmp.removeCallback();
		confFileTmp.removeCallback();

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
