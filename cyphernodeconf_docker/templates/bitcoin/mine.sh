#!/bin/sh

<% if( net === 'regtest' ) { %>

while [ -z "`bitcoin-cli listwallets | grep spending01.dat`"  ]; do echo "CYPHERNODE[mine]: waiting for wallet spending01.dat to be created" ; sleep 10 ; done

MINBLOCK=101

blockcount=`bitcoin-cli getblockcount`                            
blocktomine=`expr $MINBLOCK - $blockcount`
[ $blocktomine -gt 0 ] && echo "CYPHERNODE: About to mine [$blocktomine] new block(s)" && bitcoin-cli -rpcwallet=spending01.dat -generate $blocktomine

echo "CYPHERNODE: Done mining [$blocktomine] new block(s)"

<% } %>
