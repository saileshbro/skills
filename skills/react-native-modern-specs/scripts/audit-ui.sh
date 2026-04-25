#!/usr/bin/env bash
# audit-ui.sh
#
# One-shot UI audit for an Expo / React Native project. Combined because the
# fixes overlap and a single pass is friendlier than three separate scripts.
#
# Checks performed:
#   1. inline styles (`style={{ ... }}`) — flag and (with --apply) suggest move to StyleSheet.create
#   2. legacy shadow stack (shadowColor/shadowOffset/shadowOpacity/shadowRadius/elevation)
#      → suggest single `boxShadow` string
#   3. margin chains between siblings → suggest `gap` on the parent flex container
#   4. legacy SafeAreaView from 'react-native' → suggest 'react-native-safe-area-context'
#   5. TouchableOpacity / TouchableHighlight / TouchableWithoutFeedback → suggest `Pressable`
#   6. ScrollView with .map(             → suggest FlatList / FlashList
#   7. accessibility: Pressable / Touchable* without accessibilityLabel and accessibilityRole
#   8. design-system detection — if a DS exists, recommend migrating values to tokens
#
# Default mode: report only. Re-run with --apply to attempt safe in-place
# rewrites for items 4, 5 (import + JSX rename only, keeps props). Items 1, 2,
# 3, 6 are reported only because correct migration needs human review.
#
# Refuses to --apply on a dirty git tree.
#
# Usage:
#   audit-ui.sh                 # report
#   audit-ui.sh --apply         # report + safe rewrites
#   audit-ui.sh src/screens     # narrow scope

set -euo pipefail

APPLY=0
PATHS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply) APPLY=1; shift ;;
    -h|--help)
      sed -n '1,40p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) PATHS+=("$1"); shift ;;
  esac
done

