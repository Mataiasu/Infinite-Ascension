#!/usr/bin/env python3
"""Infinite Ascension - local Android dev host.

Run this on the development PC next to the exported game executable.
The Android dev APK can then start/stop/query the local game over Wi-Fi.
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


class State:
    def __init__(self, game: Path) -> None:
        self.game = game
        self.process: subprocess.Popen[str] | None = None
        self.lock = threading.Lock()

    def status(self) -> dict:
        with self.lock:
            running = self.process is not None and self.process.poll() is None
            if not running:
                self.process = None
            return {"ok": True, "running": running, "game": str(self.game)}

    def launch(self) -> dict:
        with self.lock:
            if self.process is not None and self.process.poll() is None:
                return {"ok": True, "running": True, "already_running": True}
            if not self.game.exists():
                return {"ok": False, "error": f"Game executable not found: {self.game}"}
            creationflags = getattr(subprocess, "CREATE_NEW_PROCESS_GROUP", 0)
            self.process = subprocess.Popen(
                [str(self.game)],
                cwd=str(self.game.parent),
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                text=True,
                creationflags=creationflags,
            )
            return {"ok": True, "running": True, "pid": self.process.pid}

    def stop(self) -> dict:
        with self.lock:
            if self.process is None or self.process.poll() is not None:
                self.process = None
                return {"ok": True, "running": False, "already_stopped": True}
            self.process.terminate()
            try:
                self.process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                self.process.kill()
            self.process = None
            return {"ok": True, "running": False}


class Handler(BaseHTTPRequestHandler):
    state: State

    def _send(self, status: int, payload: dict) -> None:
        data = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET,POST,OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()
        self.wfile.write(data)

    def do_OPTIONS(self) -> None:
        self._send(204, {})

    def do_GET(self) -> None:
        if self.path == "/status":
            self._send(200, self.state.status())
        else:
            self._send(404, {"ok": False, "error": "not found"})

    def do_POST(self) -> None:
        if self.path == "/launch":
            self._send(200, self.state.launch())
        elif self.path == "/stop":
            self._send(200, self.state.stop())
        else:
            self._send(404, {"ok": False, "error": "not found"})

    def log_message(self, fmt: str, *args: object) -> None:
        print("[Infinite Ascension Host] " + (fmt % args))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--game", default="Infinite-Ascension.exe", help="Path to the Windows game executable")
    parser.add_argument("--port", type=int, default=7777)
    args = parser.parse_args()

    game = Path(args.game).expanduser().resolve()
    state = State(game)
    handler = Handler
    handler.state = state
    server = ThreadingHTTPServer(("0.0.0.0", args.port), handler)
    print(f"Infinite Ascension local host: http://0.0.0.0:{args.port}")
    print(f"Game: {game}")
    print("Endpoints: GET /status, POST /launch, POST /stop")
    print("Keep this terminal open while using the Android dev client.")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        state.stop()
        server.server_close()


if __name__ == "__main__":
    main()
