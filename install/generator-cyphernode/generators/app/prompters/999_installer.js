const path = require('path');
const chalk = require('chalk');

const name = 'installer';

const capitalise = function( txt ) {
  return txt.charAt(0).toUpperCase() + txt.substr(1);
};

const prefix = function() {
  return chalk.green(capitalise(name)+': ');
};

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
      message: prefix()+chalk.red('Where do you want to install cyphernode?')+utils._getHelp('installer_mode'),
      choices: [{
        name: "Docker",
        value: "docker"
      }
      /*,
      {
        name: "Lunanode (not implemented)",
        value: "lunanode"
      }*/
      ]
    },
    {
      when: installerDocker,
      type: 'input',
      name: 'gatekeeper_datapath',
      default: utils._getDefault( 'gatekeeper_datapath' ),
      filter: utils._trimFilter,
      validate: utils._pathValidator,
      message: prefix()+'Where to store your gatekeeper data?'+utils._getHelp('gatekeeper_datapath'),
    },
    {
      when: installerDocker,
      type: 'input',
      name: 'proxy_datapath',
      default: utils._getDefault( 'proxy_datapath' ),
      filter: utils._trimFilter,
      validate: utils._pathValidator,
      message: prefix()+'Where to store your proxy db?'+utils._getHelp('proxy_datapath'),
    },
    {
      when: function(props) { return installerDocker(props) && props.bitcoin_mode === 'internal' },
      type: 'input',
      name: 'bitcoin_datapath',
      default: utils._getDefault( 'bitcoin_datapath' ),
      filter: utils._trimFilter,
      validate: utils._pathValidator,
      message: prefix()+'Where is your blockchain data?'+utils._getHelp('bitcoin_datapath'),
    },
    {
      when: function(props) { return installerDocker(props) && props.features.indexOf('lightning') !== -1 },
      type: 'input',
      name: 'lightning_datapath',
      default: utils._getDefault( 'lightning_datapath' ),
      filter: utils._trimFilter,
      validate: utils._pathValidator,
      message: prefix()+'Where is your lightning node data?'+utils._getHelp('lightning_datapath'),
    },
    {
      when: function(props) { return installerDocker(props) && props.features.indexOf('otsclient') !== -1 },
      type: 'input',
      name: 'otsclient_datapath',
      default: utils._getDefault( 'otsclient_datapath' ),
      filter: utils._trimFilter,
      validate: utils._pathValidator,
      message: prefix()+'Where is your otsclient data?'+utils._getHelp('otsclient_datapath'),
    },
    {
      when: function(props) { return installerDocker(props) && props.bitcoin_mode === 'internal' },
      type: 'confirm',
      name: 'bitcoin_expose',
      default: utils._getDefault( 'bitcoin_expose' ),
      message: prefix()+'Expose bitcoin full node outside of the docker network?'+utils._getHelp('bitcoin_expose'),
    },
    {
      when: function(props) { return installerDocker(props) && props.features.indexOf('lightning') !== -1  },
      type: 'confirm',
      name: 'lightning_expose',
      default: utils._getDefault( 'lightning_expose' ),
      message: prefix()+'Expose lightning node outside of the docker network?'+utils._getHelp('lightning_expose'),
    },
    {
      when: installerDocker,
      type: 'list',
      name: 'docker_mode',
      default: utils._getDefault( 'docker_mode' ),
      message: prefix()+'What docker mode: docker swarm or docker-compose?'+utils._getHelp('docker_mode'),
      choices: [{
        name: "docker swarm",
        value: "swarm"
      },
      {
        name: "docker-compose",
        value: "compose"
      }]
    },
    {
      type: 'confirm',
      name: 'installer_cleanup',
      default: utils._getDefault( 'installer_cleanup' ),
      message: prefix()+'Cleanup installer after installation?'+utils._getHelp('installer_cleanup'),
    }];
  },
  templates: function( props ) {
    if( props.installer_mode === 'docker' ) {
      return ['config.sh','start.sh', 'stop.sh', 'testfeatures.sh', path.join('docker', 'docker-compose.yaml')];
    }
    return ['config.sh','start.sh', 'stop.sh', 'testfeatures.sh'];
  }
};
