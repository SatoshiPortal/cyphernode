const path = require('path');
const chalk = require('chalk');

const name = 'installer';

const installerDocker = function(props) {
  return props.installer_mode === 'docker'
};

const installerDocker_bitcoinInternal = function(props) {
  return props.installer_mode === 'docker' && props.bitcoin_mode === 'internal' 
};

const installerDocker_bitcoinExternal = function(props) {
  return props.installer_mode === 'docker' && props.bitcoin_mode === 'external'
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
      when: installerDocker_bitcoinInternal,
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