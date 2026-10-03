#!/usr/bin/env python3
"""Check an app against the shared iOS baseline (docs/ci.md, "Baseline").

Usage: baseline.py <app-root> [--runtime <runtime-root>] [--strict]

Every app on this Runtime shares one baseline so the apps cannot drift apart
(owner decision, 2026-09-21). Within a day three apps had three pipelines, a
template fixed in one never reached the others, and a copied workflow went
stale the next time its template changed.

Errors (the file checks only in an app that set `pipeline: shared`; before
that they are warnings):
  - .github/workflows/tests.yml and testflight.yml differ from the Runtime templates
  - ci_scripts/ci_post_clone.sh next to the project differs from its template
  - Tooling/.swiftlint.yml and .swift-format differ from the Runtime templates
  - Tooling/runtime.yml names a bare, machine-shared simulator or lacks the
    baseline simulator.device_type / simulator.os
  - MARKETING_VERSION is not MAJOR.MINOR.PATCH in every configuration
Warnings (errors only with --strict):
  - the app has not opted in (`pipeline: shared`)
  - the installed Runtime is not the Runtime checkout's committed content
  - other workflows exist next to the two shared ones
"""

from __future__ import annotations

import filecmp
import json
import re
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from project_versions import marketing_versions  # noqa: E402

BASE_SIMULATOR = {"device_type": "iPhone 17", "os": "27.0"}


def config_error(path: Path) -> None:
    print(f"baseline: cannot read configuration {path}; fix its YAML mapping, then rerun just baseline", file=sys.stderr)
    raise SystemExit(2)


def load_config(path: Path) -> dict:
    if not path.is_file():
        return {}
    try:
        result = subprocess.run(["yq", "-o=json", ".", str(path)], check=True,
                                capture_output=True, text=True)
        config = json.loads(result.stdout)
    except FileNotFoundError:
        print(f'baseline: yq not installed. Fix: brew bundle --file "{path.parent / "Brewfile"}", then rerun just baseline.', file=sys.stderr)
        raise SystemExit(2)
    except (OSError, subprocess.CalledProcessError, ValueError):
        config_error(path)
    if config is None:
        return {}
    if not isinstance(config, dict):
        config_error(path)
    return config


def main() -> int:
    args = sys.argv[1:]
    if not args or args[0].startswith("-"):
        sys.exit(__doc__)
    app = Path(args[0]).resolve()
    strict = "--strict" in args
    runtime = Path(args[args.index("--runtime") + 1]).resolve() if "--runtime" in args else None
    tooling = app / "Tooling"
    templates = tooling / "templates"
    errors: list[str] = []
    warnings: list[str] = []

    config_path = tooling / "runtime.yml"
    config = load_config(config_path)
    shared = config.get("pipeline") == "shared"
    simulator = config.get("simulator") or {}
    if not isinstance(simulator, dict):
        config_error(config_path)
    if not shared:
        warnings.append("not on the shared pipeline: add `pipeline: shared` to Tooling/runtime.yml")

    pipeline_issues: list[str] = []
    for name in ("tests.yml", "testflight.yml"):
        copy, template = app / ".github/workflows" / name, templates / "github" / name
        if not template.is_file():
            pipeline_issues.append(f"Tooling/templates/github/{name} is not installed; run `just harness-update`")
        elif not copy.is_file():
            pipeline_issues.append(f".github/workflows/{name} is missing")
        elif not filecmp.cmp(copy, template, shallow=False):
            pipeline_issues.append(f".github/workflows/{name} differs from Tooling/templates/github/{name}")
    workflows = app / ".github/workflows"
    extra = sorted(p.name for p in workflows.glob("*.y*ml") if p.name not in ("tests.yml", "testflight.yml")) if workflows.is_dir() else []
    if extra:
        warnings.append("other workflows next to the shared ones: " + ", ".join(extra))

    projects = [p for p in app.rglob("*.xcodeproj") if not {".claude", "Tooling", "Pods", "build", "DerivedData"} & set(p.relative_to(app).parts)]
    post_clones = [p.parent / "ci_scripts/ci_post_clone.sh" for p in projects]
    if not any(p.is_file() for p in post_clones):
        pipeline_issues.append("ci_scripts/ci_post_clone.sh next to the project is missing")
    post_clone_template = templates / "ci_post_clone.sh"
    if not post_clone_template.is_file():
        pipeline_issues.append("Tooling/templates/ci_post_clone.sh is not installed; run `just harness-update`")
    for script in (p for p in post_clones if p.is_file() and post_clone_template.is_file()):
        if not filecmp.cmp(script, post_clone_template, shallow=False):
            pipeline_issues.append(f"{script.relative_to(app)} differs from Tooling/templates/ci_post_clone.sh")
    (errors if shared else warnings).extend(pipeline_issues)

    name = simulator.get("name")
    name = str(name) if name is not None else None
    # Per-app names start with the scheme ("Pitstop iPhone 17"); a name that starts
    # with the device family is the device every project on the Mac shares.
    if name and re.match(r"(iPhone|iPad)\b", name):
        errors.append(f"simulator.name '{name}' is a machine-shared device; use simulator.device_type instead")
    for key, value in BASE_SIMULATOR.items():
        actual = simulator.get(key)
        actual = str(actual) if actual is not None else None
        if actual != value:
            errors.append(f"simulator.{key} is {actual!r}, baseline is {value!r}")

    versions: set[str] = set()
    for project in projects:
        for name in ("project.pbxproj", "project.xcproj"):
            if (project / name).is_file():
                versions |= marketing_versions((project / name).read_text())
    bad = sorted(v for v in versions if not re.fullmatch(r"\d+\.\d+\.\d+", v))
    if bad:
        errors.append("MARKETING_VERSION is not MAJOR.MINOR.PATCH: " + ", ".join(bad))
    if len(versions) > 1:
        errors.append("MARKETING_VERSION differs across configurations: " + ", ".join(sorted(versions)))

    if runtime and (runtime / "scripts/runtime-lock.sh").is_file():
        latest = subprocess.run([str(runtime / "scripts/runtime-lock.sh"), str(runtime)], capture_output=True, text=True).stdout.strip()
        installed = (tooling / ".runtime-lock").read_text().strip() if (tooling / ".runtime-lock").is_file() else ""
        if latest and installed != latest:
            head = subprocess.run(["git", "-C", str(runtime), "log", "-1", "--format=%h %s"], capture_output=True, text=True).stdout.strip()
            warnings.append(f"installed Runtime {installed[:10] or 'unknown'} is not the Runtime checkout ({head}); run `just harness-update`")

    style_issues: list[str] = []
    for app_name, template_name in ((".swiftlint.yml", "swiftlint.yml"), (".swift-format", "swift-format")):
        copy, template = tooling / app_name, templates / template_name
        if not template.is_file():
            style_issues.append(f"Tooling/templates/{template_name} is not installed; run `just harness-update`")
        elif not copy.is_file() or not filecmp.cmp(copy, template, shallow=False):
            style_issues.append(f"Tooling/{app_name} differs from Tooling/templates/{template_name}")
    (errors if shared else warnings).extend(style_issues)

    for line in errors:
        print(f"baseline error    {line}")
    for line in warnings:
        print(f"baseline warning  {line}")
    failed = bool(errors) or (strict and bool(warnings))
    print(f"baseline: {'FAILED' if failed else 'OK'} ({len(errors)} error(s), {len(warnings)} warning(s))")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
