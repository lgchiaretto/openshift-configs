#!/bin/bash

set -e

OPENSHIFT_VERSION=4.7
OPENSHIFT_RELEASE=4.7.12
VMWARE_FOLDER=OCP4VMWUPI
CLUSTER_NAME=ocp4vmw
CLUSTER_FOLDER=/vms/clusters/${CLUSTER_NAME}
PULL_SECRET='{"auths":{"cloud.openshift.com":{"auth":"b3BlbnNoaWZ0LXJlbGVhc2UtZGV2K3JobnN1cHBvcnRsY2hpYXJldDF5OGVkdWdwZ3ByanI1dW16N3NkZXQ1MnR3dDpKNFBWS1FPUzdMQTFNSzBPV1ZUUzg5UVNVMElZQVdNRDRMT01UUUFWN1FMUjk4Q0VEVzlJVDQySjc3M09KSEMz","email":"chiaretto@redhat.com"},"quay.io":{"auth":"b3BlbnNoaWZ0LXJlbGVhc2UtZGV2K3JobnN1cHBvcnRsY2hpYXJldDF5OGVkdWdwZ3ByanI1dW16N3NkZXQ1MnR3dDpKNFBWS1FPUzdMQTFNSzBPV1ZUUzg5UVNVMElZQVdNRDRMT01UUUFWN1FMUjk4Q0VEVzlJVDQySjc3M09KSEMz","email":"chiaretto@redhat.com"},"registry.connect.redhat.com":{"auth":"NTMxOTA1MzB8dWhjLTFZOEVEVWdwZ1BSalI1dW16N1NEZXQ1MnR3VDpleUpoYkdjaU9pSlNVelV4TWlKOS5leUp6ZFdJaU9pSTFZek0wT0RRd1pHWXhNV0kwTUdRek9EWm1Oalk1Tm1SbVpqRTJNVGt3WVNKOS51TUFqZjFXZ3VjT1g1MkNycmtuMUk1bVFhOWo4dG9VZFQ1R040TmFoMEhxbi1OQjhGNENHWEFvWVdlaW8tUHo3NXViemdTTDEzQ2ZxQ2RhYXk0MXBMVkt5NUtlbEdhM0dhU090MjNaMkhmbl9jaDJ3RnBKbUMtVFROc2s3UzRNb1RtWnRicFItWm02a2tjd0VYSDI4anpGcHNwLUVJQzdvQzBsUkZlckVfY1V6T2dvbTdBNmdYRFdDRUJMTzNueUY2Q0tiUzhabklsUHhYcnM5VW5oSG9QZTFRbjZPVlJDc3NYS2hLYlA4Nmp6cTBOeXg3bGdycThYXzlBczJISVBuTWRJTWgwa3hidFFWWjIxa3h1dzlHWXZkTUNsZ0ZKUDE1SzktdkoybUZrdUN4c2g1YjVZdkZXUzFVRjlQSzBBUHFTYmpCNjgzd2JwWjVXNVBnZ2dRNFJpNzdGVWNhbEJHLXd3WWU4dFZ6endVaHpaYlZjWldnWGhRTXJQMHBmSGh5V0hkYk5raldQbUVrVFAydW1pYVNDbGZpd0RKNFJmUENrNWZLd2RlUHpRSW03V0piLU5meEpmOWdQeks1WUFHTWJxcHowaklkRFM4YnV4d0dReUJSTnpEZF8waFFwaXhaZGFuZnlUbWsxOVdQRkY3RUtRb0psY0R6QzdmbkM4Szh2UDlMQlo1VlFpZ0ItU2dxbks0R1FaQWswa3dFTzRyQkUwVjZ6clNxdGtxNHUxRjNON2c0NTQxeWpfek0yeTlCUkFoMDV0ZzRnV2kxMS1DR1gwMkxjeVkwOEh5QWtKWFprd1J2TEd1S1gwLWZnSmtqUjV6ejgxR29XS1NFTVd2aDJMcEJTSjdjLUY2T0lQMUhud0NRRmdpZ2kzMVNOQ0ZmSmJWaVJqUnVHSQ==","email":"chiaretto@redhat.com"},"registry.redhat.io":{"auth":"NTMxOTA1MzB8dWhjLTFZOEVEVWdwZ1BSalI1dW16N1NEZXQ1MnR3VDpleUpoYkdjaU9pSlNVelV4TWlKOS5leUp6ZFdJaU9pSTFZek0wT0RRd1pHWXhNV0kwTUdRek9EWm1Oalk1Tm1SbVpqRTJNVGt3WVNKOS51TUFqZjFXZ3VjT1g1MkNycmtuMUk1bVFhOWo4dG9VZFQ1R040TmFoMEhxbi1OQjhGNENHWEFvWVdlaW8tUHo3NXViemdTTDEzQ2ZxQ2RhYXk0MXBMVkt5NUtlbEdhM0dhU090MjNaMkhmbl9jaDJ3RnBKbUMtVFROc2s3UzRNb1RtWnRicFItWm02a2tjd0VYSDI4anpGcHNwLUVJQzdvQzBsUkZlckVfY1V6T2dvbTdBNmdYRFdDRUJMTzNueUY2Q0tiUzhabklsUHhYcnM5VW5oSG9QZTFRbjZPVlJDc3NYS2hLYlA4Nmp6cTBOeXg3bGdycThYXzlBczJISVBuTWRJTWgwa3hidFFWWjIxa3h1dzlHWXZkTUNsZ0ZKUDE1SzktdkoybUZrdUN4c2g1YjVZdkZXUzFVRjlQSzBBUHFTYmpCNjgzd2JwWjVXNVBnZ2dRNFJpNzdGVWNhbEJHLXd3WWU4dFZ6endVaHpaYlZjWldnWGhRTXJQMHBmSGh5V0hkYk5raldQbUVrVFAydW1pYVNDbGZpd0RKNFJmUENrNWZLd2RlUHpRSW03V0piLU5meEpmOWdQeks1WUFHTWJxcHowaklkRFM4YnV4d0dReUJSTnpEZF8waFFwaXhaZGFuZnlUbWsxOVdQRkY3RUtRb0psY0R6QzdmbkM4Szh2UDlMQlo1VlFpZ0ItU2dxbks0R1FaQWswa3dFTzRyQkUwVjZ6clNxdGtxNHUxRjNON2c0NTQxeWpfek0yeTlCUkFoMDV0ZzRnV2kxMS1DR1gwMkxjeVkwOEh5QWtKWFprd1J2TEd1S1gwLWZnSmtqUjV6ejgxR29XS1NFTVd2aDJMcEJTSjdjLUY2T0lQMUhud0NRRmdpZ2kzMVNOQ0ZmSmJWaVJqUnVHSQ==","email":"chiaretto@redhat.com"}}}'
VMWARE_PASSWORD="'*MNl@<MTD9Fhui:0Iv[%'"
SSHKEY='ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDdrq8QOVo8CzPrgKPC4MXN+Vn6dWdZksAWQVUrC6jvcjuFKQgb8EiMAxS0djFJKbk14SL6BRuUwBopjkumxD6kS38VDvGNlEIcWG2sQKnAzEtGdzG4N72qu6ObNK+ralg8Gu5uZPhziyKFXpwg9kOBl1qxOiycR4acyaDt4SxSAD7BWJPEbiYUeCrcZQ+BMrVUwLPpLYBa+h0/uJmK4+U632MfYUMiudNXLcs3e3f/yi5GMli6BcGgl7wlEbgnUZQzrW0D04jNWk0/JGU506c166b6Dy6bigefUlLvjJ4I/8vZns3ZRj3YV6oPaZMY9BZ9FrB0jE+7XgVXlMY7lyXX'

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
    defaultDatastore: HOMEDS
    network: VM Network
    password: ${VMWARE_PASSWORD}
    username: ocp4@chiaretto.local
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
govc import.ova --folder=templates --ds=HOMEDS --name=${CLUSTER_ID}-rhcos https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/${OPENSHIFT_VERSION}/latest/rhcos-vmware.x86_64.ova || err "Error when importing OVA"

