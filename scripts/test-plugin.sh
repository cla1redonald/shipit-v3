#!/usr/bin/env bash
# ShipIt Plugin Test Suite
# Usage: ./scripts/test-plugin.sh [--quiet]
# Exit 0 = all pass, 1 = failures found

set -euo pipefail

QUIET=0
[[ "${1:-}" == "--quiet" ]] && QUIET=1

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GLOBAL_CLAUDE="$HOME/.claude"

PASS=0
FAIL=0
FAILURES=()

# --------------------------------------------------------------------------
# Helpers
# --------------------------------------------------------------------------

pass() {
  PASS=$((PASS + 1))
  [[ $QUIET -eq 0 ]] && printf "  PASS: %s\n" "$1"
}

fail() {
  FAIL=$((FAIL + 1))
  FAILURES+=("$1: $2")
  [[ $QUIET -eq 0 ]] && printf "  FAIL: %s\n    --> %s\n" "$1" "$2"
}

# Extract YAML frontmatter field value (simple key: value, handles quoted/unquoted)
frontmatter_field() {
  local file="$1" field="$2"
  awk "
    /^---$/ { if (block==0) { block=1; next } else exit }
    block==1 && /^${field}:/ { sub(/^${field}:[[:space:]]*/, \"\"); gsub(/^['\"]|['\"]$/, \"\"); print; exit }
  " "$file"
}

# Check file starts with --- (YAML frontmatter)
has_frontmatter() {
  local file="$1"
  head -1 "$file" | grep -q '^---$'
}

# --------------------------------------------------------------------------
# Header
# --------------------------------------------------------------------------

if [[ $QUIET -eq 0 ]]; then
  echo "ShipIt Plugin Tests"
  echo "-------------------"
  echo ""
  echo "Phase 1: Plugin Health"
fi

# --------------------------------------------------------------------------
# Test 1: Agent frontmatter valid
# --------------------------------------------------------------------------

agent_fm_errors=()
for f in "$PLUGIN_ROOT/agents"/*.md; do
  [[ -f "$f" ]] || continue
  name=$(basename "$f")
  if ! has_frontmatter "$f"; then
    agent_fm_errors+=("$name: missing frontmatter")
    continue
  fi
  for field in name description tools model; do
    val=$(frontmatter_field "$f" "$field")
    if [[ -z "$val" ]]; then
      agent_fm_errors+=("$name: missing field '$field'")
    fi
  done
done

if [[ ${#agent_fm_errors[@]} -eq 0 ]]; then
  pass "Agent frontmatter valid"
else
  fail "Agent frontmatter valid" "$(IFS='; '; echo "${agent_fm_errors[*]}")"
fi

# --------------------------------------------------------------------------
# Test 2: Skill frontmatter valid
# --------------------------------------------------------------------------

skill_fm_errors=()
for f in "$PLUGIN_ROOT/commands"/*.md; do
  [[ -f "$f" ]] || continue
  name=$(basename "$f")
  if ! has_frontmatter "$f"; then
    skill_fm_errors+=("$name: missing frontmatter")
    continue
  fi
  val=$(frontmatter_field "$f" "description")
  if [[ -z "$val" ]]; then
    skill_fm_errors+=("$name: missing field 'description'")
  fi
done

if [[ ${#skill_fm_errors[@]} -eq 0 ]]; then
  pass "Skill frontmatter valid"
else
  fail "Skill frontmatter valid" "$(IFS='; '; echo "${skill_fm_errors[*]}")"
fi

# --------------------------------------------------------------------------
# Test 3: Reference integrity — references/*.md paths in agent bodies exist
# --------------------------------------------------------------------------

ref_errors=()
# Look for patterns like references/something.md in agent bodies
while IFS= read -r line; do
  file=$(echo "$line" | cut -d: -f1)
  ref=$(echo "$line" | grep -oE 'references/[a-zA-Z0-9/_-]+\.md' | head -1)
  [[ -z "$ref" ]] && continue
  full_path="$PLUGIN_ROOT/$ref"
  if [[ ! -f "$full_path" ]]; then
    ref_errors+=("$(basename "$file"): references '$ref' which does not exist")
  fi
done < <(grep -rn 'references/.*\.md' "$PLUGIN_ROOT/agents" 2>/dev/null || true)

if [[ ${#ref_errors[@]} -eq 0 ]]; then
  pass "Reference integrity"
else
  fail "Reference integrity" "$(IFS='; '; echo "${ref_errors[*]}")"
fi

# --------------------------------------------------------------------------
# Test 4: Symlink valid
# --------------------------------------------------------------------------

symlink_path="$GLOBAL_CLAUDE/local-plugins/shipit"
if [[ -L "$symlink_path" ]] && [[ -d "$symlink_path" ]]; then
  pass "Symlink valid"
else
  if [[ ! -L "$symlink_path" ]]; then
    fail "Symlink valid" "$symlink_path does not exist or is not a symlink"
  else
    fail "Symlink valid" "$symlink_path is a broken symlink (target missing or not a directory)"
  fi
fi

# --------------------------------------------------------------------------
# Test 5: Global fallback synced
# --------------------------------------------------------------------------

sync_errors=()

# Every agent should have a copy in ~/.claude/agents/
for f in "$PLUGIN_ROOT/agents"/*.md; do
  [[ -f "$f" ]] || continue
  agent_name=$(basename "$f")
  global_agent="$GLOBAL_CLAUDE/agents/$agent_name"
  if [[ ! -f "$global_agent" ]]; then
    sync_errors+=("agent $agent_name not found in ~/.claude/agents/")
  fi
done

# Every command should have ~/.claude/skills/<name>/SKILL.md
for f in "$PLUGIN_ROOT/commands"/*.md; do
  [[ -f "$f" ]] || continue
  skill_name=$(basename "$f" .md)
  global_skill="$GLOBAL_CLAUDE/skills/$skill_name/SKILL.md"
  if [[ ! -f "$global_skill" ]]; then
    sync_errors+=("command $skill_name not found at ~/.claude/skills/$skill_name/SKILL.md")
  fi
done

if [[ ${#sync_errors[@]} -eq 0 ]]; then
  pass "Global fallback synced"
else
  fail "Global fallback synced" "$(IFS='; '; echo "${sync_errors[*]}")"
fi

# --------------------------------------------------------------------------
# Test 6: Hook scripts exist
# --------------------------------------------------------------------------

hook_errors=()
hooks_json="$PLUGIN_ROOT/hooks/hooks.json"

if [[ ! -f "$hooks_json" ]]; then
  hook_errors+=("hooks/hooks.json not found")
else
  # Extract node script paths from hooks.json: look for "node .../hooks/something.js"
  while IFS= read -r script; do
    # Resolve ${CLAUDE_PLUGIN_ROOT} to PLUGIN_ROOT
    resolved="${script/\$\{CLAUDE_PLUGIN_ROOT\}/$PLUGIN_ROOT}"
    if [[ ! -f "$resolved" ]]; then
      hook_errors+=("hook script not found: $script")
    fi
  done < <(grep -oE '\$\{CLAUDE_PLUGIN_ROOT\}/[a-zA-Z0-9/_-]+\.[a-z]+' "$hooks_json" 2>/dev/null || true)
fi

if [[ ${#hook_errors[@]} -eq 0 ]]; then
  pass "Hook scripts exist"
else
  fail "Hook scripts exist" "$(IFS='; '; echo "${hook_errors[*]}")"
fi

# --------------------------------------------------------------------------
# Test 7: No duplicate names
# --------------------------------------------------------------------------

dup_errors=()

# Collect all names, then check for duplicates using sort
all_names=""
for f in "$PLUGIN_ROOT/agents"/*.md; do
  [[ -f "$f" ]] || continue
  val=$(frontmatter_field "$f" "name")
  [[ -z "$val" ]] && continue
  all_names="$all_names$val"$'\n'
done
for f in "$PLUGIN_ROOT/commands"/*.md; do
  [[ -f "$f" ]] || continue
  val=$(frontmatter_field "$f" "name")
  [[ -z "$val" ]] && val=$(basename "$f" .md)
  all_names="$all_names$val"$'\n'
done

# Find duplicates
dupes=$(echo "$all_names" | sort | uniq -d)
if [[ -z "$dupes" ]]; then
  pass "No duplicate names"
else
  fail "No duplicate names" "duplicates found: $dupes"
fi

# --------------------------------------------------------------------------
# Phase 2
# --------------------------------------------------------------------------

if [[ $QUIET -eq 0 ]]; then
  echo ""
  echo "Phase 2: Skill Contracts"
fi

# --------------------------------------------------------------------------
# Test 8: Template compliance
# --------------------------------------------------------------------------

required_sections=("## When to Use" "## Process" "## Anti-Rationalization" "## Exit Criteria" "## Failure Recovery")
template_errors=()

for f in "$PLUGIN_ROOT/commands"/*.md; do
  [[ -f "$f" ]] || continue
  name=$(basename "$f")
  content=$(< "$f")
  missing=()
  for section in "${required_sections[@]}"; do
    if ! grep -qF "$section" "$f"; then
      missing+=("$section")
    fi
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    template_errors+=("$name missing: $(IFS=', '; echo "${missing[*]}")")
  fi
done

if [[ ${#template_errors[@]} -eq 0 ]]; then
  pass "Template compliance"
else
  fail "Template compliance" "$(IFS='; '; echo "${template_errors[*]}")"
fi

# --------------------------------------------------------------------------
# Test 9: Pipeline inputs/outputs
# --------------------------------------------------------------------------

pipeline_errors=()

# spec.md — must reference docs/specs/ if it exists
spec_cmd="$PLUGIN_ROOT/commands/spec.md"
if [[ -f "$spec_cmd" ]]; then
  if ! grep -qF "docs/specs/" "$spec_cmd"; then
    pipeline_errors+=("spec.md does not reference docs/specs/")
  fi
fi

# gameplan.md — must reference docs/specs/ and docs/gameplans/ if it exists
gameplan_cmd="$PLUGIN_ROOT/commands/gameplan.md"
if [[ -f "$gameplan_cmd" ]]; then
  if ! grep -qF "docs/specs/" "$gameplan_cmd"; then
    pipeline_errors+=("gameplan.md does not reference docs/specs/")
  fi
  if ! grep -qF "docs/gameplans/" "$gameplan_cmd"; then
    pipeline_errors+=("gameplan.md does not reference docs/gameplans/")
  fi
fi

# build-feature.md — must reference docs/gameplans/ or docs/specs/ if it exists
build_cmd="$PLUGIN_ROOT/commands/build-feature.md"
if [[ -f "$build_cmd" ]]; then
  if ! grep -qF "docs/gameplans/" "$build_cmd" && ! grep -qF "docs/specs/" "$build_cmd"; then
    pipeline_errors+=("build-feature.md does not reference docs/gameplans/ or docs/specs/")
  fi
fi

# If none of the pipeline commands exist yet, note it but don't fail
if [[ ! -f "$spec_cmd" ]] && [[ ! -f "$gameplan_cmd" ]] && [[ ! -f "$build_cmd" ]]; then
  pipeline_errors+=("pipeline commands (spec.md, gameplan.md, build-feature.md) not yet created — skipped")
fi

if [[ ${#pipeline_errors[@]} -eq 0 ]]; then
  pass "Pipeline inputs/outputs"
else
  # Treat "skipped" as a warning, not a hard failure
  all_skipped=1
  for e in "${pipeline_errors[@]}"; do
    [[ "$e" != *"skipped"* ]] && all_skipped=0
  done
  if [[ $all_skipped -eq 1 ]]; then
    pass "Pipeline inputs/outputs (skipped — commands not yet created)"
  else
    fail "Pipeline inputs/outputs" "$(IFS='; '; echo "${pipeline_errors[*]}")"
  fi
fi

# --------------------------------------------------------------------------
# Test 10: No broken cross-references between skills
# --------------------------------------------------------------------------

xref_errors=()
# Collect known command names (filename stems) as newline-separated list
known_cmds=""
for f in "$PLUGIN_ROOT/commands"/*.md; do
  [[ -f "$f" ]] || continue
  known_cmds="$known_cmds$(basename "$f" .md)"$'\n'
done

# Scan skill bodies for /command-name patterns that look like skill references
for f in "$PLUGIN_ROOT/commands"/*.md; do
  [[ -f "$f" ]] || continue
  fname=$(basename "$f" .md)
  while IFS= read -r ref; do
    [[ "$ref" == "$fname" ]] && continue
    if ! echo "$known_cmds" | grep -qx "$ref"; then
      xref_errors+=("$(basename "$f"): references /$ref which is not a known command")
    fi
  done < <(grep -oE '`/[a-z][a-z-]+`' "$f" 2>/dev/null | sed 's/`\/\([a-z-]*\)`/\1/' | sort -u || true)
done

if [[ ${#xref_errors[@]} -eq 0 ]]; then
  pass "No broken cross-references"
else
  fail "No broken cross-references" "$(IFS='; '; echo "${xref_errors[*]}")"
fi

# --------------------------------------------------------------------------
# Results
# --------------------------------------------------------------------------

TOTAL=$((PASS + FAIL))

if [[ $QUIET -eq 0 ]]; then
  echo ""
  echo "Results: ${PASS}/${TOTAL} passed"
fi

[[ $FAIL -eq 0 ]] && exit 0 || exit 1
