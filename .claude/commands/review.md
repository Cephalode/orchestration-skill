# .claude/commands/review.md

Delegate to @reviewer to perform a thorough code review of recent changes.

$ARGUMENTS

The reviewer should check:
- Security vulnerabilities (injection, auth flaws, secrets)
- Performance issues (N+1 queries, unnecessary re-renders, memory leaks)
- Correctness (logic errors, race conditions, null handling)
- Code quality (naming, abstraction, DRY, dead code)
- Test coverage gaps

If reviewing a specific PR or branch, compare against main:
!git diff main...HEAD

Report findings with severity levels and specific fix recommendations.