VM_NAME=bootstrap
log "Creating ${VM_NAME} vm"
govc vm.clone -vm=$TEMPLATE -ds=HOMEDS -folder=${VMWARE_FOLDER} ${VM_NAME}
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
govc vm.clone -vm=$TEMPLATE -ds=HOMEDS -folder=${VMWARE_FOLDER} ${VM_NAME}
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
govc vm.clone -vm=$TEMPLATE -ds=HOMEDS -folder=${VMWARE_FOLDER} ${VM_NAME}
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
govc vm.clone -vm=$TEMPLATE -ds=HOMEDS -folder=${VMWARE_FOLDER} ${VM_NAME}
govc vm.power -off -force ${VM_NAME}
govc vm.change -vm ${VM_NAME} -cpu-hot-add-enabled -memory-hot-add-enabled
govc vm.change -vm ${VM_NAME} -c=8 -m=10240
govc vm.change -vm "${VM_NAME}" -e cpuid.coresPerSocket=8
govc vm.change -vm "${VM_NAME}" -e "guestinfo.ignition.config.data=${CONFIG_B64}"
govc vm.change -vm "${VM_NAME}" -e "guestinfo.ignition.config.data.encoding=base64"
govc vm.change -vm="${VM_NAME}" -e="disk.enableUUID=1"
govc vm.network.change --vm "${VM_NAME}" -net.address 00:50:56:b6:89:db  -net="VM Network" ethernet-0

