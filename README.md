<div align="center">

# 🎼 Orchestration Skill

### A Claude Code orchestration harness — Planning, Engineering, and Validation via native subagents, worktree isolation, and hooks. Per-agent model tiers via native frontmatter.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-subagents-blueviolet.svg)](https://docs.anthropic.com/en/docs/claude-code)

</div>

---

Replicate a multi-agent engineering team **entirely within Claude Code's native subagent system**. No `claude -p`, no external tmux management, no glue scripts — just `.claude/agents/`, `@`-mentions, worktree isolation, and hooks.

Your main Claude Code session becomes the **orchestrator**, delegating to specialized subagents that run in their own context windows with scoped tools. Each subagent returns only a summary — preserving context, enforcing role boundaries, and enabling genuine parallelism.

```
User prompt → /orchestrate "implement feature X"
                        ↓
    ┌──── Main Claude Session (Orchestrator) ────┐
    │                                             │
    │  1. @planning-lead (foreground, read-only)  │
    │     → Reads codebase, produces a structured plan│
    │                                             │
    │  2. @eng-worker (background, worktree)      │
    │     → Spawns N instances, one per module    │
    │     → Parallel via isolation: worktree      │
    │                                             │
    │  3. Orchestrator merges worktrees           │
    │                                             │
    │  4. @validator (foreground, read-only)      │
    │     → Runs tests, checks imports, reviews   │
    │                                             │
    │  5. Report results to user                  │
    └─────────────────────────────────────────────┘
```

---

## 🚀 Quick Start

**3 steps. Under 60 seconds.**

```bash
# 1. Copy the .claude/ directory and CLAUDE.md into your project
cp -r .claude/ /path/to/your/project/.claude/
cp CLAUDE.md /path/to/your/project/.claude/CLAUDE.md   # or append to existing CLAUDE.md

# 2. Open your project in Claude Code
cd /path/to/your/project && claude

# 3. Run the full pipeline
/orchestrate "Add JWT authentication with login and signup UI"
```

That's it. Claude Code loads the agents, the slash command, and hooks automatically. Use `/orchestrate` for the full pipeline, or `@`-mention individual agents (`@planning-lead`, `@eng-worker`, `@validator`) to run a single phase.

> **Prefer to cherry-pick?** Copy just the agents you need from [`.claude/agents/`](.claude/agents/).

---

## 🧑‍🚀 The Agent Roster

The harness keeps a deliberately small roster — **3 agents**, comfortably in the 3–5 sweet spot. The engineering role is a single `@eng-worker` you spawn N times for parallelism (one instance per module, distinct file ownership each).

| Agent | Role | Model | Tools | Isolation | Key Traits |
|-------|------|-------|-------|-----------|------------|
| [`@planning-lead`](.claude/agents/planning-lead.md) | Analyze, plan, specify | opus | Read, Grep, Glob, Bash | none | Read-only, no writes. Produces detailed plan with file specs |
| [`@eng-worker`](.claude/agents/eng-worker.md) | Implement modules | inherit | Read, Write, Edit, Bash, Grep, Glob | worktree | Spawn N for parallel work; disjoint file ownership per instance |
| [`@validator`](.claude/agents/validator.md) | Test, review, verify | sonnet | Read, Bash, Grep, Glob | none | Read-only + test execution. Runs full test suite |

---

## ⚙️ Configuration

### Customizing Agents

Agents are plain Markdown files with YAML frontmatter. Edit any file in `.claude/agents/` directly:

```yaml
---
name: eng-worker
model: inherit           # opus, sonnet, haiku, or inherit
tools: Read, Write, Edit, Bash, Grep, Glob
isolation: worktree
background: true
maxTurns: 50
description: "Implementation worker..."
---
```

After editing, restart Claude Code or run `/agents` to reload.

### Model Tiers

Models are set per-agent via the `model:` frontmatter (opus/sonnet/haiku/inherit). For a global economy tier, set `CLAUDE_CODE_SUBAGENT_MODEL=sonnet`. No script needed.

<!-- ponytail: no switch script; global economy tier via CLAUDE_CODE_SUBAGENT_MODEL=sonnet, per-agent via model: frontmatter. -->

---

## 🏗 Architecture

This repo uses Claude Code's **native subagent pipeline**: `@planning-lead` → `@eng-worker`×N (parallel, worktree-isolated) → merge → `@validator`. Subagents run in their own context windows with scoped tools and return only a summary, preserving context and enforcing role boundaries.

---

## 🔄 Workflow Pattern: Full Feature Pipeline

User types `/orchestrate "Add JWT authentication with login/signup UI"`:

