#!/usr/bin/env python3
"""
Generate .claude/agents/*.md from orchestration.config.yaml.

This is the single generator for the orchestration agent team.
It reads the YAML config (frontmatter/metadata) and re-emits each agent
file, preserving the existing system-prompt body if one already exists.

Usage:
    ./scripts/generate-agents.py

Prerequisite:
    pip install pyyaml     # (PyYAML)
"""

import sys
import os

try:
    import yaml
except ImportError:
    sys.exit(
        "ERROR: PyYAML is not installed.\n"
        "  Install it with:  pip install pyyaml\n"
        "  Then re-run:      ./scripts/generate-agents.py"
    )

# ── Paths ────────────────────────────────────────────────────────────────
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.dirname(SCRIPT_DIR)
CONFIG_PATH = os.path.join(REPO_ROOT, "orchestration.config.yaml")
AGENTS_DIR = os.path.join(REPO_ROOT, ".claude", "agents")

# Frontmatter field order — matches the existing deployed agent files.
FIELD_ORDER = [
    "name",
    "description",
    "model",
    "tools",
    "maxTurns",
    "background",
    "isolation",
    "color",
]


def yaml_quote_string(value):
    """Double-quote a string for YAML output, escaping as needed."""
    escaped = value.replace("\\", "\\\\").replace('"', '\\"')
    return f'"{escaped}"'


def format_field(key, value):
    """Render a single frontmatter field as a string line."""
    if key == "description":
        return f"description: {yaml_quote_string(value)}"
    if key == "tools":
        # Tools are stored as a list; emit comma-separated (Claude Code style).
        return f"tools: {', '.join(value)}"
    if isinstance(value, bool):
        return f"{key}: {'true' if value else 'false'}"
    return f"{key}: {value}"


def extract_body(path):
    """
    Read an existing agent .md file and return its body
    (the markdown after the YAML frontmatter).
    Returns None if the file does not exist.
    """
    if not os.path.exists(path):
        return None
    text = open(path, "r", encoding="utf-8").read()
    if text.startswith("---"):
        parts = text.split("---", 2)
        # parts => ['', '<frontmatter>', '\n<body...>']
        if len(parts) >= 3:
            body = parts[2].lstrip("\n")
            return body.rstrip() + "\n"
    # No recognizable frontmatter — treat the whole file as body.
    return text.rstrip() + "\n"


def build_agent_file(name, spec, model):
    """
    Build the full contents of an agent .md file from its config spec.
    Preserves the existing body if present; otherwise falls back to the
    description as the body.
    """
    existing_path = os.path.join(AGENTS_DIR, f"{name}.md")
    body = extract_body(existing_path)
    if body is None:
        # New agent with no existing file — use description as the body.
        body = spec.get("description", "").rstrip() + "\n"

    # Assemble frontmatter fields in canonical order.
    fields = {
        "name": name,
        "description": spec.get("description", ""),
        "model": model,
    }

    if "tools" in spec:
        fields["tools"] = spec["tools"]
    if "maxTurns" in spec:
        fields["maxTurns"] = spec["maxTurns"]

    # background: emit only when true (default false is omitted).
    if spec.get("background"):
        fields["background"] = True

    # isolation: emit only when set and not 'none'.
    isolation = spec.get("isolation")
    if isolation and isolation != "none":
        fields["isolation"] = isolation

    # color: emit only when present.
    if "color" in spec and spec["color"]:
        fields["color"] = spec["color"]

    # Emit in FIELD_ORDER.
    lines = ["---"]
    for key in FIELD_ORDER:
        if key in fields:
            lines.append(format_field(key, fields[key]))
    lines.append("---")
    lines.append("")  # blank line between frontmatter and body

    return "\n".join(lines) + "\n" + body


def main():
    if not os.path.exists(CONFIG_PATH):
        sys.exit(f"ERROR: config not found at {CONFIG_PATH}")

    with open(CONFIG_PATH, "r", encoding="utf-8") as f:
        config = yaml.safe_load(f)

    mode = config.get("mode", "max")
    presets = config.get("models", {})
    agents = config.get("agents", {})

    if not agents:
        sys.exit("ERROR: no agents defined in config (the `agents:` section is empty).")

    if mode not in presets:
        sys.exit(f"ERROR: mode '{mode}' has no preset under `models:`.")

    os.makedirs(AGENTS_DIR, exist_ok=True)

    generated = []
    for name, spec in agents.items():
        # Determine model: explicit per-agent override, else mode preset.
        if "model" in spec and spec["model"]:
            model = spec["model"]
        elif name in presets[mode]:
            model = presets[mode][name]
        else:
            sys.exit(
                f"ERROR: no model for agent '{name}' in mode '{mode}'.\n"
                f"  Add it under models.{mode}.{name}, or set `model:` on the agent."
            )

        content = build_agent_file(name, spec, model)
        out_path = os.path.join(AGENTS_DIR, f"{name}.md")
        with open(out_path, "w", encoding="utf-8") as f:
            f.write(content)
        generated.append((name, model))

    print(f"\n✅ Generated {len(generated)} agents (mode: {mode}):")
    for name, model in generated:
        print(f"  - {name} ({model})")
    print()


if __name__ == "__main__":
    main()
