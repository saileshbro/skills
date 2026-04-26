#!/usr/bin/env bash
# Post-commit hook: sync all globally installed skills to latest.
# Wired in via Git 2.54 config-based hooks (see .githooks.gitconfig).
# Runs detached so the commit returns immediately.

LOG="/tmp/skills-sync.log"
BUNX="/opt/homebrew/bin/bunx"

if [ ! -x "$BUNX" ]; then
  BUNX="$(command -v bunx 2>/dev/null)"
fi

if [ -z "$BUNX" ]; then
  echo "[skills-sync] bunx not found; skipping" >&2
  exit 0
fi

(
  printf '\n=== %s post-commit skills sync ===\n' "$(date '+%Y-%m-%d %H:%M:%S')"
  "$BUNX" skills@latest update -g -y
) >>"$LOG" 2>&1 &

disown 2>/dev/null || true
exit 0
