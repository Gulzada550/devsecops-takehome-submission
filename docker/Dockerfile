# syntax=docker/dockerfile:1.7
# Stage 1: builder for Python2 via pyenv (isolated)
FROM ubuntu:22.04 AS py2-builder

ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    git curl ca-certificates build-essential libssl-dev zlib1g-dev \
    libbz2-dev libreadline-dev libsqlite3-dev wget llvm libncurses5-dev \
    libncursesw5-dev xz-utils tk-dev libffi-dev liblzma-dev \
 && rm -rf /var/lib/apt/lists/*

ENV PYENV_ROOT=/opt/pyenv
RUN git clone https://github.com/pyenv/pyenv.git "$PYENV_ROOT"
ENV PATH="$PYENV_ROOT/bin:$PATH"

ARG PY2_VERSION=2.7.18
RUN bash -lc "pyenv install ${PY2_VERSION} && pyenv global ${PY2_VERSION} && pyenv rehash"
RUN mkdir -p /opt/py2 && cp -a ${PYENV_ROOT}/versions/${PY2_VERSION}/* /opt/py2/

# Stage 2: final runtime with R + Python3 + copied Python2
FROM rocker/r-ver:4.3.3

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 python3-venv python3-pip python3-dev \
    libxml2-dev libcurl4-openssl-dev libssl-dev \
    liblzma-dev libbz2-dev libzstd-dev libjpeg-dev libpng-dev \
    git curl ca-certificates tini \
 && rm -rf /var/lib/apt/lists/*

# Python2 runtime from builder (root owns /opt/py2)
COPY --from=py2-builder /opt/py2 /opt/py2
ENV PATH="/opt/py2/bin:/usr/bin:$PATH"

# --- Install R packages AS ROOT (system library is writable) ---
COPY install_r_packages.R /tmp/install_r_packages.R
RUN Rscript /tmp/install_r_packages.R && rm -f /tmp/install_r_packages.R
# ---------------------------------------------------------------

# --- Install Python2 deps AS ROOT (writeable /opt/py2) ---
RUN /opt/py2/bin/python -c "import ensurepip; ensurepip.bootstrap()" || true
RUN /opt/py2/bin/pip install --upgrade pip setuptools wheel || true
RUN /opt/py2/bin/pip install -r /tmp/requirements-py2.txt || true
# --------------------------------------------------------

# Create non-root user AFTER system-level installs
RUN useradd -m -u 10001 appuser
USER appuser
WORKDIR /home/appuser

# Python3 venv for the appuser
RUN python3 -m venv /home/appuser/py3 && /home/appuser/py3/bin/pip install --upgrade pip

# Requirements (copied as appuser)
# Note: we already used /tmp/requirements-py2.txt above; keep a copy here too if you want it in the image
COPY --chown=appuser:appuser requirements-py3.txt requirements-py3.txt
COPY requirements-py2.txt /tmp/requirements-py2.txt

# Install Python3 deps as appuser
RUN /home/appuser/py3/bin/pip install -r requirements-py3.txt

ENTRYPOINT ["/usr/bin/tini","--"]
CMD ["bash","-lc","echo 'Container started. py3: /home/appuser/py3/bin/python, py2: /opt/py2/bin/python, R: R'; tail -f /dev/null"]
