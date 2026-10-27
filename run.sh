#!/usr/bin/env bash
# Igual que run.ps1, para quien trabaje desde Git Bash.
#
#   ./run.sh              -> Chrome en el puerto 5000
#   ./run.sh windows      -> escritorio
#   ./run.sh chrome 8080  -> otro puerto
set -euo pipefail

dispositivo="${1:-chrome}"
puerto="${2:-5000}"
config="env/dev.json"

if [ ! -f "$config" ]; then
  echo "Falta $config. Copia env/example.json y pon tus claves." >&2
  echo "Las encuentras en el panel de Supabase, en Settings -> API." >&2
  exit 1
fi

args=(run -d "$dispositivo" "--dart-define-from-file=$config")
case "$dispositivo" in
  chrome|edge|web-server) args+=(--web-port "$puerto") ;;
esac

echo "flutter ${args[*]}"
exec flutter "${args[@]}"
