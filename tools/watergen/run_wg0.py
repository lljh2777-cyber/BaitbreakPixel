#!/usr/bin/env python3
"""Private, bounded WG-0 runner. Never modifies the shared suite registry.

All persistent output stays in this checkout's artifacts/watergen/<run_id>.
No player profile/store code is loaded by the preview or contract test.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timedelta, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import signal
import subprocess
import sys
import time
import uuid

ROOT = Path(__file__).resolve().parents[2]
BASELINE = json.loads((ROOT / "data/watergen/source_baseline.json").read_text(encoding="utf-8"))
TZ = timezone(timedelta(hours=8))


def git(*args: str) -> str:
    return subprocess.check_output(["git", "-C", str(ROOT), *args]).decode("utf-8").strip()


def source_manifest() -> dict:
    paths = set(git("ls-files", "-z").split("\0"))
    paths.update(git("ls-files", "--others", "--exclude-standard", "-z").split("\0"))
    return {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest()
            for name in sorted(paths) if name and (ROOT / name).is_file()
            and Path(name).suffix in {".gd", ".py", ".tscn", ".godot", ".json", ".ps1"}}


def run(command: list[str], output: Path, label: str, timeout: int, expect_summary: bool = True) -> dict:
    began = time.monotonic()
    options = {"start_new_session": True} if os.name != "nt" else {
        "creationflags": subprocess.CREATE_NEW_PROCESS_GROUP,
        "startupinfo": subprocess.STARTUPINFO(),
    }
    if os.name == "nt" and expect_summary:
        options["startupinfo"].dwFlags |= subprocess.STARTF_USESHOWWINDOW
        options["startupinfo"].wShowWindow = 0
    # These affect Godot's user data/cache resolution without touching real profiles.
    env = os.environ.copy()
    for key in ("APPDATA", "LOCALAPPDATA", "XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME"):
        directory = output / "isolated-user" / key.lower()
        directory.mkdir(parents=True, exist_ok=True)
        env[key] = str(directory)
    log = output / (label + ".log")
    timed_out = False
    launch_error = None
    returncode = None
    with log.open("xb") as handle:
        try:
            process = subprocess.Popen(command, cwd=ROOT, env=env, stdin=subprocess.DEVNULL,
                                       stdout=handle, stderr=subprocess.STDOUT, **options)
            try:
                returncode = process.wait(timeout=timeout)
            except (subprocess.TimeoutExpired, KeyboardInterrupt):
                timed_out = True
                if os.name == "nt":
                    subprocess.run(["taskkill", "/PID", str(process.pid), "/T", "/F"],
                                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=10)
                else:
                    os.killpg(process.pid, signal.SIGKILL)
                process.wait(timeout=10)
                returncode = process.returncode
        except OSError as error:
            launch_error = str(error)
    text = log.read_text(encoding="utf-8", errors="replace")
    counts = re.findall(r"\| passed=(\d+) \| failed=(\d+)", text)
    passed, failed = map(int, counts[-1]) if counts else (0, 0)
    errors = bool(re.search(r"SCRIPT ERROR:|(?:^|\n)ERROR:|WG0_\w+_FAIL", text))
    status = "BLOCKED" if launch_error else "FAIL" if timed_out or returncode != 0 or errors or failed or (expect_summary and not counts) else "PASS"
    result = dict(status=status, command=command, log=log.name, returncode=returncode,
                  timed_out=timed_out, launch_error=launch_error, passed=passed, failed=failed,
                  duration_seconds=round(time.monotonic() - began, 3))
    print(f"{label}: {status}, assertions={passed}/{passed+failed}, {result['duration_seconds']}s", flush=True)
    if status != "PASS": print(text[-12000:], flush=True)
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default=os.environ.get("GODOT", "godot"))
    parser.add_argument("--mode", choices=["all", "headless", "native", "preview"], default="all")
    parser.add_argument("--run-id", default="wg0-" + datetime.now(TZ).strftime("%Y%m%d-%H%M%S") + "-" + uuid.uuid4().hex[:6])
    parser.add_argument("--timeout", type=int, default=120)
    args = parser.parse_args()
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_-]{0,79}", args.run_id) or args.timeout <= 0:
        parser.error("run-id must be a safe single directory name and timeout must be positive")
    output = ROOT / "artifacts/watergen" / args.run_id
    output.mkdir(parents=True, exist_ok=False)
    started = datetime.now(TZ).isoformat()
    sources = source_manifest()
    changed_original = git("diff", "--name-only", "--diff-filter=DMRTUXB", BASELINE["source_commit"])
    common = [args.godot, "--path", str(ROOT), "--audio-driver", "Dummy"]
    manifest = dict(format="baitbreak-watergen-run-manifest", template_only=False,
                    task_id="WG-0", authorized_stage="WG-0", base_commit=BASELINE["source_commit"],
                    document_commit=BASELINE["document_commit"], tested_commit=git("rev-parse", "HEAD"),
                    dirty=bool(git("status", "--porcelain")), git_status=git("status", "--short"),
                    dirty_diff_sha256=hashlib.sha256(git("diff", "--binary", "HEAD").encode()).hexdigest(),
                    source_files_sha256=sources, started_at=started, timezone="Asia/Shanghai",
                    changed_original_files=changed_original.splitlines(),
                    output_directory=str(output), tests=[], generator_version=None, profile_id=None,
                    visual_seed=None, performance={"status": "NOT_RUN", "measurements": []},
                    human_acceptance={"status": "NOT_RUN", "confirmation_reference": None},
                    next_stop_gate="WAITING_FOR_REVIEW: WG-0 baseline/isolation before WG-1",
                    rollback_instructions="Close preview; production main scene and all original tracked files are unchanged.")
    (output / "run-manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
    modes = ["headless", "native"] if args.mode == "all" else [args.mode]
    for mode in modes:
        command = common + ["--log-file", str(output / (mode + "-engine.log"))]
        if mode == "headless":
            command += ["--headless", "--script", "res://tests/watergen/context_contract.gd"]
        else:
            command += ["--scene", "res://scenes/watergen/preview.tscn", "--", "--wg-output=" + output.as_posix()]
            if mode == "native": command += ["--wg-capture"]
        if mode == "preview":
            # User-invoked interactive window, held open until Escape/window close.
            result = run(command, output, mode, max(args.timeout, 43200), expect_summary=False)
            if result["status"] == "PASS": result["status"] = "NOT_APPLICABLE"
        else:
            result = run(command, output, mode, args.timeout)
        manifest["tests"].append(result)
        if result["status"] in {"FAIL", "BLOCKED"}: break
    manifest["source_unchanged_during_run"] = sources == source_manifest()
    manifest["finished_at"] = datetime.now(TZ).isoformat()
    evidence_path = output / "native-evidence.json"
    if evidence_path.exists():
        evidence = json.loads(evidence_path.read_text(encoding="utf-8"))
        for key in ("engine_version", "os", "renderer", "gpu", "map_public_digest", "screenshots"):
            manifest[key] = evidence[key]
        manifest["camera_offsets_px"] = [entry["camera_offset_px"] for entry in evidence["screenshots"]]
        manifest["performance"] = {"status": "NOT_RUN", "measurements": [{"legacy_layers_combined_us": evidence["preparation_combined_us"]}], "note": "Full performance matrix NOT_RUN. " + evidence["performance_note"]}
    manifest["commands"] = [item["command"] for item in manifest["tests"]]
    manifest["status"] = "PASS" if not changed_original and manifest["source_unchanged_during_run"] and all(r["status"] in {"PASS", "NOT_APPLICABLE"} for r in manifest["tests"]) else "FAIL"
    (output / "run-manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
    print(output, flush=True)
    return 0 if manifest["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
