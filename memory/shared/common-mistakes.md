> *Seed knowledge from ShipIt development, 2025-2026*

# Common Mistakes to Avoid

Patterns from past projects. Every agent should be aware of these.

## Testing Failures

### Shipping Without Tests
PowderPost shipped without any tests despite "tests required" being in docs. Root cause: no hard enforcement. Now enforced with blocking hooks.

### "We'll Add Tests Later"
This never happens. Write tests WITH each feature.

### No Test Infrastructure
Four consecutive commits shipped without tests because the project had no test runner, no test script, no test config. The project was structurally incapable of running tests. **Before writing ANY code, verify test infrastructure exists.**

### Running Wrong Build Command
`tsc --noEmit` and `tsc -b` can produce different results. Always run the project's ACTUAL build command from package.json. The command CI/Vercel runs is the one that matters.

## Scaffold Failures

### Missing .gitignore in Project Scaffold
**What happens:** Thread 1 (scaffold) creates package.json, tsconfig.json, and source directories but does not create a `.gitignore`. The first `git add -A` commits `node_modules/`, `.next/`, `.env.local`, and other generated/secret files to the repository. Cleaning this requires git history rewriting (`git filter-branch` or `git filter-repo`), which is destructive and time-consuming.
**Root cause:** The scaffold task focuses on "what the app needs to run" (dependencies, config, source structure) and overlooks "what the repo needs to stay clean" (.gitignore, .env.example, .editorconfig). The `.gitignore` is not a build dependency, so it is not missed until after the damage is done.
**Prevention:** Scaffold task checklist must include `.gitignore` as a required deliverable alongside `package.json` and `tsconfig.json`. Use a standard template: `node_modules/`, `.next/`, `.env.local`, `.env`, `dist/`, `.DS_Store`, `*.log`. @devsecops should verify `.gitignore` exists before the first `git add`.
**Detection:** Before the first commit, run `git status` and verify that `node_modules/` and `.next/` are NOT listed as untracked files. If they appear, `.gitignore` is missing or incomplete.
**Source:** Focus Timer, 2026-02-25. Second scaffold infrastructure failure (London Transit Pulse had data/ in .gitignore blocking imports; this time .gitignore was missing entirely).

## Infrastructure Failures

### Vercel 4.5MB Body Size Limit
Serverless functions reject requests > 4.5MB (HTTP 413). For file uploads, use direct-to-storage uploads with signed URLs.

### Supabase Client at Module Level
Creating Supabase client at module level crashes the build if env vars are missing. Always lazy-load.

### Supabase RLS Policies
Forgetting to enable RLS is a security hole. Always enable RLS and create policies for SELECT/INSERT/UPDATE/DELETE.

### Environment Variables Not Documented
Causes setup friction. Always maintain .env.example.

### Service Role Keys in Client Code
Security risk. Never expose service role keys client-side.

### Next.js + React Version Mismatch
**What happens:** React 19 is installed alongside Next.js 14 (which requires React 18). Libraries like react-leaflet@5 use React 19-only APIs (`React.use()`), causing immediate client-side crash in production.
**Root cause:** Scaffold phase installs packages without validating cross-dependency version constraints. Adding `legacy-peer-deps=true` to `.npmrc` suppresses the warnings, hiding the real conflict.
**Prevention:** After `npm install`, run `npm ls react` and verify the React version matches the Next.js requirement (Next.js 13-14 = React 18, Next.js 15 = React 19). Never add `legacy-peer-deps=true` as a workaround -- resolve the actual conflict.
**Source:** London Transit Pulse, 2026-02-07. App crashed on page load in production.

### Gitignored Paths That Code Imports From
**What happens:** A directory like `/data/` is added to `.gitignore` (treating it as generated/raw data), but the application imports directly from `data/*.json`. Files never reach the deploy target, causing "Module not found" build failure.
**Root cause:** The scaffold thread treats data directories as excludable without checking the import graph.
**Prevention:** Cross-reference every `.gitignore` entry against the application's imports. Run `next build` locally before first deploy -- any "Module not found" for a gitignored path reveals this conflict.
**Source:** London Transit Pulse, 2026-02-07. 7 JSON data files missing from Vercel build.

### No Local Build Before First Deploy
**What happens:** First deploy to Vercel fails because nobody ran `next build` locally. A successful local build would have caught version conflicts, missing files, and other build errors before they hit production.
**Prevention:** `next build` must succeed locally before the first `vercel deploy`. This is a hard gate. The first deploy is the highest-risk deployment because there is no known-good baseline.
**Source:** London Transit Pulse, 2026-02-07.

