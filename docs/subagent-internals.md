# Claude Code Subagent Internals

Deep dive on how Claude Code's subagent system works under the hood. Use this reference to understand execution models, context isolation, and advanced features.

## Execution Model

### Foreground vs Background

| Mode | Behavior | How to Trigger |
|------|----------|----------------|
| **Foreground** (default) | Blocks main conversation until subagent completes. Permission prompts pass through. | Default behavior, or ask Claude to "run this in the foreground" |
| **Background** | Subagent runs concurrently. You continue working. Results arrive as messages. | `background: true` in frontmatter, or ask Claude to "run in background", or press `Ctrl+B` on a running task |

Background subagents (v2.1.186+) surface permission prompts in the main session, naming the subagent that's asking. Press `Esc` to deny a single tool call without stopping the subagent.

Set `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1` to disable all background functionality.

### How Delegation Works

1. **Automatic delegation**: Claude reads each subagent's `description` field and decides when to delegate. Include "use proactively" in descriptions to encourage proactive delegation.

2. **Explicit `@-mention`**: Type `@` and pick the subagent from the typeahead, or type `@agent-<name>`. This guarantees the subagent runs.

3. **Natural language**: Name the subagent in your prompt ("Use the planning-lead subagent to..."). Claude decides whether to delegate.

4. **Session-wide (`--agent`)**: Run `claude --agent planning-lead` to make the entire session use that subagent's system prompt, tools, and model. The subagent's prompt replaces the default Claude Code system prompt entirely.

### The Agent Tool

In Claude Code v2.1.63+, the `Agent` tool (renamed from `Task`) is how the main session spawns subagents. When Claude decides to delegate, it uses the Agent tool with:
- `agent_type`: The subagent name (e.g., "planning-lead")
- `prompt`: The delegation message (what the subagent should do)
- Optional: `model`, `isolation`, `background`

You can restrict which subagents can be spawned using `Agent(type1, type2)` in the tools field.

## Context Isolation

### What a Subagent Sees

Each subagent starts with a **fresh, isolated context window**:

| Component | Included? | Notes |
|-----------|-----------|-------|
| Agent's system prompt | ✅ | The markdown body of the `.claude/agents/` file |
| Environment details | ✅ | Working directory, basic system info |
| Delegation message | ✅ | The prompt Claude writes when handing off work |
| CLAUDE.md (all levels) | ✅ | ~/.claude/CLAUDE.md, project CLAUDE.md, CLAUDE.local.md |
| Git status snapshot | ✅ | From parent session start. Absent if not a git repo. |
| Preloaded skills | ✅ | Full content of skills listed in `skills:` field |
| Conversation history | ❌ | Subagents do NOT see prior messages |
| Skills invoked in main session | ❌ | Not carried over |
| Files read by main session | ❌ | Not carried over |

**Exception**: Built-in `Explore` and `Plan` agents skip CLAUDE.md and git status for speed. Custom subagents always load them.

### Passing Context Effectively

Since subagents start fresh, the delegation prompt must contain everything they need:

```
@planning-lead Analyze the authentication system in src/auth/. The project uses
Express.js with TypeScript. We need to add JWT-based authentication with refresh
tokens. Current auth uses session cookies (see src/auth/session.ts). Database is
PostgreSQL via Prisma (schema in prisma/schema.prisma). Plan the migration.
```

### Forks (Full Context Inheritance)

Forks (v2.1.117+) are special subagents that inherit the **entire conversation**:

| Aspect | Fork | Named Subagent |
|--------|------|----------------|
| Context | Full conversation history | Fresh, only delegation prompt |
| System prompt | Same as main session | From agent definition |
| Tools | Same as main session | From agent definition |
| Model | Same as main session | From agent definition |
| Prompt cache | Shared with parent | Separate |
| Can spawn forks | ❌ | ✅ (other types) |

Enable with `CLAUDE_CODE_FORK_SUBAGENT=1`. Use `/fork <directive>` to create one. Forks run in the background automatically. Only the fork's final result returns to main — its tool calls stay isolated.

