# devsecops-takehome-submission
Submission for DevSecOps assignment.

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
Warm build (with cache): 4.34s
time docker build -t gulzada312/devsecops-mixed .


## Step 3 — Security Scanning & Remediation Plan

**Tool:** Trivy (vulnerability + secrets)

**Reports:**  
- `artifacts/trivy-image.txt`  
- `artifacts/trivy-secrets.txt`

### Key Findings
- CVEs reported in the Python `setuptools` package.
- Secrets scanner flagged example PEM blocks from R `openssl` docs
  at `/usr/local/lib/R/site-library/openssl/doc/keys.html` (false positives, not real secrets).

### Remediation Plan (Documented)
- **Python 3:** Rebuild with `setuptools >= 78.1.1` to remediate known CVEs.
- **Python 2.7 (EOL):** Full remediation by upgrade is not possible; last compatible `setuptools` is `44.1.1`.  
  **Mitigations:** run as non-root, minimize Py2 footprint, isolate the Py2 toolchain, and use trusted/offline wheels in production.
- **False-positive secrets:** Exclude the R `openssl` doc path during scans or remove the doc directory in a future image.

---

## Preventing Malicious Packages (3b)
**Defense-in-depth for dependencies and images:**
- **Pin & verify:** Pin versions and use hashes (e.g., `pip install -r requirements.txt --require-hashes`), keep `constraints.txt` or lock files.
- **Trusted indexes only:** Use private/proxy registries for PyPI/CRAN (allowlist), enable malware scanning at the proxy.
- **Automated scanning in CI:** Trivy/Grype on every PR; fail builds on Critical/High findings; upload reports as artifacts.
- **SBOM & signatures:** Generate SBOM (CycloneDX), sign images with `cosign`, and verify signatures in CI/CD.
- **Policy enforcement:** Admission policies (OPA Gatekeeper/Kyverno) to block `:latest`, unsigned images, root containers, or unapproved registries.
- **Review & updates:** Dependency review bot (Dependabot/Renovate) + periodic pipeline to refresh/pin safe versions.


### Step 4–5: Kubernetes Deployment & Exposure
- Namespace: `devsecops`
- Deployment: `toolset` (image `docker.io/gulzada312/devsecops-mixed:latest`)
- Service: `toolset-svc` (ClusterIP, port 80 → pod 8080)
- Command to keep pod running: `bash -c "tail -f /dev/null"`

**Verification commands:**
- `kubectl -n devsecops get deploy,rs,svc,endpoints,pods -o wide`
- `kubectl -n devsecops rollout status deploy/toolset`
- `kubectl -n devsecops exec -it <pod> -- bash -lc 'python3 --version; env LD_LIBRARY_PATH=/opt/py2/lib /opt/py2/bin/python -V; R --version | head -n1'`

### Step 7: Monitoring (HPA)
- HPA: `toolset-hpa` targeting CPU 60% (min=1, max=5)
- `kubectl -n devsecops get hpa`