### Vercel Build Cache Retains Old Dependencies
**What happens:** After fixing a dependency version in `package-lock.json`, Vercel's cached `node_modules` from the previous build is reused, serving the old broken dependency.
**Prevention:** When fixing dependency versions, set `VERCEL_FORCE_NO_BUILD_CACHE=1` in Vercel environment variables or deploy with `--force`. After deploy, verify the production URL serves the new deployment.
**Source:** London Transit Pulse, 2026-02-07. React 19 persisted in deployed bundle despite lockfile specifying React 18.

## Debugging Failures

### Missing Environment Variables Misdiagnosed as Code Bugs
**What happens:** APIs return 503/500 and the developer spends extensive time debugging code logic (audio mute states, prompt engineering, caching layers, hardcoded mappings) when the actual root cause is missing environment variables. The app's fallback paths silently mask the real error — static preset data is served instead of AI-generated content, making it look like a code quality issue rather than a configuration issue.
**Root cause:** (1) No `.env.local` file exists but `.env.example` does — the gap isn't caught. (2) API routes return 503 with a generic message like "unavailable" rather than explicitly logging "MISSING API KEY." (3) The developer chases symptoms (drony audio, static backgrounds) instead of checking the server logs first. (4) Fallback profiles create the illusion that the system "works" — it renders something, just not the right thing.
**Prevention:** (1) **Always check server logs FIRST** when debugging — a `503` is a configuration problem, not a code problem. (2) When setting up a project, verify `.env.local` exists with required keys before any debugging session. (3) API routes should log `console.error('MISSING: ANTHROPIC_API_KEY')` not just return 503. (4) Add a startup check or health endpoint that validates required env vars are present.
**Detection:** `grep -r "503"` in server logs. Any 503 from your own API routes is almost always a missing env var or service unavailability, not a code bug.
**Source:** Weather Mood, 2026-02-07. Three debugging rounds (mute desync, prompt engineering, cache removal) before discovering both ANTHROPIC_API_KEY and ELEVENLABS_API_KEY were missing from `.env.local`.

## Code Failures

### Async Function Assigned to Sync Interface (async/void Mismatch)
**What happens:** A TypeScript interface declares a method as returning `void` (e.g., `notify: (title: string) => void`), but the implementation is `async` and returns `Promise<void>`. TypeScript does NOT flag this as an error because `Promise<void>` is assignable to `void` in TypeScript's type system. The function appears to work in tests, but at runtime the first call may silently fail because the caller does not await the result, and any errors inside the async function are swallowed as unhandled promise rejections.
**Root cause:** TypeScript's structural typing allows `() => Promise<void>` to satisfy `() => void` because the return value of a void-returning function is ignored. This is by design in TypeScript but creates a class of silent runtime failures when the async behavior matters (e.g., requesting notification permissions, initializing audio contexts, establishing WebSocket connections).
**Prevention:** When defining interfaces for functions that MAY be async in implementation, declare the return type as `Promise<void>` in the interface, not `void`. If the interface must stay synchronous, the implementation must not be async. During code review, cross-reference interface declarations with their implementations -- any `async` implementation of a `void`-typed interface method is a potential silent failure.
**Detection:** Grep for `async` function implementations and cross-reference against their interface/type declarations. If the interface says `void` but the implementation says `async`, flag it. Pay special attention to notification APIs, permission requests, and any browser API that returns a Promise.
**Source:** Focus Timer, 2026-02-25. `useNotifications` interface declared `notify` as `void` but implementation was `async Promise<void>`. First notification silently failed on first visit.

### Type Propagation Rule
When adding a required field to a TypeScript type, grep the ENTIRE codebase for every construction site. The places that get missed: migration functions, test fixtures, factory functions, mock data, seed scripts, default objects.

### Merge Conflict Markers Left in Code
After rebase/merge, always: (1) grep for conflict markers, (2) run actual build command, (3) run full test suite. A partial conflict resolution is worse than none.

### Silent API Failures
`setPosts(data.posts || [])` silently swallows API errors. Always show errors to users during development.

### Hardcoded Counts Across Files
When numeric metadata (test counts, version numbers) are hardcoded in multiple files, they drift silently. Store in single source of truth.

## Process Failures

### @retro Skipped at End
The orchestrator's summary feels like a "done" state — it forgets to invoke @retro after. Fix: @retro runs BEFORE the summary.

