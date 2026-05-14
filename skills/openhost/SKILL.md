---
name: openhost
description: Reference for building and debugging openhost apps. Use when the user mentions openhost, an openhost app, compute_space, the openhost.toml manifest, or asks how openhost routes/builds/runs apps. Reads the curated docs from the cloned openhost repo at $OPENHOST_DIR (default ~/openhost).
---

# openhost reference

This workbench has a cloned copy of the openhost repo. **Always read from the local clone**, not from the web. The clone lives at `$OPENHOST_DIR` (default `~/openhost`).

## Read these first, in order

When the user asks anything openhost-shaped, read these files before answering:

1. `~/openhost/claude.md` — project orientation, structure, how to run tests.
2. `~/openhost/style_guide.md` — code style for the repo.
3. `~/openhost/README.md` — user-facing overview.
4. `~/openhost/docs/` — design docs and specs (list the directory, then read what's relevant).
5. `~/openhost/apps/test_app/` — minimal example app (Dockerfile + openhost.toml + server.py).

## Building a new openhost app

A minimal app is three files in `apps/<name>/`:
- `openhost.toml` — manifest (name, port, health_check, resources).
- `Dockerfile` — how to build the container image.
- a server that listens on the port and serves the health_check route.

For a complete tiny example, read `~/openhost/apps/test_app/`.

## Debugging an openhost app

- The router lives in `~/openhost/compute_space/src/compute_space/web/proxy.py`.
- App lifecycle (build, run, route) is in `~/openhost/compute_space/src/compute_space/core/apps.py`.
- Logs / observability code lives under `~/openhost/compute_space/src/compute_space/core/`.

## Things to remember

- `pixi run -e dev pytest -x` for the lightweight test suite. `--run-containers` for the full one.
- Apps are routed by subdomain. Each gets its own user namespace via rootless podman.
- Auth is JWT RS256 — apps verify with a public key passed in as an env var.

## If the clone is missing

If `$OPENHOST_DIR` does not exist, tell the user — the entrypoint normally clones it on first container start. They can clone manually:

```
git clone https://github.com/imbue-openhost/openhost ~/openhost
```
