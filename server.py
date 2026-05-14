"""claude-workbench: tabbed web terminals + Claude Code, for building/debugging openhost apps.

Routes:
    GET  /                         -> tabbed terminal UI
    GET  /health                   -> health check
    GET  /terminal/ws              -> WebSocket PTY (one session per connection)
    POST /api/sessions             -> queue a prefilled Claude session; returns {id, url}
                                      body: {"prompt": "...", "context": "..."}
                                      the next WS that connects with ?session=<id> picks it up
"""

from __future__ import annotations

import asyncio
import fcntl
import json
import os
import pty
import secrets
import signal
import struct
import subprocess
import termios
from dataclasses import dataclass, field
from pathlib import Path

from quart import Quart, jsonify, request, send_from_directory, websocket

APP_DIR = Path(__file__).parent
HOME = Path(os.environ.get("HOME", "/home/workbench"))
OPENHOST_DIR = Path(os.environ.get("OPENHOST_DIR", str(HOME / "openhost")))

app = Quart(__name__, template_folder=str(APP_DIR / "templates"), static_folder=str(APP_DIR / "static"))


@dataclass
class PendingSession:
    """A prefilled session waiting for a websocket to attach.

    `command` runs in the PTY at startup. `stdin_seed` is fed to its stdin
    once after launch (used to send a multi-line prompt to `claude`).
    """

    command: list[str]
    stdin_seed: str = ""
    cwd: str | None = None
    env: dict[str, str] = field(default_factory=dict)


_pending: dict[str, PendingSession] = {}


def _set_winsize(fd: int, rows: int, cols: int) -> None:
    fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack("HHHH", rows, cols, 0, 0))


@app.get("/health")
async def health() -> tuple[dict, int]:
    return {"status": "ok"}, 200


@app.get("/")
async def index() -> object:
    return await send_from_directory(str(APP_DIR / "templates"), "index.html")


@app.post("/api/sessions")
async def create_session() -> object:
    """Reserve a prefilled Claude session.

    Returns an id; the frontend opens a new tab whose websocket includes
    ?session=<id>, and we launch `claude` there with the prompt piped in.
    """
    data = await request.get_json(silent=True) or {}
    prompt: str = (data.get("prompt") or "").strip()
    context: str = (data.get("context") or "").strip()
    if not prompt and not context:
        return jsonify({"error": "prompt or context required"}), 400

    seed_parts: list[str] = []
    if context:
        seed_parts.append(f"# Context\n\n{context}\n")
    if prompt:
        seed_parts.append(prompt)
    seed = "\n\n".join(seed_parts) + "\n"

    sid = secrets.token_urlsafe(8)
    _pending[sid] = PendingSession(
        command=["claude"],
        stdin_seed=seed,
        cwd=str(OPENHOST_DIR if OPENHOST_DIR.exists() else HOME),
    )
    return jsonify({"id": sid, "url": f"/?session={sid}"})


@app.websocket("/terminal/ws")
async def terminal_ws() -> None:
    session_id = websocket.args.get("session")
    pending = _pending.pop(session_id, None) if session_id else None

    if pending is not None:
        command = pending.command
        cwd = pending.cwd
        extra_env = pending.env
        stdin_seed = pending.stdin_seed
    else:
        command = ["bash", "-l"]
        cwd = str(OPENHOST_DIR) if OPENHOST_DIR.exists() else str(HOME)
        extra_env = {}
        stdin_seed = ""

    await _bridge_pty(command=command, cwd=cwd, extra_env=extra_env, stdin_seed=stdin_seed)


async def _bridge_pty(
    *, command: list[str], cwd: str | None, extra_env: dict[str, str], stdin_seed: str
) -> None:
    master_fd, slave_fd = pty.openpty()
    _set_winsize(master_fd, 24, 80)

    env = {**os.environ, "TERM": "xterm-256color", **extra_env}
    proc = subprocess.Popen(  # noqa: S603
        command,
        stdin=slave_fd,
        stdout=slave_fd,
        stderr=slave_fd,
        cwd=cwd,
        env=env,
        preexec_fn=os.setsid,
    )
    os.close(slave_fd)

    if stdin_seed:
        # Give the child a moment to set up its TTY before we feed input.
        async def _seed() -> None:
            await asyncio.sleep(0.5)
            try:
                os.write(master_fd, stdin_seed.encode())
            except OSError:
                pass

        asyncio.create_task(_seed())

    loop = asyncio.get_event_loop()

    async def pty_to_ws() -> None:
        try:
            while True:
                data = await loop.run_in_executor(None, os.read, master_fd, 4096)
                if not data:
                    break
                await websocket.send(data)
        except Exception:
            pass

    async def ws_to_pty() -> None:
        try:
            while True:
                msg = await websocket.receive()
                if isinstance(msg, (bytes, bytearray)) and len(msg) > 0:
                    kind = msg[0]
                    payload = bytes(msg[1:])
                    if kind == 0x00:
                        os.write(master_fd, payload)
                    elif kind == 0x01:
                        ctrl = json.loads(payload)
                        if ctrl.get("type") == "resize":
                            _set_winsize(master_fd, int(ctrl["rows"]), int(ctrl["cols"]))
                elif isinstance(msg, str):
                    os.write(master_fd, msg.encode())
        except Exception:
            pass

    def cleanup() -> None:
        try:
            os.kill(proc.pid, signal.SIGHUP)
        except OSError:
            pass
        try:
            os.close(master_fd)
        except OSError:
            pass
        try:
            proc.wait(timeout=2)
        except subprocess.TimeoutExpired:
            try:
                os.kill(proc.pid, signal.SIGKILL)
            except OSError:
                pass

    tasks = [asyncio.create_task(pty_to_ws()), asyncio.create_task(ws_to_pty())]
    try:
        _, pending_tasks = await asyncio.wait(tasks, return_when=asyncio.FIRST_COMPLETED)
        for t in pending_tasks:
            t.cancel()
    finally:
        cleanup()


def main() -> None:
    import hypercorn.asyncio
    import hypercorn.config

    cfg = hypercorn.config.Config()
    cfg.bind = ["0.0.0.0:5000"]
    cfg.accesslog = "-"
    asyncio.run(hypercorn.asyncio.serve(app, cfg))


if __name__ == "__main__":
    main()
