#!/usr/bin/env sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cd "$SCRIPT_DIR"
PORT="${PORT:-8080}"

echo "MECHA OVERDRIVE — Circuit Zero 1.0.0"
echo "Le lanceur choisit un port local disponible et ouvre le jeu."
echo "Utilisez Ctrl+C pour arrêter le serveur."

if command -v node >/dev/null 2>&1; then
  PORT="$PORT" exec node tools/server.mjs --open
elif command -v python3 >/dev/null 2>&1; then
  exec python3 tools/serve.py --port "$PORT"
elif command -v python >/dev/null 2>&1; then
  exec python tools/serve.py --port "$PORT"
else
  echo "Node.js ou Python 3 est nécessaire pour le serveur local." >&2
  exit 1
fi
