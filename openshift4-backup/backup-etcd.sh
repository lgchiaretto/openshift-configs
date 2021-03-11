#!/bin/bash

set -euo pipefail

usage(){
  echo "Backup etcd data (snapshot) and config (/etc/etcd). Creates a tar.gz and save it into a NFS server"
  echo ""
  echo "Usage:"
  echo "  $0"
  exit 1
}

if [[ $# -gt 0 ]]
then
  usage
fi

# Vars
RETENTION_DAYS=3
TS=$(date +"%Y%m%d-%H%M%S")
ETCD_DATA_BCK_DIR="etcd_data_bck.${TS}"
FINAL_BCK_FILE="etcd_bkp.${TS}.tar.gz"
NFS_SERVER="nfs.chiaret.to"
NFS_DIR="/nfs/"
NFS_MOUNT_DIR=$(mktemp -d -t backup-XXXXXXXXXX)
ETCD_FINAL_BCK_DIR="${NFS_SERVER}:${NFS_DIR}"
OC=$(which oc)

log(){
  /usr/bin/date "+%F %T: ${@}" >> /var/log/backup-master.log
}

die(){
  log "$1"
  exit "$2"
}

backup_data() {
  log "Backing up ETCD data, validating snapshot."
  for ETCD in $(oc get pod -n openshift-etcd --no-headers|grep -v $(hostname) | grep -o  '\S*etcd\S*' );
  do
    log "Generating backup on $ETCD"
    ETCD_MEMBER_DNS_NAME=$(oc exec ${ETCD}  -n openshift-etcd  cat /run/etcd/environment |grep ETCD_DNS|cut -d'=' -f2)
  
    ${OC} exec ${ETCD}  -n openshift-etcd  -- /bin/sh -c "ETCDCTL_API=3 etcdctl --cert /etc/ssl/etcd/system:etcd-peer:${ETCD_MEMBER_DNS_NAME}.crt --key /etc/ssl/etcd/system:etcd-peer:${ETCD_MEMBER_DNS_NAME}.key --cacert /etc/ssl/etcd/ca.crt  snapshot save /var/lib/etcd/snapshot-${ETCD_MEMBER_DNS_NAME}.db"
    /usr/bin/mkdir -p /tmp/${ETCD_DATA_BCK_DIR}/${ETCD}
    ${OC} rsync -n openshift-etcd ${ETCD}:/var/lib/etcd/snapshot-${ETCD_MEMBER_DNS_NAME}.db /tmp/${ETCD_DATA_BCK_DIR}/${ETCD}
  done
}

mount_nfs(){
  log "Creating tmp dir to mount NFS"
  log "$NFS_MOUNT_DIR has been created" 
  log "Mounting NFS server on $NFS_MOUNT_DIR"
  /usr/bin/mount -t nfs $NFS_SERVER:$NFS_DIR $NFS_MOUNT_DIR
# TODO: Fix this check 
#  [ "$?" -ne 0 ] \
#    && die "Error when mounting NFS server" 1
}

umount_nfs(){
  log "Umounting NFS server on $NFS_MOUNT_DIR"
  /usr/bin/umount $NFS_MOUNT_DIR
  [ "$?" -ne 0 ] \
    && die "Error when umounting NFS server" 1
  log "Removing $NFS_MOUNT_DIR"
  /usr/bin/rmdir $NFS_MOUNT_DIR
}

backup(){
  log "Creating ETCD backup dir"
  /usr/bin/mkdir -p /tmp/${ETCD_DATA_BCK_DIR}/

  backup_data

  log "Creating final tar.gz file"
  tar cfz "${NFS_MOUNT_DIR}/${FINAL_BCK_FILE}" --directory /tmp "${ETCD_DATA_BCK_DIR}"

  log "Check your backup file on: ${ETCD_FINAL_BCK_DIR}/${FINAL_BCK_FILE}"

  log "Deleting temporary files"
  /usr/bin/rm -rf "/tmp/${ETCD_DATA_BCK_DIR}"
}

# Keep the last #RETENTION_DAYS backup files
purge_old_backups(){
  log "Deleting old backup files...Keeping the last ${RETENTION_DAYS} days"
  /usr/bin/find "${NFS_MOUNT_DIR}"/etcd_bkp* -type f -mtime +"${RETENTION_DAYS}"
  /usr/bin/find "${NFS_MOUNT_DIR}"/etcd_bkp* -type f -mtime +"${RETENTION_DAYS}" -delete
}

mount_nfs
backup
purge_old_backups
umount_nfs

exit 0

