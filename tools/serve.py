#!/usr/bin/env python3
"""Serveur local autonome pour MECHA OVERDRIVE — Circuit Zero."""

from __future__ import annotations

import argparse
import contextlib
import http.server
import os
import socket
import socketserver
import sys
import threading
import webbrowser
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class GameRequestHandler(http.server.SimpleHTTPRequestHandler):
    """Sert le dossier du jeu avec des en-têtes adaptés au développement local."""

    def __init__(self, *args: object, **kwargs: object) -> None:
        super().__init__(*args, directory=str(ROOT), **kwargs)

    def end_headers(self) -> None:
        self.send_header("Cache-Control", "no-cache")
        self.send_header("X-Content-Type-Options", "nosniff")
        super().end_headers()

    def log_message(self, fmt: str, *args: object) -> None:
        print(f"[MECHA OVERDRIVE] {fmt % args}")


class ReusableThreadingServer(socketserver.ThreadingMixIn, http.server.HTTPServer):
    allow_reuse_address = True
    daemon_threads = True


def port_is_free(host: str, port: int) -> bool:
    with contextlib.closing(socket.socket(socket.AF_INET, socket.SOCK_STREAM)) as sock:
        sock.settimeout(0.2)
        return sock.connect_ex((host, port)) != 0


def choose_port(host: str, preferred: int) -> int:
    if port_is_free(host, preferred):
        return preferred
    for candidate in range(preferred + 1, preferred + 101):
        if port_is_free(host, candidate):
            return candidate
    raise RuntimeError("Aucun port local disponible dans la plage demandée.")


def main() -> int:
    parser = argparse.ArgumentParser(description="Lance MECHA OVERDRIVE dans le navigateur.")
    parser.add_argument("--host", default="127.0.0.1", help="Adresse locale du serveur")
    parser.add_argument("--port", type=int, default=8080, help="Port préféré")
    parser.add_argument("--no-browser", action="store_true", help="Ne pas ouvrir automatiquement le navigateur")
    args = parser.parse_args()

    try:
        port = choose_port(args.host, args.port)
        server = ReusableThreadingServer((args.host, port), GameRequestHandler)
    except (OSError, RuntimeError) as error:
        print(f"Impossible de démarrer le serveur : {error}", file=sys.stderr)
        return 1

    url = f"http://{args.host}:{port}/index.html"
    print("=" * 68)
    print(" MECHA OVERDRIVE — CIRCUIT ZERO")
    print(f" Jeu disponible sur : {url}")
    print(" Appuyez sur Ctrl+C pour arrêter le serveur.")
    print("=" * 68)

    if not args.no_browser:
        threading.Timer(0.45, lambda: webbrowser.open(url, new=2)).start()

    try:
        server.serve_forever(poll_interval=0.25)
    except KeyboardInterrupt:
        print("\nArrêt du Circuit Zero.")
    finally:
        server.server_close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
