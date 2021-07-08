#!/bin/bash

set -e

OPENSHIFT_VERSION=4.7
OPENSHIFT_RELEASE=4.7.16
VMWARE_FOLDER=OCP4B
CLUSTER_NAME=ocp4b
CLUSTER_FOLDER=/vms/clusters/ocp4b
PULL_SECRET=$(cat /home/lchiaret/temp/pull-secret)
VMWARE_PASSWORD="password"
HTTPUSER=chiaretto1
HTTPSERVER=chiaret.to
HTTPDIR=public_html/tam/
SSHKEY="ssh-rsa ..."
DATACENTER="CHIARETTO"
CLUSTER="HOME"

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
cat <<'EOF' >> install-config.yaml
apiVersion: v1
baseDomain: chiaret.to
compute:
- architecture: amd64
  hyperthreading: Enabled
  name: worker
  platform: {}
  replicas: 2
  platform:
    vsphere:
      memoryMB: 8192
      coresPerSocket: 2
      cpus: 4
      osDisk:
        diskSizeGB: 120
controlPlane:
  architecture: amd64
  hyperthreading: Enabled
  name: master
  platform: {}
  replicas: 3
  platform:
    vsphere:
      memoryMB: 16384
      coresPerSocket: 4
      cpus: 8
      osDisk:
        diskSizeGB: 120
metadata:
  creationTimestamp: null
  name: ocp4b
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
    defaultDatastore: SSD
    network: VM Network
    password: "password"
    username: ocp4@chiaretto.local
    vCenter: chiaretto-vcsa01.chiaret.to
    folder: "/CHIARETTO/vm/OCP4B"
publish: External
pullSecret: '... pull secret here ...'
sshKey: |
  ssh-rsa ...
EOF

exit 1

log "Creating Manifests"
./openshift-install create manifests

#log "Do not use master as worker (mastersSchedulable: false)"
#sed -i 's/mastersSchedulable: true/mastersSchedulable: false/g' manifests/cluster-scheduler-02-config.yml || err "Error when setting scheduler to false"

log "Creating Ignition files"
./openshift-install create ignition-configs

for i in bootstrap master worker;  do 
  log "Generating $i.64 file"
  base64 -w0 < $i.ign > $i.64;  
 done

log "Creating append.ign"
cat <<'EOF' >> append.ign
{
  "ignition": {
    "config": {
      "merge": [
        {
          "source": "http://tam.chiaret.to/bootstrap.ign",
          "verification": {}
        }
      ]
    },
    "timeouts": {},
    "version": "3.2.0"
  },
  "networkd": {},
  "passwd": {},
  "storage": {},
  "systemd": {}
}
EOF

log "Getting cluster ID"
CLUSTER_ID=$(jq -r .infraID metadata.json)

log "Cluster ID is ${CLUSTER_ID}"

TEMPLATE=${CLUSTER_ID}-rhcos

log "Creating folder ${VMWARE_FOLDER}"
govc folder.create "/${DATACENTER}/vm/${VMWARE_FOLDER}"

# Import OVA
log "Importing ova"
govc import.ova --ds=SSD --pool=/${DATACENTER}/host/${CLUSTER}/Resources --name=${CLUSTER_ID}-rhcos https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/${OPENSHIFT_VERSION}/latest/rhcos-vmware.x86_64.ova || err "Error when importing OVA"
#read -p "Download file: https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/${OPENSHIFT_VERSION}/latest/rhcos-vmware.x86_64.ova \n Import on vmware as: ${CLUSTER_ID}-rhcos\n and type y" -n 1 -r

log "Generating base64 from append.ign"
APPEND64=$(base64 -w0 append.ign)

log "Sending file to webserver"
scp bootstrap.ign ${HTTPUSER}@${HTTPSERVER}:${HTTPDIR}

log "Changing disk of template to 120GB"
govc vm.disk.change -vm "$TEMPLATE" -size 120G

VM_NAME=bootstrap
log "Creating ${VM_NAME} vm"
IPCFG="ip=192.168.0.189::192.168.1.1:255.255.255.0:bootstrap:ens192:none nameserver=8.8.8.8"
govc vm.clone -vm=$TEMPLATE -ds=SSD -folder=${VMWARE_FOLDER} -pool=/${DATACENTER}/host/${CLUSTER}/Resources ${VM_NAME}
govc vm.power -off -force ${VM_NAME}
govc vm.change -vm ${VM_NAME} -cpu-hot-add-enabled -memory-hot-add-enabled
govc vm.change -vm ${VM_NAME} -c=8 -m=8192
govc vm.change -vm "${VM_NAME}" -e cpuid.coresPerSocket=4
govc vm.change -vm "${VM_NAME}" -e "guestinfo.ignition.config.data=$APPEND64"
govc vm.change -vm "${VM_NAME}" -e "guestinfo.ignition.config.data.encoding=base64"
govc vm.change -vm="${VM_NAME}" -e="disk.enableUUID=1"
govc vm.change -vm="${VM_NAME}" -e "guestinfo.afterburn.initrd.network-kargs=${IPCFG}"
govc vm.network.change --vm "${VM_NAME}" -net.address 00:50:56:00:01:89  -net="VM Network" ethernet-0
govc vm.power -on ${VM_NAME}

