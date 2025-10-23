# devsecops-takehome-submission
Submission for DevSecOps assignment.

## Table of Contents
- [Overview](#overview)
- [Step 2 — Build Times and Improvements](#step-2-build-times-and-improvements)
- [Step 3 — Security Scanning & Remediation](#step-3--security-scanning--remediation-plan)
- [Step 4–5 — Kubernetes Deployment & Exposure](#step-45--kubernetes-deployment--exposure)
- [Step 6 — CI/CD Pipeline](#step-6--cicd-pipeline)
- [Step 7 — Monitoring (HPA)](#step-7--monitoring-hpa)
- [Part 2 — On-Demand Dev Environments](#part-2--on-demand-dev-environments-design--templates)
- [Architecture Diagram](#-architecture-diagram)
- [Troubleshooting](#troubleshooting)

## Overview
This project implements a DevSecOps take-home assignment covering the full lifecycle:

- **Image build** with Python 2/3 and R  
- **Security scanning** with Trivy (automated in CI)  
- **Kubernetes deployment** of the image with Namespace, Deployment, Service, and HPA  
- **CI/CD pipeline** with GitHub Actions for build, scan, and deploy  
- **Basic monitoring** using Metrics Server and HPA

---

## Step 2: Build Times and Improvements

### Build Time Results
The Docker image was built twice to measure **cold** and **warm** build performance:

- **Cold build (no cache)**: `8m 55.91s`  
  ```bash
time docker build --no-cache -t gulzada312/devsecops-mixed .
**Warm build (with cache)**: `4.34s`
time docker build -t gulzada312/devsecops-mixed .

**Improvements**
- Multi-stage builds to reduce image size and leverage caching
- Layer ordering so dependency installation happens early
- `.dockerignore` to avoid sending unnecessary build context
- Minimal base image to keep the image light and secure


## Step 3: Security Scanning & Remediation Plan

### Tool
- **Scanner**: Trivy (vulnerability + secrets)

### Reports
- `artifacts/trivy-image.txt`  
- `artifacts/trivy-secrets.txt`

### Key Findings
- CVEs reported in the Python `setuptools` package.  
- Secrets scanner flagged example PEM blocks from R `openssl` docs at  
  `/usr/local/lib/R/site-library/openssl/doc/keys.html` *(false positives — not real secrets)*.
  The Trivy scan reports are stored in the artifacts/ directory and automatically generated during the CI workflow.

### Remediation Plan

- **Python 3**: Rebuild with `setuptools >= 78.1.1` to remediate known CVEs.  
- **Python 2.7 (EOL)**: Full remediation by upgrade is not possible; last compatible `setuptools` is `44.1.1`.  
  - Mitigations:
    - Run as non-root  
    - Minimize Py2 footprint  
    - Isolate the Py2 toolchain  
    - Use trusted/offline wheels in production  
- **False-positive secrets**: Exclude the R openssl doc path during scans or remove the doc directory in a future image.

### Preventing Malicious Packages (3b)
Defense-in-depth for dependencies and images:

- **Pin & verify**: Pin versions and use hashes (`pip install -r requirements.txt --require-hashes`), maintain `constraints.txt` or lock files.  
- **Trusted indexes only**: Use private/proxy registries for PyPI/CRAN (allowlist), enable malware scanning at the proxy.  
- **Automated scanning in CI**: Run Trivy/Grype on every PR, fail builds on Critical/High findings, upload reports as artifacts.  
- **SBOM & signatures**: Generate SBOM (CycloneDX), sign images with `cosign`, and verify signatures in CI/CD.  
- **Policy enforcement**: Use OPA Gatekeeper or Kyverno to block `:latest`, unsigned images, root containers, or unapproved registries.  
- **Review & updates**: Use Dependabot/Renovate and periodic pipelines to refresh/pin safe versions.

---

## Step 4–5: Kubernetes Deployment & Exposure

### Namespace
`devsecops`

### Deployment
- **Name**: `toolset`  
- **Image**: `docker.io/gulzada312/devsecops-mixed:latest`  
- **Command**:  
  ```bash
  bash -c "tail -f /dev/null"

---

## Service

- **Name:** `toolset-svc`  
- **Type:** `ClusterIP`  
- **Port:** `80` → Pod `8080`

### Verification Commands
```bash
kubectl -n devsecops get deploy,rs,svc,endpoints,pods -o wide
kubectl -n devsecops rollout status deploy/toolset
kubectl -n devsecops exec -it <pod> -- bash -lc \
  'python3 --version; env LD_LIBRARY_PATH=/opt/py2/lib /opt/py2/bin/python -V; R --version | head -n1'

---

## Step 6: CI/CD Pipeline

### CI
Triggered on every push or pull request.

Runs:
- Docker build
- Trivy image and secrets scan
- Uploads reports to `artifacts/`

### CD
- Applies Kubernetes manifests to the `devsecops` namespace  
- Confirms rollout status of the deployment

### Workflows
- `.github/workflows/ci.yml`  
- `.github/workflows/cd.yml`

---

## Step 7: Monitoring (HPA)

- **HPA Name:** `toolset-hpa`  
- **Target:** CPU 60%  
- **Min Pods:** 1  
- **Max Pods:** 5

Check HPA status:
```bash
kubectl -n devsecops get hpa

 ## How to Run This Project Locally

 # Clone the repo
git clone git@github.com:Gulzada550/devsecops-takehome-submission.git
cd devsecops-takehome-submission

# Build image
docker build -t local/devsecops-mixed .

# Deploy to Kubernetes
kubectl apply -f k8s/

# Port forward to access
kubectl -n devsecops port-forward svc/toolset-svc 8080:80

## Scripts
- `scripts/patch-metrics-server.sh` — fixes Metrics Server issues on Docker Desktop.
- `scripts/ensure-hpa-requests.sh` — ensures CPU requests/limits are set for HPA.

For troubleshooting steps (Metrics Server, HPA targets), see [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md).

## Makefile Commands
- `make build` — builds Docker image
- `make deploy` — applies K8s manifests
- `make scan` — runs Trivy scan

## Link the Docker Hub image:

Image: docker.io/gulzada312/devsecops-mixed:latest

## Part 2 — On-Demand Dev Environments (Design + Templates)

This section provides **templates** and a **how-to** for launching per-user dev environments without requiring a full deploy demo.

### Template Inputs
- **ID & Owner:** `DEPLOY_ID`, `OWNER`
- **Namespace:** `NAMESPACE`
- **Image:** `BASE_IMAGE` (e.g., `gulzada312/devsecops-mixed:latest`)
- **Packages (optional):** `PY3_PACKAGES`, `PY2_PACKAGES`, `R_PACKAGES` (comma-separated)
- **Resources:** `CPU_REQUEST`, `MEM_REQUEST`, `CPU_LIMIT`, `MEM_LIMIT`
- **Pull policy:** `IMAGE_PULL_POLICY` (default `IfNotPresent`)

### Render & Apply
```bash
export NAMESPACE=devsecops
export DEPLOY_ID=alice01
export OWNER=alice
export BASE_IMAGE=docker.io/gulzada312/devsecops-mixed:latest
export PY3_PACKAGES="numpy,pandas"
export PY2_PACKAGES=""
export R_PACKAGES="dplyr"
export CPU_REQUEST=500m; export MEM_REQUEST=2Gi
export CPU_LIMIT=2;     export MEM_LIMIT=4Gi
mkdir -p rendered
envsubst < k8s/dev-env.yaml.tmpl > rendered/dev-env-${DEPLOY_ID}.yaml
# kubectl apply -f rendered/dev-env-${DEPLOY_ID}.yaml


### Part 2 — Templates & Design (no deploy in this submission)
See `k8s/*.tmpl` and the “Render & Apply” instructions. These enable per-user dev envs with selectable base image, packages, CPU/Mem, optional HPA, and (future) DNS/Ingress.

##  Dev Environment Factory: Architecture & Strategy
## Architecture Diagram

```mermaid
graph TD
  UI[Self-Service UI / GitHub Actions] --> Templating[Render K8s Templates]
  Templating --> K8s[Kubernetes Cluster]
  K8s --> DNS[ExternalDNS / Route53]
  K8s --> Monitoring[Prometheus / HPA / VPA]
  Monitoring --> Reports[Usage Reports / Alerts] ```


This section outlines how I would **design and implement a self-service, scalable development environment factory** on Kubernetes to meet the assignment requirements.

---

## 1) Self-service UI / Workflow (Base image, Packages, CPU/Mem/GPU)

I’d stand up an EKS-backed “dev-env factory”: a small React UI (or a `workflow_dispatch` **GitHub Actions** form) writes a single YAML spec containing:

- `base image`  
- `packages`  
- `CPU/Mem/GPU` requests

A GitHub Action either pulls an existing base image from ECR or bakes requested packages (if needed) and deploys a templated Helm chart to a per-user namespace.

**Base images** live in ECR by family (Python, R, CUDA). Add-ons are composed via:

- Multi-stage builds, or  
- An initContainer that installs requested packages from a lockfile to keep builds deterministic.

**CPU/Mem/GPU options** map to Kubernetes `requests`/`limits` and node selectors/taints (e.g., `gpu=true`).  
The UI or GitHub Action just flips Helm values accordingly.

 *In this project, this behavior is represented by `k8s/dev-env.yaml.tmpl` and supporting template files (`hpa.yaml.tmpl`, `ingress.yaml.tmpl`, `pvc.yaml.tmpl`).*

---

## 2) Monitoring, Right-sizing & Idle Handling

- **Right-sizing:** Prometheus + kube-state-metrics + metrics-server provide usage data.  
  VPA runs in recommend-only mode (with Goldilocks) to surface right-sizing deltas.  
  HPA handles autoscaling on CPU/memory for scalable environments.

- **Idle detection:** PromQL checks for “low CPU & low RSS for N minutes.”  
  A controller (or cronjob) scales Deployments to zero (or a tiny preset) and notifies users in Slack/Email via Alertmanager.

- **Downscale rule example:**  
  `<3% CPU and <10% memory for 30m` ⇒ scale to 0;  
  any traffic or queue signal ⇒ restore to min replicas.  
  For job-like envs, KEDA can scale based on SQS queue length.

- **Usage tracking:** Prometheus usage is exported to S3 (remote_write / Thanos) and queried with Athena.  
  Grafana shows per-user CPU-hours, GB-hours, GPU-hours. Labels and annotations tie workloads to owners.

 *For this assignment, `scripts/patch-metrics-server.sh` and `scripts/ensure-hpa-requests.sh` help ensure metrics visibility and proper HPA behavior in a local environment.*

---

## 3) Cluster Autoscaling & Resource Segregation

I use **EKS with [Karpenter](https://karpenter.sh)** for fast bin-packing autoscaling and Managed Node Groups for baseline capacity.  
Separate node groups for:

- GPU  
- High-mem  
- General workloads

Each group has taints/labels (`workload=gpu|mem|general`).

Teams/projects get namespaces with `ResourceQuota` and `LimitRange`, plus nodeSelector/affinity rules to land on the right pool.  
IAM Roles for Service Accounts (IRSA) scope their AWS access cleanly.  
Terraform codifies the node groups, Karpenter provisioners, and EKS add-ons to replicate this in other regions/accounts.

---

## 4) SFTP / SSH Access + DNS Automation

For DNS, I use:

- [ExternalDNS](https://github.com/kubernetes-sigs/external-dns) for automatic record creation in Route53  
- [cert-manager](https://cert-manager.io) for automatic TLS certificates

Each environment gets its own hostname like: userX.dev.company.com


— handled automatically by the Helm chart.

For secure shell access:

- Prefer AWS Transfer Family (SFTP) or Teleport / AWS SSM Session Manager for audited access.  
- If direct pod access is required, a hardened toolbox sidecar is exposed behind authenticated Ingress.

 *Ingress behavior is defined in `k8s/ingress.yaml.tmpl` in this project.*

---

## 5) Handling 100–250 GB In-Memory Workloads

**(a) Real example pattern:**  
I once had a workload requiring ~200 GB of RAM for model feature loading.  
We provisioned memory-optimized r-class nodes, scheduled pods with guaranteed memory, and prewarmed data from S3 using initContainers with [s5cmd](https://github.com/peak/s5cmd).  
Hot data lived on an `emptyDir` volume with `medium: Memory` and HugePages for predictable performance.

**(b) If designing from scratch:**  
- Dedicated high-mem node group (`r7*`), tainted `mem=true`  
- Pod requests 230–260 GB → guaranteed single-node placement  
- InitContainer hydrates RAM disk (`emptyDir: Memory`) from S3 in parallel chunks  
- If startup time matters → warm node pool or layer caching (e.g., ElastiCache or Arrow Plasma).

For streaming workloads, data can be memory-mapped on NVMe ephemeral storage to reduce RAM footprint.

**(c) Monitoring memory usage/errors:**  
- `container_memory_working_set_bytes`, page faults, and OOMKill events tracked via Prometheus/cAdvisor.  
- Grafana alerts on “>90% RSS for N minutes” or OOM events.  
- VPA recommendations feed Helm defaults.  
- Init load times are logged to validate hydration SLAs.

 *PVC templates (`pvc.yaml.tmpl`) and resource configuration in this repo illustrate how large-memory workloads could be supported.*

---

## Summary

This design delivers a **self-service, multi-tenant dev environment factory** with:

-  Dynamic environment creation (UI or CI/CD)  
-  Resource isolation and autoscaling  
-  Cost and usage tracking  
-  Secure access and DNS automation  
-  Support for high-memory scientific workloads

All implemented with **standard Kubernetes building blocks**, and ready to extend into production environments.

---


