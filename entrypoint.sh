#!/usr/bin/env bash
set -euo pipefail

OPENHOST_REPO="${OPENHOST_REPO_URL:-https://github.com/imbue-openhost/openhost.git}"
OPENHOST_DIR="${OPENHOST_DIR:-$HOME/openhost}"
SKILL_SRC="/app/skills/openhost"
SKILL_DST="$HOME/.claude/skills/openhost"

if [ ! -d "$OPENHOST_DIR/.git" ]; then
    echo "[entrypoint] cloning openhost into $OPENHOST_DIR ..."
    git clone --depth 1 "$OPENHOST_REPO" "$OPENHOST_DIR" || \
        echo "[entrypoint] WARN: openhost clone failed; you can clone manually later."
fi

mkdir -p "$(dirname "$SKILL_DST")"
if [ ! -e "$SKILL_DST" ]; then
    ln -s "$SKILL_SRC" "$SKILL_DST"
fi

export OPENHOST_DIR
exec python3 /app/server.py
