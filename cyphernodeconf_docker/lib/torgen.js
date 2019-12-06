const spawn = require('child_process').spawn;
const stringio = require('@rauschma/stringio');
const fs = require('fs');
const chalk = require('chalk');

module.exports = class TorGen {

  constructor( path ) {
    this.path = path || './'
  }

  async generateTorFiles() {
//    console.log(chalk.green( 'TOR datapath=' + this.path ));

    if( !fs.existsSync(this.path) ) {
      console.log(chalk.green( 'Creating TOR Hidden Service directory...' ));
      fs.mkdirSync(this.path, { recursive: true });
    }

    if( !fs.existsSync(this.path + '/hostname') ) {

      console.log(chalk.bold.green( 'Generating TOR Hidden Service secret key, public key and hostname...' ));

      const torgenbin = spawn('./torgen/torgen', [this.path]);
      try {
        await stringio.onExit( torgenbin );
      } catch( err ) {
        console.log(chalk.bold.red('Error: ' + err) );
        return "";
      }

//      console.log(chalk.bold.green( 'Generated TOR Hidden Service secret key, public key and hostname.' ));

    } else {
      console.log(chalk.red('TOR config files already exist, skipping generation') );
    }

    try {
      var data = fs.readFileSync(this.path + '/hostname', 'utf8');
      return data.slice(0, -1);
    } catch (err) {
      console.log(chalk.bold.red('Error: ' + err) );
      return "";
    }

  }
}
