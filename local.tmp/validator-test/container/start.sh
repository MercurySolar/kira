#!/bin/bash

exec 2>&1
set -e
set -x

echo "Staring validator..."

# wget https://raw.githubusercontent.com/gdraheim/docker-systemctl-replacement/master/files/docker/systemctl.py -O /usr/local/bin/systemctl2
# chmod -v 777 /usr/local/bin/systemctl2

# systemctl2 --version

SEKAID_HOME=$HOME/.simapp

rm -rf $SEKAID_HOME

sekaid init --chain-id=testing testing --home=$SEKAID_HOME

cp /root/config.toml $SEKAID_HOME/config/config.toml
cp /root/node_key.json $SEKAID_HOME/config/node_key.json
cp /root/priv_validator_key.json $SEKAID_HOME/config/priv_validator_key.json

sekaid keys add validator --keyring-backend=test --home=$SEKAID_HOME
sekaid add-genesis-account $(sekaid keys show validator -a --keyring-backend=test --home=$SEKAID_HOME) 1000000000ukex,1000000000validatortoken,1000000000stake --home=$SEKAID_HOME

sekaid keys add test --keyring-backend=test --home=$SEKAID_HOME
sekaid add-genesis-account $(sekaid keys show test -a --keyring-backend=test --home=$SEKAID_HOME) 1000000000ukex,1000000000validatortoken,1000000000stake --home=$SEKAID_HOME

sekaid keys add frontend --keyring-backend=test --home=$SEKAID_HOME
sekaid add-genesis-account $(sekaid keys show frontend -a --keyring-backend=test --home=$SEKAID_HOME) 1000000000ukex,1000000000validatortoken,1000000000stake --home=$SEKAID_HOME

yes "chief drip promote message thing bread describe morning tiger box toe supreme quit during occur nest abstract brown paddle resource antique decide draw matter" | sekaid keys add signer --keyring-backend=test --home=$SEKAID_HOME --recover
sekaid add-genesis-account $(sekaid keys show signer -a --keyring-backend=test --home=$SEKAID_HOME) 1000000000ukex,1000000000validatortoken,1000000000stake --home=$SEKAID_HOME

yes "equip exercise shoot mad inside floor wheel loan visual stereo build frozen potato always bulb naive subway foster marine erosion shuffle flee action there" | sekaid keys add faucet --keyring-backend=test --home=$SEKAID_HOME --recover
sekaid add-genesis-account $(sekaid keys show faucet -a --keyring-backend=test --home=$SEKAID_HOME) 1000000000ukex,1000000000validatortoken,1000000000stake --home=$SEKAID_HOME

sekaid gentx-claim validator --keyring-backend=test --moniker="hello" --home=$SEKAID_HOME
# --pubkey kiravalconspub14r8u30037l6xpqgtndf6nf3hhdds6pf6uhqalu9wu4l89qlglj6szqlepn

# netstat -nl
# ping 10.1.0.2

sleep 10 && sekaid start --home=$SEKAID_HOME --trace
