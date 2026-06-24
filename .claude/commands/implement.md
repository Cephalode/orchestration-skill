# .claude/commands/implement.md

Implement the plan using @eng-worker-alpha and @eng-worker-beta sub-agents.

$ARGUMENTS

Based on the plan (from the conversation or referenced above):
1. Identify the parallel tasks from the plan's task breakdown
2. Dispatch @eng-worker-alpha and/or @eng-worker-beta per task (one worker per task), each in an isolated worktree — assign complex modules to alpha, straightforward ones to beta
3. Assign distinct file ownership — no two workers edit the same file
4. Wait for all workers to complete
5. Merge worktree changes back
6. Report what was implemented and any issues encountered

If no plan exists yet, use /plan first.
