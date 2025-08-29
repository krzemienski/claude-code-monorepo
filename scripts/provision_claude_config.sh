#!/usr/bin/env bash
set -euo pipefail
if [[ -z "${ANTHROPIC_API_KEY:-}" ]]; then
  echo "[provision] ANTHROPIC_API_KEY not set; skipping config"
  exit 0
fi
HOME_DIR="${HOME:-/home/appuser}"
mkdir -p "${HOME_DIR}/.claude" "${HOME_DIR}/.config/claude"
cat > "${HOME_DIR}/.claude.json" <<JSON
{ "api": { "provider": "anthropic", "apiKeyEnv": "ANTHROPIC_API_KEY" }, "auth": { "source": "env" } }
JSON
cat > "${HOME_DIR}/.config/claude/settings.json" <<JSON
{ "api": { "provider": "anthropic", "apiKeyEnv": "ANTHROPIC_API_KEY" }, "auth": { "source": "env" } }
JSON
echo "[provision] wrote CLI settings"
