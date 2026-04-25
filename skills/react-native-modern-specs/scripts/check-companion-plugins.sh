#!/usr/bin/env bash
# check-companion-plugins.sh
#
# Verify that the two companion plugins this skill defers to are installed.
# If not, print install commands.
#
# Plugins:
#   - expo/skills                      (Expo official: deployment, EAS, modules, etc.)
#   - software-mansion-labs/skills     (Software Mansion: deep RN topics, radon-mcp, typegpu)

set -euo pipefail

CC_DIR="${CLAUDE_CODE_DIR:-$HOME/.claude}"

echo "=== react-native-modern-specs · check-companion-plugins ==="
echo "claude code dir: $CC_DIR"
echo

found_expo=0
found_sm=0

# Look for any plugin directory or skill symlink hinting at these two repos.
# Different installs (skills CLI vs marketplaces) put files in different
# places, so we check a few candidates.

candidates=(
  "$CC_DIR/skills"
  "$CC_DIR/plugins"
  "$HOME/.agents/skills"
  "$HOME/.agents/plugins"
)

for d in "${candidates[@]}"; do
  [[ -d "$d" ]] || continue
  if find "$d" -maxdepth 4 -type d \( -iname "*expo*" -o -iname "*expo-skills*" \) 2>/dev/null | grep -q .; then
    found_expo=1
  fi
  if find "$d" -maxdepth 4 -type d \( -iname "*swmansion*" -o -iname "*software-mansion*" -o -iname "react-native-best-practices" -o -iname "radon-mcp" -o -iname "typegpu" \) 2>/dev/null | grep -q .; then
    found_sm=1
  fi
done

status() { [[ $1 -eq 1 ]] && echo "✓ installed" || echo "✗ missing"; }

echo "expo/skills:                    $(status $found_expo)"
echo "software-mansion-labs/skills:   $(status $found_sm)"
echo

if [[ $found_expo -eq 1 && $found_sm -eq 1 ]]; then
  echo "all good. companion plugins are reachable."
  exit 0
fi

echo "--- install commands ---"
[[ $found_expo -eq 0 ]] && cat <<'EOF'
expo/skills (deployment, EAS, modules, Tailwind, native-data-fetching, ...):
  npx skills add expo/skills
  # or
  /plugin marketplace add expo/skills
EOF

[[ $found_sm -eq 0 ]] && cat <<'EOF'
software-mansion-labs/skills (rn-best-practices, radon-mcp, typegpu, expo-horizon):
  npx skills add software-mansion-labs/skills
  # or
  /plugin marketplace add software-mansion-labs/skills
  /plugin install skills@swmansion
EOF

echo
echo "after install, restart Claude Code (or run /reload-plugins) so the skills register."
exit 1