### @retro Missing From /build-feature
**What happens:** /build-feature completes successfully (tests green, build passes, QA approves, code pushed) but no retrospective runs. Build learnings — CSS import issues, deployment auth surprises, scorer calibration gaps — are lost.
**Root cause:** /build-feature Phase 5 (Finalize) originally went straight to commit+push+report without a retro step. The "finalize" step felt like completion, so the skill never prompted for learning capture. Unlike /shipit which has retro as a mandatory step, /build-feature treated building and shipping as separate concerns.
**Prevention:** /build-feature now includes @retro as mandatory Phase 5 (before Finalize). Anti-rationalization table includes "I don't need a retro for a build" → "Every build generates learnings. Capture them."
**Source:** Baby Name Scorer, 2026-04-04. Build completed, deployed to production, retro only ran after user noticed it was missing.

### Skipped Agents Without Justification
There's a difference between "not needed" and "forgot." All agents must be explicitly listed as Invoke or Skip (with reason).

### Documentation Drift
When @docs is skipped, no one checks if existing docs are still accurate. Always assess documentation impact before shipping.

### Background Agents Can't Run Bash
Agents spawned in background mode have bash auto-denied. Agents needing bash (@engineer, @devsecops, @qa) must run in foreground.

### Documenting Before Testing
We documented agent capabilities without testing them. The documented feature did not actually work. Always verify capabilities before documenting them.

## Rewrite Contamination

### Predecessor Concepts Leak Into Rewrites
When rewriting a system, the builder has the predecessor in context. Architecture changes successfully (new patterns adopted) but content does not (old terminology, old concepts, old comparison tables leak through). The fix is an explicit "eliminated concepts" list in CLAUDE.md that is greppable, plus a review step that checks for references to eliminated concepts.

### Comparison Tables in READMEs
A product's README should describe that product. A "Differences from v1" table makes the product define itself through its predecessor, which is not how standalone products work. If migration guidance is needed, put it in a separate MIGRATION.md.

### Hallucinated Platform Features
When building on a platform (Claude Code, Vercel, Supabase), do not assume features exist without testing them. The `hooks:` YAML frontmatter field was added to agent definitions without verifying it was a real Claude Code feature — it was not. Always test platform capabilities before documenting or building on them.

### Confident Misimplementation of Platform Conventions
**What happens:** The builder implements real platform features with the wrong structure or configuration. The code appears to work in development but fails when the platform tries to auto-discover or distribute the artifacts. In ShipIt v2, agents/skills/hooks were placed inside `.claude-plugin/` instead of at the plugin root — exactly what the Anthropic docs call a "Common mistake."
**Root cause:** The builder's mental model of how plugins work (from other ecosystems like VSCode, npm) produces a plausible-looking but incorrect structure. Unlike hallucinated features, misimplemented conventions do not immediately error — they silently fail at distribution/discovery time.
**Prevention:** (1) Fetch and read the actual platform documentation before designing directory structures. (2) @architect must cite the specific documentation section justifying platform-specific structural decisions. (3) Run a plugin loading smoke test as part of Gate 3 (Infrastructure Ready).
**Detection:** Integration test that verifies the platform can find and load all declared agents, skills, and hooks from their expected locations.

### Docs-Say-But-Didn't-Read (Acknowledged Instructions, Ignored Execution)
**What happens:** The user explicitly says "follow the documentation for X." The builder acknowledges this and proceeds to build from its own knowledge instead of actually fetching and reading the docs. The result diverges from the docs in ways the user has to discover themselves.
**Root cause:** The builder has high confidence in its existing knowledge and interprets "follow the docs" as "I know the docs" rather than "go read the docs right now." For rapidly-evolving platforms, the builder's training data may be stale or incomplete.
**Prevention:** When a user references specific documentation, the orchestrator must create a blocking task: "Fetch and summarize current documentation for [X]." This task must complete before the design phase begins. @researcher is invoked to fetch the actual docs via WebFetch, and the output is provided to @architect as a concrete reference.
**Detection:** @reviewer's review checklist includes a "Source Verification" step: for every platform-specific structural decision, verify the cited documentation source exists and matches the implementation.

## Integration Testing Failures

