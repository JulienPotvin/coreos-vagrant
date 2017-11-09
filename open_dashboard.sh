#!/bin/bash

set -e

echo 'Open dashboard at http://127.0.0.1:9090/'
kubectl port-forward $(kubectl get pods --namespace=kube-system | grep dashboard | awk '{print$1}') 9090 --namespace=kube-system

