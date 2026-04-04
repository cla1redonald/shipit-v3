# ShipIt v3 Reference

## Lifecycle Pipeline

```
/spec -> /gameplan -> /build-feature -> /code-review -> /shipit
```

Each skill works standalone. They chain via the file system — upstream outputs are read if they exist.

## Agents

| Agent | Model | Best For | Standalone Example |
|-------|-------|----------|--------------------|
| @orchestrator | opus | Coordinate full builds | `/orchestrate "build a task manager"` |
| @researcher | haiku | Find existing solutions | `@researcher "npm packages for markdown parsing?"` |
| @strategist | opus | Raw ideas -> PRDs | `@strategist "I want a habit tracker"` |
| @pm | sonnet | Scope decisions | `@pm "Should we include social features in v1?"` |
| @architect | opus | System design, data models | `@architect "Design data model for task manager"` |
| @designer | sonnet | UI/UX specifications | `@designer "Design the settings page"` |
| @engineer | sonnet | Code implementation | `@engineer "Add dark mode toggle"` |
| @data-engineer | sonnet | Pipelines, ETL, embeddings | `@data-engineer "Set up embedding pipeline"` |
| @devsecops | sonnet | Infrastructure, deploy | `@devsecops "Set up Vercel deployment"` |
| @reviewer | sonnet | Code review, security | `@reviewer "Review the auth implementation"` |
| @qa | sonnet | Testing strategy | `@qa "Write tests for search feature"` |
| @docs | sonnet | Documentation | `@docs "Write API documentation"` |
| @retro | opus | Learning graduation | `@retro "What did we learn?"` |

## Skills

| Skill | Cost | Best For |
|-------|------|----------|
| `/spec` | None | Capture requirements before building |
| `/gameplan` | None | Plan implementation before coding |
| `/build-feature` | 3-4 agents (1 opus, 2-3 sonnet) | TDD build pipeline |
| `/tdd-build` | 1-2 agents (sonnet) | Lighter TDD workflow |
| `/code-review` | 1 agent (sonnet) | Quality and security review |
| `/prd-review` | None | Validate a PRD |
| `/prd-threads` | None | Convert PRD to executable threads |
| `/orchestrate` | 6-10 agents (mixed) | Full product build |
| `/shipit` | 3 agents (@retro opus, @docs + @reviewer sonnet) | Enforced commit workflow |

## Lightweight Alternatives

| Task | Full Path | Lean Path |
|------|-----------|-----------|
| New product | `/orchestrate` (8+ agents) | Only for building from scratch |
| New feature | `/build-feature` (3-4 agents) | `--skip-architect` if design is clear |
| Bug fix | `/build-feature` | `@engineer` directly |
| Quick review | `/code-review` | `@reviewer` directly |
| Ship it | `/shipit` (full gates) | Git commit + push manually |
