#!/bin/bash

set -e

if [[ -z "$1" ]] || [[ "$2" < 1 ]]; then
  cat << EOF
usage: ./generate_etcd_ignition_config.sh <platform> <size of the cluster>
  Provide the name of the platform to target.
  Accepted platform values: [azure digitalocean ec2 gce packet openstack-metadata vagrant-virtualbox cloudstack-configdrive]" 
  The cluster must have at least 1 node. Input: $2
EOF
  exit 1
fi

TARGET_PLATFORM=$1
CLUSTER_SIZE=$2

function fetch_transpiler {
  if [[ -x ct ]]; then 
    return 
  else
    if [ "$(uname)" == "Darwin" ]; then
      url="https://github.com/coreos/container-linux-config-transpiler/releases/download/v0.5.0/ct-v0.5.0-x86_64-apple-darwin"
    else
      url="https://github.com/coreos/container-linux-config-transpiler/releases/download/v0.5.0/ct-v0.5.0-x86_64-unknown-linux-gnu"
    fi

    curl -sL $url -o ct 
    chmod +x ct
  fi
}

#Fetch discovery token
etcd_discovery_token=$(curl -Ls https://discovery.etcd.io/new?size=$CLUSTER_SIZE)

#Create the container linux config with that token
etcd_container_linux_config=$(cat << EOF
etcd:
  #TODO: azure does not support {HOSTNAME}. We need a workaround.
  name:                        "{HOSTNAME}"
  # For multi-region and multi-cloud, use {PUBLIC_IPV4}
  listen_peer_urls:            "http://{PRIVATE_IPV4}:2380"
  listen_client_urls:          "http://0.0.0.0:2379"
  initial_advertise_peer_urls: "http://{PRIVATE_IPV4}:2380"
  advertise_client_urls:       "http://{PRIVATE_IPV4}:2379"
  # replace "<token>" with a valid etcd discovery token
  discovery:                   "$etcd_discovery_token"

systemd:
  units:
    - name: docker-tcp.socket
      enable: true
      contents: |
        [Unit]
        Description=Docker Socket for the API

        [Socket]
        ListenStream=2375
        Service=docker.service
        BindIPv6Only=both

        [Install]
        WantedBy=sockets.target
    - name: flanneld.service
      dropins:
        - name: 50-network-config.conf
          contents: |
            [Service]
            ExecStartPre=/usr/bin/etcdctl set /flannel/network/config '{ "Network": "10.1.0.0/16" }'

flannel:
  etcd_prefix: "/flannel/network"
EOF)

#Transpile the container linux config to ignition config
if [[ ! -x ct ]]; then fetch_transpiler; fi
etcd_ignition_config=$(
  echo "$etcd_container_linux_config" | ./ct --platform=$TARGET_PLATFORM --pretty
)
echo "${etcd_ignition_config}"
