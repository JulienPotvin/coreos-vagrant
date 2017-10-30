#!/bin/bash
set -e

# List of etcd servers (http://ip:port), comma separated
#export ETCD_ENDPOINTS=

# Specify the version (vX.Y.Z) of Kubernetes assets to deploy
export K8S_VER=v1.5.4_coreos.0

# Hyperkube image repository to use.
export HYPERKUBE_IMAGE_REPO=quay.io/coreos/hyperkube

# The CIDR network to use for pod IPs.
# Each pod launched in the cluster will be assigned an IP out of this range.
# Each node will be configured such that these IPs will be routable using the flannel overlay network.
export POD_NETWORK=10.2.0.0/16

# The CIDR network to use for service cluster IPs.
# Each service will be assigned a cluster IP out of this range.
# This must not overlap with any IP ranges assigned to the POD_NETWORK, or other existing network infrastructure.
# Routing to these IPs is handled by a proxy service local to each node, and are not required to be routable between nodes.
export SERVICE_IP_RANGE=10.3.0.0/24

# The IP address of the Kubernetes API Service
# If the SERVICE_IP_RANGE is changed above, this must be set to the first IP in that range.
export K8S_SERVICE_IP=10.3.0.1

# The IP address of the cluster DNS service.
# This IP must be in the range of the SERVICE_IP_RANGE and cannot be the first IP in the range.
# This same IP must be configured on all worker nodes to enable DNS service discovery.
export DNS_SERVICE_IP=10.3.0.10

# The above settings can optionally be overridden using an environment file:
ENV_FILE=controller/options.env

# --- end of constants ---

function init_variables {
    local REQUIRED=('ADVERTISE_IP' 'POD_NETWORK' 'ETCD_ENDPOINTS' 'SERVICE_IP_RANGE' 'K8S_SERVICE_IP' 'DNS_SERVICE_IP' 'K8S_VER' 'HYPERKUBE_IMAGE_REPO')

    if [ -f $ENV_FILE ]; then
        export $(cat $ENV_FILE | xargs)
    fi

    for REQ in "${REQUIRED[@]}"; do
        if [ -z "$(eval echo \$$REQ)" ]; then
            echo "Missing required config value: ${REQ}"
            exit 1
        fi
    done
}

# --- end of functions ---

init_variables

ACTIVE_ETCD=$(
  IFS=',' read -ra ES <<< "$ETCD_ENDPOINTS"
  echo "${ES[0]}"
)

template="controller/controller_config.template"
#TODO: learn bash and do this in a non-retarded way
cl_config=$(
  cat $template |
  sed -e "s~\${ADVERTISE_IP}~${ADVERTISE_IP}~g" |
  sed -e "s~\${ETCD_ENDPOINTS}~${ETCD_ENDPOINTS}~g" |
  sed -e "s~\${ACTIVE_ETCD}~${ACTIVE_ETCD}~g" |
  sed -e "s~\${POD_NETWORK}~${POD_NETWORK}~g" |
  sed -e "s~\${SERVICE_IP_RANGE}~${SERVICE_IP_RANGE}~g" |
  sed -e "s~\${K8S_SERVICE_IP}~${K8S_SERVICE_IP}~g" |
  sed -e "s~\${DNS_SERVICE_IP}~${DNS_SERVICE_IP}~g" |
  sed -e "s~\${K8S_VER}~${K8S_VER}~g" |
  sed -e "s~\${HYPERKUBE_IMAGE_REPO}~${HYPERKUBE_IMAGE_REPO}~g"
)

echo "${cl_config}"