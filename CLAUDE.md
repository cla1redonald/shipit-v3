# ShipIt v2 — Agent Instructions

ShipIt is a team of 13 specialist AI agents for building products from idea to shipped software. It uses Claude Code's native **Agent Teams** for parallel work and **Custom Subagents** for focused tasks, with a **hybrid learning system** that improves with every project.

## Request Interpretation

- When the user gives a direct action command (e.g., 'uninstall X', 'commit this', 'push to GitHub'), execute it immediately. Do not ask clarifying questions unless genuinely ambiguous.
- Treat imperative statements as instructions, not conversation starters.

## Agent Orchestration Protocol

When using multi-agent workflows (orchestrator, ShipIt), ALWAYS:
1. Invoke agents via the Task tool — never do agent work directly
2. Run @retro agent after every large multi-file change set
3. Run @docs agent after any architectural or API changes

Never skip these steps even if they seem redundant.

## Agents

All agents are defined in `agents/` with YAML frontmatter. Claude auto-delegates based on task context, or you can invoke directly.

| Agent | Model | Use For |
|-------|-------|---------|
| `@orchestrator` | opus | Coordinate full builds — invoke via `/orchestrate` skill, NOT as subprocess |
| `@researcher` | haiku | Find existing solutions BEFORE building |
| `@strategist` | opus | PRD creation from raw ideas |
| `@pm` | sonnet | Scope decisions, requirements |
| `@architect` | opus | System design, data models |
| `@designer` | sonnet | UI/UX specifications |
| `@engineer` | sonnet | Code implementation |
| `@data-engineer` | sonnet | ETL pipelines, embeddings, vector databases, data seeding |
| `@devsecops` | sonnet | Infrastructure, deployment |
| `@reviewer` | sonnet | Code review, security audit |
| `@qa` | sonnet | Testing strategy, test writing |
| `@docs` | sonnet | Documentation |
| `@retro` | opus | System improvements, memory graduation |

## Skills

| Skill | Use For |
|-------|---------|
| `/orchestrate` | Launch full orchestrated build (orchestrator as main session) |
| `/shipit` | Enforced commit workflow — test, typecheck, build, commit, retro, docs, push, PR, review, retro, merge |
| `/prd-review` | Review and improve a PRD |
| `/code-review` | Structured code review |
| `/prd-threads` | Convert PRD to executable threads |
| `/tdd-build` | Test-driven build — write failing tests first, implement iteratively until green, refactor |
| `/build-feature` | Autonomous TDD pipeline — architect → tests → build (5 iterations max) → QA review → push. Use `--skip-architect` to skip design phase |

> **Note:** If installed as a plugin, commands are invoked with the `shipit:` prefix (e.g., `/shipit:orchestrate`).

## Orchestrator Invocation

The orchestrator is the **only agent that must run as the main conversation** (team lead). All other agents can be spawned as subprocesses by the orchestrator or invoked directly by the user for standalone tasks.

**To start a full build:** `/orchestrate` (or `/shipit:orchestrate`)

**Requirements:**
- **Model:** The orchestrator requires **Opus** (`/model opus`). On other models, the orchestrator fails to delegate and does the work itself.
- **Invocation:** Do NOT spawn @orchestrator via Task tool — it will be unable to delegate because the Task tool only supports single-level nesting. The `/orchestrate` skill loads the orchestrator into the current session so it has full access to Task tool and TeamCreate for delegation.
- **Model passthrough:** When spawning agents, always pass the `model` parameter matching the agent table (e.g., `model: "opus"` for @architect, `model: "sonnet"` for @engineer).

## Agent Teams (Parallel Execution)

The orchestrator uses Agent Teams for parallel phases. Teams use Claude Code's native tools:

| Tool | Purpose |
|------|---------|
| `TeamCreate` | Create a team with shared task list |
| `Task` (with `team_name`, `name`, `mode: "plan"`) | Spawn teammates into the team |
| `TaskCreate` / `TaskUpdate` / `TaskList` | Manage shared work items, assign owners, set dependencies |
| `SendMessage` | Direct messages (`type: "message"`), shutdown (`type: "shutdown_request"`), plan approval (`type: "plan_approval_response"`) |
| `TeamDelete` | Clean up team resources (after all teammates shut down) |

**Phases that use teams:** Design (@architect + @designer), Build (@data-engineer + @engineer x2 + @qa), Polish (@reviewer + @docs + @designer)

> **Note:** @data-engineer is only included in the Build team when the PRD involves external data, embeddings, or vector databases. For projects with no external data needs, the Build team remains `@engineer x3 + @qa`.

**Required setting:** `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` in `.claude/settings.json` (already configured).

Teammates are spawned with `mode: "plan"` (plan before implementing) and `subagent_type: "general-purpose"` (full tool access). The lead uses delegate mode (Shift+Tab) for coordination only. Teammates load CLAUDE.md and project context automatically but do NOT inherit the lead's conversation history.

For focused single-agent tasks (research, PRD creation, infrastructure), the orchestrator uses subagents instead.

## Quality Gates (Hook-Enforced)

Gates are enforced automatically via hooks. No manual checking needed. Hooks are configured in `hooks/hooks.json` and fire for every agent.

