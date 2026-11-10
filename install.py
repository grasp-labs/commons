#!/usr/bin/env python3
"""Install the portable Commons skills for Cursor or Codex."""

import argparse
import json
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parent
STATE_FILE = ".commons-installed.json"


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("target", choices=("cursor", "codex"))
    parser.add_argument("--project", type=Path)
    args = parser.parse_args()

    base = args.project.resolve() if args.project else Path.home()
    destination = base / f".{args.target}" / "skills"
    destination.mkdir(parents=True, exist_ok=True)

    skills_root = ROOT / "skills"
    if not skills_root.is_dir():
        skills_root = ROOT.parent / "docs" / "onboarding" / "plugin" / "skills"
    skills = sorted(skills_root.glob("*/SKILL.md"))
    if not skills:
        raise FileNotFoundError(f"no Commons skills found in {skills_root}")
    names = {skill.parent.name for skill in skills}
    state = destination / STATE_FILE
    previous = _installed_names(state)
    stale = previous - names
    for name in sorted(stale):
        shutil.rmtree(destination / name, ignore_errors=True)
    for skill in skills:
        target = destination / skill.parent.name
        shutil.rmtree(target, ignore_errors=True)
        shutil.copytree(skill.parent, target)

    temporary = state.with_suffix(".tmp")
    temporary.write_text(
        json.dumps({"version": 1, "skills": sorted(names)}, indent=2) + "\n",
        encoding="utf-8",
    )
    temporary.replace(state)
    suffix = f"; removed {len(stale)} stale skills" if stale else ""
    print(f"installed {len(skills)} Commons skills in {destination}{suffix}")


def _installed_names(state: Path) -> set[str]:
    if not state.is_file():
        return set()
    try:
        names = json.loads(state.read_text(encoding="utf-8"))["skills"]
    except (OSError, KeyError, json.JSONDecodeError) as error:
        raise ValueError(f"{state}: invalid installer state: {error}") from error
    if not isinstance(names, list) or any(
        not isinstance(name, str)
        or not name
        or Path(name).name != name
        or name in {".", ".."}
        for name in names
    ):
        raise ValueError(f"{state}: invalid installer state")
    return set(names)


if __name__ == "__main__":
    main()