1. **Planning**: Main Claude delegates to `@planning-lead` → returns plan with:
   - File-level specs (new files, modified files)
   - Interface contracts between modules
   - Task breakdown for parallel work
2. **Engineering**: Main Claude dispatches two workers in parallel:
   - `@eng-worker` (worktree `auth-core`): JWT middleware, token validation
   - `@eng-worker` (worktree `auth-ui`): Login form, signup form, auth context
   - Both run in background simultaneously
3. **Merge**: Orchestrator merges worktrees back to main branch
4. **Validation**: `@validator` runs full test suite, checks imports, reviews
5. **Report**: Orchestrator summarizes results

---

## 🌳 Parallel Engineering with Worktrees

### Avoiding Merge Conflicts

Split work at **module boundaries**:

- One worker owns `src/auth/` — another owns `src/components/auth/`
- One worker owns backend routes — another owns frontend components
- Shared files (types, config) go to ONE worker only

If conflicts occur during merge, the orchestrator resolves them or dispatches a fix.

---

## 🪝 Hooks

This repo ships with a [`.claude/settings.json`](.claude/settings.json) that includes a production-ready security hook:

| Hook | Trigger | Purpose |
|------|---------|---------|
| **Security gate** | `PreToolUse` on `Bash` | Blocks `rm -rf`, `git push --force`, `git reset --hard`, `DROP TABLE`, `DELETE FROM` |

<!-- ponytail: cut prettier (JS-specific) and SubagentStart/Stop logging hooks — not portable / nobody reads the log; native `claude -d` covers debugging. -->

---

## ⚠️ Common Pitfalls

1. **Subagents start with fresh context.** They don't see conversation history. Pass ALL needed context in the delegation prompt — file paths, current state, specific requirements. The only shared context is CLAUDE.md and git status.

2. **Foreground subagents block the main session.** Use `background: true` for parallel work, or ask Claude to "run this in the background." Press `Ctrl+B` to background a running task.

3. **Worktree merge conflicts are real.** Split work at module boundaries. If two workers touch the same file, one overwrites the other. Assign distinct file ownership per worker.

4. **`maxTurns` prevents runaway subagents.** Set it in agent frontmatter (e.g., `maxTurns: 50` for eng-workers, `maxTurns: 30` for planning-lead). Without it, a stuck subagent burns tokens indefinitely.

5. **Tool scoping is critical for role boundaries.** Planning-lead MUST have read-only tools (no Write, no Edit). Validator should not have Write. This prevents role drift.

6. **Subagent summaries are all the orchestrator sees.** Full tool output stays in the subagent's context. Write detailed, structured summaries. Don't assume the orchestrator knows implementation details.

---

## 📁 Repo Structure

```
orchestration-skill/
├── README.md                         # You are here
├── CLAUDE.md                         # Orchestration protocol (copy into your project)
├── LICENSE                           # MIT
├── .claude/                          # Ready-to-use — copy into any project
│   ├── agents/                       # Agent definitions — edit .md files directly
│   │   ├── planning-lead.md          # Read-only planner
│   │   ├── eng-worker.md             # Implementation worker (worktree; spawn N for parallelism)
│   │   └── validator.md              # Tests + review
│   ├── commands/
│   │   └── orchestrate.md            # Full pipeline
│   └── settings.json                 # Permissions + security gate
```

---

## ✅ Verification Checklist

After setting up in your project, verify:

- [ ] `.claude/agents/` contains all agent files with correct frontmatter
- [ ] Each agent has appropriate `tools` (read-only for planning/validation, full for eng)
- [ ] `eng-worker` has `isolation: worktree` and `background: true`
- [ ] `maxTurns` set on every agent to prevent runaway
- [ ] CLAUDE.md has orchestration protocol section
- [ ] Model tier chosen via `model:` frontmatter or `CLAUDE_CODE_SUBAGENT_MODEL` (then restart Claude Code)
- [ ] Test: `/orchestrate "create a hello world endpoint"` runs full pipeline
- [ ] Worktrees cleaned up after merges (`git worktree list`)

---

<div align="center">

## 💡 About

**Orchestration Skill** is inspired by [Hermes Agent](https://hermes-agent.nousresearch.com)'s 4-team orchestration pattern — a meta-agent system that coordinates Planning → Engineering → Validation teams for complex software development.

This repo ports that pattern onto Claude Code's **native subagent system**, so you get the same structured pipeline without any external orchestration tooling. Everything lives in `.claude/` and is git-trackable, making it easy to share orchestration configs across your team.

Created by **[Cephalode](https://github.com/Cephalode)** · MIT License

</div>
