#!/usr/bin/env bash
# Deploy from your machine without CI: copy the project to the server and build there.
#
#   deploy/scripts/deploy.sh user@server [app-name]
#
# The server needs deploy/.env (and deploy/app.env if the app has variables) —
# they are never copied from here by this script, so secrets are not overwritten.
set -euo pipefail

HOST="${1:?usage: deploy.sh user@server [app-name]}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
NAME="${2:-$(basename "$ROOT")}"
DEST="/opt/apps/$NAME"

ssh "$HOST" "mkdir -p '$DEST'"
rsync -az --delete \
  --exclude .git --exclude node_modules --exclude .venv --exclude __pycache__ \
  --exclude .next --exclude dist --exclude build \
  --exclude 'deploy/.env' --exclude 'deploy/app.env' --exclude 'deploy/backups' \
  "$ROOT/" "$HOST:$DEST/"
ssh "$HOST" "cd '$DEST/deploy' && test -f .env || { echo 'missing $DEST/deploy/.env on the server' >&2; exit 1; } \
  && docker compose up -d --build --remove-orphans && docker image prune -f >/dev/null && docker compose ps"