VM_NAME=${CLUSTER_ID}-master-0
log "Creating ${VM_NAME} vm"
CONFIG_B64=$(cat master.64)
IPCFG="ip=192.168.0.190::192.168.1.1:255.255.255.0:${CLUSTER_ID}-master-0:ens192:none nameserver=8.8.8.8"
govc vm.clone -vm=$TEMPLATE -ds=SSD -folder=${VMWARE_FOLDER} -pool=/${DATACENTER}/host/${CLUSTER}/Resources ${VM_NAME}
govc vm.power -off -force ${VM_NAME}
govc vm.change -vm ${VM_NAME} -cpu-hot-add-enabled -memory-hot-add-enabled
govc vm.change -vm ${VM_NAME} -c=8 -m=16384
govc vm.change -vm "${VM_NAME}" -e cpuid.coresPerSocket=4
govc vm.change -vm "${VM_NAME}" -e "guestinfo.ignition.config.data=${CONFIG_B64}"
govc vm.change -vm "${VM_NAME}" -e "guestinfo.ignition.config.data.encoding=base64"
govc vm.change -vm="${VM_NAME}" -e="disk.enableUUID=1"
govc vm.change -vm="${VM_NAME}" -e "guestinfo.afterburn.initrd.network-kargs=${IPCFG}"
govc vm.network.change --vm "${VM_NAME}" -net.address 00:50:56:00:01:90  -net="VM Network" ethernet-0
govc vm.power -on ${VM_NAME}

VM_NAME=${CLUSTER_ID}-master-1
log "Creating ${VM_NAME} vm"
CONFIG_B64=$(cat master.64)
IPCFG="ip=192.168.0.191::192.168.1.1:255.255.255.0:${CLUSTER_ID}-master-1:ens192:none nameserver=8.8.8.8"
govc vm.clone -vm=$TEMPLATE -ds=SSD -folder=${VMWARE_FOLDER} -pool=/${DATACENTER}/host/${CLUSTER}/Resources ${VM_NAME}
govc vm.power -off -force ${VM_NAME}
govc vm.change -vm ${VM_NAME} -cpu-hot-add-enabled -memory-hot-add-enabled
govc vm.change -vm ${VM_NAME} -c=8 -m=16384
govc vm.change -vm "${VM_NAME}" -e cpuid.coresPerSocket=4
govc vm.change -vm "${VM_NAME}" -e "guestinfo.ignition.config.data=${CONFIG_B64}"
govc vm.change -vm "${VM_NAME}" -e "guestinfo.ignition.config.data.encoding=base64"
govc vm.change -vm="${VM_NAME}" -e="disk.enableUUID=1"
govc vm.change -vm="${VM_NAME}" -e "guestinfo.afterburn.initrd.network-kargs=${IPCFG}"
govc vm.network.change --vm "${VM_NAME}" -net.address 00:50:56:00:01:91  -net="VM Network" ethernet-0
govc vm.power -on ${VM_NAME}

VM_NAME=${CLUSTER_ID}-master-2
log "Creating ${VM_NAME} vm"
CONFIG_B64=$(cat master.64)
IPCFG="ip=192.168.0.192::192.168.1.1:255.255.255.0:${CLUSTER_ID}-master-2:ens192:none nameserver=8.8.8.8"
govc vm.clone -vm=$TEMPLATE -ds=SSD -folder=${VMWARE_FOLDER} -pool=/${DATACENTER}/host/${CLUSTER}/Resources ${VM_NAME}
govc vm.power -off -force ${VM_NAME}
govc vm.change -vm ${VM_NAME} -cpu-hot-add-enabled -memory-hot-add-enabled
govc vm.change -vm ${VM_NAME} -c=8 -m=16384
govc vm.change -vm "${VM_NAME}" -e cpuid.coresPerSocket=4
govc vm.change -vm "${VM_NAME}" -e "guestinfo.ignition.config.data=${CONFIG_B64}"
govc vm.change -vm "${VM_NAME}" -e "guestinfo.ignition.config.data.encoding=base64"
govc vm.change -vm="${VM_NAME}" -e="disk.enableUUID=1"
govc vm.change -vm="${VM_NAME}" -e "guestinfo.afterburn.initrd.network-kargs=${IPCFG}"
govc vm.network.change --vm "${VM_NAME}" -net.address 00:50:56:00:01:92  -net="VM Network" ethernet-0
govc vm.power -on ${VM_NAME}
