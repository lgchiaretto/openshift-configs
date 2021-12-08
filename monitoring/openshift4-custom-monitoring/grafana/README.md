Create a namespace

Install Grafana Operator

After install operator you can create the Grafana. This Grafana will use ldap access and persistent volumes on NFS (Development test only)

oc apply -f ldap-config.yaml
oc apply -f storage-class-nfs.yaml
oc apply -f grafana-pv.yaml

Create Grafana resource

oc apply -f chiaretto-grafana.yaml


oc adm policy add-cluster-role-to-user cluster-monitoring-view -z grafana-serviceaccount


BEARER_TOKEN=$(oc serviceaccounts get-token grafana-serviceaccount -n chiaretto-grafana)

cat << EOF | oc apply -n "chiaretto-grafana" -f -
apiVersion: integreatly.org/v1alpha1
kind: GrafanaDataSource
metadata:
  name: prometheus-grafanadatasource
  namespace: chiaretto-grafana
spec:
  datasources:
    - access: proxy
      editable: true
      isDefault: true
      jsonData:
        httpHeaderName1: 'Authorization'
        timeInterval: 5s
        tlsSkipVerify: true
      name: Prometheus
      secureJsonData:
        httpHeaderValue1: 'Bearer ${BEARER_TOKEN}'
      type: prometheus
      url: 'https://thanos-querier.openshift-monitoring.svc.cluster.local:9091'
  name: prometheus-grafanadatasource.yaml

EOF



# aplicar o yaml 
oc apply -f grafana-roles.yaml -n chiaretto-monitoring

oc edit csv grafana-operator.v3.10.3

# adicionar as flags abaixo no container do grafana-operator

args: ["--scan-all"]

