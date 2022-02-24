#!/bin/bash

# Output/metadata file path is given to get ips
TF_OUTPUT=$1

#Env variables (bool) used to know if we should create
# COST_EXPLORER_ES

# This script generate an ansible inventory regarding the number of ES ips/instances available.
# 1 role/group is defined:
#  INVENTORY_COST_EXPLORER_ES: Elasticsearch for Cost_Explorer

INVENTORY_COST_EXPLORER_ES=""

if [ "$COST_EXPLORER_ES" = "true" ]; then
  INVENTORY_COST_EXPLORER_ES="cost_explorer_elasticsearch"
fi

IPS=$(jq -r .es_instance_public_ip[] $TF_OUTPUT)
NUM_IPS=$(echo $IPS | wc -w)
# transform it to array
IFS=$'\n'
IPS=($IPS)
IFS=$' \t\n'

if [ $NUM_IPS -eq 1 ]; then
  for group in $(echo "$INVENTORY_COST_EXPLORER_ES"); do
    echo "[$group]"
    echo "${IPS[0]}"
  done

else
  # Dedicated IP by inventory order, then keep the same ip if no enough ip

  ip_count=0
  for group in $(echo "$INVENTORY_COST_EXPLORER_ES"); do
    echo "[$group]"
    echo "${IPS[$ip_count]}"
    if [ $ip_count -lt $((NUM_IPS-1)) ]; then
      ip_count=$((ip_count+1))
    fi
  done
fi