Forks are cheaper than fresh subagents because they reuse the parent's prompt cache.

## Worktree Isolation

### How It Works

When `isolation: worktree` is set in an agent's frontmatter:

1. Claude Code creates a temporary git worktree at `.claude/worktrees/<name>/`
2. The worktree is branched from your **default branch** (not the current HEAD)
3. The subagent works in this isolated copy — writes don't affect your working directory
4. When the subagent finishes, the orchestrator can merge the changes
5. **Auto-cleanup**: If the subagent makes no changes, the worktree is removed automatically

### Manual Worktree Management

```bash
# List active worktrees
git worktree list

# The subagent's worktree appears as:
# /path/to/project/.claude/worktrees/<hash>  <hash> [<branch-name>]

# After subagent completes, merge changes:
cd /path/to/project  # your main working directory
git merge <branch-name>  # or cherry-pick specific commits

# Clean up
git worktree remove .claude/worktrees/<hash>
git branch -d <branch-name>
```

### Worktree + Worktree CLI Flag

You can also use `--worktree` at the session level:
```bash
claude -w feature-x --tmux
```
This creates a worktree AND a tmux session for it. The main session runs inside the worktree.

## Nested Subagents (v2.1.172+)

Subagents can spawn their own subagents:

```
Main Session (depth 0)
  └── coordinator (depth 1)
       ├── planning-lead (depth 2)
       ├── eng-worker-alpha (depth 2)
       └── validator (depth 2)
```

- Maximum depth: **5 levels** below the main conversation
- At depth 5, the Agent tool is not available — no further spawning
- Nested subagent results return to their parent, not directly to main
- Only the **top-level subagent's summary** returns to the main conversation

To enable nesting, include `Agent` (or `Agent(type1, type2)`) in the subagent's `tools` field. To prevent nesting, omit `Agent` from tools or add it to `disallowedTools`.

## Subagent Resumption

Completed subagents can be resumed with full context:

```
# First invocation
@code-reviewer review the auth module
# [Agent completes, Claude receives agent ID]

# Resume
Continue that code review and now analyze the authorization logic
# [Claude resumes the subagent with full history]
```

- Claude uses the `SendMessage` tool with the agent's ID
- Stopped subagents auto-resume in the background when they receive a message
- Subagent transcripts persist at `~/.claude/projects/{project}/{sessionId}/subagents/agent-{agentId}.jsonl`
- Transcripts survive main conversation compaction
- `Explore` and `Plan` agents are one-shot — they return no agent ID and can't be resumed

## Auto-Compaction

Subagents support automatic context compaction (same logic as main conversation):
- Triggers under the same conditions as the main session
- `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` applies to subagents too
- Compaction events are logged in subagent transcripts

## Subagent Frontmatter Reference (Complete)

| Field | Required | Default | Description |
|-------|----------|---------|-------------|
| `name` | ✅ | — | Unique identifier, lowercase + hyphens |
| `description` | ✅ | — | When Claude should delegate to this subagent |
| `tools` | ❌ | All inherited | Tool allowlist. Use `Agent(type)` for spawn restrictions |
| `disallowedTools` | ❌ | — | Tool denylist. Applied before `tools` allowlist |
| `model` | ❌ | inherit | `sonnet`, `opus`, `haiku`, `fable`, full model ID, or `inherit` |
| `permissionMode` | ❌ | inherit | `default`, `acceptEdits`, `auto`, `dontAsk`, `bypassPermissions`, `plan` |
| `maxTurns` | ❌ | unlimited | Max agentic turns before subagent stops |
| `skills` | ❌ | — | Skills to preload (full content injected at startup) |
| `mcpServers` | ❌ | — | MCP servers scoped to this subagent |
| `hooks` | ❌ | — | Lifecycle hooks scoped to this subagent |
| `memory` | ❌ | none | `user`, `project`, or `local` — persistent cross-session learning |
| `background` | ❌ | false | Always run as background task |
| `effort` | ❌ | inherit | `low`, `medium`, `high`, `xhigh`, `max` |
| `isolation` | ❌ | none | `worktree` — run in isolated git worktree |
| `color` | ❌ | — | Display color: red, blue, green, yellow, purple, orange, pink, cyan |
| `initialPrompt` | ❌ | — | Auto-submitted first turn when running as main session agent |

