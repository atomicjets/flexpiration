#!/bin/bash
# usage: /bin/rm -rf "$REGTEST_DIR"; ./flexpiration-regtest.sh

# set these variables for your environment's specific configuration
REGTEST_DIR="/tmp/bitcoin-flexpiration-regtest";
BITCOIN_QT="$HOME/Desktop/bitcoin/src/qt/bitcoin-qt";
BITCOIN_CLI="$HOME/Desktop/bitcoin/src/bitcoin-cli -regtest -datadir=$REGTEST_DIR";

# setup a fresh regtest environment for this test
/bin/mkdir -p "$REGTEST_DIR";
/bin/echo "rpcpassword=regtest" > "$REGTEST_DIR/bitcoin.conf";

# configure the new regtest environment. run the gui for easy manual access to the rpc console.
$BITCOIN_QT -regtest -txindex -server -datadir=$REGTEST_DIR &

# wait for the rpc server to start by waiting for the first cli command to work
# until /bin/nc -w 1 -z -v localhost 18332 2>&1; do sleep 1; done
# gotta get some coins since we start with nothing
until $BITCOIN_CLI generate 101 > /dev/null 2>&1; do sleep 1; done
# send some value to the well-known "alice" address
$BITCOIN_CLI sendtoaddress "mkESjLZW66TmHhiFX8MCaBjrhZ543PPh9a" 10 > /dev/null 2>&1;
$BITCOIN_CLI generate 1 > /dev/null 2>&1;
# import the well known "alice" key so that we can easily get the utxo info that is different on every run
$BITCOIN_CLI importprivkey "cP3voGKJHVSrUsEdrj8HnrpwLNgNngrgijMyyyRowRo15ZattbHm" > /dev/null 2>&1;
UNSPENT=$($BITCOIN_CLI listunspent 1 1 '["mkESjLZW66TmHhiFX8MCaBjrhZ543PPh9a"]');

TXID=$(/bin/echo "$UNSPENT" | /usr/bin/env python3 -c 'import json, sys; data=json.load(sys.stdin); print(data[0]["txid"]);');
VOUT=$(/bin/echo "$UNSPENT" | /usr/bin/env python3 -c 'import json, sys; data=json.load(sys.stdin); print(data[0]["vout"]);');
SCRIPT_PUBKEY=$(/bin/echo "$UNSPENT" | /usr/bin/env python3 -c 'import json, sys; data=json.load(sys.stdin); print(data[0]["scriptPubKey"]);');
SATOSHIS=$(/bin/echo "$UNSPENT" | /usr/bin/env python3 -c 'import json, sys, decimal; data=json.load(sys.stdin, parse_float=decimal.Decimal); print(data[0]["amount"].scaleb(8));');

RESULT=$(/usr/bin/env node flexpiration.js --txid=$TXID --vout=$VOUT --scriptPubKey=$SCRIPT_PUBKEY --satoshis=$SATOSHIS);

/bin/echo "$RESULT";

EARNEST_MONEY_TRAN=$(/bin/echo $RESULT | /usr/bin/env python3 -c 'import json, sys, decimal; data=json.load(sys.stdin); print(data["earnestMoneyTransaction"]["raw"]);');
ACCEPT_TRAN=$(/bin/echo $RESULT | /usr/bin/env python3 -c 'import json, sys, decimal; data=json.load(sys.stdin); print(data["acceptTransaction"]["raw"]);');
BOGUS_ACCEPT_TRAN=$(/bin/echo $RESULT | /usr/bin/env python3 -c 'import json, sys, decimal; data=json.load(sys.stdin); print(data["bogusAcceptTransaction"]["raw"]);');
HASSLE_TRAN=$(/bin/echo $RESULT | /usr/bin/env python3 -c 'import json, sys, decimal; data=json.load(sys.stdin); print(data["hassleTransaction"]["raw"]);');

$BITCOIN_CLI getblockcount;
# setting up the offer / earnest money output should work
$BITCOIN_CLI sendrawtransaction "$EARNEST_MONEY_TRAN";
# should fail because it tries to send the earnest money to a non-escrow address
$BITCOIN_CLI sendrawtransaction "$BOGUS_ACCEPT_TRAN";
# simulate waiting until cltv expiration
$BITCOIN_CLI generate 48 > /dev/null 2>&1;
$BITCOIN_CLI getblockcount;
# should fail because it tries to use an invalidly signed transaction
$BITCOIN_CLI sendrawtransaction "$HASSLE_TRAN";
# should work because the offer was not withdrawn
$BITCOIN_CLI sendrawtransaction "$ACCEPT_TRAN";
$BITCOIN_CLI generate 1 > /dev/null 2>&1;

