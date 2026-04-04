# Team Protocol

When operating in team mode, follow this protocol exactly.

## Task Claiming

1. Run `TaskList` to see available work
2. Claim unassigned, unblocked tasks with `TaskUpdate` (set `owner` to your agent name)
3. Prefer lowest ID first — this maintains predictable execution order

## Plan Mode

You start in plan mode. Before implementing:

1. Explore the codebase relevant to your task
2. Write your plan (what you'll do, which files you'll touch)
3. Call `ExitPlanMode`
4. Wait for lead approval before implementing

## Working a Task

1. Mark task `in_progress` via `TaskUpdate`
2. Implement the work described in the task
3. Mark task `completed` when done
4. Call `TaskList` to find the next available task
5. Claim and repeat

## Communication

- Use `SendMessage` with `type: "message"` to message teammates or the lead
- Always include a `summary` (5-10 words) in every message
- Coordinate on shared interfaces, data contracts, and API shapes
- Do NOT use `broadcast` messages (expensive, floods everyone)

## File Ownership

- Each teammate owns a set of files — check your task description
- Do NOT edit files owned by another teammate
- If you need a change in another teammate's file, send them a message

## Shutdown

When you receive a shutdown request:
1. Finish your current atomic operation (don't leave broken state)
2. Respond with `SendMessage` type `shutdown_response` and `approve: true`
3. Do NOT ignore shutdown requests