## Model Resolution Order

When Claude invokes a subagent, the model is resolved in this order:
1. `CLAUDE_CODE_SUBAGENT_MODEL` environment variable (if set)
2. Per-invocation model parameter (Claude can override at dispatch time)
3. Subagent definition's `model` frontmatter
4. Main conversation's model

## Built-in Subagents

Claude Code includes built-in subagents that are always available:

| Agent | Model | Tools | Purpose |
|-------|-------|-------|---------|
| Explore | Haiku | Read-only | Fast codebase search and analysis. Skips CLAUDE.md. |
| Plan | — | Read-only | Task planning. Skips CLAUDE.md. |
| General-purpose | Inherit | All | General tasks |

Built-in agents are always registered in interactive sessions. To disable: add to `permissions.deny` as `Agent(Explore)`.

Set `CLAUDE_AGENT_SDK_DISABLE_BUILTIN_AGENTS=1` to remove all built-ins and use only your custom agents.

## Agent Teams Architecture (Experimental)

### Components

| Component | Role |
|-----------|------|
| Team Lead | Main Claude session — spawns teammates, coordinates |
| Teammates | Independent Claude Code instances — each own context window |
| Task List | Shared work items — teammates claim and complete |
| Mailbox | Inter-agent messaging system |

### How Teams Form

1. User requests teammates (or Claude proposes them)
2. First teammate spawn creates the team
3. Team name: `session-<first 8 chars of session ID>`
4. Config stored at `~/.claude/teams/{team-name}/config.json`
5. Tasks stored at `~/.claude/tasks/{team-name}/`

### Teammate Communication

- Messages delivered automatically (no polling)
- Idle teammates auto-notify the lead
- Any teammate can message any other by name
- Team coordination tools (SendMessage, task management) always available

### Subagent Definitions as Teammates

Spawn a teammate using a subagent definition:
```
Spawn a teammate using the eng-worker-alpha agent type to implement the API endpoints.
```

The teammate honors the definition's tools and model. The definition's body is appended to the teammate's system prompt as additional instructions (not replacing it).

**Note**: `skills` and `mcpServers` frontmatter fields are NOT applied when a definition runs as a teammate.

### Team Hook Events

| Event | When | Use |
|-------|------|-----|
| `TeammateIdle` | Teammate about to go idle | Exit 2 to keep teammate working |
| `TaskCreated` | Task being created | Exit 2 to prevent creation |
| `TaskCompleted` | Task being marked complete | Exit 2 to prevent completion |

### Team Limitations

- No session resumption with in-process teammates
- Orphaned tmux sessions may persist after session ends
- Teammates may stop on errors without recovering
- Lead may prematurely decide work is done
- Token costs scale linearly with teammate count

## Performance & Cost Tips

1. **Use `maxTurns` on every agent** — prevents runaway loops and token waste
2. **Route planning/review to cheaper models** — `haiku` for Explore, `sonnet` for eng, `opus` only for complex reasoning
3. **Use worktrees for parallel work** — avoids merge conflicts and enables true parallelism
4. **Preload skills** — `skills: [name]` injects skill content at startup, avoiding mid-task discovery
5. **Use forks for context-heavy side tasks** — cheaper than fresh subagents (shared prompt cache)
6. **3-5 agents is the sweet spot** — more than 5 rarely helps and gets expensive
7. **Background subagents for parallelism** — `background: true` lets multiple run simultaneously
8. **Resume instead of re-dispatching** — resuming a completed subagent is cheaper than starting fresh

## Debugging Subagents

### View Running Subagents
Use `/agents` → Running tab to see live and recently finished subagents.

### Subagent Transcripts
Stored at `~/.claude/projects/{project}/{sessionId}/subagents/agent-{agentId}.jsonl`

### Debug Mode
```bash
claude -d "agent"  # Debug logging filtered to agent-related events
claude --debug-file debug.log  # Write debug logs to file
```
