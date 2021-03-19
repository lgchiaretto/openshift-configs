#!/bin/bash

set -e

OPENSHIFT_VERSION=4.7
OPENSHIFT_RELEASE=4.7.0
VMWARE_FOLDER=OCP4VMW
CLUSTER_NAME=ocp4vmw
CLUSTER_FOLDER=/vms/clusters/${CLUSTER_NAME}
PULL_SECRET=changeme
VMWARE_PASSWORD=changeme
SSHKEY=changeme

err() {
    echo; echo;
    echo -e "\e[97m\e[101m[ERROR]\e[0m ${1}"; shift; echo;
    while [[ $# -gt 0 ]]; do echo "    $1"; shift; done
    echo; exit 1;
}

log(){
    echo "[$(date +'%d:%m:%y %H:%M:%S')] -" $1
}

log "Creating dir ${CLUSTER_FOLDER}"
mkdir -p ${CLUSTER_FOLDER}
cd ${CLUSTER_FOLDER}

log "Getting openshift-install"
curl -s -O https://mirror.openshift.com/pub/openshift-v4/clients/ocp/${OPENSHIFT_RELEASE}/openshift-install-linux.tar.gz || err "Error when downloading openshift-install"

log "Tar on openshift-install"
tar xzvf openshift-install-linux.tar.gz

log "Creating install-config.yaml"
cat <<EOF > install-config.yaml
apiVersion: v1
baseDomain: chiaret.to
compute:
- architecture: amd64
  hyperthreading: Enabled
  name: worker
  platform: {}
  replicas: 0
  platform:
    vsphere:
      osDisk:
        diskSizeGB: 60
controlPlane:
  architecture: amd64
  hyperthreading: Enabled
  name: master
  platform: {}
  replicas: 3
  platform:
    vsphere:
      memoryMB: 10240
      osDisk:
        diskSizeGB: 60
metadata:
  creationTimestamp: null
  name: ${CLUSTER_NAME}
networking:
  clusterNetwork:
  - cidr: 10.128.0.0/14
    hostPrefix: 23
  machineNetwork:
  - cidr: 10.0.0.0/16
  networkType: OpenShiftSDN
  serviceNetwork:
  - 172.30.0.0/16
platform:
  vsphere:
    cluster: HOME
    datacenter: CHIARETTO
    defaultDatastore: NFS
    network: VM Network
    password: ${VMWARE_PASSWORD}
    username: administrator@chiaretto.local
    vCenter: chiaretto-vcsa01.chiaret.to
    folder: "/CHIARETTO/vm/${VMWARE_FOLDER}"
publish: External
pullSecret: '${PULL_SECRET}'
sshKey: |
  ${SSHKEY}
EOF

log "Creating Manifests"
./openshift-install create manifests

log "Creating Ignition files"
./openshift-install create ignition-configs

for i in bootstrap master worker;  do 
  log "Generating $i.64 file"
  base64 -w0 < $i.ign > $i.64;  
done

log "Getting cluster ID"
CLUSTER_ID=$(jq -r .infraID metadata.json)
TEMPLATE=${CLUSTER_ID}-rhcos

log "Cluster ID is ${CLUSTER_ID}"

# Import OVA
log "Importing ova"
govc import.ova --folder=templates --ds=NFS --name=${CLUSTER_ID}-rhcos https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/${OPENSHIFT_VERSION}/latest/rhcos-vmware.x86_64.ova || err "Error when importing OVA"

VM_NAME=bootstrap
log "Creating ${VM_NAME} vm"
govc vm.clone -vm=$TEMPLATE -ds=NFS -folder=${VMWARE_FOLDER} ${VM_NAME}
govc vm.power -off -force ${VM_NAME}
govc vm.change -vm ${VM_NAME} -cpu-hot-add-enabled -memory-hot-add-enabled
govc vm.change -vm ${VM_NAME} -c=8 -m=8192
govc vm.change -vm "${VM_NAME}" -e cpuid.coresPerSocket=8
govc vm.change -vm "${VM_NAME}" -e "guestinfo.ignition.config.data=changeme"
govc vm.change -vm "${VM_NAME}" -e "guestinfo.ignition.config.data.encoding=base64"
govc vm.change -vm="${VM_NAME}" -e="disk.enableUUID=1"
govc vm.network.change --vm "${VM_NAME}" -net.address 00:50:56:b6:c8:db  -net="VM Network" ethernet-0

VM_NAME=${CLUSTER_ID}-master-0
log "Creating ${VM_NAME} vm"
CONFIG_B64=$(cat master.64)
govc vm.clone -vm=$TEMPLATE -ds=NFS -folder=${VMWARE_FOLDER} ${VM_NAME}
govc vm.power -off -force ${VM_NAME}
govc vm.change -vm ${VM_NAME} -cpu-hot-add-enabled -memory-hot-add-enabled
govc vm.change -vm ${VM_NAME} -c=8 -m=10240
govc vm.change -vm "${VM_NAME}" -e cpuid.coresPerSocket=8
govc vm.change -vm "${VM_NAME}" -e "guestinfo.ignition.config.data=${CONFIG_B64}"
govc vm.change -vm "${VM_NAME}" -e "guestinfo.ignition.config.data.encoding=base64"
govc vm.change -vm="${VM_NAME}" -e="disk.enableUUID=1"
govc vm.network.change --vm "${VM_NAME}" -net.address 00:50:56:b6:fd:d8  -net="VM Network" ethernet-0

VM_NAME=${CLUSTER_ID}-master-1
log "Creating ${VM_NAME} vm"
CONFIG_B64=$(cat master.64)
govc vm.clone -vm=$TEMPLATE -ds=NFS -folder=${VMWARE_FOLDER} ${VM_NAME}
govc vm.power -off -force ${VM_NAME}
govc vm.change -vm ${VM_NAME} -cpu-hot-add-enabled -memory-hot-add-enabled
govc vm.change -vm ${VM_NAME} -c=8 -m=10240
govc vm.change -vm "${VM_NAME}" -e cpuid.coresPerSocket=8
govc vm.change -vm "${VM_NAME}" -e "guestinfo.ignition.config.data=${CONFIG_B64}"
govc vm.change -vm "${VM_NAME}" -e "guestinfo.ignition.config.data.encoding=base64"
govc vm.change -vm="${VM_NAME}" -e="disk.enableUUID=1"
govc vm.network.change --vm "${VM_NAME}" -net.address 00:50:56:b6:b7:7c  -net="VM Network" ethernet-0

VM_NAME=${CLUSTER_ID}-master-2
log "Creating ${VM_NAME} vm"
CONFIG_B64=$(cat master.64)
govc vm.clone -vm=$TEMPLATE -ds=NFS -folder=${VMWARE_FOLDER} ${VM_NAME}
govc vm.power -off -force ${VM_NAME}
govc vm.change -vm ${VM_NAME} -cpu-hot-add-enabled -memory-hot-add-enabled
govc vm.change -vm ${VM_NAME} -c=8 -m=10240
govc vm.change -vm "${VM_NAME}" -e cpuid.coresPerSocket=8
govc vm.change -vm "${VM_NAME}" -e "guestinfo.ignition.config.data=${CONFIG_B64}"
govc vm.change -vm "${VM_NAME}" -e "guestinfo.ignition.config.data.encoding=base64"
govc vm.change -vm="${VM_NAME}" -e="disk.enableUUID=1"
govc vm.network.change --vm "${VM_NAME}" -net.address 00:50:56:b6:89:db  -net="VM Network" ethernet-0

# VM_NAME=${CLUSTER_ID}-worker-1
# log "Creating ${VM_NAME} vm"
# CONFIG_B64=$(cat worker.64)
# govc vm.clone -vm=$TEMPLATE -ds=NFS -folder=${VMWARE_FOLDER} ${VM_NAME}
# govc vm.power -off -force ${VM_NAME}
# govc vm.change -vm ${VM_NAME} -cpu-hot-add-enabled -memory-hot-add-enabled
# govc vm.change -vm ${VM_NAME} -c=4 -m=8192
# govc vm.change -vm "${VM_NAME}" -e cpuid.coresPerSocket=4
# govc vm.change -vm "${VM_NAME}" -e "guestinfo.ignition.config.data=${CONFIG_B64}"
# govc vm.change -vm "${VM_NAME}" -e "guestinfo.ignition.config.data.encoding=base64"
# govc vm.change -vm="${VM_NAME}" -e="disk.enableUUID=1"
# govc vm.network.change --vm "${VM_NAME}" -net.address 00:50:56:b6:c2:ed  -net="VM Network" ethernet-0
#
# VM_NAME=${CLUSTER_ID}-worker-2
# log "Creating ${VM_NAME} vm"
# CONFIG_B64=$(cat worker.64)
# govc vm.clone -vm=$TEMPLATE -ds=NFS -folder=${VMWARE_FOLDER} ${VM_NAME}
# govc vm.power -off -force ${VM_NAME}
# govc vm.change -vm ${VM_NAME} -cpu-hot-add-enabled -memory-hot-add-enabled
# govc vm.change -vm ${VM_NAME} -c=4 -m=8192
# govc vm.change -vm "${VM_NAME}" -e cpuid.coresPerSocket=4
# govc vm.change -vm "${VM_NAME}" -e "guestinfo.ignition.config.data=${CONFIG_B64}"
# govc vm.change -vm "${VM_NAME}" -e "guestinfo.ignition.config.data.encoding=base64"
# govc vm.change -vm="${VM_NAME}" -e="disk.enableUUID=1"
# govc vm.network.change --vm "${VM_NAME}" -net.address 00:50:56:b6:51:e1  -net="VM Network" ethernet-0