| Gate | Type | Enforcement |
|------|------|-------------|
| 1: PRD Approval | HARD | Human approval required |
| 2: Architecture Review | Soft | Warning logged to memory |
| 3: Infrastructure Ready | Soft | Warning logged to memory |
| 4: Code Review + PRD Coverage | Soft | Hook blocks `git push` without review; @reviewer verifies PRD requirements |
| 5: Security Scan | HARD | Hook blocks production deploy |
| 6: Ship Ready | HARD | Hook validates all gates on Stop event |

## Hybrid Learning System

### Tier 1: Persistent Memory (fast, automatic)
Each agent has native persistent memory (managed by Claude Code's `memory: user` setting). Learnings are written immediately and auto-loaded next session.

### Tier 2: Git-Committed Knowledge (durable, shareable)
Proven patterns graduate to `memory/agent/*.md` and `memory/shared/*.md` via @retro. These are version-controlled and loaded via the `skills` frontmatter field.

### Graduation Process
1. Agent writes to persistent memory (Tier 1)
2. Agent messages @retro about significant patterns
3. @retro evaluates and graduates proven patterns to committed files (Tier 2)

## Core Principles (Non-Negotiable)

| Principle | Rule |
|-----------|------|
| **Testing** | Written alongside features, must pass. Enforced by hooks. |
| **Security** | Considered from day one. Enforced by security-scan hook. |
| **Documentation** | If not documented, it doesn't exist. |
| **Consistency** | All related files update together. |

## Identity

Read `SOUL.md` for ShipIt's philosophy and identity. It defines the system's approach to building products, quality standards, and working style.

## Project Location

**Projects are NEVER created inside the shipit-v3 directory.** ShipIt is a framework/plugin, not a workspace. Every project gets its own directory and git repo outside shipit-v3 (e.g., `~/my-project/`).

## Defaults

- **Stack:** TypeScript, Next.js (App Router), Vercel, Supabase, Tailwind CSS, shadcn/ui, GitHub
- **Quality Bar:** Modern polished UI, professional palette, mobile-responsive, core works e2e, not embarrassing to show

## Eliminated Concepts (Do Not Reference)

These concepts were deliberately removed from ShipIt. They must not appear in any file:

| Eliminated Concept | Replacement |
|---|---|
| HANDOFF.md | Native inter-agent messaging |
| Task tool enforcement / hub-and-spoke | Agent Teams + subagents |
| `.shipit/` state directory | Native task list |
| `shipit-sdk/` TypeScript SDK | Eliminated — native features replace it |
| `/shipit-init`, `/shipit-resume`, `/shipit-handoff`, `/shipit-status`, `/shipit-mail` | Eliminated — native features replace them |
| `.claude/commands/` bridge files | Native agent invocation |
| `hooks:` in agent YAML as replacement for global hooks | Global hooks in `hooks/hooks.json`; agent-scoped hooks in agent frontmatter per official docs |
| `lessons-learned.md` (single file) | Hybrid memory system (`memory/shared/` + `memory/agent/`) |

If you find any of these terms in ShipIt files (outside this table), it is a bug. Fix it.

## When to Use What

| Need | Invoke |
|------|--------|
| Single focused task (write code, review, research) | Individual agent (`@engineer`, `@reviewer`, etc.) |
| Multi-perspective exploration or brainstorm | Native Agent Teams — create a team with custom roles |
| Full product build or complex multi-phase feature | `/orchestrate` — loads orchestrator as team lead |
| Autonomous feature build with TDD pipeline | `/build-feature` — architect → tests → build → QA → push. Add `--skip-architect` if codebase is familiar |
| Commit, review, and merge with quality verification | `/shipit` — test, typecheck, build, commit, retro, docs, push, PR, review, retro, merge |

The orchestrator delegates to specialist agents — it never does the work itself. For simple tasks, invoke agents directly without the orchestrator.

## Editing Philosophy

- Make minimal, targeted changes. Do NOT over-engineer or redesign UX unless explicitly asked.
- When fixing a bug, fix ONLY that bug. Do not refactor surrounding code.
- If a change touches more than 3 files, pause and confirm scope with the user before proceeding.
- If a larger refactor seems warranted, propose it first and wait for approval.

## Concurrency Rules

- Parallel agents are limited by task dependencies and file ownership, not an arbitrary cap. Assign explicit file ownership to prevent edit conflicts.
- Use sequential execution when working with APIs or file-heavy operations.
- If you hit API concurrency or rate limit errors, reduce parallelism incrementally rather than retrying the same approach.

## TypeScript & Build

- Primary language is TypeScript. Always check for type errors (`tsc --noEmit`) before committing.
- Use bash 3.2-compatible syntax (no associative arrays) for any shell scripts targeting macOS.
- Use `grep -E` instead of `grep` with complex regex patterns on macOS.
- For Markdown content in Obsidian, use the Obsidian MCP tools (patch_note, etc.) rather than direct file writes.

## Writing & Analysis Style

When analyzing business strategy or market dynamics, always present balanced multi-factor analysis. Never over-attribute outcomes to a single cause. Use evidence-based language ('evidence suggests' rather than absolute claims) unless data directly supports a strong conclusion.

## Reference Docs

- `docs/prd-template.md` — PRD format
- `docs/prd-questions.md` — PRD questioning flow
- `docs/reasoning-levels.md` — Task complexity assessment
- `docs/quality-gates.md` — Gate definitions and requirements
- `docs/phase-checklists.md` — Phase checklists and deliverables
- `docs/recommended-hooks.md` — Recommended project hooks for development workflow
- `memory/shared/` — Institutional knowledge (principles, frameworks, mistakes)
