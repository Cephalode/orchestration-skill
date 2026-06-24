# Slash Command Templates

Drop these into `.claude/commands/` in your project. Each file becomes a `/command`.

## orchestrate.md

Full pipeline: Planning → Engineering → Validation.

```markdown
# .claude/commands/orchestrate.md

Orchestrate the following task through the full pipeline:

$ARGUMENTS

Follow the Orchestration Protocol from CLAUDE.md:

1. **Planning Phase**: Delegate to @planning-lead to analyze the codebase and produce a detailed implementation plan. Wait for the plan.

2. **Engineering Phase**: Based on the plan's task breakdown, dispatch @eng-worker sub-agents. Each worker runs in an isolated worktree in the background. Assign distinct file ownership per worker. Wait for all workers to complete.

3. **Merge Phase**: Merge all worktree changes back to the working directory. Resolve any conflicts.

4. **Validation Phase**: Delegate to @validator to run the full test suite, check imports, and review the implementation. If validation finds issues, dispatch fixes.

5. **Report**: Summarize what was accomplished, what files changed, and any remaining issues.
```

Usage: `/orchestrate Add JWT authentication with login and signup`

## plan.md

Planning phase only — produces a plan without implementing.

```markdown
# .claude/commands/plan.md

Delegate to @planning-lead to analyze the codebase and create a detailed implementation plan for:

$ARGUMENTS

The plan should include:
- Files to create and modify (with exact paths)
- Interface contracts between modules
- Task breakdown for parallel engineering (split at module boundaries)
- Risks and considerations

Do NOT implement anything. This is planning only.
```

Usage: `/plan Migrate from REST to GraphQL`

## implement.md

Engineering phase only — implements from an existing plan.

```markdown
# .claude/commands/implement.md

Implement the plan using @eng-worker sub-agents.

$ARGUMENTS

Based on the plan (from the conversation or referenced above):
1. Identify the parallel tasks from the plan's task breakdown
2. Dispatch one @eng-worker per task, each in an isolated worktree
3. Assign distinct file ownership — no two workers edit the same file
4. Wait for all workers to complete
5. Merge worktree changes back
6. Report what was implemented and any issues encountered

If no plan exists yet, use /plan first.
```

Usage: `/implement` (after running `/plan`)

## validate.md

Validation phase only — runs tests and review.

```markdown
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
```

Usage: `/validate` or `/validate focus on the auth module`

## review.md

Standalone code review.

```markdown
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
```

Usage: `/review` or `/review the auth changes in src/auth/`

## bugfix.md

Quick bug fix pipeline — investigate, fix, validate.

```markdown
# .claude/commands/bugfix.md

Fix the following bug through the pipeline:

$ARGUMENTS

1. **Investigate**: Delegate to @planning-lead to investigate the root cause. Read relevant source files, trace the error, and identify the fix.

2. **Fix**: Dispatch @eng-worker to implement the fix based on the investigation.

3. **Validate**: Delegate to @validator to run tests and verify the fix.

4. **Report**: Summary of root cause, fix applied, and verification results.
```

Usage: `/bugfix Users get 500 error on Google OAuth login`

## research.md

Parallel research — spawn multiple investigators.

```markdown
# .claude/commands/research.md

Research the following topic using parallel sub-agents:

$ARGUMENTS

1. Spawn 2-3 @planning-lead or @reviewer sub-agents in the background, each investigating a different aspect of the topic.

2. Wait for all to complete.

3. Synthesize their findings into a comprehensive summary with:
   - Key findings from each investigator
   - Areas of agreement and disagreement
   - Recommended next steps
```

Usage: `/research Evaluate SQLite vs PostgreSQL for our use case`
