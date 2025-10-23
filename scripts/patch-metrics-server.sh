#!/usr/bin/env bash
set -euo pipefail

echo " Installing metrics-server..."
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

echo "  Patching deployment for Docker Desktop compatibility..."
kubectl -n kube-system patch deploy metrics-server --type='json' -p='[
  {"op":"replace","path":"/spec/template/spec/containers/0/args","value":[
    "--cert-dir=/tmp",
    "--secure-port=4443",
    "--kubelet-insecure-tls",
    "--kubelet-preferred-address-types=InternalIP,Hostname,ExternalIP",
    "--metric-resolution=15s"
  ]}
]'

echo "Metrics-server patch completed."