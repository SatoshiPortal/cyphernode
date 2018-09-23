# Contributions are welcome!

There are a lot to contribute.  Bugfixes, improvements, new features, documentation, tests, etc.  Let's be a team!

# How to contribute

## Cyphernode Architecture

Cyphernode is an assembly of Docker containers being called by a request dispatcher.

- The request dispatcher (requesthandler.sh) is the HTTP entry point.
- The request dispatcher is stateful: it keeps some data to be more effective on next calls.
- The request dispatcher is where Cyphernode scales with new features: add your switch, dispatch requests to your stuff.

We are trying to construct each container so that it can be used separately, as a standalone reusable component.

Important to us:

- Be as optimized as possible, using Alpine when possible and having the smallest Docker image size possible
- Reuse existing software: built-in shell commands, well-established pieces of software, etc.
- Use open-source software
- Don't reinvent the wheel
- Expose the less possible surface

## Center element: proxy_docker

The proxy_docker is the container receiving and dispatching calls from clients.  When adding a feature to Cyphernode, it is the first part to be modified to integrate the new feature.

### proxy_docker/app/script/requesthandler.sh

You will find in there the switch statement used to dispatch the requests.  Just add a case block with your command, using other cases as examples for POST or GET requests.

### proxy_docker/app/config

You will find there config files.  config.properties should be used to centralize configs.  spender and watcher properties are used to obfuscate credentials on curl calls.

### proxy_docker/app/data

watching.sql contains the data model.  Called "watching" because in the beginning of the project, it was only used for watching addresses.  Now could be used to index the blockchain (build an explorer) and add more features.

## cron_docker

If you have jobs to be scheduled, use this container.  Just add an executable and add it to the crontab.

Currently used to make sure callbacks have been called for missed transactions.

## docker-compose

Deployment flexibility:
- distribute your components all over the world using docker-compose.yml constraints in a swarm
- scales your system with load-balancers
- automatically restarts a component if it crashes

# What to contribute

## TODO

- Stress/load tests
  - How does netcat behave on high traffic
  - sqlite3 tweaks for dealing with threaded calls
- Security check
- Installation scripts:
  - Configuration (config files)
  - Deployment (docker-compose)
  - Launcher app with lunanode

## Improvements

- wget is included in Alpine, we could use it instead of curl if we don't have to POST over HTTPS
- Make sure everything is thread-safe
  - There's currently a flock in do_callbacks, do we need one elsewhere?
- Using inter-containers direct calls (through docker.sock?) instead of HTTP?
- Possibility to automate additions of new endpoints?
  - With name, type (GET/POST), function name and script file, it's possible
- Autoconfig pruned property (in config.properties) by using getblockchaininfo RPC call
- Compile lightning-cli during configuration process (if not too slow) instead of precompile it
- Add results of gettransaction RPC calls in the DB (like already done for getrawtransaction results) and check DB before calling the node
  - only when confirmations > 0 in DB

## Features

- Timestamping (OTS)
- Electrum Server features
- Web Admin Panel
  - Using Trezor/Coldcard for authentication/signing
  - Multi-authorization: SuperAdmin, Accounting (transactions, etc.), Marketing (usage, etc.), etc.
- Web Wallet
  - Using Trezor/Coldcard for authentication/signing
- Index the blockchain (full explorer)
- PGP features: signing, verifying, etc.
- Full blockchain explorer
- e-mail notifications when things happen (monitoring):
  - less than X BTC in the spending wallet
  - more than Y% CPU used for more than Z minutes on the proxy container
  - bitcoind instance unreachable
  - any error

# F.A.Q.

Q. Why use netcat instead of an HTTP server like nginx or apache httpd?
A. We want to be able to run cyphernode everywhere, so we are trying to get the smallest possible docker images.

Q. Why use Shell Scripting instead of a regular language like Python, C++, Java?...
A. Almost all parts of cyphernode were existing software or builtin commands: curl, sed, tr, grep, echo, etc.  Remember, we want to keep docker images as small as possible.

Q. Why don't you directly execute binaries from one container to the other instead of having an HTTP interface?
A. It would be great to improve that, it is actually in the TO-DO's.

Q. Why haven't you secured the HTTP access of the proxy?
A. The proxy port is not published, so if you have access to the proxy port, you have access to the Docker overlay network which means you have a root/admin/docker access on the server meaning you are probably legit.  In the TO-DO's, you will find "Security check" which is improvements security-wise.  Don't hesitate!

Q. The REST API is not pure, GET and POST concepts are not followed.
A. Yeah.  The key point is if you need to pass multiple parameters, you will use a POST request and if 0 or 1 param, a GET request.  Once again, very open to improvements!

Q. Why don't you send the getrawtransaction output when calling conf from Bitcoin Core's walletnotify?
A. Because we need it only the first time.  If we don't already have it in our DB, we'll request it.  Let's be optimal, not only in space but also bandwidth.

Q. Why do you compute transaction fees instead of using the fee element returned by Bitcoin Core's gettransaction?
A. Because when the transaction has not been created by our instance of Bitcoin Core, the fee element is absent.  We have to calculate fees by looking at each input transactions.

Q. What's up with the manage_missed_conf thing?
A. If a network glitch blocked 0-conf and 1-conf notifications, we still need to know if the transactions got in to call the app's callbacks.  The cron container will check every 15 minutes.  Yes, we use the UTXO set to manage to get the missed payment ... and if the outputs have been spent, we'll have a problem.  We hope this won't happen within 15 minutes.  Improvements welcome!

Q. Why pycoin?  Why a fork of it?
A. It works well!  SegWit was added in the fork.
