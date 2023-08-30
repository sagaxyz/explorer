#!/bin/bash

# env
ETHEREUM_JSONRPC_HTTP_URL=${ETHEREUM_JSONRPC_HTTP_URL}
HEALTH_MAX_RETRIES=${HEALTH_MAX_RETRIES:-100}
HEALTH_DELAY_SECONDS=${HEALTH_DELAY_SECONDS:-10}

SESSION_STAMP=blockscout_start_`date +%m%d%Y%H%M%S`
LOGDIR=/tmp
LOGFILE=${LOGDIR}/${SESSION_STAMP}.log

Logger()
{
	MSG=$1
	echo "`date` $MSG" >> $LOGFILE
	echo "`date` $MSG"
}

WaitForChainletReadiness()
{
    for i in $(eval echo "{1..$HEALTH_MAX_RETRIES}"); do
        Logger "checking chainlet readiness.. tentative $i"
        status_code=$(curl --write-out '%{http_code}' \
            --silent -H "Content-Type: application/json" \
            --data '{"jsonrpc":"2.0","method":"net_version","params":[],"id":"99"}' \
            --output /dev/null \
            $ETHEREUM_JSONRPC_HTTP_URL)
        if [[ "$status_code" -ne 200 ]] ; then
            Logger "jsonrpc not available yet"
            sleep $HEALTH_DELAY_SECONDS
        else
            Logger "jsonrpc is available"
            block_height=$(curl \
                --silent -H "Content-Type: application/json" \
                --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":"99"}' \
                $ETHEREUM_JSONRPC_HTTP_URL | jq -r .result)
            if [[ "$block_height" -eq "0x0" ]] ; then
                Logger "chainlet is not producing blocks yet"
                sleep $HEALTH_DELAY_SECONDS
            else
                Logger "chainlet is producing blocks"
                break
            fi
        fi
    done
}

WaitForChainletReadiness

Logger "chainlet is healthy. starting blockscout"

sh -c "bin/blockscout eval \"Elixir.Explorer.ReleaseTasks.create_and_migrate()\" && bin/blockscout start"