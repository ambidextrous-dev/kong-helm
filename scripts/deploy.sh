#variables
namespace=kong
license_path="../license/license"

#connect to specific cluster
export KUBECONFIG=:/opt/kubecfg/$bamboo_deploy_environment-kubecfg
kubectl config use-context $bamboo_deploy_environment

#create namespace
kubectl create namespace $namespace --dry-run -o yaml | kubectl apply -f -

#create self-signed certs for mTLS
openssl req -new -x509 -nodes -newkey ec:<(openssl ecparam -name secp384r1) -keyout cluster.key -out cluster.crt -days 1095 -subj "/CN=kong_clustering"

#create required secrets
kubectl create secret tls kong-cluster-cert --cert=cluster.crt --key=cluster.key -n $namespace --dry-run -o yaml | kubectl apply -f -
kubectl create secret generic kong-enterprise-superuser-password -n $namespace --from-literal=password=HardToGuessPassword! --dry-run -o yaml | kubectl apply -f -
kubectl create secret generic kong-enterprise-license --from-file=$license_path -n $namespace --dry-run -o yaml | kubectl apply -f -

#create postgresdb and then create secret for postgres
kubectl apply -f ../k8-manifests/$bamboo_deploy_environment/dbsecret.yaml -n $namespace

#create kong session config secrets
kubectl create secret generic kong-session-config --from-file=../conf/$bamboo_deploy_environment/admin_gui_session_conf --from-file=../conf/$bamboo_deploy_environment/portal_session_conf --namespace $namespace --dry-run -o yaml | kubectl apply -f -

#Install Kong
helm repo add kong https://charts.konghq.com
helm repo update
helm install kong-cp kong/kong --namespace $namespace --values=../k8-manifests/$bamboo_deploy_environment/controlplane-values.yaml 
helm install kong-dp kong/kong --namespace $namespace --values=../k8-manifests/$bamboo_deploy_environment/dataplane-values.yaml

#create tls cert secrets 
kubectl create secret tls kong-tls --cert=../certs/wildcard-company.crt --key=../certs/wildcard-company.key --namespace $namespace --dry-run -o yaml | kubectl apply -f -

#create ingress
kubectl apply -f ../k8-manifests/$bamboo_deploy_environment/ingress.yaml --namespace kong