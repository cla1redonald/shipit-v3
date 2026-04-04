---
name: orchestrate
description: Launch a full orchestrated build. The orchestrator runs as the main session so it can delegate to all specialist agents via Task tool and Agent Teams.
argument-hint: Your idea or PRD
---

# /orchestrate -- Full Orchestrated Build

**Usage:** `/orchestrate <idea or PRD>`
**Example:** `/orchestrate build me a mood journal app`

## When to Use

- You're building a new product from scratch (idea to shipped software)
- You have a PRD and want the full agent pipeline (research -> strategy -> design -> build -> review -> ship)
- You need multi-agent coordination across research, architecture, engineering, QA, docs
- NOT for: one-file bug fixes (use `@engineer`), quick features (use `/build-feature`), just shipping (use `/shipit`)

**Cost:** Spawns 6-10 agents including Opus. For a one-file change, use `@engineer` directly.

## Process

1. **Pre-flight checks:**
   - Verify you're running on Opus (orchestration requires it for reliable delegation)
   - Verify `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` is set in settings.json
   - If either fails, warn the user and stop

2. **Load orchestrator definition.** Read `agents/orchestrator.md` for the full agent catalog and delegation instructions.

3. **Confirm readiness.** "Orchestrator loaded. 13 specialist agents available. Ready to build."

4. **Begin orchestration.** Follow the orchestrator definition. Delegate to specialists. Typical flow:
   - @researcher -> @strategist (PRD, requires user approval) -> @architect + @designer (parallel) -> @devsecops (setup) -> @engineer + @qa (parallel build) -> @reviewer + @docs (parallel polish) -> @retro -> ship

5. **Always invoke @retro** before presenting final summary.

## Anti-Rationalization

| Thought | Reality |
|---------|---------|
| "I can just do this myself without delegating" | You are the orchestrator. Coordination, not implementation. Delegate. |
| "This is too small for a full orchestrated build" | Then don't use /orchestrate. Use @engineer directly. |
| "I'll skip @retro, the project went fine" | @retro is mandatory. Most common failure mode. Every project has learnings. |
| "I don't need @researcher, I already know the space" | @researcher takes 2 minutes and might save days of reinvention. |
| "I'll skip @docs, we can add docs later" | Later never comes. Documentation drift compounds. |

## Exit Criteria

- [ ] All delegated agents completed their tasks
- [ ] PRD approved by user before build started
- [ ] @retro completed and learnings captured
- [ ] @docs completed and documentation updated
- [ ] Code committed and pushed to feature branch
- [ ] Build report presented to user

## Failure Recovery

| Problem | Action |
|---------|--------|
| Not running on Opus | Tell user to switch: `/model opus` |
| Agent Teams not enabled | Tell user to add env var to settings.json |
| Agent fails to complete | Retry once, then report to user with details |
| PRD not approved | Do not proceed to build. Wait for user sign-off. |
| @retro skipped | Go back and run it. Never skip. |
