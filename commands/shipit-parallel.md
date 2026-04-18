---
name: shipit-parallel
description: Parallel workstream builder. Takes GitHub issues, groups into non-conflicting workstreams, spawns isolated build agents, and merges with integration testing. Use --dry-run to preview.
argument-hint: Issue numbers (#12 #15) or milestone:"name" [--dry-run]
---

# /shipit-parallel -- Parallel Workstream Builder

**Usage:** `/shipit-parallel <issues-or-milestone> [--dry-run]`
**Examples:**
```
/shipit-parallel #12 #15 #18 #22
/shipit-parallel milestone:"v2.1"
/shipit-parallel #12 #15 #18 --dry-run
/shipit-parallel #5 #6 #7 --max-agents=2
```

**Flags:**
- `--dry-run` — Show proposed workstream splits and file dependency analysis without executing builds
- `--max-agents=N` — Override the default 3-agent parallelism cap (max 5)

## When to Use

- You have 3+ GitHub issues that can be built in parallel
- You want to batch-build a milestone or sprint
- You trust agents to implement, test, and produce mergeable branches
- You want verified integration — every branch merged and tested before a single PR
- NOT for: single issues (use `/build-feature`), full product builds from scratch (use `/orchestrate`), issues with heavy cross-dependencies that all touch the same files

**Cost:** 1 Opus analysis pass + N Sonnet workstream agents + 1 Sonnet integration agent + potential fix agents. For a 4-issue batch split into 2 workstreams: ~1 Opus + 3 Sonnet spawns. Use `--dry-run` first to preview cost.

## Why This Is a Skill

Like `/orchestrate`, this skill **must run as the main conversation** (the coordinator). It delegates to multiple sub-agents via the Task tool, and the Task tool only supports single-level nesting. If this ran as a subprocess, it would lose delegation capability and try to do everything itself.

## Process

### Phase 0: Pre-Flight

1. **Verify prerequisites:**
   - Git repo is clean: `git status --porcelain` returns empty or only untracked files
   - On a stable base branch (main/master/develop) — record branch name and commit SHA
   - Test runner exists and passes: detect from `package.json` scripts (test, vitest, jest, pytest) and run it
   - GitHub CLI authenticated: `gh auth status` succeeds
   - If any check fails, report what failed and STOP

2. **Parse input:**
   - Issue numbers (e.g., `#12 #15 #18`): collect the numbers
   - Milestone (e.g., `milestone:"v2.1"`): run `gh issue list --milestone "v2.1" --state open --json number,title,body,labels --limit 50`
   - Extract `--dry-run` and `--max-agents=N` flags
   - If fewer than 2 issues, tell the user to use `/build-feature` instead

3. **Detect project commands:** Identify the test, typecheck, and build commands from `package.json` or project config. Store as `TEST_CMD`, `TYPECHECK_CMD`, `BUILD_CMD`.

### Phase 1: Issue Analysis & Workstream Grouping

For each issue, gather context and predict file impact:

1. **Fetch issue details:**
   ```bash
   gh issue view <number> --json title,body,labels,assignees
   ```

2. **Predict file impact.** For each issue, read the body and analyse the codebase to predict which files will be created or modified:
   - Look for explicit file paths or component names in the issue body
   - Grep the codebase for related identifiers, API routes, component names
   - Consider project structure — where do similar features live?
   - Produce a list of **predicted touched files** per issue (high/medium/low confidence)

3. **Build conflict graph.** Two issues conflict if they share any predicted touched file. Create an adjacency list.

4. **Group into workstreams.** Connected-component grouping:
   - Start with each issue as its own component
   - Merge any two components that share a predicted file
   - Each resulting component = one workstream
   - Generate a short slug for each workstream based on the dominant theme (e.g., `auth-improvements`, `dashboard-charts`)

5. **Enforce parallelism cap.** If workstream count exceeds `--max-agents` (default 3):
   - Sort workstreams by estimated complexity (file count * issue count)
   - Merge the smallest workstreams until count <= cap
   - Document which workstreams were merged and why

6. **Present the workstream plan:**

   ```
   Parallel Build Plan
   ===================
   Base branch: main (commit abc1234)
   Issues analyzed: 4
   Workstreams: 2

   Workstream 1: auth-improvements
     Issues: #12 (Add OAuth provider), #15 (Fix token refresh)
     Predicted files: src/lib/auth.ts, src/app/api/auth/route.ts,
                      src/middleware.ts, tests/auth.test.ts
     Estimated complexity: Medium

   Workstream 2: dashboard-charts
     Issues: #18 (Add revenue chart), #22 (Add user growth chart)
     Predicted files: src/components/dashboard/RevenueChart.tsx,
                      src/components/dashboard/GrowthChart.tsx,
                      src/lib/analytics.ts, tests/dashboard.test.ts
     Estimated complexity: Low

   Branches:
     parallel/auth-improvements
     parallel/dashboard-charts
     parallel/integration (final merge target)

   Estimated cost: 1 Opus (analysis) + 3 Sonnet (2 workstreams + integration)
   ```

7. **If `--dry-run`:** Present the plan and STOP. Do not proceed.

8. **If not dry-run:** Ask the user to confirm. Wait for explicit approval before spawning agents.

### Phase 2: Parallel Build

Spawn an engineer agent per workstream with worktree isolation. Launch up to 3 in a single message (respecting parallelism cap). If more workstreams exist, queue them and spawn as earlier ones complete.

**Agent prompt template:**

```
You are building workstream '{SLUG}' for a parallel build.

BASE BRANCH: {BASE_BRANCH} (commit {BASE_COMMIT})
BRANCH NAME: parallel/{SLUG}

ISSUES TO IMPLEMENT:
{For each issue:}
  Issue #{NUMBER}: {TITLE}
  {BODY}

PREDICTED FILES: {list}

YOUR TASK:
1. Create branch: git checkout -b parallel/{SLUG}
2. For EACH issue in order:
   a. Write failing tests for the issue requirements
   b. Implement the minimum code to pass tests
   c. Run: {TEST_CMD} && {TYPECHECK_CMD} && {BUILD_CMD}
   d. Commit: 'feat: {title} (closes #{NUMBER})'
3. After all issues implemented:
   a. Run full test suite one final time
   b. Push: git push -u origin parallel/{SLUG}

RULES:
- Tests FIRST for every issue
- If stuck after 5 iterations on an issue, skip it with a SKIPPED.md and continue
- Do NOT modify files outside the predicted list unless necessary (document any surprises)
- Commit after each issue, not one big commit

REPORT BACK with:
- Issues completed (list)
- Issues skipped (if any, with reasons)
- Test results (pass/fail count)
- Files actually modified vs predicted
- Unexpected dependencies discovered
```

**Spawn each agent with:**
```
Task(
  subagent_type: "engineer",
  model: "sonnet",
  isolation: "worktree",
  name: "workstream-{SLUG}",
  prompt: [above template filled in]
)
```

Wait for all workstream agents to complete. Collect their reports.

### Phase 3: Integration

After all workstream agents finish, spawn a single integration agent:

```
Task(
  subagent_type: "engineer",
  model: "sonnet",
  isolation: "worktree",
  name: "integration",
  prompt: "You are the INTEGRATION agent for a parallel build.

BASE BRANCH: {BASE_BRANCH} (commit {BASE_COMMIT})

WORKSTREAM BRANCHES TO MERGE (in order, simplest first):
{list of parallel/{SLUG} branches}

YOUR TASK:
1. Create branch: git checkout -b parallel/integration {BASE_BRANCH}
2. Merge each workstream branch ONE AT A TIME:
   a. git merge parallel/{SLUG} --no-edit
   b. If merge conflict:
      - Record which files conflict and the conflict content
      - Attempt resolution if trivial (adjacent line additions)
      - If non-trivial: STOP and report which workstream, which files, conflict content
   c. After successful merge, run: {TEST_CMD} && {TYPECHECK_CMD} && {BUILD_CMD}
   d. If any fail: STOP and report which workstream caused it, test output, diff
   e. If all pass: continue to next workstream
3. After ALL merged: run final test + typecheck + build
4. Push: git push -u origin parallel/integration

REPORT with:
- Merge order and result per workstream (clean/conflict/test-failure)
- Final test results
- Final build result
- Which workstream caused any failure
"
)
```

### Phase 4: Conflict/Failure Resolution

If integration reports a merge conflict or test failure:

1. **Identify the failing workstream** from the integration report.

2. **Spawn a fix agent** for that workstream:
   ```
   Task(
     subagent_type: "engineer",
     model: "sonnet",
     isolation: "worktree",
     prompt: "Fix integration failure on branch parallel/{SLUG}.

   PROBLEM: {MERGE_CONFLICT or TEST_FAILURE details}

   The integration branch has merged all workstreams up to but NOT including yours.

   YOUR TASK:
   1. git fetch origin parallel/integration
   2. git rebase origin/parallel/integration
   3. Resolve conflicts
   4. Run: {TEST_CMD} && {TYPECHECK_CMD} && {BUILD_CMD}
   5. git push --force-with-lease origin parallel/{SLUG}

   REPORT: what was fixed, test results, whether rebase was clean
   "
   )
   ```

3. **After fix completes:** Re-run integration from the failed merge point.

4. **Max 2 fix cycles per workstream.** If it fails twice, exclude that workstream from the PR and report which issues could not be integrated.

### Phase 5: PR Creation

After successful integration:

1. **Create PR:**
   ```bash
   gh pr create \
     --base {BASE_BRANCH} \
     --head parallel/integration \
     --title "feat: parallel build — {summary}" \
     --body "## Summary
   Parallel build implementing {N} issues across {M} workstreams.

   ### Issues Closed
   {- Closes #NUMBER: TITLE for each}

   ### Workstream Breakdown
   {**SLUG** — Issues: #X, #Y — Files: list for each}

   ### Integration
   - All workstreams merged cleanly: {yes/no}
   - Fix cycles needed: {count}
   - Full test suite: PASSING
   - Full build: PASSING

   ### Build Report
   - Total wall-clock time: {duration}
   - Workstream agents: {count}
   - Issues completed: {count}/{total}
   - Issues skipped: {count} {reasons if any}
   "
   ```

2. **Clean up workstream branches** (keep integration branch as PR head):
   ```bash
   git push origin --delete parallel/{SLUG}  # for each workstream
   ```

### Phase 6: Summary

Present the final report:

```
Parallel Build Complete
=======================
Issues: #12, #15, #18, #22
Workstreams: 2 (auth-improvements, dashboard-charts)
Branches merged: 2/2
Fix cycles: 0
Total time: 12m 30s

PR: https://github.com/user/repo/pull/42

Workstream Details:
  auth-improvements: #12, #15 — MERGED
  dashboard-charts: #18, #22 — MERGED
```

## Core Rules

```
1. DRY-RUN FIRST — Always recommend --dry-run on first use
2. USER APPROVAL — Never proceed past Phase 1 without explicit confirmation
3. ISOLATION — Every workstream agent runs in its own worktree
4. SEQUENTIAL MERGE — Integration merges one branch at a time, testing after each
5. MAX 2 FIX CYCLES — If a workstream can't integrate after 2 attempts, exclude it
6. SINGLE PR — One PR with all changes, not one per workstream
7. TESTS GATE EVERYTHING — No merge without passing tests, no PR without passing build
```

## Anti-Rationalization

| Thought | Reality |
|---------|---------|
| "These issues are all independent, I don't need dependency analysis" | Two issues that both touch `utils.ts` will produce merge conflicts. Always analyse. |
| "I'll skip the dry-run, I know these issues are safe" | Dry-run costs 30 seconds. A bad workstream split wastes 30 minutes of failed merges. |
| "3 agents is too slow, I'll spawn 5" | API rate limits are real. 3 is the safe default. Exceeding it causes retries slower than sequential. |
| "The merge conflict is trivial, just pick one side" | Trivial-looking conflicts hide semantic breaks. Merge then TEST. Tests catch what eyes miss. |
| "I'll merge all branches at once instead of sequentially" | Sequential merge with testing isolates which workstream broke things. Bulk merge hides the culprit. |
| "This workstream only has one file, it doesn't need tests" | One-file changes break builds. The test takes 2 minutes. The debugging takes 2 hours. |
| "I'll skip user confirmation, the split looks obvious" | The user knows their codebase better than dependency analysis. Always confirm. |
| "The fix agent failed twice but a third try would work" | Two cycles is the budget. If it can't integrate in two tries, the coupling is deeper. Exclude and report. |

## Exit Criteria

- [ ] All issues analysed and grouped into workstreams
- [ ] User approved the workstream plan (or `--dry-run` completed)
- [ ] All workstream agents completed with clear reports
- [ ] Integration branch merges all workstreams with tests passing
- [ ] Production build succeeds on integration branch
- [ ] Single PR created listing all closed issues
- [ ] Summary report presented with PR URL
- [ ] Workstream branches cleaned up (integration branch kept as PR head)

## Failure Recovery

| Problem | Action |
|---------|--------|
| Git repo not clean | Tell user to stash or commit first |
| `gh auth` fails | Tell user to run `gh auth login` |
| No test runner detected | Tell user to set up tests; this skill requires a test suite |
| Issue fetch fails (404) | Skip that issue, warn user, continue with rest |
| Milestone has 0 open issues | Report and stop |
| ALL issues conflict (one giant component) | Put everything in 1 workstream. Warn there's no parallelism benefit — suggest `/build-feature` instead |
| Workstream agent crashes | Note failure, continue with others, report unbuilt issues |
| Merge conflict in integration | Spawn fix agent for originating workstream (Phase 4) |
| Test failure after merge | Spawn fix agent with failing test details (Phase 4) |
| Fix agent fails twice | Exclude workstream from PR, report which issues excluded and why |
| API rate limit during parallel spawn | Reduce to 2 agents, retry. If still failing, go sequential |
| All workstreams excluded | Do not create PR. Report full failure with details per workstream |
| PR creation fails | Report error, provide manual `gh pr create` command |
| Fewer than 2 issues provided | Redirect to `/build-feature` — parallel build needs 2+ issues |
