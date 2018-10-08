INSTALLER_MODE=<%= installer_mode %>
BITCOIN_INTERNAL=<%= (bitcoin_mode==="internal"?'true':'false') %>
FEATURE_LIGHTNING=<%= (features.indexOf('lightning') != -1)?'true':'false' %>
FEATURE_OPENTIMESTAMPS=<%= (features.indexOf('opentimestamps') != -1)?'true':'false' %>
FEATURE_ELECTRUM=<%= (features.indexOf('electrum') != -1)?'true':'false' %>
