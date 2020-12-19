/* eslint-disable camelcase */
const spawn = require('child_process').spawn;
const stringio = require('@rauschma/stringio');
const fs = require('fs');
const chalk = require('chalk');

module.exports = class TorGen {

  async generateTorFiles(path) {
    path = path || './';

    if ( !fs.existsSync(path) ) {
      console.log(chalk.green( 'Creating Tor Hidden Service directory...' ));
      fs.mkdirSync(path, {
        recursive: true
      });
    }

    if ( !fs.existsSync(path + '/hostname') ) {

      console.log(chalk.green( 'Generating Tor Hidden Service secret key, public key and hostname...' ));

      const torgenbin = spawn('./torgen/torgen', [path]);
      try {
        await stringio.onExit( torgenbin );
      } catch ( err ) {
        console.log(chalk.bold.red('Error: ' + err) );
        return '';
      }

    } else {
      console.log(chalk.green('Tor config files already exist, skipping Tor generation.') );
    }

    try {
      var data = fs.readFileSync(path + '/hostname', 'utf8');
      // Remove the LF at the end of the host name
      return data.slice(0, -1);
    } catch (err) {
      console.log(chalk.bold.red('Error: ' + err) );
      return '';
    }

  }
};
