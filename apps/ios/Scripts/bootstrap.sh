#!/usr/bin/env bash
set -euo pipefail

echo "[bootstrap] Ensuring XcodeGen is installed…"
if ! command -v xcodegen >/dev/null 2>&1; then
  if command -v brew >/dev/null 2>&1; then
    brew install xcodegen
  else
    echo "Homebrew not found. Install Homebrew or XcodeGen manually." >&2
    exit 1
  fi
fi

echo "[bootstrap] Generating Xcode project from Project.yml…"
xcodegen -s /Users/nick/Documents/claude-code-monorepo/apps/ios/Project.yml

echo "[bootstrap] Opening Xcode…"
open ClaudeCode.xcodeproj

echo "[bootstrap] Done."
