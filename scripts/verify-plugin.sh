#!/usr/bin/env bash
set -euo pipefail

# ShipIt Plugin Health Check
# Run after Claude Code updates or when things feel broken.

SHIPIT_DIR="${HOME}/shipit-v2"
PLUGIN_LINK="${HOME}/.claude/local-plugins/shipit"
GLOBAL_AGENTS="${HOME}/.claude/agents"
GLOBAL_SKILLS="${HOME}/.claude/skills"
ERRORS=0

green() { printf "\033[32m%s\033[0m" "$1"; }
red() { printf "\033[31m%s\033[0m" "$1"; }
yellow() { printf "\033[33m%s\033[0m" "$1"; }

check() {
  local label="$1" result="$2" detail="$3"
  if [ "$result" = "OK" ]; then
    printf "%-20s $(green "OK")  %s\n" "$label" "$detail"
  elif [ "$result" = "WARN" ]; then
    printf "%-20s $(yellow "WARN")  %s\n" "$label" "$detail"
  else
    printf "%-20s $(red "FAIL")  %s\n" "$label" "$detail"
    ERRORS=$((ERRORS + 1))
  fi
}

echo ""
echo "ShipIt Health Check"
echo "-------------------"

# 1. Symlink
if [ -L "$PLUGIN_LINK" ] && [ -d "$PLUGIN_LINK" ]; then
  target=$(readlink "$PLUGIN_LINK")
  check "Symlink" "OK" "$PLUGIN_LINK -> $target"
else
  check "Symlink" "FAIL" "$PLUGIN_LINK missing or broken. Fix: ln -sf $SHIPIT_DIR $PLUGIN_LINK"
fi

# 2. Plugin manifest
manifest="$SHIPIT_DIR/.claude-plugin/plugin.json"
if [ -f "$manifest" ] && jq empty "$manifest" 2>/dev/null; then
  check "Plugin manifest" "OK" "plugin.json valid"
else
  check "Plugin manifest" "FAIL" "plugin.json missing or invalid JSON. Fix: check $manifest"
fi

# 3. Agent frontmatter
agent_count=0
agent_fail=0
for f in "$SHIPIT_DIR"/agents/*.md; do
  [ -f "$f" ] || continue
  agent_count=$((agent_count + 1))
  frontmatter=$(sed -n '/^---$/,/^---$/p' "$f" | sed '1d;$d')
  for field in name description tools model; do
    if ! echo "$frontmatter" | grep -q "^${field}:"; then
      echo "  Missing '$field' in $(basename "$f")" >&2
      agent_fail=$((agent_fail + 1))
      break
    fi
  done
done
if [ "$agent_fail" -eq 0 ]; then
  check "Agents ($agent_count/$agent_count)" "OK" "All frontmatter parseable"
else
  check "Agents" "FAIL" "$agent_fail agents have invalid frontmatter"
fi

# 4. Commands
cmd_count=0
cmd_fail=0
for f in "$SHIPIT_DIR"/commands/*.md; do
  [ -f "$f" ] || continue
  cmd_count=$((cmd_count + 1))
  frontmatter=$(sed -n '/^---$/,/^---$/p' "$f" | sed '1d;$d')
  if ! echo "$frontmatter" | grep -q "^description:"; then
    echo "  Missing 'description' in $(basename "$f")" >&2
    cmd_fail=$((cmd_fail + 1))
  fi
done
if [ "$cmd_fail" -eq 0 ]; then
  check "Commands ($cmd_count/$cmd_count)" "OK" "All discoverable"
else
  check "Commands" "FAIL" "$cmd_fail commands missing description frontmatter"
fi

# 5. Hook scripts
hook_fail=0
hook_count=0
settings="$SHIPIT_DIR/.claude/settings.json"
if [ -f "$settings" ]; then
  hook_scripts=$(jq -r '.. | .command? // empty' "$settings" 2>/dev/null | grep -oE '\$\{CLAUDE_PLUGIN_ROOT\}/[^ "]+|~/shipit-v2/[^ "]+' | sort -u)
  while IFS= read -r script; do
    [ -z "$script" ] && continue
    resolved=$(echo "$script" | sed "s|\${CLAUDE_PLUGIN_ROOT}|$SHIPIT_DIR|g" | sed "s|~/shipit-v2|$SHIPIT_DIR|g")
    hook_count=$((hook_count + 1))
    if [ ! -f "$resolved" ]; then
      echo "  Missing hook script: $resolved" >&2
      hook_fail=$((hook_fail + 1))
    fi
  done <<< "$hook_scripts"
  if [ "$hook_fail" -eq 0 ]; then
    check "Hooks ($hook_count/$hook_count)" "OK" "All registered in settings.json"
  else
    check "Hooks" "FAIL" "$hook_fail hook scripts missing"
  fi
else
  check "Hooks" "WARN" "No settings.json found at $settings"
fi

# 6. Global fallback sync
sync_fail=0
for f in "$SHIPIT_DIR"/agents/*.md; do
  [ -f "$f" ] || continue
  name=$(basename "$f")
  if [ ! -f "$GLOBAL_AGENTS/$name" ]; then
    echo "  Missing global fallback: $GLOBAL_AGENTS/$name" >&2
    sync_fail=$((sync_fail + 1))
  fi
done
for f in "$SHIPIT_DIR"/commands/*.md; do
  [ -f "$f" ] || continue
  name=$(basename "$f" .md)
  if [ ! -f "$GLOBAL_SKILLS/$name/SKILL.md" ]; then
    echo "  Missing global fallback: $GLOBAL_SKILLS/$name/SKILL.md" >&2
    sync_fail=$((sync_fail + 1))
  fi
done
if [ "$sync_fail" -eq 0 ]; then
  check "Global fallback" "OK" "All agents synced to ~/.claude/agents/"
  check "" "OK" "All skills synced to ~/.claude/skills/"
else
  check "Global fallback" "FAIL" "$sync_fail files not synced. Fix: ./scripts/sync-global.sh"
fi

# 7. Run test suite if it exists
if [ -x "$SHIPIT_DIR/scripts/test-plugin.sh" ]; then
  if "$SHIPIT_DIR/scripts/test-plugin.sh" --quiet 2>/dev/null; then
    check "Tests" "OK" "All checks passing"
  else
    check "Tests" "FAIL" "Run ./scripts/test-plugin.sh for details"
  fi
fi

echo ""
if [ "$ERRORS" -eq 0 ]; then
  echo "Status: $(green "HEALTHY")"
else
  echo "Status: $(red "UNHEALTHY") ($ERRORS issues)"
fi
echo ""
exit "$ERRORS"
