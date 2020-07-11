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
HOSTNAME=$(hostnamectl --static)
RETENTION_DAYS=3
TS=$(date +"%Y%m%d-%H%M%S")
MASTER_EXEC="/usr/local/bin/master-exec"
ETCD_POD_MANIFEST="/etc/origin/node/pods/etcd.yaml"
ETCD_DATA_BCK_DIR="etcd_data_bck.${TS}"
ETCD_CONFIG_DIR="/etc/etcd"
MASTER_CONFIG_DIR="/etc/origin"
ETCD_CONFIG_BCK_DIR="etcd_config_bck.${TS}"
MASTER_CONFIG_BCK_DIR="master_config_bck.${TS}"
FINAL_BCK_FILE="etcd_master_bck.${HOSTNAME}.${TS}.tar.gz"
NFS_SERVER="nfs.openshift.chiaret.to"
NFS_DIR="/nfsshare/"
NFS_MOUNT_DIR=$(mktemp -d -t backup-XXXXXXXXXX)
ETCD_FINAL_BCK_DIR="${NFS_SERVER}:${NFS_DIR}"

log(){
  /usr/bin/date "+%F %T: ${@}" >> /var/log/backup-master.log
}

die(){
  log "$1"
  exit "$2"
}

## Pre checks
# Check master-exec
[ -z "${MASTER_EXEC}" ] \
  && die "${MASTER_EXEC} not found" 1

# Check master-exec
[ -z "${ETCD_POD_MANIFEST}" ] \
  && die "${ETCD_POD_MANIFEST} not found" 1

backup_config() {
  log "Backing up ETCD config."
  /usr/bin/cp -a "${ETCD_CONFIG_DIR}" "/tmp/${ETCD_CONFIG_BCK_DIR}"
  log "Backing up master $(hostname -s) config."
  /usr/bin/cp -a "${MASTER_CONFIG_DIR}" "/tmp/${MASTER_CONFIG_BCK_DIR}"
}

backup_data() {

  log "Backing up ETCD data, performing snapshot."
  # etcd endpoint 
  ETCD_EP=$(grep https ${ETCD_POD_MANIFEST} | cut -d '/' -f3)

  # snapshot output is /var/lib/etcd/ because is mounted from the host, and we can move it later to another host folder.
  # > /usr/local/bin/master-exec etcd etcd /bin/bash -c "ETCDCTL_API=3 /usr/bin/etcdctl \
  # --cert /etc/etcd/peer.crt --key /etc/etcd/peer.key --cacert /etc/etcd/ca.crt --endpoints ${ETCD_EP} snapshot save /var/lib/etcd/snapshot.db"
  ${MASTER_EXEC} etcd etcd /bin/sh -c "ETCDCTL_API=3 etcdctl \
  --cert /etc/etcd/peer.crt --key /etc/etcd/peer.key --cacert /etc/etcd/ca.crt \
  --endpoints ${ETCD_EP} snapshot save /var/lib/etcd/snapshot.db"

  log "Backing up ETCD data, validating snapshot."
  # Validate the status of the snapshot
  # > snapshot status /var/lib/etcd/snapshot.db 
  ${MASTER_EXEC} etcd etcd /bin/sh -c "ETCDCTL_API=3 etcdctl \
  --cert /etc/etcd/peer.crt --key /etc/etcd/peer.key --cacert /etc/etcd/ca.crt \
  --endpoints ${ETCD_EP} snapshot status /var/lib/etcd/snapshot.db"

   # Check the etcd snapshot
  [ "$?" -ne 0 ] \
    && die "/var/lib/etcd/snapshot.db is not a valid etcd backup. Please check the status of your etcd cluster" 1

  # Move the snapshot to the temp bck dir.
  /usr/bin/mv /var/lib/etcd/snapshot.db /tmp/${ETCD_DATA_BCK_DIR}/snapshot.db
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

  backup_config
  backup_data

  log "Creating final tar.gz file"
  tar cfz "${NFS_MOUNT_DIR}/${FINAL_BCK_FILE}" --directory /tmp "${ETCD_CONFIG_BCK_DIR}" "${ETCD_DATA_BCK_DIR}" "${MASTER_CONFIG_BCK_DIR}"

  log "Check your backup file on: ${ETCD_FINAL_BCK_DIR}/${FINAL_BCK_FILE}"

  log "Deleting temporary files"
  /usr/bin/rm -rf "/tmp/${ETCD_CONFIG_BCK_DIR}" "/tmp/${ETCD_DATA_BCK_DIR}" "${MASTER_CONFIG_BCK_DIR}"
}

# Keep the last #RETENTION_DAYS backup files
purge_old_backups(){
  log "Deleting old backup files...Keeping the last ${RETENTION_DAYS} days"
  /usr/bin/find "${NFS_MOUNT_DIR}"/etcd_master_bck.${HOSTNAME}* -type f -mtime +"${RETENTION_DAYS}"
  /usr/bin/find "${NFS_MOUNT_DIR}"/etcd_master_bck.${HOSTNAME}* -type f -mtime +"${RETENTION_DAYS}" -delete
}

mount_nfs
backup
purge_old_backups
umount_nfs

exit 0

