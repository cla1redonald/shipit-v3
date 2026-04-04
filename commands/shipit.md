---
name: shipit
description: Enforced commit workflow — test, typecheck, build, commit, retro, docs, push, PR, review, retro, merge. Ensures quality gates pass and mandatory agents run before shipping.
---

# /shipit -- Enforced Commit Workflow

**Usage:** `/shipit`
**Example:** `/shipit` (run from a feature branch with changes ready to ship)

## When to Use

- You're done implementing and want to ship with full quality gates
- You want enforced test -> typecheck -> build -> commit -> review -> merge flow
- You need @retro and @docs to run (mandatory, never skipped)
- NOT for: quick commit-and-push without gates (use git directly or `/ship`)

**Cost:** @retro (opus) + @docs (sonnet) + @reviewer (sonnet) = 3 agent spawns. No cost if you just need to push — use git directly.

## Process

Execute in order. If any step fails, stop and fix before continuing.

1. **Run tests:** `npm test -- --run`. Fix failures before proceeding.
2. **Type check:** `npx tsc --noEmit`. Fix errors before proceeding.
3. **Build:** `npm run build` (the actual CI/Vercel command). Fix failures.
4. **Ensure feature branch.** If on main, create feature branch first.
5. **Commit.** Stage and commit with conventional prefix (`feat:`, `fix:`, `test:`, etc.).
6. **Run @retro (NEVER SKIP).** Invoke via Task tool with what changed and why.
7. **Run @docs (NEVER SKIP).** Invoke via Task tool to assess documentation impact.
8. **Push.** Verify `gh auth status`, then `git push -u origin HEAD`.
9. **Create PR.** `gh pr create` with summary and test plan.
10. **Code review.** Invoke @reviewer with the PR diff. Handle verdict: Ready to ship -> merge. Fix and re-review -> fix, re-run gates, retry. Major rework -> stop, ask user.
11. **Post-review @retro (NEVER SKIP).** Invoke @retro with review findings for learning graduation.
12. **Merge PR.** `gh pr merge --squash --delete-branch`.

## Anti-Rationalization

| Thought | Reality |
|---------|---------|
| "Tests can wait, this is a hotfix" | Hotfixes especially need tests. Written under pressure, most likely to have bugs. |
| "The build passed locally, I don't need CI" | Local and CI environments differ. Run the actual build command. |
| "I'll skip code review, it's a small change" | Small changes cause big breaks. Review is not proportional to size. |
| "I don't need @retro for this" | @retro is mandatory in /shipit. Use git directly if you want no gates. |
| "Docs are fine, nothing changed" | Let @docs decide that. Your assessment is biased by familiarity. |

## Exit Criteria

- [ ] All tests passing
- [ ] TypeScript compiles without errors
- [ ] Production build succeeds
- [ ] Committed with conventional commit message
- [ ] @retro completed (both pre-merge and post-review)
- [ ] @docs completed
- [ ] PR created and reviewed
- [ ] PR merged to main

## Failure Recovery

| Problem | Action |
|---------|--------|
| Tests fail | Fix tests, restart from step 1 |
| Type errors | Fix types, restart from step 2 |
| Build fails | Fix build, restart from step 3 |
| On main branch | `git checkout -b [type]/[description]` |
| @retro fails | Retry — never skip |
| @docs fails | Retry — never skip |
| Push fails | Check `gh auth status`, fix auth, retry |
| PR already exists | Use existing PR, skip to step 10 |
| Review finds Must Fix | Fix issues, re-run steps 1-3, commit, push, re-review (max 3 cycles) |
| Merge conflicts | Resolve, re-run steps 1-3, push, retry merge |
