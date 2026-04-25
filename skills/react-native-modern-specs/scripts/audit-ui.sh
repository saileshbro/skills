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
  for d in src app components screens features; do
    [[ -d "$d" ]] && PATHS+=("$d")
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
[[ -f tailwind.config.js || -f tailwind.config.ts ]] && DS_LIST+=("tailwind/nativewind  → migrate hex/spacing values to Tailwind classes (className=...)")
[[ -f tamagui.config.ts  || -f tamagui.config.tsx ]] && DS_LIST+=("tamagui              → migrate to <Stack>/<Text> with theme tokens (\$bg, \$space.4, ...)")
[[ -f unistyles.config.ts ]] && DS_LIST+=("unistyles            → migrate to createStyleSheet + theme.colors / theme.space")
node -e "const p=require('./package.json');const d={...p.dependencies,...p.devDependencies};process.exit(d['@shopify/restyle']?0:1)" 2>/dev/null \
  && DS_LIST+=("restyle              → migrate to themed components (<Box bg=\"surface\">)")
for d in src/theme src/design-system theme design-system; do
  [[ -d "$d" ]] && DS_LIST+=("local theme dir: $d/  → reuse existing tokens; do not introduce parallel constants")
done

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
