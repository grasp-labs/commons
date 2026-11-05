#!/usr/bin/env python3
"""Install the portable Commons skills for Cursor or Codex."""

import argparse
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parent


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("target", choices=("cursor", "codex"))
    parser.add_argument("--project", type=Path)
    args = parser.parse_args()

    base = args.project.resolve() if args.project else Path.home()
    destination = base / f".{args.target}" / "skills"
    destination.mkdir(parents=True, exist_ok=True)

    skills = sorted((ROOT / "skills").glob("*/SKILL.md"))
    for skill in skills:
        target = destination / skill.parent.name
        shutil.rmtree(target, ignore_errors=True)
        shutil.copytree(skill.parent, target)

    print(f"installed {len(skills)} Commons skills in {destination}")


if __name__ == "__main__":
    main()
