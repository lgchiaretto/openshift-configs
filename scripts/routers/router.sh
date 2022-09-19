#!/bin/bash

now=$(date +'%d%m%y_%H%M%S')
logfile="router.sh-$now"

err() {
    echo; echo;
    echo -e "\e[97m\e[101m[ERROR]\e[0m ${1}"; shift; echo;
    while [[ $# -gt 0 ]]; do echo "    $1"; shift; done
    echo; exit 1;
}

log(){
    echo "[$(date +'%d:%m:%y %H:%M:%S')] -" $1
    echo "[$(date +'%d:%m:%y %H:%M:%S')] -" $1 >> $logfile
}

log "Deleting customrouter-csf configmap"
oc delete configmap customrouter-csf --ignore-not-found=true -n default
log "Deleting rsyslog-config configmap"
oc delete configmap rsyslog-config --ignore-not-found=true -n default
log "Creating customrouter-csf configmap"
oc create configmap customrouter-csf --from-file=haproxy-config.template -n default || err "Error creating customrouter-csf configmap"

#create ConfigMap for rsyslog  local container
log "Creating rsyslog-config configmap"
cat <<'EOF' | oc create -f -
apiVersion: v1
data:
  rsyslog.conf: |
    $ModLoad imuxsock
    $SystemLogSocketName /var/lib/rsyslog/rsyslog.sock
    $ModLoad omstdout.so
    *.* :omstdout:
kind: ConfigMap
metadata:
  name: rsyslog-config
EOF

for router in router router-matera; do
  if [[ "$router" == "router" ]]; then
    replicas=$(oc get nodes --no-headers -l router=default | wc -l)
    log "Adding nodeSelector on dc/$router to $router: default"
    log "Changing triggers to manual on dc/$router"
    oc set triggers dc/$router --manual -n default|| err "Error changing triggers to manual on dc/$router"
    log "Deleting customrouter-csf configmap"
    oc patch dc/$router -p '{"spec":{"template":{"spec":{"nodeSelector":{"router": "default"}}}}}' || err "Error adding nodeSelector on dc/$router to $router: true"
  else
    replicas=$(oc get nodes --no-headers -l router=matera | wc -l)
    log "Adding nodeSelector on dc/$router to $router: matera"
    log "Changing triggers to manual on dc/$router"
    oc set triggers dc/$router --manual -n default|| err "Error changing triggers to manual on dc/$router"
    log "Deleting customrouter-csf configmap"
    oc patch dc/$router -p '{"spec":{"template":{"spec":{"nodeSelector":{"router": "matera"}}}}}' || err "Error adding nodeSelector on dc/$router to $router: true"
  fi

  log "Setting volume to customrouter-csf configmap on router $router"
  oc set volume dc/$router --add --overwrite --name=config-volume --mount-path=/var/lib/haproxy/conf/custom --source='{"configMap": { "name": "customrouter-csf"}}' -n default || err "Error setting volume to customrouter-csf configmap"
  log "Setting TEMPLATE_FILE variable on router $router"
  oc set env dc/$router TEMPLATE_FILE=/var/lib/haproxy/conf/custom/haproxy-config.template -n default || err "Error setting TEMPLATE_FILE variable"
  log "Removing ROUTER_METRICS_TYPE variable on router $router"
  oc set env dc $router ROUTER_METRICS_TYPE- -n default || err "Error removing ROUTER_METRICS_TYPE variable"
  log "Changing number of threds to 4 on router $router"
  oc set env dc/$router ROUTER_THREADS=4 -n default || err "Error changing number of threads to 4"
  log "Changing readinessProbe on router $router"
  oc patch dc $router -p '"spec": {"template": {"spec": {"containers": [{"name": "router","readinessProbe": {"httpGet": {"path": "/healthz"}}}]}}}' -n default || err "Error changing readinessProbe"
  log "Changing numer of replicas to $replicas on router $router"
  oc scale dc/$router --replicas=$replicas -n default || err "Error changing numer of replicas to $replicas on router $router" | tee $logfile

  # Make sure to get a backup of dc/$router
  log "Backup of dc/$router"
  oc get dc/$router -o yaml > dc-$router-bkp.yaml || err "Error to create dc/$router backup"

  # Patch $router DeploymentConfig and enable rsyslog sidecar container
  log "Adding the syslog sidecar on $router"
  oc patch dc/$router -p "spec:
  template:
    spec:
      containers:
      - name: router
        env:
        - name: ROUTER_SYSLOG_ADDRESS
          value: /var/lib/rsyslog/rsyslog.sock
        - name: ROUTER_LOG_LEVEL
          value: info
        volumeMounts:
        - mountPath: /var/lib/rsyslog
          name: rsyslog-socket
      - name: syslog
        command:
        - /sbin/rsyslogd
        - -n
        - -i
        - /tmp/rsyslog.pid
        - -f
        - /etc/rsyslog/rsyslog.conf
        image: registry.redhat.io/openshift3/ose-haproxy-router:v3.11
        imagePullPolicy: IfNotPresent
        resources:
          requests:
            cpu: 100m
            memory: 256Mi
        volumeMounts:
        - mountPath: /etc/rsyslog
          name: rsyslog-config
        - mountPath: /var/lib/rsyslog
          name: rsyslog-socket
      volumes:
      - configMap:
          name: rsyslog-config
        name: rsyslog-config
      - emptyDir: {}
        name: rsyslog-socket"

  log "Changing triggers to auto on dc/$router"
  oc set triggers dc/$router --auto -n default || err "Error changing triggers to manual on dc/$router"
  log "--------------"
done

log "Done"
