FROM node:20-bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
        python3 python3-pip python3-venv \
        git ca-certificates curl tini bash less vim \
    && rm -rf /var/lib/apt/lists/*

RUN npm install -g @anthropic-ai/claude-code

# Python deps for the server.
RUN python3 -m venv /opt/venv \
    && /opt/venv/bin/pip install --no-cache-dir 'quart>=0.19' 'hypercorn>=0.16' 'httpx>=0.27'
ENV PATH="/opt/venv/bin:$PATH"

# Non-root user — keystrokes shouldn't run as root inside the workbench.
# The node base image already ships a uid 1000 user ("node"); rename it to
# workbench and give it a /home/workbench so paths match the rest of the image.
RUN usermod -l workbench -d /home/workbench -m node \
    && groupmod -n workbench node \
    && chsh -s /bin/bash workbench
ENV HOME=/home/workbench

WORKDIR /app
COPY server.py /app/server.py
COPY templates /app/templates
COPY static /app/static
COPY skills /app/skills
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh && chown -R workbench:workbench /app

USER workbench
WORKDIR /home/workbench

EXPOSE 5000
ENTRYPOINT ["/usr/bin/tini", "--", "/app/entrypoint.sh"]
