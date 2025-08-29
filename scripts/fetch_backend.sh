#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="$ROOT/services/backend/claude-code-api"
REPO="https://github.com/codingworkflow/claude-code-api.git"
REF="${1:-main}"
if [[ -d "$DEST/.git" ]]; then
  echo "Updating existing checkout at $DEST to $REF..."
  git -C "$DEST" fetch origin
  git -C "$DEST" checkout "$REF"
  git -C "$DEST" reset --hard "$REF"
else
  echo "Cloning backend into $DEST (ref $REF)..."
  rm -rf "$DEST"
  git clone "$REPO" "$DEST"
  git -C "$DEST" checkout "$REF"
fi
echo "Done. Backend available at $DEST"