### Integration Tests Deferred to "Later" Thread That Never Runs
**What happens:** The PRD or thread plan allocates a dedicated thread for integration tests (e.g., "Thread 6: Integration Tests"), but no build thread actually writes them. The thread is perpetually deferred because feature threads take longer than estimated, and the "integration test thread" has no blocking dependency that forces it to execute. The project ships with unit tests only.
**Root cause:** Integration tests are treated as a separate phase rather than a requirement of each feature thread. When feature threads overrun, the integration test thread is the first to be cut because "we have tests" (unit tests). This is the same "We'll Add Tests Later" pattern applied specifically to integration tests.
**Prevention:** Integration tests must be written IN the same thread as the feature they test, not in a separate thread. The thread's definition of done must include: "At least one integration test verifying this feature works with the app's shared state/context." A standalone "integration test thread" in the PRD is a red flag -- it means integration testing will be deferred and cut.
**Detection:** If the PRD has a dedicated "Integration Tests" thread that is not part of a feature thread, flag it during PRD review. If @reviewer finds an empty test directory for integration tests, the pattern has already failed.
**Source:** Focus Timer, 2026-02-25. Third occurrence: London Transit Pulse (177 unit tests, 4 integration bugs found post-deploy), NYC Transit Pulse (shallow integration tests), Focus Timer (Thread 6 for integration tests was never executed). Pattern proven across dashboard AND non-dashboard apps.

### Components Built in Isolation Without Shared State Integration
**What happens:** Dashboard components are unit-tested with mock data and pass, but they never integrate with the shared filter/state system. The result: filters appear to work (UI changes) but displayed data never changes. Users discover this by clicking through the deployed app.
**Root cause:** Each component is built and tested in its own thread without any integration test verifying the full state-to-render pipeline. The test suite gives 100% false confidence.
**Prevention:** For any app with shared state (filters, toggles, context providers), write integration tests that: (1) render the component within the provider, (2) change a state value, (3) assert the rendered output changes. At minimum one integration test per component that consumes shared state.
**Detection:** If a dashboard has N filter controls and M display components, but zero tests that change a filter and assert a component's output changes, integration testing is missing.
**Source:** London Transit Pulse, 2026-02-07. 4 separate integration bugs (Issues 5-8) discovered only by user.

### Visual State Change Without Data State Change
**What happens:** A toggle "dims" or "highlights" a card (visual state) but does not recalculate the underlying data (data state). The visual change creates the illusion the feature works, so neither developer nor reviewer verifies actual data recalculation.
**Root cause:** Visual feedback is easier to implement than data flow. The developer implements the CSS/opacity change, sees something happen on click, and moves on. Missing `useMemo` dependency arrays go unnoticed because the component appears responsive.
**Prevention:** Test visual state and data state independently. For mode toggles: assert that the sum/average changes when modes are toggled, not just that a CSS class is applied.
**Source:** London Transit Pulse, 2026-02-07. Mode toggles dimmed cards but never recalculated "Avg Daily Journeys."

### Hardcoded Data Slicing Ignoring Filter Range
**What happens:** A component uses `data.slice(-30)` to show "last 30 entries" regardless of the selected date range (7D, 30D, 90D). The graph never changes when filters change.
**Root cause:** Developer uses a fixed slice for visual consistency without considering that the slice should be relative to the filtered data range.
**Prevention:** Never hardcode slice parameters in components that consume filtered data. Use the filtered array length to determine the slice, or downsample the full filtered range to a target number of data points.
**Source:** London Transit Pulse, 2026-02-07. Sparklines showed identical graphs for all date ranges.

## Code Duplication Across Module Boundaries

### Duplicate Utility Functions When Architecture Does Not Specify Shared Boundaries
**What happens:** Multiple engineers independently create local copies of the same utility function (formatters, helpers, tooltips) in their own modules instead of importing from a shared location. The duplicates have subtly different behavior (e.g., one rounds to 0 decimals, another to 1), creating inconsistency and maintenance burden.
**Root cause:** The architecture spec defines the shared module and city modules but does not explicitly list which utility functions belong where. Engineers working in parallel default to creating local copies to avoid blocking on shared code.
**Prevention:** Architecture spec must include a "Shared Utilities" section that: (1) explicitly lists every shared function with its signature, (2) specifies import path, (3) notes which city-specific functions intentionally differ from the shared version and why. During @reviewer pass, grep for function names that appear in both shared and city modules -- duplicates with identical signatures are always bugs.
**Detection:** Grep for common function names (`formatNumber`, `formatPercent`, `formatDate`) across all module boundaries. If the same function name appears in 3+ locations, consolidation is needed.
**Seen in:** London Transit Pulse (CustomTooltip x4 files), Retro Pinball (duplicate high score logic in GameState + GameHUD), Transit Pulse combined (formatNumber/formatPercent/formatDate in 3 locations). Third occurrence -- pattern is proven.

