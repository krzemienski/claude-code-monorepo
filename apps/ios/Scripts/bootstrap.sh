#!/usr/bin/env bash
set -euo pipefail

echo "[bootstrap] Ensuring Tuist is installed…"
if ! command -v tuist >/dev/null 2>&1; then
  echo "[bootstrap] Installing Tuist…"
  curl -Ls https://install.tuist.io | bash
fi

echo "[bootstrap] Generating Xcode project from Project.swift…"
cd /Users/nick/Documents/claude-code-monorepo/apps/ios
tuist generate

echo "[bootstrap] Opening Xcode workspace…"
tuist open

echo "[bootstrap] Tuist setup complete!"
echo "[bootstrap] Note: The project uses Tuist as the sole build system."
echo "[bootstrap] Use 'tuist generate' to regenerate the project after changes to Project.swift"
echo "[bootstrap] Use './ios-build.sh' for building, testing, and running the app."
echo "[bootstrap] Done."