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

module.exports = {
  name: function() {
    return name;
  },
  prompts: function( utils ) {
    return [{
      type: 'list',
      name: 'installer_mode',
      default: utils.getDefault( 'installer_mode' ),
      message: prefix()+chalk.red('Where do you want to install cyphernode?')+utils.getHelp('installer_mode'),
      choices: [{
        name: "Docker",
        value: "docker"
      }]
    },
    {
      when: installerDocker,
      type: 'list',
      name: 'postgres_datapath',
      default: utils.getDefault( 'postgres_datapath' ),
      choices: [
        {
          name: utils.setupDir()+"/cyphernode/postgres",
          value: utils.setupDir()+"/cyphernode/postgres"
        },
        {
          name: utils.defaultDataDirBase()+"/cyphernode/postgres",
          value: utils.defaultDataDirBase()+"/cyphernode/postgres"
        },
        {
          name: utils.defaultDataDirBase()+"/.cyphernode/postgres",
          value: utils.defaultDataDirBase()+"/.cyphernode/postgres"
        },
        {
          name: utils.defaultDataDirBase()+"/postgres",
          value: utils.defaultDataDirBase()+"/postgres"
        },
        {
          name: "Custom path",
          value: "_custom"
        }
      ],
      message: prefix()+'Where do you want to store your Postgres files?'+utils.getHelp('postgres_datapath'),
    },
    {
      when: (props)=>{ return installerDocker(props) && (props.postgres_datapath === '_custom') },
      type: 'input',
      name: 'postgres_datapath_custom',
      default: utils.getDefault( 'postgres_datapath_custom' ),
      filter: utils.trimFilter,
      validate: utils.pathValidator,
      message: prefix()+'Custom path for Postgres files?'+utils.getHelp('postgres_datapath_custom'),
    },
    {
      when: installerDocker,
      type: 'list',
      name: 'logs_datapath',
      default: utils.getDefault( 'logs_datapath' ),
      choices: [
        {
          name: utils.setupDir()+"/cyphernode/logs",
          value: utils.setupDir()+"/cyphernode/logs"
        },
        {
          name: utils.defaultDataDirBase()+"/cyphernode/logs",
          value: utils.defaultDataDirBase()+"/cyphernode/logs"
        },
        {
          name: utils.defaultDataDirBase()+"/.cyphernode/logs",
          value: utils.defaultDataDirBase()+"/.cyphernode/logs"
        },
        {
          name: utils.defaultDataDirBase()+"/logs",
          value: utils.defaultDataDirBase()+"/logs"
        },
        {
          name: "Custom path",
          value: "_custom"
        }
      ],
      message: prefix()+'Where do you want to store your log files?'+utils.getHelp('logs_datapath'),
    },
    {
      when: (props)=>{ return installerDocker(props) && (props.logs_datapath === '_custom') },
      type: 'input',
      name: 'logs_datapath_custom',
      default: utils.getDefault( 'logs_datapath_custom' ),
      filter: utils.trimFilter,
      validate: utils.pathValidator,
      message: prefix()+'Custom path for log files?'+utils.getHelp('logs_datapath_custom'),
    },
    {
      when: installerDocker,
      type: 'list',
      name: 'traefik_datapath',
      default: utils.getDefault( 'traefik_datapath' ),
      choices: [
        {
          name: utils.setupDir()+"/cyphernode/traefik",
          value: utils.setupDir()+"/cyphernode/traefik"
        },
        {
          name: utils.defaultDataDirBase()+"/cyphernode/traefik",
          value: utils.defaultDataDirBase()+"/cyphernode/traefik"
        },
        {
          name: utils.defaultDataDirBase()+"/.cyphernode/traefik",
          value: utils.defaultDataDirBase()+"/.cyphernode/traefik"
        },
        {
          name: utils.defaultDataDirBase()+"/traefik",
          value: utils.defaultDataDirBase()+"/traefik"
        },
        {
          name: "Custom path",
          value: "_custom"
        }
      ],
      message: prefix()+'Where do you want to store your traefik data?'+utils.getHelp('traefik_datapath'),
    },
    {
      when: (props)=>{ return installerDocker(props) && (props.traefik_datapath === '_custom') },
      type: 'input',
      name: 'traefik_datapath_custom',
      default: utils.getDefault( 'traefik_datapath_custom' ),
      filter: utils.trimFilter,
      validate: utils.pathValidator,
      message: prefix()+'Custom path for traefik data?'+utils.getHelp('traefik_datapath_custom'),
    },
    {
      when: (props)=>{ return installerDocker(props) && props.features.indexOf('tor') !== -1 },
      type: 'list',
      name: 'tor_datapath',
      default: utils.getDefault( 'tor_datapath' ),
      choices: [
        {
          name: utils.setupDir()+"/cyphernode/tor",
          value: utils.setupDir()+"/cyphernode/tor"
        },
        {
          name: utils.defaultDataDirBase()+"/cyphernode/tor",
          value: utils.defaultDataDirBase()+"/cyphernode/tor"
        },
        {
          name: utils.defaultDataDirBase()+"/.cyphernode/tor",
          value: utils.defaultDataDirBase()+"/.cyphernode/tor"
        },
        {
          name: utils.defaultDataDirBase()+"/tor",
          value: utils.defaultDataDirBase()+"/tor"
        },
        {
          name: "Custom path",
          value: "_custom"
        }
      ],
      message: prefix()+'Where do you want to store your tor data?'+utils.getHelp('tor_datapath'),
    },
    {
      when: (props)=>{ return installerDocker(props) && props.features.indexOf('tor') !== -1 && props.tor_datapath === '_custom' },
      type: 'input',
      name: 'tor_datapath_custom',
      default: utils.getDefault( 'tor_datapath_custom' ),
      filter: utils.trimFilter,
      validate: utils.pathValidator,
      message: prefix()+'Custom path for Tor data?'+utils.getHelp('tor_datapath_custom'),
    },
    {
      when: installerDocker,
      type: 'list',
      name: 'gatekeeper_datapath',
      default: utils.getDefault( 'gatekeeper_datapath' ),
      choices: [
        {
          name: utils.setupDir()+"/cyphernode/gatekeeper",
          value: utils.setupDir()+"/cyphernode/gatekeeper"
        },
        {
          name: utils.defaultDataDirBase()+"/cyphernode/gatekeeper",
          value: utils.defaultDataDirBase()+"/cyphernode/gatekeeper"
        },
        {
          name: utils.defaultDataDirBase()+"/.cyphernode/gatekeeper",
          value: utils.defaultDataDirBase()+"/.cyphernode/gatekeeper"
        },
        {
          name: utils.defaultDataDirBase()+"/gatekeeper",
          value: utils.defaultDataDirBase()+"/gatekeeper"
        },
        {
          name: "Custom path",
          value: "_custom"
        }
        ],
      message: prefix()+'Where do you want to store your gatekeeper data?'+utils.getHelp('gatekeeper_datapath'),
    },
    {
      when: (props)=>{ return installerDocker(props) && (props.gatekeeper_datapath === '_custom') },
      type: 'input',
      name: 'gatekeeper_datapath_custom',
      default: utils.getDefault( 'gatekeeper_datapath_custom' ),
      filter: utils.trimFilter,
      validate: utils.pathValidator,
      message: prefix()+'Custom path for gatekeeper data?'+utils.getHelp('gatekeeper_datapath_custom'),
    },
    {
      when: installerDocker,
      type: 'list',
      name: 'proxy_datapath',
      default: utils.getDefault( 'proxy_datapath' ),
      choices: [
        {
          name: utils.setupDir()+"/cyphernode/proxy",
          value: utils.setupDir()+"/cyphernode/proxy"
        },
        {
          name: utils.defaultDataDirBase()+"/cyphernode/proxy",
          value: utils.defaultDataDirBase()+"/cyphernode/proxy"
        },
        {
          name: utils.defaultDataDirBase()+"/.cyphernode/proxy",
          value: utils.defaultDataDirBase()+"/.cyphernode/proxy"
        },
        {
          name: utils.defaultDataDirBase()+"/proxy",
          value: utils.defaultDataDirBase()+"/proxy"
        },
        {
          name: "Custom path",
          value: "_custom"
        }
      ],
      message: prefix()+'Where do you want to store your proxy data?'+utils.getHelp('proxy_datapath'),
    },
    {
      when: (props)=>{ return installerDocker(props) && (props.proxy_datapath === '_custom') },
      type: 'input',
      name: 'proxy_datapath_custom',
      default: utils.getDefault( 'proxy_datapath_custom' ),
      filter: utils.trimFilter,
      validate: utils.pathValidator,
      message: prefix()+'Custom path for your proxy data?'+utils.getHelp('proxy_datapath_custom'),
    },
    {
      when: function(props) { return installerDocker(props) && props.bitcoin_mode === 'internal' },
      type: 'list',
      name: 'bitcoin_datapath',
      default: utils.getDefault( 'bitcoin_datapath' ),
      choices: [
        {
          name: utils.setupDir()+"/cyphernode/bitcoin",
          value: utils.setupDir()+"/cyphernode/bitcoin"
        },
        {
          name: utils.defaultDataDirBase()+"/cyphernode/bitcoin",
          value: utils.defaultDataDirBase()+"/cyphernode/bitcoin"
        },
        {
          name: utils.defaultDataDirBase()+"/.cyphernode/bitcoin",
          value: utils.defaultDataDirBase()+"/.cyphernode/bitcoin"
        },
        {
          name: utils.defaultDataDirBase()+"/bitcoin",
          value: utils.defaultDataDirBase()+"/bitcoin"
        },
        {
          name: "Custom path",
          value: "_custom"
        }
      ],
      message: prefix()+'Where do you want to store your bitcoin full node data?'+utils.getHelp('bitcoin_datapath'),
    },
    {
      when: function(props) { return installerDocker(props) && props.bitcoin_mode === 'internal' && props.bitcoin_datapath === '_custom' },
      type: 'input',
      name: 'bitcoin_datapath_custom',
      default: utils.getDefault( 'bitcoin_datapath_custom' ),
      filter: utils.trimFilter,
      validate: utils.pathValidator,
      message: prefix()+'Custom path for your bitcoin full node data?'+utils.getHelp('bitcoin_datapath_custom'),
    },
    {
      when: function(props) { return installerDocker(props) && props.features.indexOf('lightning') !== -1 },
      type: 'list',
      name: 'lightning_datapath',
      default: utils.getDefault( 'lightning_datapath' ),
      choices: [
        {
          name: utils.setupDir()+"/cyphernode/lightning",
          value: utils.setupDir()+"/cyphernode/lightning"
        },
        {
          name: utils.defaultDataDirBase()+"/cyphernode/lightning",
          value: utils.defaultDataDirBase()+"/cyphernode/lightning"
        },
        {
          name: utils.defaultDataDirBase()+"/.cyphernode/lightning",
          value: utils.defaultDataDirBase()+"/.cyphernode/lightning"
        },
        {
          name: utils.defaultDataDirBase()+"/lightning",
          value: utils.defaultDataDirBase()+"/lightning"
        },
        {
          name: "Custom path",
          value: "_custom"
        }
      ],
      message: prefix()+'Where do you want to store your lightning node data?'+utils.getHelp('lightning_datapath'),
    },
    {
      when: function(props) { return installerDocker(props) && props.features.indexOf('lightning') !== -1 && props.lightning_datapath === '_custom'},
      type: 'input',
      name: 'lightning_datapath_custom',
      default: utils.getDefault( 'lightning_datapath_custom' ),
      filter: utils.trimFilter,
      validate: utils.pathValidator,
      message: prefix()+'Custom path for your lightning node data?'+utils.getHelp('lightning_datapath_custom'),
    },
    {
      when: function(props) { return installerDocker(props) && props.features.indexOf('otsclient') !== -1 },
      type: 'list',
      name: 'otsclient_datapath',
      default: utils.getDefault( 'otsclient_datapath' ),
      choices: [
        {
          name: utils.setupDir()+"/cyphernode/otsclient",
          value: utils.setupDir()+"/cyphernode/otsclient"
        },
        {
          name: utils.defaultDataDirBase()+"/cyphernode/otsclient",
          value: utils.defaultDataDirBase()+"/cyphernode/otsclient"
        },
        {
          name: utils.defaultDataDirBase()+"/.cyphernode/otsclient",
          value: utils.defaultDataDirBase()+"/.cyphernode/otsclient"
        },
        {
          name: utils.defaultDataDirBase()+"/otsclient",
          value: utils.defaultDataDirBase()+"/otsclient"
        },
        {
          name: "Custom path",
          value: "_custom"
        }
      ],
      message: prefix()+'Where do you want to store your OTS data?'+utils.getHelp('otsclient_datapath'),
    },
    {
      when: function(props) { return installerDocker(props) && props.features.indexOf('otsclient') !== -1 && props.otsclient_datapath === '_custom' },
      type: 'input',
      name: 'otsclient_datapath_custom',
      default: utils.getDefault( 'otsclient_datapath_custom' ),
      filter: utils.trimFilter,
      validate: utils.pathValidator,
      message: prefix()+'Where is your otsclient data?'+utils.getHelp('otsclient_datapath_custom'),
    },
    {
      type: 'confirm',
      name: 'gatekeeper_expose',
      default: utils.getDefault( 'gatekeeper_expose' ),
      message: prefix()+'Expose gatekeeper outside of the docker network?'+utils.getHelp('gatekeeper_expose'),
    },
    {
      when: function(props) { return installerDocker(props) && props.bitcoin_mode === 'internal' },
      type: 'confirm',
      name: 'bitcoin_expose',
      default: utils.getDefault( 'bitcoin_expose' ),
      message: prefix()+'Expose bitcoin full node P2P port outside of the docker network?'+utils.getHelp('bitcoin_expose'),
    },
    {
      when: function(props) { return installerDocker(props) && props.features.indexOf('lightning') !== -1  },
      type: 'confirm',
      name: 'lightning_expose',
      default: utils.getDefault( 'lightning_expose' ),
      message: prefix()+'Expose lightning node outside of the docker network?'+utils.getHelp('lightning_expose'),
    },
    {
      when: installerDocker,
      type: 'list',
      name: 'docker_mode',
      default: utils.getDefault( 'docker_mode' ),
      message: prefix()+'What docker mode: docker swarm or docker-compose?'+utils.getHelp('docker_mode'),
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
      default: utils.getDefault( 'installer_cleanup' ),
      message: prefix()+'Cleanup installer after installation?'+utils.getHelp('installer_cleanup'),
    }];
  },
  templates: function( props ) {
    if( props.installer_mode === 'docker' ) {
      return ['config.sh','start.sh', 'stop.sh', 'testfeatures.sh', 'testdeployment.sh', 'tgsetup.sh', 'run-tgsetup.sh', path.join('docker', 'docker-compose.yaml')];
    }
    return ['config.sh','start.sh', 'stop.sh', 'testfeatures.sh', 'testdeployment.sh', 'tgsetup.sh', 'run-tgsetup.sh'];
  }
};