VM_NAME=${CLUSTER_ID}-master-3
log "Creating ${VM_NAME} vm"
CONFIG_B64=$(cat master.64)
govc vm.clone -vm=$TEMPLATE -ds=HOMEDS -folder=${VMWARE_FOLDER} ${VM_NAME}
govc vm.power -off -force ${VM_NAME}
govc vm.change -vm ${VM_NAME} -cpu-hot-add-enabled -memory-hot-add-enabled
govc vm.change -vm ${VM_NAME} -c=8 -m=10240
govc vm.change -vm "${VM_NAME}" -e cpuid.coresPerSocket=8
govc vm.change -vm "${VM_NAME}" -e "guestinfo.ignition.config.data=${CONFIG_B64}"
govc vm.change -vm "${VM_NAME}" -e "guestinfo.ignition.config.data.encoding=base64"
govc vm.change -vm="${VM_NAME}" -e="disk.enableUUID=1"
govc vm.network.change --vm "${VM_NAME}" -net.address 00:50:56:b6:51:e2  -net="VM Network" ethernet-0

VM_NAME=${CLUSTER_ID}-worker-1
log "Creating ${VM_NAME} vm"
CONFIG_B64=$(cat worker.64)
govc vm.clone -vm=$TEMPLATE -ds=HOMEDS -folder=${VMWARE_FOLDER} ${VM_NAME}
govc vm.power -off -force ${VM_NAME}
govc vm.change -vm ${VM_NAME} -cpu-hot-add-enabled -memory-hot-add-enabled
govc vm.change -vm ${VM_NAME} -c=4 -m=8192
govc vm.change -vm "${VM_NAME}" -e cpuid.coresPerSocket=4
govc vm.change -vm "${VM_NAME}" -e "guestinfo.ignition.config.data=${CONFIG_B64}"
govc vm.change -vm "${VM_NAME}" -e "guestinfo.ignition.config.data.encoding=base64"
govc vm.change -vm="${VM_NAME}" -e="disk.enableUUID=1"
govc vm.network.change --vm "${VM_NAME}" -net.address 00:50:56:b6:c2:ed  -net="VM Network" ethernet-0

VM_NAME=${CLUSTER_ID}-worker-2
log "Creating ${VM_NAME} vm"
CONFIG_B64=$(cat worker.64)
govc vm.clone -vm=$TEMPLATE -ds=HOMEDS -folder=${VMWARE_FOLDER} ${VM_NAME}
govc vm.power -off -force ${VM_NAME}
govc vm.change -vm ${VM_NAME} -cpu-hot-add-enabled -memory-hot-add-enabled
govc vm.change -vm ${VM_NAME} -c=4 -m=8192
govc vm.change -vm "${VM_NAME}" -e cpuid.coresPerSocket=4
govc vm.change -vm "${VM_NAME}" -e "guestinfo.ignition.config.data=${CONFIG_B64}"
govc vm.change -vm "${VM_NAME}" -e "guestinfo.ignition.config.data.encoding=base64"
govc vm.change -vm="${VM_NAME}" -e="disk.enableUUID=1"
govc vm.network.change --vm "${VM_NAME}" -net.address 00:50:56:b6:51:e1  -net="VM Network" ethernet-0
