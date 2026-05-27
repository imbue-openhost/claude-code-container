# ~/.bashrc for the claude-workbench user.
#
# Don't source /etc/bash.bashrc here: bash auto-loads it for interactive
# non-login shells, and /etc/profile loads it for login shells. Sourcing
# it again from .bashrc caused Ubuntu's sudo motd to print twice.

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
