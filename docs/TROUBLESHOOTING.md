# Troubleshooting Log

## 1. Metrics Server Not Available

**Symptom:**  
- `kubectl get apiservices v1beta1.metrics.k8s.io` → `False`  
- `kubectl top ...` → `Metrics API not available`

**Root Cause:**  
- On Docker Desktop, kubelet uses a self-signed cert.  
- The metrics-server requires additional flags and correct container port/probes to work.

**Fix (commands run):**
```bash
# install metrics-server
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# add docker-desktop friendly args
kubectl -n kube-system patch deploy metrics-server --type='json' -p='[
  {"op":"replace","path":"/spec/template/spec/containers/0/args","value":[
    "--cert-dir=/tmp",
    "--secure-port=4443",
    "--kubelet-insecure-tls",
    "--kubelet-preferred-address-types=InternalIP,Hostname,ExternalIP",
    "--metric-resolution=15s"
  ]}
]'

# correct container port and probes to match secure port 4443
kubectl -n kube-system patch deploy metrics-server --type='json' -p='[
  {"op":"replace","path":"/spec/template/spec/containers/0/ports","value":[
    {"containerPort":4443,"name":"https","protocol":"TCP"}
  ]},
  {"op":"replace","path":"/spec/template/spec/containers/0/livenessProbe","value":{
    "httpGet":{"path":"/livez","port":"https","scheme":"HTTPS"},
    "initialDelaySeconds":0,"timeoutSeconds":1,"periodSeconds":10,"successThreshold":1,"failureThreshold":3
  }},
  {"op":"replace","path":"/spec/template/spec/containers/0/readinessProbe","value":{
    "httpGet":{"path":"/readyz","port":"https","scheme":"HTTPS"},
    "initialDelaySeconds":20,"timeoutSeconds":1,"periodSeconds":10,"successThreshold":1,"failureThreshold":3
  }}
]'

# verify
kubectl get apiservices v1beta1.metrics.k8s.io -o=jsonpath='{.status.conditions[?(@.type=="Available")].status}'; echo
kubectl top nodes
kubectl top pods -n devsecops

Verification:

Metrics API became available (True).

kubectl top nodes and kubectl top pods returned data successfully.

2. HPA Target Utilization <unknown>

Symptom:

kubectl get hpa -n devsecops showed cpu: <unknown>/60%.

Root Cause:

No resources.requests.cpu defined for the container, so the HPA couldn’t calculate utilization.

Fix (command run):

kubectl -n devsecops patch deploy toolset --type='json' -p='[
  {"op":"add","path":"/spec/template/spec/containers/0/resources","value":{
    "requests":{"cpu":"100m","memory":"128Mi"},
    "limits":{"cpu":"500m","memory":"512Mi"}
  }}
]'


Verification:

kubectl get hpa -n devsecops showed actual CPU utilization instead of <unknown>.

Autoscaling started to behave as expected.
## Runtime verification (metrics + HPA + curl)
\`\`\`console
$ kubectl top pods -n devsecops
NAME                       CPU(cores)   MEMORY(bytes)
toolset-749486f9c7-5wwm7   1m           9Mi

$ kubectl top nodes
NAME             CPU(cores)   CPU%   MEMORY(bytes)   MEMORY%
docker-desktop   274m         2%     1485Mi          19%

$ kubectl get hpa -n devsecops
NAME          REFERENCE            TARGETS       MINPODS   MAXPODS   REPLICAS   AGE
toolset-hpa   Deployment/toolset   cpu: 1%/60%   1         5         1          12h

$ curl -I http://localhost:8080
HTTP/1.0 200 OK
Server: SimpleHTTP/0.6 Python/3.10.12
\`\`\`