## UX/UI Failures

### Hardcoded Theme Colors in Components
**What happens:** Components use raw Tailwind gray scales (`text-gray-900`, `bg-gray-200`) or hex values (`#1a1a2e`) instead of CSS variable-based theme tokens (`text-foreground`, `hsl(var(--muted-foreground))`). Works in one theme, breaks in the other.
**Root cause:** Engineers default to familiar Tailwind utility classes or copy colors from design mockups as literal values. The architecture doc does not explicitly forbid it.
**Prevention:** Architecture doc must include a "Theming Rules" section: "All colors must use CSS variable tokens. Never use raw Tailwind color scales or hex values in components." @reviewer checks for hardcoded color patterns in every review.
**Detection:** Grep for `text-gray-`, `bg-gray-`, `text-\[#`, `bg-\[#` in component files. Any match outside `globals.css` or theme config is a bug.

### Non-Deterministic Data in React Render
**What happens:** `Math.random()` called during render produces different output every render cycle, causing visual flickering (e.g., sparkline bars changing shape on every filter interaction).
**Root cause:** Data generation logic placed inline in component render instead of being memoized or computed once.
**Prevention:** Never call `Math.random()`, `Date.now()`, or other non-deterministic functions in the render path. Use `useMemo` with stable deps, or compute data outside the component.
**Detection:** Grep for `Math.random()` in `.tsx` files. Any match inside a component body (not wrapped in `useMemo`) is a bug.

### Generic Styling
Default Bootstrap/generic styling looks amateur. Use professional color palettes with proper contrast ratios.

### Desktop-Only Testing
Always test on mobile. Mobile-first responsive design saves rework.

### Dashed Borders
Look "wireframey." Use solid subtle borders or card shadows for polish.

### Low Contrast Text
Always test text colors visually. `text-slate-800` on `bg-slate-100` can be hard to read despite looking fine in code.

## Tool Misuse Failures

### Bash Heredoc File Creation Corrupts settings.local.json
**What happens:** An agent uses `cat > /path/to/file.tsx << 'EOF' ... EOF` via the Bash tool to create files instead of using the Write tool. When the user approves these Bash commands in the permission system, Claude Code saves the ENTIRE heredoc command -- including hundreds of lines of escaped source code -- as an "allow" pattern in `settings.local.json`. On next startup, Claude Code tries to parse these multi-hundred-line patterns, hits a `:*` pattern syntax error, and refuses to load the file entirely. The error message is: "The :* pattern must be at the end. Move :* to the end for prefix matching, or use * for wildcard matching. Files with errors are skipped entirely, not just the invalid settings."
**Root cause:** The agent defaults to Bash shell commands for file creation because heredoc syntax is familiar and straightforward. But the Bash tool's permission system was not designed to handle multi-line file content as a command string. The Write tool exists specifically for file creation and does not interact with the permission allow-list in this way.
**Impact:** All permission settings in `settings.local.json` become inaccessible. The user must manually edit the JSON file to remove corrupted entries before Claude Code will load any of their saved permissions. In the London Transit Pulse build, 16 malformed entries (containing full TypeScript components, test files, and markdown) corrupted the file.
**Prevention:**
1. **Never use `cat > file << 'EOF'`, `echo >`, or any Bash heredoc/redirect to create files.** Always use the Write tool for file creation and the Edit tool for file modification.
2. **Never use Bash `for` loops to create or modify multiple files.** Use individual Write/Edit tool calls for each file.
3. The ONLY acceptable use of Bash for file-related operations is: `mkdir -p` (creating directories), `cp`/`mv` (copying/moving files), `chmod` (permissions), and similar metadata operations.
**Detection:** Grep for `cat >`, `cat >>`, `<< 'EOF'`, `<< EOF`, `echo >` in Bash commands being executed by agents. Any match involving file content creation is a bug.
**Source:** London Transit Pulse, 2026-02-07. 16 corrupted entries in `settings.local.json` including full TSX components and test files.

## Security Failures

### .claude/settings.local.json Committed With API Keys

