# Openshift 4 Backup Automation

This tool was built to automate the steps to create an Openshift backup described on https://access.redhat.com/documentation/en-us/openshift_container_platform/4.7/html-single/backup_and_restore/index

Cronjob **openshift-backup** resource  will be created to run at 11:56 PM and you can change it to run when you want

### Prerequesites

Create a new project called openshift-etcd-backup

`oc new-project openshift-etcd-backup --description "Openshift Backup Automation Tool"` 

### Apply yaml to create Openshift resources

`oc apply -f openshift4-backup.yaml`

### Privileged permissions

Grant access to the **privileged** scc to the service account **openshift-backup** running the Cronjob deploy through CLI.

`oc adm policy add-scc-to-user privileged -z openshift-backup`

