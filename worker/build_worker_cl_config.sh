#!/bin/bash
set -e

# The endpoint the worker node should use to contact controller nodes (https://ip:port)
# In HA configurations this should be an external DNS record or loadbalancer in front of the control nodes.
# However, it is also possible to point directly to a single control node.
#export MASTER_ENDPOINT=

# Specify the version (vX.Y.Z) of Kubernetes assets to deploy
export K8S_VER=v1.5.4_coreos.0

# Hyperkube image repository to use.
export HYPERKUBE_IMAGE_REPO=quay.io/coreos/hyperkube

# The CIDR network to use for pod IPs.
# Each pod launched in the cluster will be assigned an IP out of this range.
# Each node will be configured such that these IPs will be routable using the flannel overlay network.
export POD_NETWORK=10.2.0.0/16

# The IP address of the cluster DNS service.
# This must be the same DNS_SERVICE_IP used when configuring the controller nodes.
export DNS_SERVICE_IP=10.3.0.10

# The above settings can optionally be overridden using an environment file:
ENV_FILE=worker/options.env


# -------------

function init_variables {
    local REQUIRED=( 'ADVERTISE_IP' 'ETCD_ENDPOINTS' 'MASTER_ENDPOINT' 'POD_NETWORK' 'DNS_SERVICE_IP' 'K8S_VER' 'HYPERKUBE_IMAGE_REPO' )

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

template="worker/worker_cl_config.template"
#TODO: learn bash :)
cl_config=$(
  cat $template |
  sed -e "s~\${ADVERTISE_IP}~${ADVERTISE_IP}~g" |
  sed -e "s~\${ETCD_ENDPOINTS}~${ETCD_ENDPOINTS}~g" |
  sed -e "s~\${MASTER_ENDPOINT}~${MASTER_ENDPOINT}~g" |
  sed -e "s~\${POD_NETWORK}~${POD_NETWORK}~g" |
  sed -e "s~\${DNS_SERVICE_IP}~${DNS_SERVICE_IP}~g" |
  sed -e "s~\${K8S_VER}~${K8S_VER}~g" |
  sed -e "s~\${HYPERKUBE_IMAGE_REPO}~${HYPERKUBE_IMAGE_REPO}~g"
)
echo "${cl_config}"