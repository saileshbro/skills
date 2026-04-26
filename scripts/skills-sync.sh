#!/usr/bin/env bash
# reference-transaction hook: sync globally installed skills after a
# successful push (detected via update to refs/remotes/origin/*).
# Also fires on fetch — accepted: sync is idempotent and runs detached.
#
# Wired in via Git 2.54 config-based hooks (see .githooks.gitconfig).
# Hook contract: $1 is the transaction phase (prepared|committed|aborted).
# Stdin streams "<oldvalue> <newvalue> <refname>" lines.

PHASE="${1:-}"
LOG="/tmp/skills-sync.log"

# Read all ref updates so Git doesn't hit SIGPIPE.
TRIGGER=0
while read -r _oldval _newval refname; do
  case "$refname" in
    refs/remotes/origin/*) [ "$PHASE" = "committed" ] && TRIGGER=1 ;;
  esac
done

[ "$TRIGGER" -eq 1 ] || exit 0

BUNX="/opt/homebrew/bin/bunx"
[ -x "$BUNX" ] || BUNX="$(command -v bunx 2>/dev/null)"
if [ -z "$BUNX" ]; then
  echo "[skills-sync] bunx not found; skipping" >&2
  exit 0
fi

(
  printf '\n=== %s post-push skills sync (ref-tx) ===\n' "$(date '+%Y-%m-%d %H:%M:%S')"
  "$BUNX" skills@latest update -g -y
) >>"$LOG" 2>&1 &

disown 2>/dev/null || true
exit 0
