#!/usr/bin/env bash
set -euo pipefail

ts() { date -Iseconds; }
echo "$(ts) [entrypoint] Claude Code API starting on port ${PORT:-8000}"

# Best-effort: provision CLI config from env for headless runs
if [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
  /bin/bash -lc "/workspace/../scripts/provision_claude_config.sh" || true
  echo "$(ts) [entrypoint] ANTHROPIC_API_KEY detected (len=${#ANTHROPIC_API_KEY})"
else
  echo "$(ts) [entrypoint] WARNING: ANTHROPIC_API_KEY not set."
fi

cd /opt/claude-code-api
exec uvicorn claude_code_api.main:app --host 0.0.0.0 --port "${PORT:-8000}"
