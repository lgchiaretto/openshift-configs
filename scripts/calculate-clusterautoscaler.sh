#!/bin/bash

IFS=$'\n' # make newlines the only separator

NODES_LIST=$(oc get nodes -o 'jsonpath={range .items[*]}{.metadata.name}{"\n"}{end}')

for node in $NODES_LIST;
do
  echo $node
  node_memory=$(oc get nodes $node -o 'jsonpath={.status.capacity.memory}' | awk '{$0=$0/(1024^2); print $1,"GB";}')
  node_cpu=$(oc get nodes $node -o 'jsonpath={.status.capacity.cpu}')
  echo "Memory: ${node_memory//Ki}"
  echo "CPU: ${node_cpu}"
  echo "--------------------------------"
done

CPU_CLUSTER_COUNT=$(oc get nodes -o 'jsonpath={range .items[*]}{.status.capacity.cpu}{"\n"}{end}' | awk '{s+=$1} END {print s}')
MEMORY_CLUSTER_COUNT=$(oc get nodes -o 'jsonpath={range .items[*]}{.status.capacity.memory}{"\n"}{end}' | awk '{s+=$1} END {print s}')

MEMORY_CLUSTER_COUNT_GB=$(echo $MEMORY_CLUSTER_COUNT | awk '{$0=$0/(1024^2); print int($1),"GB";}')

echo "CPU must be higher than: $CPU_CLUSTER_COUNT"
echo "Mem must be higher than: $MEMORY_CLUSTER_COUNT_GB"
