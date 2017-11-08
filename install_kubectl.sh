#!/bin/bash

set -e

#Check environment params
if [[ -z "$MASTER_ENDPOINT" ]] || [[ -z "$CA_CERT" ]] || [[ -z "$ADMIN_KEY" ]] || [[ -z "$ADMIN_CERT" ]]; then
  cat << EOF
usage: MASTER_ENDPOINT=https://<master ip> CA_CERT=<path> ADMIN_KEY=<path> ADMIN_CERT=<path> ./install_kubectl.sh
EOF
  exit 1
fi

#Download the binary if missing 
if ! type kubectl > /dev/null; then
  if [ "$(uname)" == "Darwin" ]; then
    curl -O https://storage.googleapis.com/kubernetes-release/release/v1.6.1/bin/darwin/amd64/kubectl 
  else 
    curl -O https://storage.googleapis.com/kubernetes-release/release/v1.6.1/bin/linux/amd64/kubectl
  fi
  chmod +x kubectl
  mv kubectl /usr/local/bin/kubectl
fi

#Configure
kubectl config set-cluster default-cluster --server=${MASTER_ENDPOINT} --certificate-authority=${CA_CERT}
kubectl config set-credentials default-admin --certificate-authority=${CA_CERT} --client-key=${ADMIN_KEY} --client-certificate=${ADMIN_CERT}
kubectl config set-context default-system --cluster=default-cluster --user=default-admin
kubectl config use-context default-system

