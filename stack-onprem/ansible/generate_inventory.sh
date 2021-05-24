#!/bin/bash

# Output/metadata file path is given to get ips
TF_OUTPUT=$1

#Env variables (bool) used to know if we should create
# CONCOURSE_WORKER
# MINIO
# ELASTICSEARCH

# This script generate an ansible inventory regarding the number of ips/instances available.
# 4 role/groups are defined:
#  INVENTORY_CYCLOID_CORE: cycloid API + frontend + nginx
#  INVENTORY_CYCLOID: cycloid dependancies (DB / Vault / Smtp ...)
#  INVENTORY_OTHER: Optional services (Concourse + DB / ES / Minio ...)
#  INVENTORY_WORKER: Concourse worker

# How it is splited by IPs
# 1: everything on the same instance
# 2: split worker and onprem or cycloid service and others
# 3: split worker, cycloid service and others or cycloid core, cycloid and others
# 4: split worker, cycloid core and all the groups one by one regarding inventory order until the last ip. If not enough IPs, then keep last one for last groups

INVENTORY_CYCLOID_CORE="cycloid_core"
INVENTORY_CYCLOID="cycloid_db cycloid_cache smtp_server cycloid_creds"
INVENTORY_OTHER="cycloid_scheduler cycloid_scheduler_db"
INVENTORY_WORKER=""

if [ "$ELASTICSEARCH" = "true" ]; then
  INVENTORY_OTHER="$INVENTORY_OTHER elasticsearch"
fi

if [ "$MINIO" = "true" ]; then
  INVENTORY_OTHER="$INVENTORY_OTHER minio"
fi

if [ "$CONCOURSE_WORKER" = "true" ]; then
  INVENTORY_WORKER="cycloid_worker"
fi

IPS=$(jq -r .cy_instances_public_ip[] $TF_OUTPUT)
NUM_IPS=$(echo $IPS | wc -w)
# transform it to array
IFS=$'\n'
IPS=($IPS)
IFS=$' \t\n'

if [ $NUM_IPS -eq 1 ]; then
  for group in $(echo "$INVENTORY_CYCLOID_CORE $INVENTORY_CYCLOID $INVENTORY_OTHER $INVENTORY_WORKER"); do
    echo "[$group]"
    echo "${IPS[0]}"
  done

elif [ $NUM_IPS -eq 2 ]; then
  if [ "$CONCOURSE_WORKER" = "true" ]; then
    for group in $(echo "$INVENTORY_CYCLOID_CORE $INVENTORY_CYCLOID $INVENTORY_OTHER"); do
      echo "[$group]"
      echo "${IPS[0]}"
    done
    for group in $(echo "$INVENTORY_WORKER"); do
      echo "[$group]"
      echo "${IPS[1]}"
    done
  else
    for group in $(echo "$INVENTORY_CYCLOID_CORE $INVENTORY_CYCLOID"); do
      echo "[$group]"
      echo "${IPS[0]}"
    done
    for group in $(echo "$INVENTORY_OTHER"); do
      echo "[$group]"
      echo "${IPS[1]}"
    done
  fi

elif [ $NUM_IPS -eq 3 ]; then
  if [ "$CONCOURSE_WORKER" = "true" ]; then
    for group in $(echo "$INVENTORY_CYCLOID_CORE $INVENTORY_CYCLOID"); do
      echo "[$group]"
      echo "${IPS[0]}"
    done
    for group in $(echo "$INVENTORY_OTHER"); do
      echo "[$group]"
      echo "${IPS[1]}"
    done
    for group in $(echo "$INVENTORY_WORKER"); do
      echo "[$group]"
      echo "${IPS[2]}"
    done
  else
    for group in $(echo "$INVENTORY_CYCLOID_CORE"); do
      echo "[$group]"
      echo "${IPS[0]}"
    done
    for group in $(echo "$INVENTORY_OTHER"); do
      echo "[$group]"
      echo "${IPS[1]}"
    done
    for group in $(echo "$INVENTORY_CYCLOID"); do
      echo "[$group]"
      echo "${IPS[2]}"
    done
  fi

else
  # Dedicated IP by inventory order, then keep the same ip if no enough ip

  ip_count=0
  for group in $(echo "$INVENTORY_CYCLOID_CORE $INVENTORY_WORKER $INVENTORY_OTHER $INVENTORY_CYCLOID"); do
    echo "[$group]"
    echo "${IPS[$ip_count]}"
    if [ $ip_count -lt $((NUM_IPS-1)) ]; then
      ip_count=$((ip_count+1))
    fi
  done
fi
