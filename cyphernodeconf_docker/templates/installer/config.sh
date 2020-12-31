INSTALLER_MODE=<%= installer_mode %>
BITCOIN_INTERNAL=<%= (bitcoin_mode==="internal"?'true':'false') %>
FEATURE_LIGHTNING=<%= (features.indexOf('lightning') != -1)?'true':'false' %>
FEATURE_BATCHER=<%= (features.indexOf('batcher') != -1)?'true':'false' %>
FEATURE_SPECTER=<%= (features.indexOf('specter') != -1)?'true':'false' %>
FEATURE_OTSCLIENT=<%= (features.indexOf('otsclient') != -1)?'true':'false' %>
LIGHTNING_IMPLEMENTATION=<%= lightning_implementation %>
PROXY_DATAPATH=<%= proxy_datapath %>
GATEKEEPER_DATAPATH=<%= gatekeeper_datapath %>
GATEKEEPER_PORT=<%= gatekeeper_port %>
LOGS_DATAPATH=<%= logs_datapath %>
TRAEFIK_DATAPATH=<%= traefik_datapath %>
FEATURE_TOR=<%= (features.indexOf('tor') != -1)?'true':'false' %>
<% if ( features.indexOf('tor') !== -1 ) { -%>
TOR_DATAPATH=<%= tor_datapath %>
TOR_OTS_WEBHOOKS=<%= (torifyables && torifyables.indexOf('tor_otswebhooks') !== -1)?'true':'false' %>
TOR_ADDR_WATCH_WEBHOOKS=<%= (torifyables && torifyables.indexOf('tor_addrwatcheswebhooks') !== -1)?'true':'false' %>
TOR_TXID_WATCH_WEBHOOKS=<%= (torifyables && torifyables.indexOf('tor_txidwatcheswebhooks') !== -1)?'true':'false' %>
TOR_TRAEFIK=<%= (torifyables && torifyables.indexOf('tor_traefik') !== -1)?'true':'false' %>
TOR_BITCOIN=<%= (torifyables && torifyables.indexOf('tor_bitcoin') !== -1)?'true':'false' %>
TOR_LIGHTNING=<%= (torifyables && torifyables.indexOf('tor_lightning') !== -1)?'true':'false' %>
<% } -%>
DOCKER_MODE=<%= docker_mode %>
RUN_AS_USER=<%= run_as_different_user?username:'' %>
CLEANUP=<%= installer_cleanup?'true':'false' %>
SHARED_HTPASSWD_PATH=<%= traefik_datapath %>/htpasswd
<% if ( features.indexOf('lightning') !== -1 && lightning_implementation === 'c-lightning' ) { -%>
LIGHTNING_DATAPATH=<%= lightning_datapath %>
<% } -%>
<% if ( features.indexOf('otsclient') !== -1 ) { -%>
OTSCLIENT_DATAPATH=<%= otsclient_datapath %>
<% } -%>
<% if ( bitcoin_mode==="internal" ) { -%>
BITCOIN_DATAPATH=<%= bitcoin_datapath %>
<% } -%>
ADMIN_DATAPATH=<%= admin_datapath %>
