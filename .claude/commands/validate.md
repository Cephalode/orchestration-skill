# .claude/commands/validate.md

Run the full validation pipeline:

1. Delegate to @validator to run the complete test suite, check for import errors, verify type checking, and review code quality.

2. If the user provided arguments, focus validation on those areas:
$ARGUMENTS

3. Report:
   - Build status (pass/fail)
   - Test results (X passed, Y failed)
   - Issues found (with severity and file:line)
   - Verdict (APPROVED or NEEDS_FIXES with specific items)

If validation fails, offer to dispatch @eng-worker to fix the issues.
