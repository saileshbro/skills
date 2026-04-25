#!/usr/bin/env bash
# audit-use-effect.sh
#
# Find every useEffect in the project, classify it, and suggest the right
# replacement pattern from references/side-effects.md.
#
# Read-only. No edits. Output is a per-call report.
#
# Usage:
#   audit-use-effect.sh                # scan src/, app/, components/
#   audit-use-effect.sh path/to/dir    # scan a specific dir

set -euo pipefail

SCAN_PATHS=("$@")
if [[ ${#SCAN_PATHS[@]} -eq 0 ]]; then
  SCAN_PATHS=()
  for d in src app components screens features; do
    [[ -d "$d" ]] && SCAN_PATHS+=("$d")
  done
fi
[[ ${#SCAN_PATHS[@]} -eq 0 ]] && SCAN_PATHS=(.)

# ripgrep preferred, grep fallback
if command -v rg >/dev/null 2>&1; then
  GREP_CMD=(rg --no-heading --line-number --color=never -t ts -t tsx)
else
  GREP_CMD=(grep -rn --include='*.ts' --include='*.tsx')
fi

# ---------- find all useEffect call sites ----------

CALLS=$("${GREP_CMD[@]}" 'useEffect\s*\(' "${SCAN_PATHS[@]}" 2>/dev/null || true)
TOTAL=$(echo "$CALLS" | grep -c . || true)

echo "=== react-native-modern-specs · audit-use-effect ==="
echo
echo "scanning: ${SCAN_PATHS[*]}"
echo "found:    $TOTAL useEffect call sites"
echo

if [[ $TOTAL -eq 0 ]]; then
  echo "clean. no useEffect to audit."
  exit 0
fi

# ---------- classifier ----------

# For each match, read 8 lines starting at the match line and pattern-match
# against known anti-patterns.

classify() {
  local file="$1" line="$2"
  local snippet
  snippet=$(awk "NR>=${line} && NR<=${line}+8" "$file" 2>/dev/null || true)

  # order matters — most specific first
  if   echo "$snippet" | grep -qE 'navigation\.(navigate|replace|push|goBack)'; then
    echo "navigate-in-effect|move into event handler OR conditional stack rendering (navigation.md)"
  elif echo "$snippet" | grep -qE 'fetch\(|axios\.|\.json\(\)'; then
    echo "fetch-in-effect|use @tanstack/react-query / swr / Expo Router data loader (side-effects.md #2)"
  elif echo "$snippet" | grep -qE 'setState|set[A-Z][a-zA-Z]+\(' && \
       echo "$snippet" | grep -qE '\}, \[[a-zA-Z]'; then
    echo "setstate-from-prop|derive inline OR lift to single state OR use key-reset (side-effects.md #1, #5)"
  elif echo "$snippet" | grep -qE 'analytics|track\(|log\(|screenView'; then
    echo "analytics-on-mount|use useFocusEffect for screen views, or store subscribe (navigation.md, side-effects.md #4)"
  elif echo "$snippet" | grep -qE 'AppState|addListener|addEventListener|subscribe\('; then
    echo "subscription|legitimate IF no library hook exists. add comment explaining why."
  elif echo "$snippet" | grep -qE 'setTimeout|setInterval'; then
    echo "timer|legitimate IF cleanup is present. verify return () => clearTimeout/clearInterval."
  elif echo "$snippet" | grep -qE 'useEffect\(\s*\(\)\s*=>\s*\{[^}]*\},\s*\[\]\s*\)'; then
    echo "mount-only|consider a useMountEffect helper for clarity. legitimate if imperative setup."
  else
    echo "unclassified|read the code — does it match any of the 5 patterns in side-effects.md?"
  fi
}

# ---------- emit report ----------

declare -A COUNTS
echo "$CALLS" | while IFS= read -r match; do
  [[ -z "$match" ]] && continue
  file=$(echo "$match" | cut -d: -f1)
  line=$(echo "$match" | cut -d: -f2)
  text=$(echo "$match" | cut -d: -f3-)

  IFS='|' read -r tag advice < <(classify "$file" "$line")

  printf "[%s]\n  %s:%s\n  %s\n  → %s\n\n" \
    "$tag" "$file" "$line" "$(echo "$text" | sed 's/^[[:space:]]*//' | cut -c1-100)" "$advice"
done

# summary (counts via second pass since while-subshell loses arrays in bash)
echo "--- summary ---"
echo "$CALLS" | while IFS= read -r match; do
  [[ -z "$match" ]] && continue
  file=$(echo "$match" | cut -d: -f1)
  line=$(echo "$match" | cut -d: -f2)
  IFS='|' read -r tag _ < <(classify "$file" "$line")
  echo "$tag"
done | sort | uniq -c | sort -rn

echo
echo "next: open the highest-count category, apply the matching pattern from references/side-effects.md."
echo "remember: every surviving useEffect needs a one-line // useEffect: <why> comment."
