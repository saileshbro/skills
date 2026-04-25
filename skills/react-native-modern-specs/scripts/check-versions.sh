#!/usr/bin/env bash
# check-versions.sh
#
# Read package.json (root + workspaces) and tell the model which rules in this
# skill apply at the project's current versions, and which fall back to legacy
# APIs.
#
# Output is a small, model-friendly report. No side effects.
#
# Exit code is always 0 — this is a diagnostic, not a gate.

set -euo pipefail

if [[ ! -f package.json ]]; then
  echo "no package.json in $(pwd)"; exit 0
fi

# ---------- read versions ----------

read_dep() {
  # $1 = package name. checks dependencies + devDependencies + peerDependencies
  # in the root package.json AND in every workspace package.json (apps/*, packages/*).
  # First match wins. Empty string when not found.
  node -e "
    const fs = require('fs');
    const path = require('path');
    const roots = ['.'];
    for (const ws of ['apps', 'packages']) {
      try {
        for (const entry of fs.readdirSync(ws)) {
          const p = path.join(ws, entry);
          if (fs.statSync(p).isDirectory()) roots.push(p);
        }
      } catch {}
    }
    let found = '';
    for (const r of roots) {
      if (found) break;
      try {
        const p = require(path.resolve(r, 'package.json'));
        const all = { ...p.dependencies, ...p.devDependencies, ...p.peerDependencies };
        if (all['$1']) found = all['$1'];
      } catch {}
    }
    process.stdout.write(found);
  " 2>/dev/null
}

# strip leading ^ ~ >= = etc, take the version core
ver() { echo "${1#[\^~>=<]*}" | sed -E 's/[^0-9.].*$//'; }

# semver major
major() { echo "${1%%.*}"; }

RN=$(read_dep "react-native")
EXPO=$(read_dep "expo")
EXPO_ROUTER=$(read_dep "expo-router")
REA=$(read_dep "react-native-reanimated")
REACT=$(read_dep "react")
RNGH=$(read_dep "react-native-gesture-handler")
RNSAC=$(read_dep "react-native-safe-area-context")

# ---------- detect monorepo ----------
IS_MONOREPO=0
if [[ -f pnpm-workspace.yaml ]] \
  || node -e "process.exit(require('./package.json').workspaces?0:1)" 2>/dev/null; then
  IS_MONOREPO=1
fi

# ---------- design system detection ----------
# Search root + every monorepo workspace (apps/*, packages/*) so we don't
# false-negative on Turbo/Bun/pnpm setups where theme dirs live under apps/<name>/.

