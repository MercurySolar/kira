#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
source $KIRA_MANAGER/utils.sh
# quick edit: FILE="$KIRA_MANAGER/containers/start-snapshot.sh" && rm $FILE && nano $FILE && chmod 555 $FILE

set -x

MAX_HEIGHT=$1
SYNC_FROM_SNAP=$2

[ -z "$MAX_HEIGHT" ] && MAX_HEIGHT="0"
# ensure to create parent directory for shared status info
CONTAINER_NAME="snapshot"
CONTAINER_NETWORK="$KIRA_SENTRY_NETWORK"
SNAP_STATUS="$KIRA_SNAP/status"
SCAN_DIR="$KIRA_HOME/kirascan"
LATEST_BLOCK_SCAN_PATH="$SCAN_DIR/latest_block"
COMMON_PATH="$DOCKER_COMMON/$CONTAINER_NAME"
COMMON_LOGS="$COMMON_PATH/logs"
HALT_FILE="$COMMON_PATH/halt"

CPU_CORES=$(cat /proc/cpuinfo | grep processor | wc -l || echo "0")
RAM_MEMORY=$(grep MemTotal /proc/meminfo | awk '{print $2}' || echo "0")
CPU_RESERVED=$(echo "scale=2; ( $CPU_CORES / 6 )" | bc)
RAM_RESERVED="$(echo "scale=0; ( $RAM_MEMORY / 6 ) / 1024 " | bc)m"
LATETS_BLOCK=$(cat $LATEST_BLOCK_SCAN_PATH || echo "0") && (! $(isNaturalNumber "$LATETS_BLOCK")) && LATETS_BLOCK=0

rm -fvr "$SNAP_STATUS"
mkdir -p "$SNAP_STATUS" "$COMMON_LOGS"

echo "INFO: Setting up $CONTAINER_NAME config vars..." # * Config ~/configs/config.toml

SENTRY_STATUS=$(timeout 3 curl 0.0.0.0:$KIRA_SENTRY_RPC_PORT/status 2>/dev/null | jsonParse "result" 2>/dev/null || echo -n "")
PRIV_SENTRY_STATUS=$(timeout 3 curl 0.0.0.0:$KIRA_PRIV_SENTRY_RPC_PORT/status 2>/dev/null | jsonParse "result" 2>/dev/null || echo -n "")

SENTRY_CATCHING_UP=$(echo $SENTRY_STATUS | jsonQuickParse "catching_up" 2>/dev/null || echo -n "") && ($(isNullOrEmpty "$SENTRY_CATCHING_UP")) && SENTRY_CATCHING_UP="true"
PRIV_SENTRY_CATCHING_UP=$(echo $PRIV_SENTRY_STATUS | jsonQuickParse "catching_up" 2>/dev/null || echo -n "") && ($(isNullOrEmpty "$PRIV_SENTRY_CATCHING_UP")) && PRIV_SENTRY_CATCHING_UP="true"

SENTRY_NETWORK=$(echo $SENTRY_STATUS | jsonQuickParse "network" 2>/dev/null || echo -n "")
PRIV_SENTRY_NETWORK=$(echo $PRIV_SENTRY_STATUS | jsonQuickParse "network"  2>/dev/null || echo -n "")

SENTRY_BLOCK=$(echo $SENTRY_STATUS | jsonQuickParse "latest_block_height" || echo -n "") && (! $(isNaturalNumber "$SENTRY_BLOCK")) && SENTRY_BLOCK=0
PRIV_SENTRY_BLOCK=$(echo $PRIV_SENTRY_STATUS | jsonQuickParse "latest_block_height" || echo -n "") && (! $(isNaturalNumber "$PRIV_SENTRY_BLOCK")) && PRIV_SENTRY_BLOCK=0

[[ $MAX_HEIGHT -le 0 ]] && MAX_HEIGHT=$LATETS_BLOCK
SNAP_FILENAME="${NETWORK_NAME}-$MAX_HEIGHT-$(date -u +%s).zip"
SNAP_FILE="$KIRA_SNAP/$SNAP_FILENAME"

set +x
echoWarn "------------------------------------------------"
echoWarn "| STARTING $CONTAINER_NAME NODE"
echoWarn "|-----------------------------------------------"
echoWarn "|     NETWORK: $CONTAINER_NETWORK"
echoWarn "|    HOSTNAME: $KIRA_SNAPSHOT_DNS"
echoWarn "| SYNC HEIGHT: $MAX_HEIGHT"
echoWarn "|  SNAP DEST.: $SNAP_FILE"
echoWarn "| SNAP SOURCE: $SYNC_FROM_SNAP"
echoWarn "|     MAX CPU: $CPU_RESERVED / $CPU_CORES"
echoWarn "|     MAX RAM: $RAM_RESERVED"
echoWarn "------------------------------------------------"

echoInfo "INFO: Loading secrets..."
source $KIRAMGR_SCRIPTS/load-secrets.sh
set -x
set -e

echoInfo "INFO: Checking peers info..."
SENTRY_SEED=$(echo "${SENTRY_NODE_ID}@sentry:$KIRA_SENTRY_P2P_PORT" | xargs | tr -d '\n' | tr -d '\r')
PRIV_SENTRY_SEED=$(echo "${PRIV_SENTRY_NODE_ID}@priv_sentry:$KIRA_PRIV_SENTRY_P2P_PORT" | xargs | tr -d '\n' | tr -d '\r')

