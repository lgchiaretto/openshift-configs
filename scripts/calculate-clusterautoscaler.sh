#!/bin/bash

IFS=$'\n' # make newlines the only separator

AWK_CMD=$(which awk)
ECHO_CMD=$(which echo)
OC_CMD=$(which oc)

NODES_LIST=$($OC_CMD get nodes -o 'jsonpath={range .items[*]}{.metadata.name}{"\n"}{end}')

for node in $NODES_LIST;
do
  $ECHO_CMD $node
  node_memory=$($OC_CMD get nodes $node -o 'jsonpath={.status.capacity.memory}' | $AWK_CMD '{$0=$0/(1024^2); print $1,"GB";}')
  node_cpu=$($OC_CMD get nodes $node -o 'jsonpath={.status.capacity.cpu}')
  $ECHO_CMD "Memory: ${node_memory//Ki}"
  $ECHO_CMD "CPU: ${node_cpu}"
  $ECHO_CMD "--------------------------------"
done

CPU_CLUSTER_COUNT=$($OC_CMD get nodes -o 'jsonpath={range .items[*]}{.status.capacity.cpu}{"\n"}{end}' | $AWK_CMD '{s+=$1} END {print s}')
MEMORY_CLUSTER_COUNT=$($OC_CMD get nodes -o 'jsonpath={range .items[*]}{.status.capacity.memory}{"\n"}{end}' | $AWK_CMD '{s+=$1} END {print s}')

MEMORY_CLUSTER_COUNT_GB=$($ECHO_CMD $MEMORY_CLUSTER_COUNT | $AWK_CMD '{$0=$0/(1024^2); print int($1),"GB";}')

$ECHO_CMD "CPU must be higher than: $CPU_CLUSTER_COUNT"
$ECHO_CMD "Mem must be higher than: $MEMORY_CLUSTER_COUNT_GB"
