# .claude/commands/orchestrate.md

Orchestrate the following task through the full pipeline:

$ARGUMENTS

Follow the Orchestration Protocol from CLAUDE.md:

1. **Planning Phase**: Delegate to @planning-lead to analyze the codebase and produce a detailed implementation plan. Wait for the plan.

2. **Engineering Phase**: Based on the plan's task breakdown, dispatch @eng-worker sub-agents. Each worker runs in an isolated worktree in the background. Assign distinct file ownership per worker. Wait for all workers to complete.

3. **Merge Phase**: Merge all worktree changes back to the working directory. Resolve any conflicts.

4. **Validation Phase**: Delegate to @validator to run the full test suite, check imports, and review the implementation. If validation finds issues, dispatch fixes.

5. **Report**: Summarize what was accomplished, what files changed, and any remaining issues.
