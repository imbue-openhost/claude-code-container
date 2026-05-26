# ~/.bashrc for the claude-workbench user.

# Source the system bashrc if present.
if [ -f /etc/bash.bashrc ]; then
    . /etc/bash.bashrc
fi

alias claude='claude --dangerously-skip-permissions'

# Interactive login banner: prompt to configure the `oh` CLI if no config
# exists yet. The workbench tries to seed this file from secrets-v2 on
# startup (keys: OH_HOSTNAME, OH_TOKEN); if those weren't set, fall back to
# nudging the user.
if [[ $- == *i* ]] && [ ! -f "$HOME/.openhost/compute_space_cli.toml" ]; then
    cat <<'EOF'
────────────────────────────────────────────────────────────────
  The `oh` openhost CLI is installed but not configured.

  To auto-configure on next start, set these secrets in the
  secrets app, then restart this workbench:

      OH_HOSTNAME   your compute space host (e.g. x.host.com)
      OH_TOKEN      an API token for that instance

  Or configure it interactively now:

      oh instance login
────────────────────────────────────────────────────────────────
EOF
fi
