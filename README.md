# devsecops-takehome-submission
Submission for DevSecOps assignment.

## 🧭 Overview
This project implements a DevSecOps take-home assignment covering the full lifecycle:

- **Image build** with Python 2/3 and R  
- **Security scanning** with Trivy (automated in CI)  
- **Kubernetes deployment** of the image with Namespace, Deployment, Service, and HPA  
- **CI/CD pipeline** with GitHub Actions for build, scan, and deploy  
- **Basic monitoring** using Metrics Server and HPA

---

## 🐳 Step 2: Build Times and Improvements

### ⏱ Build Time Results
The Docker image was built twice to measure **cold** and **warm** build performance:

- **Cold build (no cache)**: `8m 55.91s`  
  ```bash
  time docker build --no-cache -t gulzada312/devsecops-mixed .
Warm build (with cache): 4.34s
time docker build -t gulzada312/devsecops-mixed .


## Step 3 — Security Scanning & Remediation Plan

**Tool used:** Trivy (vulnerability and secrets scanning)

### Findings
- **CVEs:** Trivy reported vulnerabilities in the `setuptools` package (e.g., CVE-2022-40897 and related).  
- **Secrets:** Trivy flagged example PEM keys located in  
  `/usr/local/lib/R/site-library/openssl/doc/keys.html` (these are not real secrets but documentation examples from the R `openssl` package).

Scan reports:
- `artifacts/trivy-image.txt`
- `artifacts/trivy-secrets.txt`

### Remediation Plan (Documented)
- **Python 3:** Upgrade `setuptools` to `>=78.1.1` in a future image to address known CVEs.  
- **Python 2.7:** Full remediation is not possible due to EOL; last compatible version is `44.1.1`.  
  *Mitigation:* minimize Py2 footprint, run as non-root, and restrict network access in production.
- **Secrets false positives:** Exclude or remove the R `openssl` docs from the image in future builds.

This approach meets the assignment requirement to scan, evaluate, and propose best-practice remediation steps without altering the original Dockerfile.
