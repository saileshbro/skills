#!/usr/bin/env bash
# Enroll this clone in the repo's shared Git 2.54 config-based hooks.
# Run once after cloning. Idempotent.
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

REQUIRED="2.54.0"
CURRENT="$(git --version | awk '{print $3}')"
if [ "$(printf '%s\n%s\n' "$REQUIRED" "$CURRENT" | sort -V | head -n1)" != "$REQUIRED" ]; then
  echo "[install-hooks] git $CURRENT < $REQUIRED; config-based hooks unsupported." >&2
  exit 1
fi

git config --local --replace-all include.path ../.githooks.gitconfig
chmod +x scripts/skills-sync.sh

echo "[install-hooks] enrolled. Configured hooks:"
git hook list post-commit || true
