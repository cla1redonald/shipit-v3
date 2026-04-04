# Commit Conventions

Load this reference when committing code.

## Conventional Commits

Format: `type: description`

| Type | When to Use |
|------|------------|
| `feat:` | New feature or functionality |
| `fix:` | Bug fix |
| `test:` | Adding or updating tests |
| `docs:` | Documentation changes |
| `refactor:` | Code change that neither fixes a bug nor adds a feature |
| `chore:` | Build process, dependencies, tooling |
| `style:` | Formatting, missing semi-colons (no code change) |
| `perf:` | Performance improvement |

## Examples

```
feat: add dark mode toggle to settings page
fix: prevent crash on empty search results
test: add edge case tests for date parsing
docs: update API documentation for /items endpoint
refactor: extract validation logic into shared utility
chore: upgrade vitest to v2.0
```

## Rules

- Keep the first line under 72 characters
- Use imperative mood ("add" not "added" or "adds")
- Don't end with a period
- Body (optional) explains WHY, not WHAT

## When to Squash vs Individual Commits

| Situation | Approach |
|-----------|----------|
| Feature branch with many small commits | Squash on merge |
| Each commit is a logical unit | Keep individual |
| WIP or fixup commits | Squash before PR |
| Multiple unrelated changes | Split into separate PRs |

## Co-Author Attribution

When agents contribute to code:
```
Co-Authored-By: Claude <noreply@anthropic.com>
```
