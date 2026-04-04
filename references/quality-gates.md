# Quality Gates

Load this reference when verifying code quality before shipping.

## Triple Gate

Run after every implementation attempt. All three must pass.

```bash
# 1. Tests
npm test -- --run

# 2. Type check
npx tsc --noEmit

# 3. Build (the actual CI/Vercel command)
npm run build
```

**Important:** `tsc --noEmit` and the build command can produce different results (different tsconfig resolution, project references). The build command is what CI runs — that's the one that matters.

For Python projects:
```bash
# 1. Tests
pytest

# 2. Type check
mypy src/

# 3. Build/lint
ruff check src/
```

## Test Requirements

| Test Type | Minimum per Feature |
|-----------|-------------------|
| Happy path | Required |
| Error case | Required |
| Key edge case | Required |

A feature is NOT complete until tests are written and passing.

## Pre-Push Verification

After any rebase, merge, or conflict resolution:

1. **Grep for conflict markers:**
```bash
grep -rn "^<<<<<<<\|^=======\|^>>>>>>>" src/
```
If any results appear, the conflict is not resolved.

2. **Run the build command** (not just typecheck)

3. **Run the full test suite**

## Pre-Commit Checklist

- [ ] No `any` types without justification
- [ ] No hardcoded secrets or credentials
- [ ] No console.log/print statements left in production code
- [ ] No commented-out code blocks
- [ ] No TODO/FIXME without a tracking issue
- [ ] All new functions have meaningful names
- [ ] Error handling present on all async operations
- [ ] Input validation on all user-facing endpoints

## Security Baseline

Every commit should pass:

- [ ] Input validation on all user input (Zod/Pydantic)
- [ ] Parameterised queries (no string concatenation in SQL)
- [ ] No XSS vectors (no `dangerouslySetInnerHTML` without sanitisation)
- [ ] Secrets in environment variables, not code
- [ ] Auth checks on protected routes
- [ ] Database access control configured (RLS or equivalent)
