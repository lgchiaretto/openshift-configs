
#!/bin/bash

# Variables Editable
OCP_VERSION=4.11.5                                                                                                                                                                                                                                                                    
CLUSTER_NAME=srvtest
OCP_INSTALL_DIR=/vms/clusters/${CLUSTER_NAME}
NODEINTERFACE=enp1s0f3
NODEDISK="/dev/sda"
NODEIP=192.168.0.197
NODEGW=192.168.0.1
NODEMASK=255.255.255.0
NODEDNS=8.8.8.8
ARCH=x86_64
CREATEDNS="true"


# Variables (do not edit)
CURL_CMD=$(which curl)
TAR_CMD=$(which tar)
ECHO_CMD=$(which echo)
AWS_CMD=$(which aws)
COREOS_INSTALLER="podman run --privileged --pull always --rm -v /dev:/dev -v /run/udev:/run/udev -v ${OCP_INSTALL_DIR}:/data -w /data quay.io/coreos/coreos-installer:release"

# Functions
err() {
    $ECHO_CMD; $ECHO_CMD;
    $ECHO_CMD -e "\e[97m\e[101m[ERROR]\e[0m ${1}"; shift; $ECHO_CMD;
    while [[ $# -gt 0 ]]; do $ECHO_CMD "    $1"; shift; done
    $ECHO_CMD; exit 1;
}

log(){
    $ECHO_CMD "[$(date +'%d:%m:%y %H:%M:%S')] - " $1
}

# Begin

log "Creating route53.json file"
cat <<EOF > route53.json
{
"Comment": "CREATE/DELETE/UPSERT a record ",
"Changes": [ {
   "Action": "UPSERT",
   "ResourceRecordSet": {
      "Name": "api.${CLUSTER_NAME}.chiaret.to",
      "Type": "A",
      "TTL": 0,
      "ResourceRecords": [{"Value": "${NODEIP}"}]
    }},
    {
    "Action": "UPSERT",
    "ResourceRecordSet": {
      "Name": "api-int.${CLUSTER_NAME}.chiaret.to",
      "Type": "A",
      "TTL": 0,
      "ResourceRecords": [{"Value": "${NODEIP}"}]
    }},
    {
    "Action": "UPSERT",
    "ResourceRecordSet": {
      "Name": "*.apps.${CLUSTER_NAME}.chiaret.to",
      "Type": "A",
      "TTL": 0,
      "ResourceRecords": [{"Value": "${NODEIP}"}]                                                                                                                                                                                                                                     
    }},
    {
    "Action": "UPSERT",
    "ResourceRecordSet": {
      "Name": "node.${CLUSTER_NAME}.chiaret.to",
      "Type": "A",
      "TTL": 0,
      "ResourceRecords": [{"Value": "${NODEIP}"}]                                                                                                                                                                                                                                     
    }}    
]
}
EOF

log "Creating DNS to api.${CLUSTER_NAME}.chiaret.to, api-int.${CLUSTER_NAME}.chiaret.to, *.apps.${CLUSTER_NAME}.chiaret.to and node.${CLUSTER_NAME}.chiaret.to"
${AWS_CMD} route53 change-resource-record-sets --hosted-zone-id XXXXXXXXXXXXX --change-batch file://route53.json || err "Error Downloading openshift-install-linux.tar.gz"

log "Creating dir ${OCP_INSTALL_DIR}"
mkdir ${OCP_INSTALL_DIR} || err "Directory ${OCP_INSTALL_DIR} exists, remove it!"
cd ${OCP_INSTALL_DIR}

log "Downloading openshift-install-linux.tar.gz"
$CURL_CMD -s -k https://mirror.openshift.com/pub/openshift-v4/clients/ocp/${OCP_VERSION}/openshift-install-linux.tar.gz > ${OCP_INSTALL_DIR}/openshift-install-linux.tar.gz || err "Error Downloading openshift-install-linux.tar.gz"
log "Unpackaging openshift-install-linux.tar.gz"
$TAR_CMD -xzf openshift-install-linux.tar.gz

log "Getting rhcos-live.iso file"
ISO_URL=$(./openshift-install coreos print-stream-json | grep location | grep $ARCH | grep iso | cut -d\" -f4)
alias coreos-installer='podman run --privileged --pull always --rm -v /dev:/dev -v /run/udev:/run/udev -v $PWD:/data -w /data quay.io/coreos/coreos-installer:release'
$CURL_CMD -s -L $ISO_URL -o rhcos-live.iso  || err "Error Getting rhcos-live.iso file" || err "Error Getting rhcos-live.iso file"

log "Creating install-config.yaml file"
cat <<EOF > install-config.yaml
apiVersion: v1
baseDomain: chiaret.to 
compute:
- name: worker
  replicas: 0 
controlPlane:
  name: master
  replicas: 1 
metadata:
  name: ${CLUSTER_NAME}
networking: 
  clusterNetwork:
  - cidr: 10.128.0.0/14
    hostPrefix: 23
  machineNetwork:
  - cidr: 10.0.0.0/16 
  networkType: OVNKubernetes
  serviceNetwork:
  - 172.30.0.0/16
platform:
  none: {}
bootstrapInPlace:
  installationDisk: ${NODEDISK}
pullSecret: '<pull secret>'
sshKey: |
  <sshrsapub...>
imageContentSources:
- mirrors:
  - quay.chiaret.to:8443/ocp4/${OCP_VERSION}
  source: quay.io/openshift-release-dev/ocp-release
- mirrors:
  - quay.chiaret.to:8443/ocp4/${OCP_VERSION}
  source: quay.io/openshift-release-dev/ocp-v4.0-art-dev
EOF

log "Generating backup of install-config.yaml"
cp install-config.yaml backup-install-config.yaml || err "Error Generating backup of install-config.yaml"

log "Generating single-node ignition files"
./openshift-install create single-node-ignition-config || err "Error Generating single-node ignition files"

log "Append static IPs kargs"
${COREOS_INSTALLER} iso kargs modify --append "rd.neednet=1 ip=${NODEIP}::${NODEGW}:${NODEMASK}:node.${CLUSTER_NAME}.chiaret.to:${NODEINTERFACE}:none nameserver=${NODEDNS}" rhcos-live.iso  || err "Error Append static IPs kargs"

log "Append ignition file to iso"
${COREOS_INSTALLER} iso ignition embed -fi bootstrap-in-place-for-live-iso.ign rhcos-live.iso || err "Error Append ignition file to iso"
log "Finish!"