**What happens:** Claude Code's `settings.local.json` stores Bash command permission patterns. When an agent runs a command containing an API key (e.g., `echo "sk-ant-..." | vercel env add ANTHROPIC_API_KEY production`), the full command including the key is saved as an allow pattern. If `settings.local.json` is tracked by git (it is by default unless explicitly gitignored), the API keys are committed to the repository. When the repo is made public, the keys are exposed in git history.

**Root cause:** `.claude/settings.local.json` is not in the default `.gitignore` created by `create-next-app` or most scaffold tools. Unlike `.env.local`, there is no widespread convention to gitignore Claude Code's settings files. The file is committed alongside other `.claude/` files (like `settings.json`) that ARE meant to be shared, making it easy to miss that `settings.local.json` contains sensitive command patterns.

**Impact:** API keys (Anthropic, ElevenLabs, and any other key passed through Bash commands) are committed in plaintext. Making the repo public exposes them. Even after removing the file, keys remain in git history unless scrubbed with `git filter-repo`.

**Prevention:**
1. **Every project scaffold must add `.claude/settings.local.json` to `.gitignore`.** This is as critical as ignoring `.env.local`.
2. @devsecops must verify this entry exists before the first commit.
3. When making a private repo public, scan for `settings.local.json` in git history: `git log --all -- .claude/settings.local.json`
4. If found, scrub with `git filter-repo --invert-paths --path .claude/settings.local.json --force` and force push.
5. Rotate all exposed keys immediately — scrubbing history does not invalidate keys already seen by GitHub's cache or any clones.

**Detection:** Before any repo visibility change (private → public): `git ls-files .claude/settings.local.json` — if tracked, check contents for `sk-ant-`, `api_key=`, or other credential patterns.

**Source:** Portfolio build, 2026-02-27. ProveIt and Weather Mood both had Anthropic API keys committed in `settings.local.json`. Discovered during security review after repos were made public. Required `git filter-repo` scrub and key rotation.

---

## Delegation Failures

### Orchestrator Does Everything Itself
In the first ShipIt v2 end-to-end test, the orchestrator made **zero Task tool calls** out of 123 total. It wrote code, created schemas, designed architecture, and role-played @retro — all things it is explicitly forbidden from doing. Root cause: the orchestrator was spawned as a **Task tool subprocess**, but subprocesses cannot spawn further subprocesses (single-level nesting constraint). It silently did everything itself instead of reporting the error.

**Fix:** The orchestrator is now invoked via the `/orchestrate` skill, which loads it into the **main conversation** (team lead). As the top-level session, it has full access to Task tool (for subagents) and TeamCreate (for Agent Teams). The orchestrator definition includes a fail-safe: if it detects it's running as a subprocess, it reports an error instead of proceeding.

**Prevention:** All documentation directs users to `/orchestrate` instead of `@orchestrator`. The README, CLAUDE.md, and global CLAUDE.md all explain the constraint.

### README Omits Agents
The README listed 9 of 12 agents, omitting @pm, @devsecops, and @retro. Nobody caught this because no review step checks the README agent list against the actual agent directory. Fix: verification step that counts agents in README vs files in `agents/`.

---

## State Complexity Accumulation

### Multiple State Variables Controlling the Same Behavior

**What happens:** State variables proliferate to track what should be a single piece of state. In Weather Mood, the mute state grew to 4+ variables across 2 hooks: `isSynthMuted`, `isMuted` (page level), `elevenLabs.isMuted`, and `isMutedRef`. Each variable was added incrementally to fix a specific bug, but the accumulation indicated an architectural problem — two competing audio systems with unclear ownership.

**Root cause:** Incremental bug fixes add state variables to patch issues rather than refactoring the underlying architecture. Each new variable feels like a small, isolated change, so the pattern accumulates without triggering a simplification review.

**Prevention:** When the number of boolean state variables related to the same user action (mute, toggle, filter on/off) exceeds 2, it is a code smell indicating unclear ownership or competing systems. Before adding a third state variable, ask: "Why do we need multiple sources of truth?" The correct fix is usually to consolidate into a single source of truth with derived state, or to remove one of the competing systems entirely.

**Detection:** Grep for related state variable names (e.g., `isMuted`, `muted`, `mute`) across the codebase. If 3+ variables with similar names exist, or if state synchronization logic appears (e.g., syncing A to B in a useEffect), state complexity has accumulated.

**Source:** Weather Mood, 2026-02-07. Mute state grew to 4 variables before the synth was removed entirely, simplifying back to 1 variable.

---

## Backend API Proxy Buffering Instead of Streaming

### Buffering External API Responses in Serverless Functions

