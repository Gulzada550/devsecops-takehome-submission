#!/usr/bin/env bash
set -euo pipefail

echo " Ensuring resource requests/limits for 'toolset' deployment..."
kubectl -n devsecops patch deploy toolset --type='json' -p='[
  {"op":"add","path":"/spec/template/spec/containers/0/resources","value":{
    "requests":{"cpu":"100m","memory":"128Mi"},
    "limits":{"cpu":"500m","memory":"512Mi"}
  }}
]' || kubectl -n devsecops patch deploy toolset --type='json' -p='[
  {"op":"replace","path":"/spec/template/spec/containers/0/resources","value":{
    "requests":{"cpu":"100m","memory":"128Mi"},
    "limits":{"cpu":"500m","memory":"512Mi"}
  }}
]'

echo "HPA resource requests/limits ensured."