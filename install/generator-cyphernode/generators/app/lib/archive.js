const fs = require('fs');
const spawn = require('child_process').spawn;
const stringio = require('@rauschma/stringio');
const defaultArgs = ['-t7z', '-ms=on', '-mhe=on'];

module.exports = class Archive {

	constructor( file, password ) {
		this.file = file || 'archive.7z'
		this.password = password;
	}

	async readEntry( entryName ) {
		if( !entryName ) {
			return;
		}
		let args = defaultArgs.slice();
		args.unshift('x');
		args.push( '-so' ); 
		if( this.password ) {
			args.push('-p'+this.password );
		}
		args.push( this.file )
		args.push( entryName )
		const archiver = spawn('7z', args,  { stdio: ['ignore', 'pipe', 'ignore'] } );
		const result = await stringio.readableToString(archiver.stdout);
		try {
			await stringio.onExit( archiver );
		} catch( err ) {
			return { error: err };
		}
		return { error: null, value: result };
	}

	async writeEntry( entryName, content ) {
		if( !entryName ) {
			return;
		}
		let args = defaultArgs.slice();
		args.unshift('a');
		if( this.password ) {
			args.push('-p'+this.password );
		}
		args.push( '-si'+entryName ); 
		args.push( this.file )
		const archiver = spawn('7z', args,  { stdio: ['pipe', 'ignore', 'ignore' ] } );
		await stringio.streamWrite(archiver.stdin, content);
		await stringio.streamEnd(archiver.stdin);
		try {
			await stringio.onExit( archiver );
		} catch( err ) {
			return false;
		}
		return true;
	}

	async deleteEntry( entryName ) {
		if( !entryName ) {
			return;
		}
		let args = defaultArgs.slice();
		args.unshift('d');
		if( this.password ) {
			args.push('-p'+this.password );
		}
		args.push( this.file )
		args.push( entryName )
		const archiver = spawn('7z', args,  { stdio: ['ignore', 'pipe','ignore'] } );
		try {
			await stringio.onExit( archiver );
		} catch( err ) {
			return false;
		}
		return true;
	}

}
