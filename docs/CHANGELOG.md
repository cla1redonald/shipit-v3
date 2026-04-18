# Changelog

## v3.1.0 (2026-04-18)

### New Features
- **`/shipit-parallel`:** Parallel workstream builder. Takes GitHub issues or a milestone, analyses file dependencies to group into non-conflicting workstreams, spawns isolated engineer agents per workstream (worktree isolation), merges sequentially with integration testing, and opens a single PR when all tests pass.
- `--dry-run` mode shows proposed workstream splits without executing builds
- `--max-agents=N` flag to control parallelism (default 3, max 5)
- Conflict/failure resolution with fix agents (max 2 cycles per workstream)

### Files Added
- `commands/shipit-parallel.md` — full skill definition with v3 template
- `~/.claude/commands/shipit-parallel.md` — command entry point

## v3.0.0 (2026-04-04)

### Breaking Changes
- Agent frontmatter simplified — `permissionMode`, `memory`, `hooks` fields removed
- Agent hooks moved from frontmatter to `.claude/settings.json`
- Stack-specific patterns extracted from agent bodies to `references/`

### New Features
- **Standalone agents:** All 13 agents work in any project, any stack
- **Lifecycle pipeline:** `/spec` -> `/gameplan` -> `/build-feature` -> `/code-review` -> `/shipit`
- **Dual registration:** Agents and skills sync to global fallback paths
- **Plugin health check:** `verify-plugin.sh` and `test-plugin.sh` (10 tests)
- **SessionStart hook:** Auto health check with 24-hour caching
- **Security hooks:** Sensitive file protection + secret detection
- **Anti-rationalization tables:** Every agent and skill has failure-mode guards
- **Exit criteria:** Every agent and skill has explicit definition of done
- **Progressive disclosure:** Stack patterns, team protocol, quality gates in `references/`

### Agent Changes
- All agents: removed "in the ShipIt system" framing, now role-based identity
- All agents: added Default Preferences section (stack guidance, not mandates)
- All agents: added Before Starting section (detect project stack first)
- All agents: added Operating Mode section (standalone + team conditional)
- @researcher: removed Write tool (principle of least privilege)
- @docs: removed Bash tool
- @reviewer: tools reduced to Read, Glob, Grep (deliberately read-only)
- Model assignments documented with rationale

### Skill Changes
- All skills: standardized to consistent template
- All skills: added Anti-Rationalization tables
- All skills: added Exit Criteria and Failure Recovery
- All skills: added cost guidance in When to Use
- `/build-feature`: reads upstream spec/gameplan from pipeline
- New: `/spec` — lightweight feature specification
- New: `/gameplan` — implementation planning

### Token Reduction
Average 58% reduction across agent definitions:

| Agent | v2 Lines | v3 Lines | Reduction |
|-------|----------|----------|-----------|
| retro | 482 | 198 | 59% |
| architect | 363 | 138 | 62% |
| engineer | 350 | 162 | 54% |
| data-engineer | 328 | 82 | 75% |
| designer | 323 | 90 | 72% |
| reviewer | 301 | 81 | 73% |
| docs | 296 | 81 | 73% |
| strategist | 236 | 86 | 64% |
| devsecops | 234 | 82 | 65% |
| researcher | 225 | 95 | 58% |
| qa | 222 | 77 | 65% |
| pm | 190 | 74 | 61% |
| orchestrator | 152 | 146 | 4% |

### Files Added
- `references/` (5 files) — progressive disclosure
- `hooks/session-start.js` — auto health check
- `hooks/block-sensitive-paths.js` — sensitive file protection
- `hooks/detect-secrets.js` — secret pattern detection
- `scripts/verify-plugin.sh` — health check CLI
- `scripts/sync-global.sh` — dual registration sync
- `scripts/test-plugin.sh` — automated test suite
- `commands/spec.md` — new lifecycle skill
- `commands/gameplan.md` — new lifecycle skill
- `commands/build-feature.md` — moved from global skills to plugin
- `docs/shipit-reference.md` — v3 reference tables
- `docs/CHANGELOG.md` — this file
