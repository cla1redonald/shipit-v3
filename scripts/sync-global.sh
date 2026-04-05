#!/usr/bin/env bash
set -euo pipefail

# Sync ShipIt agents and skills to global fallback locations.
# Run after editing any agent or command definition.

SHIPIT_DIR="${HOME}/shipit-v3"
GLOBAL_AGENTS="${HOME}/.claude/agents"
GLOBAL_SKILLS="${HOME}/.claude/skills"

echo "Syncing ShipIt to global fallbacks..."

# Sync agents: direct copy
mkdir -p "$GLOBAL_AGENTS"
synced=0
for f in "$SHIPIT_DIR"/agents/*.md; do
  [ -f "$f" ] || continue
  name=$(basename "$f")
  cp "$f" "$GLOBAL_AGENTS/$name"
  synced=$((synced + 1))
done
echo "  Agents: $synced synced to $GLOBAL_AGENTS/"

# Sync commands: transform to skill directory structure
# commands/foo.md -> ~/.claude/skills/foo/SKILL.md
synced=0
for f in "$SHIPIT_DIR"/commands/*.md; do
  [ -f "$f" ] || continue
  name=$(basename "$f" .md)
  mkdir -p "$GLOBAL_SKILLS/$name"
  cp "$f" "$GLOBAL_SKILLS/$name/SKILL.md"
  synced=$((synced + 1))
done
echo "  Skills: $synced synced to $GLOBAL_SKILLS/"

echo "Done."
