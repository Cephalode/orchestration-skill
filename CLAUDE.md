# Orchestration Protocol

This project uses a sub-agent orchestration pipeline. For features, bug fixes, and refactors that touch multiple files or modules, follow this pipeline.

> **This file is a drop-in protocol section.** Copy its contents into your project's `CLAUDE.md` (or `~/.claude/CLAUDE.md` for global use) to teach the main Claude session how to orchestrate sub-agents.

## Pipeline Phases

1. **Planning**: Delegate to `@planning-lead` to analyze the codebase and produce a detailed plan
   - Planning-lead is read-only — it will not modify files
   - Wait for the plan before proceeding to implementation

2. **Engineering**: Dispatch `@eng-worker` sub-agents based on the plan
   - Each worker runs in an isolated worktree (`isolation: worktree`)
   - Workers run in the background for parallelism
   - Assign distinct file ownership per worker to avoid conflicts (split at module boundaries)
   - Spawn one worker for single-module work, two or more for parallel multi-module work

3. **Merge**: After all workers complete, merge their worktree changes
   - Check for merge conflicts at module boundaries
   - If conflicts occur, resolve them or dispatch a fix worker

4. **Validation**: Delegate to `@validator` to verify the implementation
   - Validator runs the full test suite and checks for issues
   - If validation fails, dispatch fixes to `@eng-worker`

## When to Use the Full Pipeline

Use the pipeline for:
- New features spanning multiple files
- Refactors that touch shared interfaces
- Bug fixes requiring investigation
- Any change that benefits from a plan before implementation

Skip the pipeline for:
- Single-file changes under 50 lines
- Quick typo or config fixes
- Tasks you can describe in one sentence

## Orchestrator Behavior

As the orchestrator (main session), you:
- DO NOT write code yourself — delegate to sub-agents
- DO read sub-agent summaries and make decisions
- DO pass complete context to each sub-agent (they start fresh)
- DO synthesize results between phases
- DO commit after each successful phase

## Agent Roster

Models are set per-agent via the `model:` frontmatter (opus/sonnet/haiku/inherit). For a global economy tier, set `CLAUDE_CODE_SUBAGENT_MODEL=sonnet`.

<!-- ponytail: no switch script; global economy tier via CLAUDE_CODE_SUBAGENT_MODEL=sonnet, per-agent via model: frontmatter. -->

| Agent | Purpose | Model | Writes? |
|-------|---------|-------|---------|
| @planning-lead | Analyze, plan, specify | inherit (read-only) | No |
| @eng-worker | Implement modules | inherit | Yes (worktree) |
| @validator | Test, verify, review | inherit (read-only + tests) | No |
