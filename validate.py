#!/usr/bin/env python3
"""Validate the generated public Commons repository without dependencies."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
TEXT_SUFFIXES = {".json", ".md", ".py", ".sh", ".toml", ".yaml", ".yml"}
PATTERN_FILE = ROOT / "private-reference-pattern.txt"
INTERNAL_REFERENCE = re.compile(
    PATTERN_FILE.read_text(encoding="utf-8").strip(),
    re.IGNORECASE,
)


def main() -> int:
    errors: list[str] = []
    if (ROOT / "INSTRUCTIONS.md").exists():
        errors.append("INSTRUCTIONS.md is private and must not be distributed")
    if not (ROOT / "LICENSE").is_file():
        errors.append("LICENSE is missing")
    plugin = ROOT / "plugins" / "commons" / ".claude-plugin" / "plugin.json"
    try:
        default_url = json.loads(plugin.read_text(encoding="utf-8"))["userConfig"][
            "mcp_url"
        ]["default"]
        if default_url != "https://grasp-daas.com/api/ai-gateway/v1/mcp":
            errors.append("plugin MCP default must be production")
    except (OSError, KeyError, json.JSONDecodeError) as error:
        errors.append(f"plugin manifest is invalid: {error}")

    for path in sorted(ROOT.rglob("*")):
        if (
            not path.is_file()
            or ".git" in path.parts
            or path.resolve() == PATTERN_FILE.resolve()
        ):
            continue
        relative = path.relative_to(ROOT).as_posix()
        if path.suffix == ".json":
            try:
                json.loads(path.read_text(encoding="utf-8"))
            except (UnicodeDecodeError, json.JSONDecodeError) as error:
                errors.append(f"{relative}: invalid JSON: {error}")
        if path.suffix in TEXT_SUFFIXES:
            text = path.read_text(encoding="utf-8")
            if "\r" in text:
                errors.append(f"{relative}: CRLF is not allowed")
            if INTERNAL_REFERENCE.search(text):
                errors.append(f"{relative}: references an internal source path")

    if errors:
        print("\n".join(errors), file=sys.stderr)
        return 1
    print("public distribution: valid")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
