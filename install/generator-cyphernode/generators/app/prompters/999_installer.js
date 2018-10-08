const path = require('path');
const chalk = require('chalk');

const name = 'installer';

const installerDocker = function(props) {
  return props.installer_mode === 'docker'
};

const installerLunanode = function(props) {
  return props.installer_mode === 'lunanode'
};

module.exports = {
  name: function() { 
    return name;
  },
  prompts: function( utils ) {
    return [{
      type: 'list',
      name: 'installer_mode',
      default: utils._getDefault( 'installer_mode' ),
      message: chalk.red('Where do you want to install cyphernode?')+'\n',
      choices: [{
        name: "Docker",
        value: "docker"
      },
      {
        name: "Lunanode (not implemented)",
        value: "lunanode"
      },
      {
        name: "No installation. Just create config files",
        value: "none"
      }]
    },
    {
      when: installerDocker,
      type: 'input',
      name: 'proxy_datapath',
      default: utils._getDefault( 'proxy_datapath' ),
      validate: utils._pathValidator,
      message: 'Where to store your proxy db?'+'\n',
    },
    {
      when: function(props) { return installerDocker(props) && props.bitcoin_mode === 'internal' },
      type: 'input',
      name: 'bitcoin_datapath',
      default: utils._getDefault( 'bitcoin_datapath' ),
      validate: utils._pathValidator,
      message: 'Where is your blockchain data?'+'\n',
    },
    {
      when: function(props) { return installerDocker(props) && props.features.indexOf('lightning') !== -1 },
      type: 'input',
      name: 'lightning_datapath',
      default: utils._getDefault( 'lightning_datapath' ),
      validate: utils._pathValidator,
      message: 'Where is your lightning node data?'+'\n',
    },
    {
      when: function(props) { return installerDocker(props) && props.bitcoin_mode === 'internal' },
      type: 'confirm',
      name: 'bitcoin_expose',
      default: utils._getDefault( 'bitcoin_expose' ),
      message: 'Expose bitcoin full node outside of the docker network?'+'\n',
    },
    {
      when: installerLunanode,
      type: 'confirm',
      name: 'installer_confirm_lunanode',
      default: utils._getDefault( 'installer_confirm_lunanode' ),
      message: 'Lunanode?! No wayyyy!'+'\n'
    }];
  },
  templates: function( props ) {
    if( props.installer_mode === 'docker' ) {
      return ['config.sh', path.join('docker', 'docker-compose.yaml')];
    }
    return ['config.sh'];
  }
};