#!/usr/bin/env python3
"""Bounded Godot regression runner; Python 3, no third-party dependencies.

The curated current profile is a release gate, not a claim that every historical
suite passes. See tests/suite_registry.json and tests/README.md for coverage.
"""
from __future__ import annotations

import argparse
import json
import math
import os
from pathlib import Path
import re
import signal
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
REGISTRY = ROOT / "tests" / "suite_registry.json"
ERROR = re.compile(r"(?:SCRIPT ERROR:|(?:^|\n)ERROR:|\b[A-Z0-9_]*FAIL\b)")
SUMMARY = re.compile(r"\b(?:passed|continuous_alpha_poses)=(\d+)\s*\|\s*failed=(\d+)")
PASSED_ONLY = re.compile(r"\bpassed=(\d+)")
PASS = re.compile(r"\b[A-Z0-9_]*PASS\b")
FAIL = re.compile(r"\b[A-Z0-9_]*FAIL\b")


def load_registry(path: Path = REGISTRY) -> dict:
    registry = json.loads(path.read_text(encoding="utf-8"))
    registered = registry["suites"]
    actual = {p.stem for p in (ROOT / "tests").glob("*.gd")}
    if actual != set(registered):
        raise ValueError(f"registry mismatch: missing={sorted(actual-set(registered))}, stale={sorted(set(registered)-actual)}")
    for name, entry in registered.items():
        if entry["status"] not in {"current", "historical", "retired", "manual"}:
            raise ValueError(f"invalid status: {name}")
        if entry["mode"] not in {"headless", "renderer"}:
            raise ValueError(f"invalid mode: {name}")
        if entry["status"] == "retired" and not entry.get("reason"):
            raise ValueError(f"retired suite needs a reason: {name}")
        if not math.isfinite(entry.get("timeout_seconds", 90)) or entry.get("timeout_seconds", 90) <= 0:
            raise ValueError(f"invalid timeout: {name}")
    return registry


