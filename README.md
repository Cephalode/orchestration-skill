<div align="center">

# 🎼 Claude Code Orchestration

### A 4-team orchestration harness for Claude Code — Planning, Engineering, and Validation via native subagents, worktree isolation, and hooks.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-subagents-blueviolet.svg)](https://docs.anthropic.com/en/docs/claude-code)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)

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
    │     → Reads codebase, produces plan.md      │
    │                                             │
    │  2. @eng-worker × N (background, worktree)  │
    │     → Each implements independent module    │
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

That's it. Claude Code loads the agents, slash commands, and hooks automatically. Use `/orchestrate` for the full pipeline, or `/plan`, `/implement`, `/validate` to run individual phases.

> **Prefer to cherry-pick?** Copy just the agents you need from [`.claude/agents/`](.claude/agents/) and the relevant commands from [`.claude/commands/`](.claude/commands/).

---

## 📋 Table of Contents

- [Quick Start](#-quick-start)
- [The Agent Roster](#-the-agent-roster)
- [Architecture](#-architecture)
- [Workflow Patterns](#-workflow-patterns)
- [Parallel Engineering with Worktrees](#-parallel-engineering-with-worktrees)
- [Hooks for Orchestration](#-hooks-for-orchestration)
- [Agent Teams (Experimental)](#-agent-teams-experimental)
- [Common Pitfalls](#-common-pitfalls)
- [Deep Dive: Subagent Internals](#-deep-dive-subagent-internals)
- [Repo Structure](#-repo-structure)
- [About](#-about)

---

## 🧑‍🚀 The Agent Roster

| Agent | Role | Model | Tools | Isolation | Key Traits |
|-------|------|-------|-------|-----------|------------|
| [`@planning-lead`](.claude/agents/planning-lead.md) | Analyze, plan, specify | opus | Read, Grep, Glob, Bash | none | Read-only, no writes. Produces detailed plan with file specs |
| [`@eng-worker`](.claude/agents/eng-worker.md) | Implement features | sonnet | Read, Write, Edit, Bash | worktree | Scoped to assigned files. Runs in background for parallelism |
| [`@validator`](.claude/agents/validator.md) | Test, review, verify | sonnet | Read, Bash, Grep, Glob | none | Read-only + test execution. Runs full test suite |
| [`@reviewer`](.claude/agents/reviewer.md) _(optional)_ | Code review | opus | Read, Grep, Glob | none | Security, performance, best practices |
| [`@coordinator`](.claude/agents/coordinator.md) _(advanced)_ | Nested coordination | opus | Agent(\*), Read, Bash | none | Spawns its own subagents for complex multi-phase tasks |

### Hermes → Claude Code Mapping

This harness maps each role from a traditional multi-agent orchestrator onto Claude Code's native primitives:

| Traditional Concept | Claude Code Equivalent |
|---------------------|------------------------|
| Orchestrator (lead) | Main Claude session + `Agent` tool |
| Leaf worker delegation | `@subagent-name` invocation |
| Parallel task dispatch | Multiple background subagents with `isolation: worktree` |
| Subagent timeout | `maxTurns` field in agent frontmatter |
| Autonomous cycle | `/loop` or Claude's goals feature |
| Knowledge vault | MCP server or CLAUDE.md integration |
| Hooks (PostToolUse, etc.) | `.claude/settings.json` hooks (identical concept) |
| Planning Team | `@planning-lead` subagent (read-only, opus) |
| Engineering Alpha/Beta | `@eng-worker` subagents (sonnet, worktree isolation) |
| Validation Team | `@validator` subagent (read-only + test execution) |

---

## 🏗 Architecture

### The Pipeline

The default workflow is the **Subagent Pipeline** — a sequential, phase-based flow where the orchestrator delegates to one role at a time (or spawns parallel workers within the Engineering phase):

```
User prompt → /orchestrate "implement feature X"
                        ↓
    ┌──── Main Claude Session (Orchestrator) ────┐
    │                                             │
    │  1. @planning-lead (foreground, read-only)  │
    │     → Reads codebase, produces plan.md      │
    │                                             │
    │  2. @eng-worker × N (background, worktree)  │
    │     → Each implements independent module    │
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

### Two Approaches

| Approach | Maturity | Parallelism | Inter-agent comms | Best for |
|----------|----------|-------------|-------------------|----------|
| **Subagent Pipeline** (primary) | Stable | Background subagents + worktrees | Report back to main only | Most projects |
| **Agent Teams** (advanced) | Experimental | Independent Claude instances | Teammates message each other | Complex multi-agent collaboration |

This repo focuses on the **Subagent Pipeline** as the default, with **Agent Teams** as an optional upgrade for projects that need inter-agent discussion. See [Agent Teams (Experimental)](#-agent-teams-experimental).

### Why Native Subagents (not `claude -p`)

| Factor | `claude -p` (print mode) | Native Subagents |
|--------|------------------------|-----------------|
| Process management | External tmux/PTY needed | Claude Code handles lifecycle |
| Context | Fresh session each call | Isolated within session, resumable |
| Parallelism | Manual tmux sessions | `background: true` + `isolation: worktree` |
| Result handling | Parse JSON from stdout | Summary returns to main conversation |
| Hooks | None | SubagentStart, SubagentStop, per-agent hooks |
| Nesting | Not possible | Up to depth 5 (v2.1.172+) |
| Session state | Stateless | Resumable by agent ID |

---

## 🔄 Workflow Patterns

### Pattern 1: Full Feature Pipeline

User types `/orchestrate "Add JWT authentication with login/signup UI"`

1. **Planning**: Main Claude delegates to `@planning-lead` → returns plan with:
   - File-level specs (new files, modified files)
   - Interface contracts between modules
   - Task breakdown for parallel work
2. **Engineering**: Main Claude dispatches multiple `@eng-worker` agents:
   - Worker A (worktree `auth-core`): JWT middleware, token validation
   - Worker B (worktree `auth-ui`): Login form, signup form, auth context
   - Both run in background simultaneously
3. **Merge**: Orchestrator merges worktrees back to main branch
4. **Validation**: `@validator` runs full test suite, checks imports, reviews
5. **Report**: Orchestrator summarizes results

### Pattern 2: Bug Fix Cycle

```
User: "Users can't log in with Google OAuth — getting 500 error"
  ↓ @planning-lead (investigate root cause)
  → "The callback URL is missing trailing slash, causing redirect mismatch"
  ↓ @eng-worker (fix)
  → Adds trailing slash normalization in OAuth callback handler
  ↓ @validator (verify fix)
  → "All auth tests pass, including new regression test for trailing slash"
```

Or use the `/bugfix` slash command for this pattern directly.

### Pattern 3: Parallel Research

```
User: "Evaluate migration paths from REST to GraphQL"
  ↓ Spawn 3 background subagents:
    @planning-lead → "Analyze current REST API surface"
    @reviewer → "Research GraphQL schema design patterns"
    @validator → "Assess testing implications"
  ↓ All run in parallel, return summaries
  ↓ Orchestrator synthesizes into recommendation
```

Or use the `/research` slash command.

### Pattern 4: Autonomous Development Loop

Use Claude Code's `/loop` command combined with `/orchestrate` to run repeated plan→implement→validate cycles until a feature is complete.

---

## 🌳 Parallel Engineering with Worktrees

### How `isolation: worktree` Works

When `eng-worker` has `isolation: worktree` in its frontmatter:

1. Claude Code creates a temporary git worktree branched from your default branch
2. The subagent works in this isolated copy — file writes don't affect your working directory
3. When the subagent finishes, the orchestrator merges the worktree back
4. If the subagent makes no changes, the worktree is auto-cleaned

### Dispatching Parallel Workers

From the main session, ask Claude:

```
Implement the plan from @planning-lead. Spawn two eng-worker subagents in parallel:
- Worker A: implement the auth middleware (src/auth/)
- Worker B: implement the login UI (src/components/auth/)
Both should run in the background with worktree isolation.
```

Claude dispatches both as background subagents, each in its own worktree. You can continue working while they run. Results arrive as messages when they finish.

### Avoiding Merge Conflicts

Split work at **module boundaries**:

- Worker A owns `src/auth/` — Worker B owns `src/components/auth/`
- Worker A owns backend routes — Worker B owns frontend components
- Shared files (types, config) go to ONE worker only

If conflicts occur during merge, the orchestrator resolves them or dispatches a fix.

---

## 🪝 Hooks for Orchestration

This repo ships with a [`.claude/settings.json`](.claude/settings.json) that includes production-ready hooks:

| Hook | Trigger | Purpose |
|------|---------|---------|
| **Auto-format** | `PostToolUse` on `Edit\|Write` | Runs `prettier` after every file write |
| **Security gate** | `PreToolUse` on `Bash` | Blocks `rm -rf`, `git push --force`, `DROP TABLE`, etc. |
| **Orchestration logging** | `SubagentStart` / `SubagentStop` | Logs phase transitions to `.claude/orchestration.log` |

### Per-Agent Hooks

You can also define hooks directly in an agent's frontmatter. These run only while that agent is active:

```yaml
hooks:
  PostToolUse:
    - matcher: "Edit|Write"
      hooks:
        - type: command
          command: "npx prettier --write $CLAUDE_FILE_PATHS 2>/dev/null || true"
```

### Hook Events Reference

| Event | When | Use Case |
|-------|------|----------|
| `SubagentStart` | Subagent begins | Setup, logging, context injection |
| `SubagentStop` | Subagent completes | Post-phase actions, test triggers |
| `PreToolUse` | Before any tool | Security gates, command validation |
| `PostToolUse` | After any tool | Auto-format, auto-lint |
| `Stop` | Subagent finishes | Converted to SubagentStop at runtime |

See [`templates/settings.md`](templates/settings.md) for all hook configuration variants.

---

## 👥 Agent Teams (Experimental)

For projects needing inter-agent discussion (e.g., competing debugging hypotheses, adversarial code review), enable Agent Teams:

```json
// .claude/settings.json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  },
  "teammateMode": "auto"
}
```

### Team Architecture

```
Team Lead (main session)
  ├── Spawn teammates using subagent definitions
  │   ├── @planning-lead as "architect" teammate
  │   ├── @eng-worker as "backend-dev" teammate
  │   ├── @eng-worker as "frontend-dev" teammate
  │   └── @validator as "qa" teammate
  ├── Shared task list (auto-coordinated)
  ├── Mailbox (inter-agent messaging)
  └── Synthesizes results when all done
```

### When to Use Teams vs Subagents

| Need | Use |
|------|-----|
| Sequential pipeline (plan → build → test) | Subagents |
| Parallel implementation of independent modules | Subagents + worktrees |
| Agents need to discuss/challenge each other | Agent Teams |
| Competing debugging hypotheses | Agent Teams |
| Cross-layer coordination (frontend + backend + tests) | Agent Teams |
| Simple delegation with summary return | Subagents |

### Team Best Practices

- Start with 3–5 teammates (token costs scale linearly)
- Give each teammate 5–6 tasks to stay productive
- Assign distinct file ownership to prevent conflicts
- Use plan approval for risky changes: "Require plan approval before implementation"
- Set `teammateMode: "auto"` to auto-detect tmux/iTerm2 for split panes

---

## ⚠️ Common Pitfalls

1. **Subagents start with fresh context.** They don't see conversation history. Pass ALL needed context in the delegation prompt — file paths, current state, specific requirements. The only shared context is CLAUDE.md and git status.

2. **Foreground subagents block the main session.** Use `background: true` for parallel work, or ask Claude to "run this in the background." Press `Ctrl+B` to background a running task.

3. **Worktree merge conflicts are real.** Split work at module boundaries. If two workers touch the same file, one overwrites the other. Assign distinct file ownership per worker.

4. **`maxTurns` prevents runaway subagents.** Set it in agent frontmatter (e.g., `maxTurns: 50` for eng-worker, `maxTurns: 20` for planning-lead). Without it, a stuck subagent burns tokens indefinitely.

5. **Agent files require session restart.** Files edited on disk aren't picked up until restart. Use `/agents` command for live management instead.

6. **Nested subagents have a depth limit of 5.** A subagent at depth 5 cannot spawn further subagents. Plan your delegation tree depth accordingly.

7. **Tool scoping is critical for role boundaries.** Planning-lead MUST have read-only tools (no Write, no Edit). Validator should not have Write. This prevents role drift.

8. **Subagent summaries are all the orchestrator sees.** Full tool output stays in the subagent's context. Write detailed, structured summaries. Don't assume the orchestrator knows implementation details.

9. **`background: true` changes permission flow (v2.1.186+).** Background subagents surface permission prompts in the main session. Pre-approve common operations in settings to reduce friction.

10. **Agent Teams is experimental.** Session resumption doesn't restore in-process teammates. Teammates may stop on errors. Have a fallback plan for critical work.

11. **`Explore` and `Plan` built-in agents skip CLAUDE.md.** They're designed for fast, cheap research. Custom subagents DO load CLAUDE.md. Don't rely on built-in agents for tasks that need project context.

12. **Token costs scale with agent count.** Each subagent/teammate has its own context window. 3–5 agents is the sweet spot. More than 5 rarely helps and gets expensive fast.

13. **`@`-mention syntax requires exact name.** Use `@planning-lead` not `@planning_lead`. The typeahead picker helps avoid typos.

14. **Worktrees auto-clean only if no changes.** If a subagent makes changes but the merge fails, the worktree persists. Check `git worktree list` and clean up manually if needed.

---

## 🔬 Deep Dive: Subagent Internals

For a complete reference on how Claude Code's subagent system works under the hood — execution models, context isolation, forks, nested subagents, resumption, the full frontmatter spec, and agent teams architecture — see:

📖 **[docs/subagent-internals.md](docs/subagent-internals.md)**

---

## 📁 Repo Structure

```
claude-code-orchestration/
├── README.md                         # You are here
├── CLAUDE.md                         # Orchestration protocol (copy into your project)
├── LICENSE                           # MIT
├── .claude/                          # ⭐ Ready-to-use — copy into any project
│   ├── agents/
│   │   ├── planning-lead.md          # Read-only planner (opus)
│   │   ├── eng-worker.md             # Implementation worker (sonnet, worktree)
│   │   ├── validator.md              # Test runner + reviewer (sonnet)
│   │   ├── reviewer.md               # Optional code reviewer (opus)
│   │   └── coordinator.md            # Advanced nested coordinator (opus)
│   ├── commands/
│   │   ├── orchestrate.md            # Full pipeline
│   │   ├── plan.md                   # Planning only
│   │   ├── implement.md              # Engineering only
│   │   ├── validate.md               # Validation only
│   │   ├── review.md                 # Standalone code review
│   │   ├── bugfix.md                 # Quick bug fix pipeline
│   │   └── research.md               # Parallel research
│   └── settings.json                 # Permissions, hooks, security gates
├── docs/
│   └── subagent-internals.md         # Deep dive on subagent mechanics
└── templates/                        # Original templates for reference/customization
    ├── agents.md
    ├── claude-md.md
    ├── commands.md
    └── settings.md
```

---

## ✅ Verification Checklist

After setting up in your project, verify:

- [ ] `.claude/agents/` contains all agent files with correct frontmatter
- [ ] Each agent has appropriate `tools` (read-only for planning/validation, full for eng)
- [ ] `eng-worker` has `isolation: worktree` and `background: true`
- [ ] `maxTurns` set on every agent to prevent runaway
- [ ] CLAUDE.md has orchestration protocol section
- [ ] Slash commands created in `.claude/commands/`
- [ ] Test: `/orchestrate "create a hello world endpoint"` runs full pipeline
- [ ] Verify agent isolation: planning-lead cannot write files
- [ ] Hooks configured in `.claude/settings.json` (if used)
- [ ] Worktrees cleaned up after merges (`git worktree list`)

---

<div align="center">

## 💡 About

**Claude Code Orchestration** is inspired by [Hermes Agent](https://hermes-agent.nousresearch.com)'s 4-team orchestration pattern — a meta-agent system that coordinates Planning → Engineering → Validation teams for complex software development.

This repo ports that pattern onto Claude Code's **native subagent system**, so you get the same structured pipeline without any external orchestration tooling. Everything lives in `.claude/` and is git-trackable, making it easy to share orchestration configs across your team.

Created by **[Cephalode](https://github.com/Cephalode)** · MIT License

</div>
