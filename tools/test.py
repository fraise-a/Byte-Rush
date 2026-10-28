#!/usr/bin/env python3
"""Run Byte Rush's headless regressions with only the Python standard library."""

import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys

PROJECT = Path(__file__).resolve().parents[1]
SUITES = (
    "controllers", "systems", "geometry", "correctness", "lifecycle",
    "autotest_isolation", "display", "prompt_audit", "races",
)


def find_godot(requested):
    candidate = requested or os.environ.get("BYTE_RUSH_GODOT")
    if candidate:
        return shutil.which(candidate) or str(Path(candidate).expanduser().resolve())
    for name in ("godot", "godot4"):
        executable = shutil.which(name)
        if executable:
            return executable
    mac_app = Path("/Applications/Godot.app/Contents/MacOS/Godot")
    if mac_app.is_file():
        return str(mac_app)
    raise RuntimeError("Godot was not found. Supply --godot /path/to/godot.")


def check_versions(executable):
    result = subprocess.run(
        [executable, "--version"], capture_output=True, text=True,
        check=True, timeout=30,
    )
    if not result.stdout.strip().startswith("4.5.1."):
        raise RuntimeError("Use Godot 4.5.1 Standard for these reproducible checks.")
    source = (PROJECT / "scripts/game.gd").read_text(encoding="utf-8")
    match = re.search(r'const VERSION\s*:=\s*"([^"]+)"', source)
    if not match:
        raise RuntimeError("The game version constant is missing.")
    version = match.group(1)
    preset = (PROJECT / "export_presets.cfg").read_text(encoding="utf-8")
    for field in ("application/short_version", "application/version"):
        if f'{field}="{version}"' not in preset:
            raise RuntimeError(f"{field} must match game version {version}.")
    return version


def run(executable, name, arguments, logs):
    command = [executable, "--headless", "--path", str(PROJECT)] + arguments
    print(f"Running {name}…", flush=True)
    try:
        result = subprocess.run(
            command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            text=True, timeout=180,
        )
    except subprocess.TimeoutExpired as error:
        output = error.stdout or b""
        if isinstance(output, bytes):
            output = output.decode("utf-8", errors="replace")
        (logs / f"{name}.log").write_text(output, encoding="utf-8")
        raise RuntimeError(f"{name} timed out; see build/test-results/{name}.log")
    (logs / f"{name}.log").write_text(result.stdout, encoding="utf-8")
    errors = re.search(r"(?m)^(?:SCRIPT ERROR:|ERROR:|FAIL |LEAK )", result.stdout)
    if result.returncode or errors:
        print(result.stdout[-6000:], file=sys.stderr)
        raise RuntimeError(f"{name} failed; see build/test-results/{name}.log")
    checks = sum(line.startswith("PASS ") for line in result.stdout.splitlines())
    print(f"Passed {name}" + (f" ({checks} checks)" if checks else ""), flush=True)
    return {"name": name, "passed": True, "checks": checks}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", help="Path to the Godot 4.5.1 executable")
    parser.add_argument("--suite", nargs="+", choices=SUITES, default=list(SUITES))
    args = parser.parse_args()
    build = PROJECT / "build"
    logs = build / "test-results"
    logs.mkdir(parents=True, exist_ok=True)
    (build / ".gdignore").touch()
    summary = {"passed": False, "suites": []}
    try:
        executable = find_godot(args.godot)
        summary["version"] = check_versions(executable)
        run(executable, "import", ["--import"], logs)
        for name in args.suite:
            arguments = ["--fixed-fps", "60"]
            if name == "races":
                arguments += ["--", "--autotest"]
            else:
                arguments += ["--script", f"res://tests/{name}.gd"]
                if name == "autotest_isolation":
                    arguments += ["--", "--autotest"]
            summary["suites"].append(run(executable, name, arguments, logs))
        summary["passed"] = True
        print("All requested checks passed.")
        return 0
    except (RuntimeError, OSError, subprocess.SubprocessError) as error:
        summary["error"] = str(error)
        print(str(error), file=sys.stderr)
        return 1
    finally:
        (logs / "summary.json").write_text(
            json.dumps(summary, indent=2) + "\n", encoding="utf-8",
        )


if __name__ == "__main__":
    sys.exit(main())