def stop_process_tree(process: subprocess.Popen) -> None:
    """A test may leave Godot child processes; terminate the entire test group."""
    if os.name == "nt":
        try:
            subprocess.run(["taskkill", "/PID", str(process.pid), "/T", "/F"],
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=10)
        except (OSError, subprocess.TimeoutExpired):
            process.kill()
    else:
        try:
            os.killpg(process.pid, signal.SIGTERM)
        except ProcessLookupError:
            return
        try:
            process.wait(timeout=2)
        except subprocess.TimeoutExpired:
            pass
        # The group leader may exit before its children; always clear the group.
        try:
            os.killpg(process.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass


def run_bounded(command: list[str], timeout: float, cwd: Path, env: dict | None = None) -> dict:
    began = time.monotonic()
    options = {"start_new_session": True} if os.name != "nt" else {"creationflags": subprocess.CREATE_NEW_PROCESS_GROUP}
    # Use a file rather than PIPE: a child inheriting stdout cannot keep the
    # runner blocked in communicate()/a Windows pipe reader after timeout.
    with tempfile.TemporaryFile(mode="w+b") as output_file:
        try:
            process = subprocess.Popen(command, cwd=cwd, env=env, stdin=subprocess.DEVNULL,
                                       stdout=output_file, stderr=subprocess.STDOUT, **options)
        except OSError as error:
            return {"returncode": None, "timed_out": False, "output": str(error), "duration_seconds": 0, "launch_error": True}
        timed_out = False
        try:
            process.wait(timeout=timeout)
        except KeyboardInterrupt:
            stop_process_tree(process)
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
            raise
        except subprocess.TimeoutExpired:
            timed_out = True
            stop_process_tree(process)
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
        output_file.seek(0)
        output = output_file.read().decode("utf-8", errors="replace")
    return {"returncode": process.returncode, "timed_out": timed_out, "output": output,
            "duration_seconds": round(time.monotonic()-began, 3), "launch_error": False}


def classify(result: dict, expect_summary: bool = True) -> dict:
    output = result["output"]
    summaries = SUMMARY.findall(output)
    passed_only = PASSED_ONLY.findall(output)
    passed, failed = (map(int, summaries[-1]) if summaries else (int(passed_only[-1]) if passed_only else len(PASS.findall(output)), len(FAIL.findall(output))))
    result.update(passed=passed, failed=failed, count_basis="summary" if summaries or passed_only else "log_markers")
    if result["launch_error"]:
        result.update(status="blocked", reason="process could not start")
    elif result["timed_out"]:
        result.update(status="timeout", reason="deadline exceeded; process tree terminated")
    elif result["returncode"] != 0 or failed or ERROR.search(output):
        result.update(status="failed", reason="nonzero exit, failed assertion, or engine/script error")
    elif expect_summary and not summaries and not passed_only and not PASS.search(output):
        result.update(status="failed", reason="no test completion evidence")
    else:
        result.update(status="passed", reason="")
    return result


def select_suites(registry: dict, profile: str, names: list[str]) -> list[str]:
    entries = registry["suites"]
    if names:
        unknown = set(names)-set(entries)
        if unknown:
            raise ValueError("unknown suite(s): "+", ".join(sorted(unknown)))
        return list(dict.fromkeys(names))
    return [name for name, entry in entries.items() if (
        (profile == "current" and entry["status"] == "current" and entry["mode"] == "headless") or
        (profile == "native" and entry["status"] == "current" and entry["mode"] == "renderer") or
        (profile == "historical" and entry["status"] == "historical" and entry["mode"] == "headless") or
        (profile == "all-headless" and entry["mode"] == "headless" and entry["status"] not in {"retired", "manual"})
    )]


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default=os.environ.get("GODOT", "godot"), help="Godot executable (or set GODOT)")
    parser.add_argument("--profile", choices=["current", "native", "historical", "all-headless"], default="current")
    parser.add_argument("--suite", action="append", default=[], help="explicit registered suite name; repeatable")
    parser.add_argument("--timeout", type=float, help="per-process timeout override in seconds")
    parser.add_argument("--output-directory", type=Path, default=ROOT / "artifacts" / "test-runs")
    parser.add_argument("--pack", type=Path, help="validate exported PCK with external test scripts")
    parser.add_argument("--import", dest="import_project", action="store_true", help="bounded editor import before source tests")
    parser.add_argument("--list", action="store_true", help="show every registered suite without running")
    args = parser.parse_args(argv)
    if args.timeout is not None and (not math.isfinite(args.timeout) or args.timeout <= 0):
        parser.error("--timeout must be finite and greater than zero")
    if args.pack and args.import_project:
        parser.error("--import cannot be used with --pack")
    if args.pack and not args.pack.is_file():
        parser.error("--pack must identify an existing PCK")
    try:
        registry = load_registry()
        selected = select_suites(registry, args.profile, args.suite)
    except (ValueError, OSError, KeyError) as error:
        parser.error(str(error))
    if args.list:
        for name, entry in registry["suites"].items():
            print(f"{name:34} {entry['mode']:8} {entry['status']:10} {entry.get('reason', '')}")
        return 0
    output_dir = args.output_directory.resolve()
    output_dir.mkdir(parents=True, exist_ok=True)
    results = []
    environment = dict(os.environ)
    # Linux Godot uses XDG locations (HOME alone does not isolate user://).
    if sys.platform.startswith("linux"):
        for key, suffix in [("XDG_DATA_HOME", "data"), ("XDG_CONFIG_HOME", "config"), ("XDG_CACHE_HOME", "cache")]:
            folder = output_dir / "profile" / suffix
            folder.mkdir(parents=True, exist_ok=True)
            environment[key] = str(folder)
    if args.import_project:
        imported = classify(run_bounded([args.godot, "--headless", "--path", str(ROOT), "--editor", "--import", "--quit"],
                                       args.timeout or 120, ROOT, environment), expect_summary=False)
        (output_dir / "import.log").write_text(imported.pop("output"), encoding="utf-8")
        imported.update(suite="editor-import", log="import.log")
        results.append(imported)
        print(f"{imported['status'].upper()} editor-import", flush=True)
        if imported["status"] != "passed":
            (output_dir / "summary.json").write_text(json.dumps({"results": results}, indent=2)+"\n", encoding="utf-8")
            return 1
    for name in selected:
        entry = registry["suites"][name]
        if args.pack and entry.get("pack_compatible") is False:
            result = {"suite": name, "status": "blocked", "reason": entry["pack_reason"], "passed": 0, "failed": 0}
            results.append(result)
            print(f"BLOCKED {name}: {entry['pack_reason']}", flush=True)
            continue
        if entry["status"] in {"retired", "manual"}:
            status = "retired" if entry["status"] == "retired" else "blocked"
            result = {"suite": name, "status": status, "reason": entry["reason"], "passed": 0, "failed": 0}
            results.append(result)
            print(f"{status.upper()} {name}: {entry['reason']}", flush=True)
            continue
        print(f"RUN {name} [{entry['status']}]", flush=True)
        captures = output_dir / "captures" / name
        captures.mkdir(parents=True, exist_ok=True)
        command = [args.godot, "--audio-driver", "Dummy"]
        if entry["mode"] == "headless":
            command.append("--headless")
        else:
            command += ["--rendering-method", "gl_compatibility"]
        if args.pack:
            # Export intentionally excludes tests: absolute --script loads this
            # source test, while res:// gameplay resources resolve inside PCK.
            command += ["--main-pack", str(args.pack.resolve()), "--script", str(ROOT / "tests" / f"{name}.gd")]
            cwd = args.pack.resolve().parent
        else:
            command += ["--path", str(ROOT), "--script", f"res://tests/{name}.gd"]
            cwd = ROOT
        command += ["--", "--test-profile", "--capture-output-directory="+str(captures)]
        result = classify(run_bounded(command, args.timeout or entry.get("timeout_seconds", 90), cwd, environment))
        log_name = name+".log"
        (output_dir / log_name).write_text(result.pop("output"), encoding="utf-8")
        result.update(suite=name, registry_status=entry["status"], log=log_name, command=command)
        results.append(result)
        print(f"{result['status'].upper()} {name}: {result['passed']} passed, {result['failed']} failed; {result['reason']} log={log_name}", flush=True)
    summary = {"profile": args.profile, "pack": str(args.pack.resolve()) if args.pack else None, "results": results}
    summary["counts"] = {status: sum(r["status"] == status for r in results) for status in ["passed", "failed", "timeout", "blocked", "retired"]}
    (output_dir / "summary.json").write_text(json.dumps(summary, indent=2)+"\n", encoding="utf-8")
    print("SUMMARY "+json.dumps(summary["counts"]), flush=True)
    # Explicitly selecting an inactive suite must never look like a green test.
    return 0 if results and all(r["status"] == "passed" for r in results) else 1


if __name__ == "__main__":
    raise SystemExit(main())
