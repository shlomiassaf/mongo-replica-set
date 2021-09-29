#!/bin/bash

DATA_DIR_TEMPLATE="/var/lib/mongo"
LOG_DIR_TEMPLATE="/var/log/mongodb"

NODES=(1 2 3)
PORTS=(27017 27018 27019)

declare -a mongodParms
prepMongoArgs()
{
  mongodParms=(mongod --dbpath ${DATA_DIR_TEMPLATE}"$1" --logpath ${LOG_DIR_TEMPLATE}"$1"/mongod.log --port "$2" --bind_ip_all --replSet rs0)
}

waitForMongodInit()
{
  local READY=("${NODES[@]}")
  until [[ ${#READY[*]} -eq 0 ]]; do
    local R=( "${READY[@]}" )
    READY=()
    for n in ${R[@]}; do 
      if ! [ -f "${DATA_DIR_TEMPLATE}${n}/storage.bson" ]; then
        READY+=("$n")
      fi
    done

    echo "Waiting mongoDB to init"
    sleep 1s
  done

  # Wait server to be up
  until (test $(echo "db.serverStatus().ok" | mongo --quiet) -eq 1); do
    echo "Waiting mongoDB to start"
    sleep 1s
  done
}

prepMongoArgs "${NODES[0]}" "${PORTS[0]}"
"${mongodParms[@]}" &

prepMongoArgs "${NODES[1]}" "${PORTS[1]}"
"${mongodParms[@]}" --fork

prepMongoArgs "${NODES[2]}" "${PORTS[2]}"
"${mongodParms[@]}" --fork

# Wait init mongodb
waitForMongodInit


LOCAL_HOST="127.0.0.1"
EXPOSED_HOST="$PUBLIC_HOST"

if [ -z "$EXPOSED_HOST" ]; then
    EXPOSED_HOST="$LOCAL_HOST"
fi

RS_MEMBER_1="{ \"_id\": 0, \"host\": \"${EXPOSED_HOST}:${PORTS[0]}\", \"priority\": 2 }"
RS_MEMBER_2="{ \"_id\": 1, \"host\": \"${EXPOSED_HOST}:${PORTS[1]}\", \"priority\": 0 }"
RS_MEMBER_3="{ \"_id\": 2, \"host\": \"${EXPOSED_HOST}:${PORTS[2]}\", \"priority\": 0 }"

mongo --eval "rs.initiate({ \"_id\": \"rs0\", \"members\": [${RS_MEMBER_1}, ${RS_MEMBER_2}, ${RS_MEMBER_3}] });" || exit 1

tail -v -n +1 -F ${LOG_DIR_TEMPLATE}${NODES[0]}/mongod.log ${LOG_DIR_TEMPLATE}${NODES[1]}/mongod.log ${LOG_DIR_TEMPLATE}${NODES[2]}/mongod.log

