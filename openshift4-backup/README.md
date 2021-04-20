# Openshift 4 Backup Automation

### Prerequesites

Create a new project called openshift-etcd-backup

`oc new-project openshift-etcd-backup --description "Openshift Backup Automation Tool"` 

### Apply yaml to create Openshift resources

`oc apply -f openshift4-backup.yaml`

### Privileged permissions

Grant access to the privileged scc to the service account running 3bddaba8bca12801978149e39877ca5fdb7bc

`oc adm policy add-scc-to-user privileged -z openshift-backup`

