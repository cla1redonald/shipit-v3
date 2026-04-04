---
name: build-feature
description: Autonomous TDD pipeline — architect, tests, build, QA review, push. Use --skip-architect to go straight to tests.
argument-hint: Feature description
---

# /build-feature -- Autonomous TDD Build

**Usage:** `/build-feature <feature-description>`
**Example:** `/build-feature "Add dark mode toggle to settings page"`

**Flags:**
- `--skip-architect` — Skip architect phase (use when design is clear or spec/gameplan exist)
- `--max-iterations=N` — Override the default 5-iteration builder cap
- `--resume <slug>` — Resume a failed build from the last successful phase

## When to Use

- You want autonomous feature building with TDD and quality gates
- You want agent-driven: architect -> tests -> build -> QA review -> push
- You trust the agents to make decisions and document assumptions
- NOT for: full product builds (use `/orchestrate`), manual TDD (use `/tdd-build`), one-line fixes (use `@engineer`)

**Cost:** Typical build: 3-4 agent spawns (1 opus @architect, 2-3 sonnet @qa/@engineer). Use `--skip-architect` to drop the opus call when design is clear.

## Pipeline Integration

Before starting, check for upstream outputs:

1. **Spec:** Look for `docs/specs/<slug>.md`. If found, read it for requirements and success criteria.
2. **Gameplan:** Look for `docs/gameplans/<slug>.md`. If found, read it for file targets, step order, and complexity.
3. **If both exist:** Use them as source of truth. Skip architect phase (equivalent to `--skip-architect`).
4. **If neither exists:** Proceed normally — the build pipeline generates its own context.

## Process

### Phase 0: Setup
1. Parse feature description, slugify it
2. Create feature branch: `git checkout -b feat/<slug>`
3. Detect test runner, confirm it works
4. Create feature directory: `docs/features/<slug>/`
5. Record start time

### Phase 1: @architect (skip with --skip-architect or existing gameplan)
Spawn @architect (model: opus) to produce `docs/features/<slug>/design.md` covering technical approach, files to modify, dependencies, edge cases, testing strategy.

### Phase 2: @qa (Test Architect)
Spawn @qa (model: sonnet) to write comprehensive failing tests. Must cover: happy path, edge cases, integration, regression. All tests must FAIL before proceeding.

### Phase 3: @engineer (Builder)
Spawn @engineer (model: sonnet) to implement iteratively. Triple gate after each attempt: `npm test -- --run && npx tsc --noEmit && npm run build`. Max iterations (default 5). If stuck, write handoff doc.

### Phase 4: @qa (QA Reviewer)
Spawn @qa (model: sonnet) for final quality review: unused imports, missing exports, UI styling, env vars documented. Run production build. Verdict: SHIP IT or NEEDS FIXES.

### Phase 5: Finalize
Commit all changes, push to feature branch, write build report to `docs/features/<slug>/build-report.md`.

## Core Rules

```
1. NO QUESTIONS — decide and document assumptions
2. TESTS FIRST — failing tests before any implementation
3. TRIPLE GATE — tests + typecheck + build after every attempt
4. MAX 5 ITERATIONS — hand off if stuck
5. FEATURE BRANCH — always branch, commit, push. NEVER merge.
```

## Anti-Rationalization

| Thought | Reality |
|---------|---------|
| "Tests are slowing me down, I'll write them after" | TDD is faster. Catch bugs at write time, not debug time. |
| "I can skip the architect phase, I know what to build" | Use --skip-architect explicitly. Don't silently skip it. |
| "The triple gate is overkill for small changes" | Small changes break builds. The gate takes 10 seconds. |
| "5 iterations isn't enough" | If 5 iterations can't solve it, the approach is wrong. Rethink, don't retry. |
| "I'll merge to main, it's just me" | Feature branches protect your work. Always branch. |

## Exit Criteria

- [ ] All tests passing
- [ ] TypeScript compiles without errors
- [ ] Production build succeeds
- [ ] QA review completed
- [ ] Build report written
- [ ] Code committed and pushed to feature branch
- [ ] Do NOT create PR or merge (user runs `/shipit` for that)

## Failure Recovery

| Problem | Action |
|---------|--------|
| No test runner | Set up Vitest, retry |
| Branch already exists | `git checkout feat/<slug>` instead |
| Architect can't understand codebase | STOP, report to user |
| Tests error (syntax) instead of fail | Fix syntax, re-run |
| Stuck after max iterations | Write handoff.md, STOP pipeline |
| Previously passing test regresses | Fix regression first (counts as iteration) |
| Build fails | Report to user with error |
| QA finds Must Fix issues | One more builder iteration if budget allows |
| Push fails | Check `gh auth status`, report auth issue |