CFG_persistent_peers="tcp://$PRIV_SENTRY_SEED,tcp://$SENTRY_SEED"

cp -f -a -v $KIRA_SECRETS/snapshot_node_key.json $COMMON_PATH/node_key.json

SNAP_DESTINATION="$COMMON_PATH/snap.zip"
rm -rfv $SNAP_DESTINATION
if [ -f "$KIRA_SNAP_PATH" ] ; then
    echoInfo "INFO: State snapshot was found, cloning..."
    ln -fv "$KIRA_SNAP_PATH" "$SNAP_DESTINATION"
fi

echoInfo "INFO: Cleaning up snapshot container..."
$KIRA_SCRIPTS/container-delete.sh "$CONTAINER_NAME"

# cleanup
rm -f -v "$COMMON_LOGS/start.log" "$COMMON_PATH/executed" "$HALT_FILE"

echoInfo "INFO: Wiping '$CONTAINER_NAME' resources..."
$KIRA_SCRIPTS/container-delete.sh "$CONTAINER_NAME"

echoInfo "INFO: Starting '$CONTAINER_NAME' container..."
docker run -d \
    --cpus="$CPU_RESERVED" \
    --memory="$RAM_RESERVED" \
    --oom-kill-disable \
    -p $KIRA_SNAPSHOT_RPC_PORT:$DEFAULT_RPC_PORT \
    --hostname $KIRA_SNAPSHOT_DNS \
    --restart=always \
    --name $CONTAINER_NAME \
    --net=$CONTAINER_NETWORK \
    --log-opt max-size=5m \
    --log-opt max-file=5 \
    -e HALT_HEIGHT="$MAX_HEIGHT" \
    -e SNAP_FILENAME="$SNAP_FILENAME" \
    -e NETWORK_NAME="$NETWORK_NAME" \
    -e CFG_moniker="KIRA ${CONTAINER_NAME^^} NODE" \
    -e CFG_persistent_peers="$CFG_persistent_peers" \
    -e CFG_grpc_laddr="tcp://0.0.0.0:$DEFAULT_GRPC_PORT" \
    -e CFG_rpc_laddr="tcp://0.0.0.0:$DEFAULT_RPC_PORT" \
    -e CFG_p2p_laddr="tcp://0.0.0.0:$DEFAULT_P2P_PORT" \
    -e CFG_private_peer_ids="$SENTRY_NODE_ID,$PRIV_SENTRY_NODE_ID" \
    -e CFG_unconditional_peer_ids="$VALIDATOR_NODE_ID,$PRIV_SENTRY_NODE_ID" \
    -e CFG_pex="false" \
    -e CFG_addr_book_strict="false" \
    -e CFG_seed_mode="false" \
    -e CFG_max_num_outbound_peers="0" \
    -e CFG_max_num_inbound_peers="0" \
    -e CFG_handshake_timeout="30s" \
    -e CFG_dial_timeout="15s" \
    -e CFG_max_txs_bytes="131072000" \
    -e CFG_max_tx_bytes="131072" \
    -e CFG_send_rate="65536000" \
    -e CFG_recv_rate="65536000" \
    -e CFG_max_packet_msg_payload_size="131072" \
    -e KIRA_SETUP_VER="$KIRA_SETUP_VER" \
    -e NODE_TYPE=$CONTAINER_NAME \
    -v $COMMON_PATH:/common \
    -v $KIRA_SNAP:/snap \
    -v $DOCKER_COMMON_RO:/common_ro:ro \
    kira:latest # use sentry image as base

echoInfo "INFO: Waiting for $CONTAINER_NAME node to start..."
CONTAINER_CREATED="true" && $KIRAMGR_SCRIPTS/await-sentry-init.sh "$CONTAINER_NAME" "$SNAPSHOT_NODE_ID" || CONTAINER_CREATED="false"

set +x
if [ "${CONTAINER_CREATED,,}" != "true" ]; then
    echoInfo "INFO: Snapshot failed, '$CONTAINER_NAME' container did not start"
    $KIRA_SCRIPTS/container-pause.sh $CONTAINER_NAME || echoErr "ERROR: Failed to pause container"
else
    echoInfo "INFO: Success '$CONTAINER_NAME' container was started"
    rm -fv "$SNAP_DESTINATION"

    echoInfo "INFO: Checking genesis SHA256 hash"
    TEST_SHA256=$(docker exec -i "$CONTAINER_NAME" sha256sum $SEKAID_HOME/config/genesis.json | awk '{ print $1 }' | xargs || echo -n "")
    if [ -z "$TEST_SHA256" ] || [ "$TEST_SHA256" != "$GENESIS_SHA256" ]; then
        echoErr "ERROR: Snapshot failed, expected genesis checksum to be '$GENESIS_SHA256' but got '$TEST_SHA256'"
        $KIRA_SCRIPTS/container-pause.sh $CONTAINER_NAME || echoErr "ERROR: Failed to pause container"
        exit 1
    fi

    echoInfo "INFO: Snapshot destination: $SNAP_FILE"
    echoInfo "INFO: Work in progress, await snapshot container to reach 100% sync status"
fi
set -x
