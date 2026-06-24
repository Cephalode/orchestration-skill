# Settings & Hooks Templates

Configuration for `.claude/settings.json` to automate orchestration workflows.

## Base Settings (Orchestration-Ready)

```json
{
  "permissions": {
    "allow": [
      "Read",
      "Bash(npm run *)",
      "Bash(npx *)",
      "Bash(git *)",
      "Bash(node *)",
      "Bash(python *)",
      "Bash(pytest *)"
    ],
    "deny": [
      "Bash(rm -rf *)",
      "Read(.env)",
      "Read(.env.*)"
    ]
  },
  "env": {
    "CLAUDE_CODE_SUBAGENT_MODEL": ""
  }
}
```

## Hooks: Auto-Format After Engineering Writes

Runs prettier/eslint automatically after eng-worker writes files.

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "npx prettier --write $CLAUDE_FILE_PATHS 2>/dev/null || true"
          }
        ]
      }
    ]
  }
}
```

## Hooks: Orchestration Logging

Log when each sub-agent phase starts and stops.

```json
{
  "hooks": {
    "SubagentStart": [
      {
        "matcher": "planning-lead",
        "hooks": [
          {
            "type": "command",
            "command": "echo \"[$(date -Iseconds)] PLANNING START\" >> .claude/orchestration.log"
          }
        ]
      },
      {
        "matcher": "eng-worker",
        "hooks": [
          {
            "type": "command",
            "command": "echo \"[$(date -Iseconds)] ENGINEERING START\" >> .claude/orchestration.log"
          }
        ]
      },
      {
        "matcher": "validator",
        "hooks": [
          {
            "type": "command",
            "command": "echo \"[$(date -Iseconds)] VALIDATION START\" >> .claude/orchestration.log"
          }
        ]
      }
    ],
    "SubagentStop": [
      {
        "matcher": "validator",
        "hooks": [
          {
            "type": "command",
            "command": "echo \"[$(date -Iseconds)] VALIDATION COMPLETE\" >> .claude/orchestration.log && cat .claude/orchestration.log | tail -20"
          }
        ]
      }
    ]
  }
}
```

## Hooks: Security Gate (Block Dangerous Commands)

Prevent sub-agents from running destructive commands.

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "echo \"$CLAUDE_TOOL_INPUT\" | grep -qE '(rm -rf|git push.*--force|git reset --hard|DROP TABLE|\\bDELETE FROM)' && echo 'BLOCKED: Dangerous command detected' && exit 2 || exit 0"
          }
        ]
      }
    ]
  }
}
```

## Hooks: Post-Validation Notification

Run a script after validation completes to notify or deploy.

```json
{
  "hooks": {
    "SubagentStop": [
      {
        "matcher": "validator",
        "hooks": [
          {
            "type": "command",
            "command": "./scripts/post-validation.sh"
          }
        ]
      }
    ]
  }
}
```

Example `scripts/post-validation.sh`:
```bash
#!/bin/bash
# Read the validation result from the subagent transcript
# Trigger deployment, send notification, update issue tracker, etc.

RESULT=$(cat)  # Hook receives JSON via stdin
STATUS=$(echo "$RESULT" | jq -r '.stop_hook_active // false')

echo "Validation completed. Status: $STATUS"
# Add your post-validation logic here:
# - Deploy to staging
# - Send Slack/Discord notification
# - Update GitHub PR status
# - Create Jira ticket for failures
```

## Agent Teams Settings (Experimental)

Full configuration for enabling agent teams with split-pane display.

```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  },
  "teammateMode": "auto",
  "permissions": {
    "allow": [
      "Read",
      "Write",
      "Edit",
      "Bash(npm run *)",
      "Bash(git *)"
    ]
  }
}
```

Display mode options:
- `"in-process"` — All teammates in one terminal (default, works everywhere)
- `"auto"` — Split panes if tmux/iTerm2 detected, else in-process
- `"tmux"` — Force split panes via tmux
- `"iterm2"` — Force iTerm2 native split panes (requires `it2` CLI)

## Fork Mode Settings

Enable fork-based subagents (inherits full conversation context).

```json
{
  "env": {
    "CLAUDE_CODE_FORK_SUBAGENT": "1"
  }
}
```

With fork mode enabled:
- `/fork <directive>` creates a subagent with full conversation context
- All subagent spawns run in the background
- Forks are cheaper (reuse parent's prompt cache)
- Forks CANNOT spawn further forks

## Per-Agent Hooks (in Agent Frontmatter)

Define hooks directly in agent `.md` files. These run only while that agent is active.

Example for eng-worker.md:
```yaml
hooks:
  PostToolUse:
    - matcher: "Edit|Write"
      hooks:
        - type: command
          command: "npx eslint --fix $CLAUDE_FILE_PATHS 2>/dev/null || true"
  PreToolUse:
    - matcher: "Bash"
      hooks:
        - type: command
          command: "./scripts/validate-bash.sh"
```

## Complete Settings Example

A full `.claude/settings.json` for an orchestration-ready project:

```json
{
  "permissions": {
    "allow": [
      "Read",
      "Bash(npm run *)",
      "Bash(npx *)",
      "Bash(git *)",
      "Bash(node *)",
      "Bash(pytest *)"
    ],
    "deny": [
      "Bash(rm -rf *)",
      "Read(.env)",
      "Read(.env.*)"
    ]
  },
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  },
  "teammateMode": "auto",
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "npx prettier --write $CLAUDE_FILE_PATHS 2>/dev/null || true"
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "echo \"$CLAUDE_TOOL_INPUT\" | grep -qE '(rm -rf|git push.*--force)' && echo 'BLOCKED' && exit 2 || exit 0"
          }
        ]
      }
    ]
  }
}
```
