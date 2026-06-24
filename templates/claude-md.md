# CLAUDE.md Orchestration Protocol

Append this section to your project's `CLAUDE.md` to teach the main Claude session how to orchestrate sub-agents.

## When to Use

Add this when:
- You've set up `.claude/agents/` with the orchestration agent files
- You want Claude to automatically use the Planning → Engineering → Validation pipeline
- You want consistent orchestration behavior across team members

## Template

```markdown
## Orchestration Protocol

This project uses a sub-agent orchestration pipeline. For features, bug fixes, and refactors that touch multiple files or modules, follow this pipeline:

### Pipeline Phases

1. **Planning**: Delegate to `@planning-lead` to analyze the codebase and produce a detailed plan
   - Planning-lead is read-only — it will not modify files
   - Wait for the plan before proceeding to implementation

2. **Engineering**: Dispatch `@eng-worker` sub-agents based on the plan
   - Each worker runs in an isolated worktree (`isolation: worktree`)
   - Workers run in the background for parallelism
   - Assign distinct file ownership per worker to avoid conflicts
   - For single-module changes, one worker is sufficient

3. **Merge**: After all workers complete, merge their worktree changes
   - Check for merge conflicts at module boundaries
   - If conflicts occur, resolve them or dispatch a fix worker

4. **Validation**: Delegate to `@validator` to verify the implementation
   - Validator runs the full test suite and checks for issues
   - If validation fails, dispatch fixes to `@eng-worker`

### When to Use the Full Pipeline

Use the pipeline for:
- New features spanning multiple files
- Refactors that touch shared interfaces
- Bug fixes requiring investigation
- Any change that benefits from a plan before implementation

Skip the pipeline for:
- Single-file changes under 50 lines
- Quick typo or config fixes
- Tasks you can describe in one sentence

### Orchestrator Behavior

As the orchestrator (main session), you:
- DO NOT write code yourself — delegate to sub-agents
- DO read sub-agent summaries and make decisions
- DO pass complete context to each sub-agent (they start fresh)
- DO synthesize results between phases
- DO commit after each successful phase

### Agent Roster

| Agent | Purpose | Model | Writes? |
|-------|---------|-------|---------|
| @planning-lead | Analyze, plan, specify | opus | No (read-only) |
| @eng-worker | Implement features | sonnet | Yes (worktree) |
| @validator | Test, verify, review | sonnet | No (read-only) |
| @reviewer | Security & quality review | opus | No (read-only) |

### Quick Reference

- Plan a feature: `/plan "description"` or `@planning-lead analyze and plan: ...`
- Implement a plan: `/implement` or spawn `@eng-worker` agents per task
- Validate: `/validate` or `@validator run full test suite and review`
- Full pipeline: `/orchestrate "description"`
```

## Agent Teams Variant

If using experimental Agent Teams, use this variant instead:

```markdown
## Orchestration Protocol (Agent Teams)

For complex tasks, spawn an agent team:

1. Describe the task and teammates you want
2. The lead (you) creates tasks and assigns them
3. Teammates work in parallel, communicate with each other
4. Synthesize results when all teammates are done

Example prompt:
"Spawn 4 teammates to implement the user profile feature:
- 'backend' teammate: implement API endpoints in src/api/profiles/
- 'frontend' teammate: implement profile UI in src/components/profile/
- 'tests' teammate: write integration tests in tests/profiles/
- 'reviewer' teammate: review code as it's committed
Use the eng-worker agent type for implementers, validator for the reviewer."

Team rules:
- Each teammate owns distinct files — no shared file editing
- Use plan approval for risky changes
- Check in periodically — don't let teammates run unattended too long
- Shut down teammates when their work is done
```
