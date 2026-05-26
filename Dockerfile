FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
        python3 python3-pip python3-venv \
        git ca-certificates curl wget tini bash less vim sudo \
        htop tree jq ripgrep fd-find fzf tmux ncdu \
        unzip zip file man-db gnupg \
    && rm -rf /var/lib/apt/lists/*

# Node.js 20 from NodeSource — Ubuntu's own nodejs package lags badly.
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

# GitHub CLI — install from the official apt repo so it stays current.
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        -o /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update && apt-get install -y --no-install-recommends gh \
    && rm -rf /var/lib/apt/lists/*

# GitLab CLI — official binary release (no apt repo available).
ARG GLAB_VERSION=1.65.0
RUN set -eux; \
    arch="$(dpkg --print-architecture)"; \
    case "$arch" in \
        amd64) glab_arch=x86_64 ;; \
        arm64) glab_arch=arm64 ;; \
        *) echo "unsupported arch: $arch" >&2; exit 1 ;; \
    esac; \
    curl -fsSL "https://gitlab.com/gitlab-org/cli/-/releases/v${GLAB_VERSION}/downloads/glab_${GLAB_VERSION}_linux_${glab_arch}.tar.gz" \
        -o /tmp/glab.tar.gz; \
    tar -xzf /tmp/glab.tar.gz -C /usr/local --strip-components=0 bin/glab; \
    rm /tmp/glab.tar.gz

RUN npm install -g @anthropic-ai/claude-code

# Python deps for the server.
RUN python3 -m venv /opt/venv \
    && /opt/venv/bin/pip install --no-cache-dir 'quart>=0.19' 'hypercorn>=0.16' 'httpx>=0.27'
ENV PATH="/opt/venv/bin:$PATH"

# uv — used to install the `oh` openhost CLI. Ubuntu 24.04 ships Python 3.12
# natively, but uv still manages the tool's isolated environment cleanly.
RUN curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR=/usr/local/bin sh

# Non-root user — keystrokes shouldn't run as root inside the workbench.
# Ubuntu 24.04 ships a uid 1000 user ("ubuntu"); rename it to workbench and
# give it a /home/workbench so paths match the rest of the image.
RUN usermod -l workbench -d /home/workbench -m ubuntu \
    && groupmod -n workbench ubuntu \
    && chsh -s /bin/bash workbench \
    && echo 'workbench ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/workbench \
    && chmod 0440 /etc/sudoers.d/workbench
ENV HOME=/home/workbench

WORKDIR /app
COPY server.py /app/server.py
COPY templates /app/templates
COPY static /app/static
COPY skills /app/skills
COPY entrypoint.sh /app/entrypoint.sh
COPY bashrc /home/workbench/.bashrc
RUN chmod +x /app/entrypoint.sh \
    && chown -R workbench:workbench /app \
    && chown workbench:workbench /home/workbench/.bashrc

USER workbench
WORKDIR /home/workbench

# Install the `oh` openhost CLI as the workbench user. uv fetches Python 3.12
# automatically (the CLI requires it).
ENV PATH="/home/workbench/.local/bin:$PATH"
RUN uv tool install "oh @ git+https://github.com/imbue-ai/openhost.git#subdirectory=compute_space_cli"

EXPOSE 5000
ENTRYPOINT ["/usr/bin/tini", "--", "/app/entrypoint.sh"]
