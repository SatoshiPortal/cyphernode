const chalk = require('chalk');

const name = 'tor';

const capitalise = function( txt ) {
  return txt.charAt(0).toUpperCase() + txt.substr(1);
};

const prefix = function() {
  return chalk.green(capitalise(name)+': ');
};

const featureCondition = function(props) {
  return props.features && props.features.indexOf( name ) != -1;
};

module.exports = {
  name: function() {
    return name;
  },
  prompts: function( utils ) {
    return [{
      // https://github.com/SBoudrias/Inquirer.js#question
      // input, confirm, list, rawlist, expand, checkbox, password, editor
      when: featureCondition,
      type: 'checkbox',
      name: 'torifyables',
      message: prefix()+'What features do you want to TORify?'+utils.getHelp('torifyables'),
      choices: utils.torifyableChoices()
    },
    {
      when: featureCondition,
      type: 'checkbox',
      name: 'clearnet',
      default: utils.getDefault( 'clearnet' ),
      message: prefix()+'What features do you want to allow using clearnet?'+utils.getHelp('clearnet'),
      choices: [{
        name: "Bitcoin Node",
        value: "clearnet_bitcoinnode"
      },{
        name: "LN Node",
        value: "clearnet_lnnode"
      }]
    }];
  },
  templates: function( props ) {
    return [ 'torrc' ];
  }
};

// Do you want to access Cyphernode via a TOR Hidden Service?
// Do you want to access Cyphernode also via clearnet?
// Do you want your Bitcoin node to use TOR?
// Do you want your Bitcoin node to also use clearnet?
// Do you want your LN node to use TOR?
// Do you want your LN node to also use clearnet?
// Do you want your OTS client to use TOR?
// Do you want your Cyphernode callbacks (address watches, TXID watches and OTS notifications) to perform through TOR?

// Do you want TOR?
// What do you want to TOR?
// - Cyphernode as Hidden Service
// - Bitcoin Node
// - LN Node
// - OTS stamp, upgrade and verify
// - OTS Callbacks (webhooks)
// - Address Watches Callbacks (webhooks)
// - TXID Watches Callbacks (webhooks)

// Certain services can also use clearnet.  What do you want to allow to use clearnet?
// - Bitcoin Node
// - LN Node
// 
// Do you want to announce your LN node onion address and/or IP address?
// 
// What is your public IP address?

