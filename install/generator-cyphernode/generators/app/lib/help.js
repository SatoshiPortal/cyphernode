const chalk = require('chalk');
const wrap = require('wrap-ansi');

module.exports = {
  text: function( topic ) {
    let r=wrap('Lorem ipsum dolor sit amet, consetetur sadipscing elitr, sed diam nonumy eirmod tempor invidunt ut labore et dolore magna aliquyam erat, sed diam voluptua. At vero eos et accusam et justo duo dolores et ea rebum. Stet clita kasd gubergren, no sea takimata sanctus est Lorem ipsum dolor sit amet. Lorem ipsum dolor sit amet, consetetur sadipscing elitr, sed diam', 82);
    switch( topic ) {
      case 'features':
        break;
      case 'net':
        break;
      case 'username':
        break;
      case 'xpub':
        break;
      case 'derivation_path':
        break;
      case 'auth_clientkeyspassword':
        break;
      case 'auth_recreatekeys':
        break;
      case 'auth_edit_ipwhitelist':
        break;
      case 'auth_ipwhitelist':
        break;
      case 'auth_edit_apiproperties':
        break;
      case 'auth_apiproperties':
        break;
      case 'bitcoin_mode':
        break;
      case 'bitcoin_node_ip':
        break;
      case 'bitcoin_rpcuser':
        break;
      case 'bitcoin_rpcpassword':
        break;
      case 'bitcoin_prune':
        break;
      case 'bitcoin_uacomment':
        break;
      case 'lightning_implementation':
        break;
      case 'lightning_external_ip':
        break;
      case 'lightning_nodename':
        break;
      case 'lightning_nodecolor':
        break;
      case 'electrum_implementation':
        break;
      case 'proxy_datapath':
        break;
      case 'bitcoin_datapath':
        break;
      case 'lightning_datapath':
        break;
      case 'bitcoin_expose':
        break;
      case 'docker_mode':
        break;
    }
    return r;
  }
}



 