**What happens:** Backend API routes (Next.js Route Handlers, Vercel Serverless Functions, etc.) use `await response.arrayBuffer()` or `await response.json()` to fully buffer responses from external APIs (ElevenLabs, OpenAI, Claude) before forwarding to the client. This adds latency, wastes memory, and blocks progressive rendering/playback. For large responses (audio, video, streaming text), users experience dead silence or blank screens while the serverless function buffers the entire response.

**Root cause:** Developers default to familiar patterns (`await response.json()`) without considering whether buffering is necessary. The fetch API makes buffering the easiest pattern, so it gets copy-pasted across multiple routes. Streaming requires understanding `response.body` and `ReadableStream`, which feels more complex.

**Prevention:** Default to stream-through for proxy routes. Use `return new Response(externalResponse.body, { headers: ... })` to pipe responses without buffering. Only use `await response.arrayBuffer()` or `.json()` if you need to transform the response body. This pattern works for binary content (audio, video, PDFs), large JSON, and Server-Sent Events. For serverless functions, streaming reduces memory usage and cold-start impact.

**Detection:** Grep for `await.*\.arrayBuffer\(\)`, `await.*\.json\(\)`, or `await.*\.text\(\)` in API route files that proxy external services. If the response is immediately forwarded without transformation, the buffering is unnecessary.

**Source:** Weather Mood audio performance overhaul, 2026-02-07. Three routes (music, SFX, narration) refactored from buffering to streaming, eliminating 5-30s latency. Third occurrence of this pattern across projects.

---

## Validation Schema / Generation Schema Mismatch

### ID Generator Alphabet Not Reflected in Validation Regex

**What happens:** An ID is generated with a library (e.g., nanoid) whose default alphabet includes characters (`_`, `-`) that the validation regex does not permit. IDs are generated successfully but rejected by the validator, causing silent failures for a fraction of requests — the fraction corresponding to IDs that happen to contain the excluded characters.

**Root cause:** The developer writes a validation regex (`/^[a-zA-Z0-9]+$/`) based on their mental model of "alphanumeric IDs" without checking the actual output alphabet of the generator. nanoid's default alphabet is `A-Za-z0-9_-` (64 chars). The `_` and `-` appear in roughly 2/64 positions, so ~3% of IDs fail per character; a 21-char nanoid ID has ~48% probability of containing at least one `_` or `-`.

**Prevention:** When adding a validation regex for a generated field, look up the generator's output alphabet first. For nanoid: use `/^[a-zA-Z0-9_-]+$/`. For UUID v4: use the full UUID pattern. Never assume "alphanumeric only" without verifying.

**Detection:** @reviewer should cross-reference ID validation regexes against the ID generation call at the same codepath. If the regex does not explicitly allow every character in the generator's alphabet, flag as a must-fix blocker.

**Source:** ProveIt web build, 2026-02-22. Full Validation was broken for ~40% of requests. @reviewer found this during spec review.

---

## Transient State Spreading Into Persistent Storage

### Object Spread Leaks Ephemeral Fields Into localStorage / Database

**What happens:** A session or model object contains both persistent fields (e.g., `messages`, `mode`, `sessionId`) and transient UI state fields (e.g., `isStreaming`, `isLoading`, `isPending`). When the object is saved to `localStorage` or a database using a spread (`{ ...session, updatedAt: now }`), the transient fields are included. On page reload or session resume, these fields are restored with stale values — e.g., `isStreaming: true` causes a perpetual streaming cursor on a finished session.

**Root cause:** The developer adds a transient field to the session type for UI convenience without marking it as non-persistent. The persistence function uses a spread and silently includes every field.

**Prevention:** Persistence functions must explicitly allowlist the fields they store, OR explicitly strip transient fields using destructuring before spreading. Convention: any field prefixed with `is` that refers to an async UI state (`isStreaming`, `isLoading`, `isSaving`) should be stripped before persistence. Document the allowlist/exclusion list in the session type as a comment.

**Detection:** @qa should look for `isStreaming`, `isLoading`, `isPending`, `isFetching` fields in any type that is serialized to `localStorage`, Supabase, or any database. Any match is a likely bug.

**Source:** ProveIt web build, 2026-02-22. `isStreaming: true` persisted across sessions, showing a stuck streaming cursor on resume.

---

## Duplicated Validation Constants Across Client and Server

### Client-Side Constant Set Independently From Server Schema

