# .claude/commands/orchestrate.md

Orchestrate the following task through the full pipeline:

$ARGUMENTS

Follow the Orchestration Protocol in CLAUDE.md: **@planning-lead** (analyze + plan, wait for it) → **@eng-worker** (parallel, one per module, worktree isolation; merge worktrees back) → **@validator** (test + review; dispatch fixes to @eng-worker if needed).

Summarize what was accomplished, files changed, and any remaining issues.
