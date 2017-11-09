#!/bin/bash
set -e

if [[ -z "$DNS_SERVICE_IP" ]] || [[ -z "$DIR" ]]; then
  cat "usage DNS_SERVICE_IP=<ip> DIR=<path> ./deploy_addons.sh"
  exit 1
fi

for file in $DIR/*; do
  cat $file | sed -e "s~\${DNS_SERVICE_IP}~${DNS_SERVICE_IP}~g" | kubectl create -f -
done
