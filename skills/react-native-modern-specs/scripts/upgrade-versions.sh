#!/usr/bin/env bash
# upgrade-versions.sh
#
# Bump dependencies in an Expo / React Native project, then run Expo's own
# checks until the project is healthy or we give up.
#
# Pipeline:
#   1. Detect package manager (bun > pnpm > yarn > npm) and monorepo shape.
#   2. Snapshot package.json, lockfile(s), and (for monorepos) every
#      packages/*/package.json so we can roll back.
#   3. `bunx npm-check-updates -u`        (single repo)
#      `bunx npm-check-updates -uw`       (monorepo — walks workspaces)
#   4. Reinstall dependencies.
#   5. Retry loop (max 3):
#        npx expo install --check
#        npx expo install --fix
#        npx expo-doctor
#      Break when --check and expo-doctor both report clean.
#   6. If still red → prompt user to roll back to the snapshot.
#
# Flags:
#   --no-prompt   Skip the rollback prompt; never roll back automatically.
#   --max-retries N   Override retry count (default 3).
#   --dry-run     Print what would happen, don't run anything destructive.
#
# Exit codes:
#   0  upgrade clean
#   1  upgrade applied but some doctor warnings remain (user opted to keep)
#   2  rolled back to snapshot
#   3  pre-flight failed (dirty git tree, missing deps, etc.)

set -euo pipefail

NO_PROMPT=0
MAX_RETRIES=3
DRY_RUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-prompt)   NO_PROMPT=1; shift ;;
    --max-retries) MAX_RETRIES="$2"; shift 2 ;;
    --dry-run)     DRY_RUN=1; shift ;;
    -h|--help)
      sed -n '1,40p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "unknown flag: $1" >&2; exit 3 ;;
  esac
done

run() {
  if [[ $DRY_RUN -eq 1 ]]; then
    echo "[dry-run] $*"
  else
    echo "+ $*"
    "$@"
  fi
}

# ---------- pre-flight ----------

if [[ ! -f package.json ]]; then
  echo "error: no package.json in $(pwd)" >&2
  exit 3
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "error: not a git repo. refuse to upgrade without rollback safety." >&2
  echo "       run 'git init && git add . && git commit -m initial' first." >&2
  exit 3
fi

if [[ -n "$(git status --porcelain)" ]]; then
  echo "error: working tree is dirty. commit or stash first." >&2
  echo "       upgrade-versions needs a clean tree to roll back cleanly." >&2
  exit 3
fi

# ---------- detect package manager ----------

PM=""
if   [[ -f bun.lock || -f bun.lockb ]]; then PM=bun
elif [[ -f pnpm-lock.yaml ]];           then PM=pnpm
elif [[ -f yarn.lock ]];                then PM=yarn
elif [[ -f package-lock.json ]];        then PM=npm
else
  PM=bun  # user's default per session
fi
echo "package manager: $PM"

# ---------- detect monorepo ----------

IS_MONOREPO=0
if [[ -f pnpm-workspace.yaml ]] \
  || node -e "const p=require('./package.json'); process.exit(p.workspaces?0:1)" 2>/dev/null; then
  IS_MONOREPO=1
fi
echo "monorepo: $IS_MONOREPO"

# ---------- snapshot ----------

SNAP_DIR=".upgrade-snapshot-$(date +%s)"
mkdir -p "$SNAP_DIR"
echo "snapshot dir: $SNAP_DIR"

cp package.json "$SNAP_DIR/package.json"
for lf in bun.lock bun.lockb pnpm-lock.yaml yarn.lock package-lock.json; do
  [[ -f "$lf" ]] && cp "$lf" "$SNAP_DIR/$lf"
done

if [[ $IS_MONOREPO -eq 1 ]]; then
  while IFS= read -r -d '' pj; do
    rel="${pj#./}"
    mkdir -p "$SNAP_DIR/$(dirname "$rel")"
    cp "$pj" "$SNAP_DIR/$rel"
  done < <(find packages apps -maxdepth 3 -name package.json -not -path '*/node_modules/*' -print0 2>/dev/null)
fi

rollback() {
  echo
  echo ">>> rolling back from $SNAP_DIR"
  cp "$SNAP_DIR/package.json" package.json
  for lf in bun.lock bun.lockb pnpm-lock.yaml yarn.lock package-lock.json; do
    [[ -f "$SNAP_DIR/$lf" ]] && cp "$SNAP_DIR/$lf" "$lf"
  done
  if [[ $IS_MONOREPO -eq 1 ]]; then
    (cd "$SNAP_DIR" && find packages apps -name package.json 2>/dev/null) | while read -r rel; do
      cp "$SNAP_DIR/$rel" "$rel"
    done
  fi
  install_deps
  echo "<<< rollback complete"
}

install_deps() {
  case "$PM" in
    bun)  run bun install ;;
    pnpm) run pnpm install ;;
    yarn) run yarn install ;;
    npm)  run npm install ;;
  esac
}

# ---------- upgrade ----------

NCU_FLAGS="-u"
[[ $IS_MONOREPO -eq 1 ]] && NCU_FLAGS="-uw"

echo
echo ">>> running npm-check-updates $NCU_FLAGS"
run bunx npm-check-updates $NCU_FLAGS

echo
echo ">>> reinstalling dependencies"
install_deps

# ---------- expo health loop ----------

attempt=1
healthy=0
last_check_log=""
last_doctor_log=""

while [[ $attempt -le $MAX_RETRIES ]]; do
  echo
  echo "=== attempt $attempt/$MAX_RETRIES ==="

  echo "+ npx expo install --check"
  if [[ $DRY_RUN -eq 0 ]]; then
    if last_check_log=$(npx expo install --check 2>&1); then
      check_ok=1
    else
      check_ok=0
    fi
    echo "$last_check_log"
  else
    check_ok=1
  fi

  if [[ ${check_ok:-1} -eq 0 ]]; then
    echo "+ npx expo install --fix"
    run npx expo install --fix || true
  fi

  echo "+ npx expo-doctor"
  if [[ $DRY_RUN -eq 0 ]]; then
    if last_doctor_log=$(npx expo-doctor 2>&1); then
      doctor_ok=1
    else
      doctor_ok=0
    fi
    echo "$last_doctor_log"
  else
    doctor_ok=1
  fi

  if [[ ${check_ok:-1} -eq 1 && ${doctor_ok:-1} -eq 1 ]]; then
    healthy=1
    break
  fi

  attempt=$((attempt + 1))
done

# ---------- report ----------

echo
echo "============================================================"
if [[ $healthy -eq 1 ]]; then
  echo "RESULT: clean. expo install --check and expo-doctor both pass."
  echo "snapshot kept at $SNAP_DIR (delete when you're confident)."
  exit 0
fi

echo "RESULT: still red after $MAX_RETRIES attempts."
echo
echo "--- last expo install --check ---"
echo "$last_check_log" | tail -40
echo
echo "--- last expo-doctor ---"
echo "$last_doctor_log" | tail -40
echo "============================================================"

if [[ $NO_PROMPT -eq 1 ]]; then
  echo "no-prompt mode: keeping upgrade. snapshot at $SNAP_DIR."
  exit 1
fi

echo
read -r -p "roll back to snapshot $SNAP_DIR? [y/N] " ans
case "${ans:-N}" in
  y|Y|yes|YES) rollback; exit 2 ;;
  *)           echo "keeping upgrade. snapshot at $SNAP_DIR."; exit 1 ;;
esac
