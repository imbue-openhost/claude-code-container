# claude-workbench

An openhost app that gives you tabbed in-browser terminals, preinstalled
Claude Code, and a cloned copy of the openhost repo. Meant as a starting
point for building or debugging openhost apps.

## What's inside the container

- `@anthropic-ai/claude-code` (npm, installed at image build time).
- Python 3 + git + the usual tools.
- A clone of `https://github.com/imbue-openhost/openhost` placed at
  `~/openhost` on first container start (override with `OPENHOST_REPO_URL`
  or `OPENHOST_DIR` env vars).
- A Claude Code skill at `~/.claude/skills/openhost/` that points Claude
  at the curated docs in the local openhost clone.

Authentication for `claude` is whatever the user sets up inside the
terminal — either `ANTHROPIC_API_KEY` in the environment or an interactive
`claude login`. The workbench doesn't manage that.

As a convenience, if the `secrets-v2` app is installed and `ANTHROPIC_API_KEY`
is set there, the workbench fetches it on first PTY launch and exports it
into every new terminal's environment. This is best-effort — if the secrets
app isn't around the terminal still works, you just have to set the key
yourself.

## The UI

`GET /` serves a tabbed xterm.js page. Each tab opens its own WebSocket
to `/terminal/ws`, which bridges to a PTY running `bash -l` inside the
container.

## Prefilling a Claude session (preview)

There's a stub for the eventual "open a Claude session with this context"
flow:

```
POST /api/sessions
  { "prompt": "fix this 503", "context": "<app logs / request info>" }
  -> { "id": "<token>", "url": "/?session=<token>" }
```

Opening the returned URL launches a new tab that runs `claude` and pipes
the combined context+prompt into its stdin. The session id is consumed on
first use.

This is intentionally minimal — the intent is that openhost error pages
(503 from openhost or from an app) can POST request info and app logs
here and then link the user to a pre-loaded Claude session.

## Running locally without openhost

```
pip install quart hypercorn
python3 server.py
```

Then open http://localhost:5000.
