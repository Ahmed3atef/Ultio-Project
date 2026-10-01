FROM docker.io/frappe/bench:v5.27.0

LABEL maintainer="Ultio Project"
LABEL description="Extended Frappe Bench image with GitLab CLI, pre-commit, and devcontainer tooling"

USER root

# GitLab CLI version
ARG GLAB_VERSION=1.119.0

# Install GitLab CLI (glab) with multi-architecture support (amd64 / arm64)
RUN set -eux; \
    ARCH="$(dpkg --print-architecture)"; \
    case "${ARCH}" in \
        amd64) GLAB_ARCH="linux_amd64" ;; \
        arm64) GLAB_ARCH="linux_arm64" ;; \
        *) echo "Unsupported architecture: ${ARCH}" && exit 1 ;; \
    esac; \
    GLAB_DEB="glab_${GLAB_VERSION}_${GLAB_ARCH}.deb"; \
    echo "Installing GitLab CLI v${GLAB_VERSION} (${GLAB_ARCH})..."; \
    wget -qO /tmp/glab.deb "https://gitlab.com/gitlab-org/cli/-/releases/v${GLAB_VERSION}/downloads/${GLAB_DEB}" \
        || wget -qO /tmp/glab.deb "https://gitlab.com/api/v4/projects/gitlab-org%2Fcli/packages/generic/glab/${GLAB_VERSION}/${GLAB_DEB}"; \
    dpkg -i /tmp/glab.deb || (apt-get update && apt-get install -f -y); \
    rm -f /tmp/glab.deb; \
    glab --version

# Configure system-wide Git HTTP performance optimizations and SSH defaults
RUN git config --system http.version HTTP/1.1 \
    && git config --system http.postBuffer 1048576000 \
    && git config --system http.lowSpeedLimit 0 \
    && git config --system http.lowSpeedTime 999999 \
    && git config --system gpg.format ssh \
    && git config --system gpg.ssh.allowedSignersFile /home/frappe/.ssh/allowed_signers

# Install pre-commit via uv for the frappe user
USER frappe
ENV PATH="/home/frappe/.local/bin:${PATH}"
RUN uv tool install pre-commit

# Switch to root to expose pre-commit in /usr/local/bin and install lifecycle scripts
USER root
RUN ln -sf /home/frappe/.local/bin/pre-commit /usr/local/bin/pre-commit

# Copy devcontainer helper scripts into system PATH
COPY scripts/post-create.sh /usr/local/bin/devcontainer-post-create.sh
COPY scripts/post-start.sh /usr/local/bin/devcontainer-post-start.sh
RUN chmod +x /usr/local/bin/devcontainer-post-create.sh /usr/local/bin/devcontainer-post-start.sh

# Revert to standard bench user
USER frappe
