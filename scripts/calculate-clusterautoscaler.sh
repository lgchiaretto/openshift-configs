#!/bin/bash

IFS=$'\n' # make newlines the only separator

AWK_CMD=$(which awk)
ECHO_CMD=$(which echo)
OC_CMD=$(which oc)
DEFAULT_TIMEOUT=3

err() {
    $ECHO_CMD; $ECHO_CMD;
    $ECHO_CMD -e "\e[97m\e[101m[ERROR]\e[0m ${1}"; shift; $ECHO_CMD;
    while [[ $# -gt 0 ]]; do $ECHO_CMD "    $1"; shift; done
    $ECHO_CMD; exit 1;
}

log(){
    $ECHO_CMD "[$(date +'%d:%m:%y %H:%M:%S')] - " $1
}

# check if connected on OCP
$OC_CMD --request-timeout="$DEFAULT_TIMEOUT" project -q > /dev/null
OPENSHIFT_CONNECTED=$?
if [[ $OPENSHIFT_CONNECTED == 1 ]]; then
  err "You are not connected in an Openshift 4 cluster"
  exit 1
fi

# Getting all nodes
NODES_LIST=$($OC_CMD --request-timeout="$DEFAULT_TIMEOUT" get nodes -o 'jsonpath={range .items[*]}{.metadata.name}{"\n"}{end}')
NUMBER_OF_NODES=0
for node in $NODES_LIST;
do
  ((NUMBER_OF_NODES++))
  log   $node
  node_memory=$($OC_CMD --request-timeout="$DEFAULT_TIMEOUT" --request-timeout="$DEFAULT_TIMEOUT" get nodes $node -o 'jsonpath={.status.capacity.memory}' | $AWK_CMD '{$0=$0/(1024^2); print $1,"GB";}')
  node_cpu=$($OC_CMD --request-timeout="$DEFAULT_TIMEOUT" get nodes $node -o 'jsonpath={.status.capacity.cpu}')
  log   "Memory: ${node_memory}"
  log   "CPU: ${node_cpu}"
  log   "--------------------------------"
done

CPU_CLUSTER_COUNT=$($OC_CMD --request-timeout="$DEFAULT_TIMEOUT" get nodes -o 'jsonpath={range .items[*]}{.status.capacity.cpu}{"\n"}{end}' | $AWK_CMD '{s+=$1} END {print s}')
MEMORY_CLUSTER_COUNT=$($OC_CMD --request-timeout="$DEFAULT_TIMEOUT" get nodes -o 'jsonpath={range .items[*]}{.status.capacity.memory}{"\n"}{end}' | $AWK_CMD '{s+=$1} END {print s}')
MEMORY_CLUSTER_COUNT_GB=$($ECHO_CMD $MEMORY_CLUSTER_COUNT | $AWK_CMD '{$0=$0/(1024^2); print int($1),"GB";}')

log   "ClusterAutoscaler configs"
log   "spec.cores.max must be higher than:  $CPU_CLUSTER_COUNT"
log   "spec.memory.max must be higher than: $MEMORY_CLUSTER_COUNT_GB"
log   "maxNodesTotal must be higher than:   $NUMBER_OF_NODES"
log   "--------------------------------"

# Checking machineSet sizing
MACHINESETS=$($OC_CMD get -o 'jsonpath={range .items[*]}{.metadata.name}{"\n"}{end}' --no-headers  --request-timeout=3 machineset -n openshift-machine-api)
if [ -z "$MACHINESETS" ]; then
  err "There's no MachineSet created on cluster and it's prereq to configure ClusterAutoScaler"
fi

log   "MachineAutoscaler configs"

for machineset in $MACHINESETS; 
do
  ms_current_size=$($OC_CMD get -o 'jsonpath={.status.replicas}' --no-headers  --request-timeout=3 machineset -n openshift-machine-api $machineset)
  log "Machineset $machineset has found and the MaxReplicas on MachineAutoscaler for MachineSet $machineset must be higher than: $ms_current_size"
done
log   "--------------------------------"