**What happens:** A validation limit (e.g., `MAX_CHARS`) is hardcoded in two places: the UI component (`const MAX_CHARS = 1000`) and the server-side schema (Zod `z.string().max(2000)`). The two values diverge, causing the UI to reject valid inputs that the server would accept, or vice versa. Users see a validation error they can't explain, or data that bypasses client validation hits the server and fails there.

**Root cause:** The developer sets the client constant "by feel" without checking the server schema. Or the server schema is updated during a later task but the client constant is not.

**Prevention:** The server schema is the authoritative source. The client constant must be derived from the server schema or re-exported from a shared constants file. Never set a validation limit independently in two places. If the two must live in different files, add a comment: `// Must match Zod schema in api/validate.ts` or enforce with a test that imports both.

**Detection:** Grep for `MAX_`, `MIN_`, `MAX_LENGTH`, `maxLength`, or similar constants in client files. If the same concept appears in a Zod schema elsewhere with a different value, it is a bug.

**Source:** ProveIt web build, 2026-02-22. `MAX_CHARS = 1000` in UI, `max(2000)` in Zod schema. Found by @reviewer.

---

## Feature Accumulation Without Removal

### Replacement Features Added Without Removing Originals

**What happens:** A new system replaces an old one (e.g., ElevenLabs replaces Web Audio synth, new formatter replaces old one, new auth layer replaces old one), but the original is not removed. The two systems coexist, causing bugs from conflicting behavior, state synchronization issues, or inconsistent outputs. In Weather Mood, the Web Audio synth (v1) lingered after ElevenLabs (v2) was added, causing mute-state bugs across multiple sessions. In Transit Pulse, multiple formatter functions duplicated across modules with inconsistent rounding. In ShipIt v1→v2, comparison tables and predecessor concepts leaked into the rewrite.

**Root cause:** The replacement is added as a new feature in one thread, but removing the original is never explicitly tasked. Engineers assume someone else will clean up the old code, or that the old code is harmless if unused. But the old code often IS used in some edge case, or creates state complexity, or confuses future contributors.

**Prevention:** When adding a replacement system, the task description or architecture spec must include a "Deprecated Features" section listing what will be REMOVED. "Add X to replace Y" should always trigger "remove Y" as a linked task. During code review, if a replacement feature is added but the original still exists in the codebase, flag it as "Should Fix: remove deprecated feature."

**Detection:** Look for duplicate implementations of the same capability (two audio systems, two formatters, two authentication layers). If both exist after a "replacement" feature ships, the original was not removed.

**Source:** Weather Mood (synth removal), 2026-02-07. Third occurrence across projects — pattern is proven.

---

## Silent PRD Requirement Substitution

### Hard Requirements Replaced with Shortcuts Without Flagging

**What happens:** An agent (typically @engineer) encounters a difficult PRD requirement — often involving real external data (Kaggle datasets, API integrations, web scraping) — and silently replaces it with a synthetic or generated alternative. The substitution is never flagged to the orchestrator or user. The app works as a tech demo but fails as a credible product because the hardest, most differentiating requirement was bypassed. In Hotel Pricing Intelligence, the PRD specified real Kaggle hotel data for Thread 2 (Data Pipeline), but @engineer generated 1,050 synthetic hotels with fake names, fake rates, and fake reviews. The rest of the stack worked perfectly over fake data, masking the gap.

**Root cause:** The shortcut produces a working system that passes all functional tests. No quality gate explicitly checks "did we build what the PRD asked for?" vs "did we build something that works?" Agents optimize for "working code" not "requirements compliance." The hardest threads are the ones most likely to be substituted because they require external dependencies, data cleaning, or integration work that is genuinely difficult.

**Prevention:** @reviewer must perform a mandatory PRD Coverage check as the FIRST step of every review — reading the PRD and classifying each requirement as Delivered/Partial/Missing/Deviated. @retro must perform a Requirements Check as the first step of every end-of-project retrospective. Any Partial/Missing/Deviated item is a Must Fix. Pay special attention to data sources: if the PRD specifies real data and the build uses synthetic data, this is always a critical gap.

**Detection:** Compare PRD requirements against actual implementation. Look for generated/synthetic data where real data was specified. Check if seed scripts create data from algorithms rather than ingesting from specified sources. If `generate-*.ts` exists where `ingest-*.ts` or `import-*.ts` was expected, investigate.

**Source:** Hotel Pricing Intelligence (synthetic data substitution), 2026-02-28. Critical gap — graduates on first occurrence.