if [[ ${#PATHS[@]} -eq 0 ]]; then
  PATHS=()
  # Source roots to scan: root + each monorepo workspace (apps/*, packages/*).
  SCAN_ROOTS=(".")
  for ws in apps/* packages/*; do
    [[ -d "$ws" ]] && SCAN_ROOTS+=("$ws")
  done
  for root in "${SCAN_ROOTS[@]}"; do
    prefix=""
    [[ "$root" != "." ]] && prefix="$root/"
    for d in src app components screens features; do
      [[ -d "$root/$d" ]] && PATHS+=("${prefix}${d}")
    done
  done
  [[ ${#PATHS[@]} -eq 0 ]] && PATHS=(.)
fi

if [[ $APPLY -eq 1 ]]; then
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "error: --apply requires a git repo" >&2; exit 3
  fi
  if [[ -n "$(git status --porcelain)" ]]; then
    echo "error: working tree dirty. commit or stash before --apply." >&2; exit 3
  fi
fi

if command -v rg >/dev/null 2>&1; then
  RG=(rg --no-heading --line-number --color=never -tts -ttsx)
else
  RG=(grep -rn --include='*.ts' --include='*.tsx')
fi

section() { echo; echo "=== $* ==="; }
count() { wc -l | tr -d ' '; }

# ---------- design system detection ----------

section "design system"
DS_LIST=()
# Search root + each monorepo workspace; theme dirs in Turbo/Bun/pnpm setups
# typically live under apps/<name>/src/theme, not the repo root.
DS_ROOTS=(".")
for ws in apps/* packages/*; do
  [[ -d "$ws" ]] && DS_ROOTS+=("$ws")
done

# Tailwind v4 ditches tailwind.config.* in favour of a CSS file with
# `@import "tailwindcss"` or `@tailwind base;` directives. NativeWind v5 +
# react-native-css follow the same CSS-first config.
has_tailwind_css() {
  [[ -f "$1" ]] || return 1
  grep -qE '^[[:space:]]*@import[[:space:]]+["'\''"]tailwindcss' "$1" 2>/dev/null && return 0
  grep -qE '^[[:space:]]*@tailwind[[:space:]]+(base|components|utilities)' "$1" 2>/dev/null && return 0
  return 1
}

for root in "${DS_ROOTS[@]}"; do
  prefix=""
  [[ "$root" != "." ]] && prefix="$root/"
  [[ -f "$root/tailwind.config.js" || -f "$root/tailwind.config.ts" ]] && DS_LIST+=("${prefix}tailwind/nativewind (config)  → migrate hex/spacing values to Tailwind classes (className=...)")
  [[ -f "$root/tamagui.config.ts"  || -f "$root/tamagui.config.tsx" ]] && DS_LIST+=("${prefix}tamagui              → migrate to <Stack>/<Text> with theme tokens (\$bg, \$space.4, ...)")
  [[ -f "$root/unistyles.config.ts" ]] && DS_LIST+=("${prefix}unistyles (config)   → migrate to createStyleSheet + theme.colors / theme.space")
  for css in globals.css app/globals.css src/globals.css styles/globals.css src/styles/globals.css global.css src/global.css; do
    if has_tailwind_css "$root/$css"; then
      DS_LIST+=("${prefix}tailwind v4 (${css})  → migrate hex/spacing to className=…; tokens live in @theme block of the css file")
    fi
  done
  for d in src/theme src/design-system theme design-system; do
    [[ -d "$root/$d" ]] && DS_LIST+=("local theme dir: ${prefix}${d}/  → reuse existing tokens; do not introduce parallel constants")
  done
done

# Package-based design systems. Read root + workspace package.jsons.
has_pkg() {
  node -e "
    const fs = require('fs'); const path = require('path');
    const roots = ['.'];
    for (const ws of ['apps','packages']) {
      try { for (const e of fs.readdirSync(ws)) {
        const p = path.join(ws,e);
        if (fs.statSync(p).isDirectory()) roots.push(p);
      } } catch {}
    }
    let hit = 0;
    for (const r of roots) {
      try {
        const p = require(path.resolve(r, 'package.json'));
        const all = { ...p.dependencies, ...p.devDependencies };
        if (all['$1']) { hit = 1; break; }
      } catch {}
    }
    process.exit(hit?0:1);
  " 2>/dev/null
}
ds_pkg() {
  if has_pkg "$1"; then DS_LIST+=("$2"); fi
}
ds_pkg "nativewind"                "nativewind (pkg)         → className=… with Tailwind tokens"
ds_pkg "react-native-css"          "react-native-css         → Tailwind v4 RN runtime; use className with tokens from globals.css @theme"
ds_pkg "uniwind"                   "uniwind                  → utility-first; use uniwind class strings, do not hand-roll StyleSheet"
ds_pkg "react-native-unistyles"    "unistyles (pkg)          → createStyleSheet + theme.colors / theme.space"
ds_pkg "@shopify/restyle"          "restyle                  → themed components (<Box bg=\"surface\">)"
ds_pkg "tamagui"                   "tamagui (pkg)            → <Stack>/<Text> with \$tokens"
ds_pkg "@gluestack-ui/themed"      "gluestack-ui             → use <Box>/<VStack> primitives with theme config"
ds_pkg "@gluestack-ui/nativewind-utils" "gluestack-ui (nativewind) → className tokens via gluestack utils"
ds_pkg "react-native-paper"        "react-native-paper       → use Paper components + theme provider"
ds_pkg "@rneui/themed"             "react-native-elements    → ThemeProvider + makeStyles"
ds_pkg "native-base"               "native-base              → use NB primitives (legacy; consider migration)"
ds_pkg "dripsy"                    "dripsy                   → sx prop with theme scales"
ds_pkg "@stylexjs/stylex"          "stylex                   → stylex.create + stylex.props"
ds_pkg "@vanilla-extract/css"      "vanilla-extract          → .css.ts files with createTheme"
ds_pkg "@tonnic/ui"                "tonnic                   → tonnic primitives + tokens"
ds_pkg "react-native-reusables"    "shadcn/ui (rnr)          → composed primitives with className via nativewind"

if [[ ${#DS_LIST[@]} -gt 0 ]]; then
  echo "detected:"
  printf "  - %s\n" "${DS_LIST[@]}"
  echo
  echo "rule: when migrating values below, prefer existing tokens over hardcoded literals."
else
  echo "no design system detected."
  echo "rule: before bulk-migrating, scaffold theme/{colors,spacing,typography}.ts"
  echo "      so we don't sprinkle fresh literals across the codebase."
fi

# ---------- 1. inline styles ----------

section "1. inline styles  (rule: StyleSheet.create at module scope)"
INLINE=$("${RG[@]}" 'style=\{\{' "${PATHS[@]}" 2>/dev/null | grep -vE '/\*|//' || true)
N=$(echo "$INLINE" | grep -c . || true)
echo "$N occurrences"
if [[ $N -gt 0 ]]; then
  echo "$INLINE" | head -20
  [[ $N -gt 20 ]] && echo "... ($((N-20)) more)"
  echo "fix: extract to const styles = StyleSheet.create({...}) at module scope."
  echo "     dynamic-only values can stay inline as a single composed entry: style={[styles.x, { width: w }]}"
fi

# ---------- 2. legacy shadow stack ----------

section "2. legacy shadow props  (rule: prefer single boxShadow string)"
SHADOW=$("${RG[@]}" 'shadowColor:|shadowOffset:|shadowOpacity:|shadowRadius:|elevation:' "${PATHS[@]}" 2>/dev/null || true)
N=$(echo "$SHADOW" | grep -c . || true)
echo "$N occurrences"
if [[ $N -gt 0 ]]; then
  echo "$SHADOW" | head -20
  [[ $N -gt 20 ]] && echo "... ($((N-20)) more)"
  echo "fix: replace the 4-prop stack with a single line —"
  echo "     boxShadow: \"0 4px 24px rgba(0,0,0,0.15)\""
  echo "     skip if RN < 0.76 (run scripts/check-versions.sh first)."
fi

# ---------- 3. margin chains → gap ----------

section "3. potential margin chains  (rule: prefer gap on flex parents)"
# Heuristic: marginRight or marginBottom on multiple siblings within a 30-line window.
MARGIN=$("${RG[@]}" 'marginRight:|marginBottom:|marginTop:|marginLeft:' "${PATHS[@]}" 2>/dev/null || true)
N=$(echo "$MARGIN" | grep -c . || true)
echo "$N margin* occurrences (heuristic — review which are siblings in a flex row/column)"
if [[ $N -gt 0 ]]; then
  echo "$MARGIN" | head -15
  [[ $N -gt 15 ]] && echo "... ($((N-15)) more)"
  echo "fix: where these are siblings inside a flex container, drop the margins and"
  echo "     put gap/rowGap/columnGap on the parent."
fi

# ---------- 4. SafeAreaView from 'react-native' ----------

section "4. legacy SafeAreaView import  (rule: use react-native-safe-area-context)"
LEGACY_SAV=$("${RG[@]}" "SafeAreaView.*from\s+['\"]react-native['\"]|from\s+['\"]react-native['\"].*SafeAreaView" "${PATHS[@]}" 2>/dev/null || true)
N=$(echo "$LEGACY_SAV" | grep -c . || true)
echo "$N occurrences"
if [[ $N -gt 0 ]]; then
  echo "$LEGACY_SAV"
  echo "fix: import SafeAreaView from 'react-native-safe-area-context'"
  if [[ $APPLY -eq 1 ]]; then
    echo "applying..."
    echo "$LEGACY_SAV" | cut -d: -f1 | sort -u | while read -r f; do
      # Only rewrites pure SafeAreaView imports; mixed imports left for human.
      sed -i.bak -E "s|import \{ ?SafeAreaView ?\} from ['\"]react-native['\"]|import { SafeAreaView } from 'react-native-safe-area-context'|g" "$f"
      rm -f "${f}.bak"
    done
    echo "done. verify with git diff."
  fi
fi

# ---------- 5. Touchable* → Pressable ----------

section "5. legacy Touchable* components  (rule: prefer Pressable)"
TOUCH=$("${RG[@]}" '<TouchableOpacity|<TouchableHighlight|<TouchableWithoutFeedback' "${PATHS[@]}" 2>/dev/null || true)
N=$(echo "$TOUCH" | grep -c . || true)
echo "$N occurrences"
if [[ $N -gt 0 ]]; then
  echo "$TOUCH" | head -20
  [[ $N -gt 20 ]] && echo "... ($((N-20)) more)"
  echo "fix: replace component, keep props (most are compatible). For press feedback,"
  echo "     migrate the activeOpacity prop to style={({pressed}) => [...]}"
  if [[ $APPLY -eq 1 ]]; then
    echo "skipping --apply for Touchables: prop semantics differ enough that automatic"
    echo "rewrites tend to silently change press feedback. open each file manually."
  fi
fi

# ---------- 6. ScrollView + .map() ----------

section "6. ScrollView with .map()  (rule: virtualize lists)"
# Find files that contain both <ScrollView and .map(
SCROLL=$("${RG[@]}" -l '<ScrollView' "${PATHS[@]}" 2>/dev/null || true)
SUSPECT=""
if [[ -n "$SCROLL" ]]; then
  SUSPECT=$(echo "$SCROLL" | while read -r f; do
    grep -lE '\.map\(' "$f" 2>/dev/null || true
  done)
fi
N=$(echo "$SUSPECT" | grep -c . || true)
echo "$N files contain both <ScrollView and .map()"
if [[ $N -gt 0 ]]; then
  echo "$SUSPECT" | head -20
  echo "fix: if the .map() renders >10 items or unbounded data, switch to FlatList"
  echo "     (or FlashList from @shopify/flash-list) with keyExtractor + memoized renderItem."
fi

# ---------- 7. accessibility ----------

section "7. interactive elements without accessibilityLabel / accessibilityRole"
INTERACTIVE_FILES=$("${RG[@]}" -l '<Pressable|<TouchableOpacity|<TouchableHighlight|<TouchableWithoutFeedback' "${PATHS[@]}" 2>/dev/null || true)
A11Y_MISS=0
if [[ -n "$INTERACTIVE_FILES" ]]; then
  while read -r f; do
    [[ -z "$f" ]] && continue
    # Per-component scan: rough heuristic — find <Pressable...> opening tags that
    # don't carry accessibilityLabel within 8 lines.
    awk '
      /<(Pressable|TouchableOpacity|TouchableHighlight|TouchableWithoutFeedback)/ {
        start=NR; window=""; depth=0
        for (i=0; i<10 && (getline line)>0; i++) {
          window = window "\n" line
          if (line ~ />/) break
        }
        if (window !~ /accessibilityLabel/ && window !~ /accessibilityRole/) {
          print FILENAME ":" start ":  " window
        }
      }
    ' "$f" 2>/dev/null
  done <<< "$INTERACTIVE_FILES" | head -30
  echo "(showing up to 30 — re-run with narrower path if many)"
fi

# ---------- ts-pattern detection ----------

section "ts-pattern (recommended for exhaustive matching, replaces nested ternaries)"
TSP=$(node -e "const p=require('./package.json');const d={...p.dependencies,...p.devDependencies};process.stdout.write(d['ts-pattern']||'')" 2>/dev/null)
if [[ -n "$TSP" ]]; then
  echo "ts-pattern installed: $TSP"
  TERN=$("${RG[@]}" -c '\?.*:.*\?.*:' "${PATHS[@]}" 2>/dev/null | awk -F: '{s+=$2} END {print s+0}')
  echo "nested ternaries found across files: $TERN"
  echo "candidates for migration → references/ts-pattern.md"
else
  echo "ts-pattern NOT installed."
  echo "consider adding it (catalog dep if monorepo) for type-safe exhaustive matching."
  echo "  bun add ts-pattern         # single repo"
  echo "  add to packages/catalog    # monorepo (reuse across workspaces)"
  echo "see references/ts-pattern.md"
fi

# ---------- summary ----------

section "next steps"
cat <<EOF
1. fix high-count categories first; small ones can ride along.
2. if a design system was detected above, migrate values to its tokens
   instead of reintroducing literals.
3. re-run with --apply once you've reviewed and want the safe rewrites
   (currently SafeAreaView import only).
4. for the heuristic ones (margin chains, ScrollView+.map, ternaries),
   open each suspect file and decide case by case.
EOF