DS_ROOTS=(".")
for ws in apps/* packages/*; do
  [[ -d "$ws" ]] && DS_ROOTS+=("$ws")
done

# Tailwind v4 ditches tailwind.config.* in favour of a CSS file with
# `@import "tailwindcss"` or `@tailwind base;` directives. Detect by content
# in the conventional globals.css locations (also catches react-native-css /
# NativeWind v5 setups which reuse the same CSS-first config).
has_tailwind_css() {
  # $1 = candidate css file
  [[ -f "$1" ]] || return 1
  grep -qE '^[[:space:]]*@import[[:space:]]+["'\''"]tailwindcss' "$1" 2>/dev/null && return 0
  grep -qE '^[[:space:]]*@tailwind[[:space:]]+(base|components|utilities)' "$1" 2>/dev/null && return 0
  return 1
}

DS_FOUND=()
for root in "${DS_ROOTS[@]}"; do
  prefix=""
  [[ "$root" != "." ]] && prefix="$root/"
  # Config-file based design systems
  [[ -f "$root/tailwind.config.js" || -f "$root/tailwind.config.ts" ]] && DS_FOUND+=("${prefix}tailwind/nativewind (config)")
  [[ -f "$root/tamagui.config.ts"  || -f "$root/tamagui.config.tsx" ]] && DS_FOUND+=("${prefix}tamagui")
  [[ -f "$root/unistyles.config.ts" ]] && DS_FOUND+=("${prefix}unistyles (config)")
  # Tailwind v4 / react-native-css / NativeWind v5: globals.css with @import
  for css in globals.css app/globals.css src/globals.css styles/globals.css src/styles/globals.css global.css src/global.css; do
    if has_tailwind_css "$root/$css"; then
      DS_FOUND+=("${prefix}tailwind v4 (css-first): ${css}")
    fi
  done
  # Local theme dirs
  for d in src/theme src/design-system theme design-system; do
    [[ -d "$root/$d" ]] && DS_FOUND+=("local: ${prefix}${d}/")
  done
done

# Package-based design systems (root + workspace package.jsons via read_dep).
# Order: utility-first, then component libs, then style runtimes.
ds_pkg() {
  if [[ -n "$(read_dep "$1")" ]]; then DS_FOUND+=("$2"); fi
}
ds_pkg "nativewind"                "nativewind (pkg)"
ds_pkg "react-native-css"          "react-native-css (Tailwind v4 RN runtime)"
ds_pkg "uniwind"                   "uniwind"
ds_pkg "react-native-unistyles"    "unistyles (pkg)"
ds_pkg "@shopify/restyle"          "restyle"
ds_pkg "tamagui"                   "tamagui (pkg)"
ds_pkg "@gluestack-ui/themed"      "gluestack-ui"
ds_pkg "@gluestack-ui/nativewind-utils" "gluestack-ui (nativewind)"
ds_pkg "react-native-paper"        "react-native-paper"
ds_pkg "@rneui/themed"             "react-native-elements"
ds_pkg "native-base"               "native-base"
ds_pkg "dripsy"                    "dripsy"
ds_pkg "@stylexjs/stylex"          "stylex"
ds_pkg "@vanilla-extract/css"      "vanilla-extract"
ds_pkg "@tonnic/ui"                "tonnic"
ds_pkg "react-native-reusables"    "shadcn/ui (react-native-reusables)"

# ---------- print report ----------

echo "=== react-native-modern-specs · check-versions ==="
echo
echo "monorepo:        $IS_MONOREPO"
echo "react-native:    ${RN:-(missing)}"
echo "expo:            ${EXPO:-(missing)}"
echo "expo-router:     ${EXPO_ROUTER:-(missing)}"
echo "reanimated:      ${REA:-(missing)}"
echo "react:           ${REACT:-(missing)}"
echo "gesture-handler: ${RNGH:-(missing)}"
echo "safe-area-ctx:   ${RNSAC:-(missing)}"
echo
if [[ ${#DS_FOUND[@]} -gt 0 ]]; then
  echo "design system:   ${DS_FOUND[*]}"
else
  echo "design system:   none detected — skill will recommend creating theme/{colors,spacing,typography}.ts"
fi
echo

# rules table
echo "--- rule applicability ---"

rule() {
  # $1 label, $2 ok (1/0), $3 detail
  local mark="✓"
  if [[ $2 -eq 0 ]]; then mark="✗ legacy"; fi
  printf "  %-50s %s\n" "$1" "$mark"
  if [[ -n "${3:-}" ]]; then printf "    %s\n" "$3"; fi
}

rn_major=$(major "$(ver "${RN:-0}")")
rea_major=$(major "$(ver "${REA:-0}")")
router_major=$(major "$(ver "${EXPO_ROUTER:-0}")")
react_major=$(major "$(ver "${REACT:-0}")")
expo_major=$(major "$(ver "${EXPO:-0}")")

# RN 0.76 → modern style props
if [[ -n "$RN" && "$rn_major" == "0" ]]; then
  rn_minor=$(echo "$(ver "$RN")" | awk -F. '{print $2+0}')
  if [[ $rn_minor -ge 76 ]]; then
    rule "modern style props (boxShadow, gap, filter, mixBlendMode)" 1
  else
    rule "modern style props (boxShadow, gap, filter, mixBlendMode)" 0 "RN < 0.76 — fall back to shadow* stack and margin chains"
  fi
elif [[ "$rn_major" -ge 1 ]]; then
  rule "modern style props (boxShadow, gap, filter, mixBlendMode)" 1
fi

# Reanimated 4 → CSS animations
if [[ -n "$REA" && $rea_major -ge 4 ]]; then
  rule "CSS animations / animationName / keyframes (Reanimated 4)" 1
else
  rule "CSS animations / animationName / keyframes (Reanimated 4)" 0 "use shared values + useAnimatedStyle instead"
fi

# Expo Router 4 → Stack.Protected
if [[ -n "$EXPO_ROUTER" && $router_major -ge 4 ]]; then
  rule "Stack.Protected permission gates" 1
else
  rule "Stack.Protected permission gates" 0 "use conditional stack rendering pattern"
fi

# React 19 → use(), useEffectEvent
if [[ -n "$REACT" && $react_major -ge 19 ]]; then
  rule "use() hook, useEffectEvent, ref-as-prop" 1
else
  rule "use() hook, useEffectEvent, ref-as-prop" 0 "stick to existing escape hatches"
fi

# Expo SDK
if [[ -n "$EXPO" && $expo_major -ge 52 ]]; then
  rule "Expo SDK 52+ features (assumed by skill)" 1
else
  rule "Expo SDK 52+ features (assumed by skill)" 0 "verify rule applicability manually"
fi

# companion deps
[[ -n "$RNGH"  ]] && rule "gesture-handler installed (gestures.md applies)" 1
[[ -n "$RNSAC" ]] && rule "safe-area-context installed (use over RN core SafeAreaView)" 1

echo
echo "tip: run 'scripts/upgrade-versions.sh' if you want to bump to the assumed stack."
