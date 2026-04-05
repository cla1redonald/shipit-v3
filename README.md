# ShipIt v3

13 specialist AI agents and 9 composable skills for Claude Code. Build products from idea to shipped software, or call any agent standalone in any project.

## Quick Start

**Install:**
```bash
# ShipIt is already installed as a local plugin
# Verify it's working:
~/shipit-v3/scripts/verify-plugin.sh
```

**Call a single agent:**
```
@architect "Design the data model for a task manager"
@engineer "Add dark mode toggle to settings"
@reviewer "Review the auth implementation"
```

**Run the lifecycle pipeline:**
```
/spec "Add dark mode toggle"        # Capture requirements
/gameplan "Add dark mode toggle"    # Plan the implementation
/build-feature "Add dark mode"      # TDD build pipeline
/code-review                        # Quality + security review
/shipit                             # Test, commit, review, merge
```

**Full orchestrated build:**
```
/orchestrate "build me a mood journal app"
```

## Agents

All agents work standalone in any project. In team mode (via `/orchestrate`), they coordinate automatically.

| Agent | Model | Use For |
|-------|-------|---------|
| @orchestrator | opus | Coordinate full builds |
| @researcher | haiku | Find existing solutions before building |
| @strategist | opus | Turn raw ideas into PRDs |
| @pm | sonnet | Scope decisions, prioritization |
| @architect | opus | System design, data models, API structure |
| @designer | sonnet | UI/UX specifications, design systems |
| @engineer | sonnet | Code implementation |
| @data-engineer | sonnet | Pipelines, ETL, embeddings |
| @devsecops | sonnet | Infrastructure, deployment, security |
| @reviewer | sonnet | Code review, security audit |
| @qa | sonnet | Test strategy, test writing |
| @docs | sonnet | Documentation |
| @retro | opus | Learning graduation (two-tier system) |

## Skills

| Skill | Cost | Use For |
|-------|------|---------|
| `/spec` | None | Capture requirements |
| `/gameplan` | None | Plan implementation |
| `/build-feature` | 3-4 agents | TDD build pipeline |
| `/tdd-build` | 1-2 agents | Lighter TDD workflow |
| `/code-review` | 1 agent | Quality + security review |
| `/prd-review` | None | Validate a PRD |
| `/prd-threads` | None | Break PRD into threads |
| `/orchestrate` | 6-10 agents | Full product build |
| `/shipit` | 3 agents | Enforced commit workflow |

## Lifecycle Pipeline

```
/spec -> /gameplan -> /build-feature -> /code-review -> /shipit
```

Each skill works standalone. They chain via the file system — upstream outputs are read if they exist. Use the full pipeline or any individual skill.

## Standalone vs Team Mode

Agents detect their operating mode automatically:

- **Standalone:** Called directly. Work independently, produce outputs, report back.
- **Team mode:** Detected when `MODE: team` is in the prompt OR TaskList/SendMessage tools are available. Agents follow the shared team protocol for task claiming, communication, and file ownership.

## Resilience

ShipIt survives Claude Code updates with three layers:

1. **Dual registration.** Agents and skills sync to both the plugin path and global fallback paths (`~/.claude/agents/`, `~/.claude/skills/`).
2. **Verification.** `scripts/verify-plugin.sh` checks plugin health after updates.
3. **Automated tests.** `scripts/test-plugin.sh` validates frontmatter, references, hooks, and skill contracts (10 tests).

```bash
# After a Claude update:
~/shipit-v3/scripts/verify-plugin.sh

# If unhealthy:
~/shipit-v3/scripts/sync-global.sh
```

## Cost Guide

| Task | Full Path | Lean Path |
|------|-----------|-----------|
| New product | `/orchestrate` (8+ agents) | Only for building from scratch |
| New feature | `/build-feature` (3-4 agents) | `--skip-architect` if design is clear |
| Bug fix | `/build-feature` | `@engineer` directly |
| Quick review | `/code-review` | `@reviewer` directly |
| Ship it | `/shipit` (full gates) | Git commit + push manually |

## Security

- **Tool allowlists:** Each agent has minimum required tools (e.g., @reviewer is read-only)
- **Sensitive file protection:** PreToolUse hook blocks writes to `~/.claude/settings.json`, `~/.ssh/`, `~/.aws/`, `.env` files
- **Secret detection:** PostToolUse hook warns if written files contain API keys, tokens, or passwords

## References

On-demand reference files loaded by agents when relevant:

| File | Content |
|------|---------|
| `references/team-protocol.md` | Team coordination protocol |
| `references/stack-nextjs-supabase.md` | Next.js + Supabase patterns |
| `references/stack-python-fastapi.md` | Python + FastAPI patterns |
| `references/quality-gates.md` | Triple gate, test requirements |
| `references/commit-conventions.md` | Conventional commits |

## Project Structure

```
~/shipit-v3/
├── agents/          # 13 agent definitions
├── commands/        # 9 skill definitions
├── references/      # On-demand reference material
├── hooks/           # Hook scripts (security, health check)
├── scripts/         # Verify, sync, test scripts
└── docs/            # Reference docs, changelog
```
