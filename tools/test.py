#!/usr/bin/env python3
"""Run affected GUT scripts, or the full suite with --full. No third-party dependencies."""
import argparse
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import time
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parent.parent


def git(*args):
    return subprocess.check_output(["git", *args], cwd=ROOT).decode().split("\0")[:-1]


def select(changed):
    files = {str(p.relative_to(ROOT)): p.read_text() for folder in
             ("game", "autoload", "tests", "tools", "mods")
             for p in (ROOT / folder).rglob("*") if p.suffix in (".gd", ".tscn", ".tres")}
    tests = {p for p in files if p.startswith("tests/") and p.endswith(".gd")
             and Path(p).name.startswith("test_")}
    classes = {m[1]: p for p, source in files.items()
               if (m := re.search(r"^class_name\s+(\w+)", source, re.M))}
    reverse = {}
    for path, source in files.items():
        dependencies = {classes[token] for token in re.findall(r"\b\w+\b", source) if token in classes}
        dependencies.update(re.findall(r'res://([^"\s\)]+)', source))
        for dependency in dependencies:
            reverse.setdefault(dependency, set()).add(path)
    affected = set(changed)
    for path in changed:
        if path.endswith((".md", ".uid")) or path.startswith(("docs/", "assets/brand/")):
            continue
        if path not in files or not (ROOT / path).exists():
            return sorted(tests), "full suite: shared configuration, asset, infrastructure or deleted file"
    pending = list(affected)
    while pending:
        for consumer in reverse.get(pending.pop(), ()):
            if consumer not in affected:
                affected.add(consumer)
                pending.append(consumer)
    selected = tests & affected
    if any(p in files and not p.startswith("tests/") for p in changed):
        selected.add("tests/unit/test_smoke.gd")
    return sorted(selected), "changed files and transitive consumers"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("paths", nargs="*", help="changed files; default: working tree vs HEAD")
    parser.add_argument("--base", help="compare merge base with this Git ref, including working changes")
    parser.add_argument("--full", action="store_true")
    parser.add_argument("--list", action="store_true", help="show selection without starting Godot")
    parser.add_argument("--import", dest="scan", action="store_true", help="refresh Godot class index")
    parser.add_argument("--shard", default="1/1", help="CI partition, e.g. 1/4; separate workers only")
    args = parser.parse_args()
    os.chdir(ROOT)
    if args.full:
        selected, reason = select(["project.godot"])
    else:
        base = subprocess.check_output(["git", "merge-base", args.base, "HEAD"]).decode().strip() if args.base else "HEAD"
        changed = args.paths or sorted(set(git("diff", "--name-only", "-z", base) +
                                           git("ls-files", "--others", "--exclude-standard", "-z")))
        selected, reason = select(changed)
    index, count = map(int, args.shard.split("/"))
    if not 1 <= index <= count <= 16:
        parser.error("--shard must be INDEX/COUNT with 1 <= INDEX <= COUNT <= 16")
    if count > 1:
        buckets = [[] for _ in range(count)]
        weights = [0] * count
        def cost(path):
            cases = len(re.findall(r"^func test_", (ROOT / path).read_text(), re.M))
            return max(1, cases) * (8 if "/integration/" in path else 1)
        for path in sorted(selected, key=lambda p: (-cost(p), p)):
            bucket = min(range(count), key=weights.__getitem__)
            buckets[bucket].append(path)
            weights[bucket] += cost(path)
        selected = sorted(buckets[index - 1])
    print(f"{len(selected)} test scripts: {reason}", flush=True)
    if args.list:
        if selected:
            print("\n".join(selected))
        return 0
    if not selected:
        return 0
    godot = os.environ.get("GODOT_BIN") or shutil.which("godot") or "/Applications/Godot.app/Contents/MacOS/Godot"
    env = dict(os.environ, GODOT_CAP=os.environ.get("GODOT_CAP", "480"),
               GODOT_GRACE="3", GODOT_DONE="---- All tests passed! ----")
    def run(arguments):
        return subprocess.run(["tools/ci_godot.sh", godot, "--headless", "--path", ".", *arguments], env=env).returncode
    if args.scan or not (ROOT / ".godot/global_script_class_cache.cfg").exists():
        status = run(["--editor", "--quit"])
        if status:
            return status
    started = time.monotonic()
    with tempfile.TemporaryDirectory(prefix="pokerecomp-tests-") as temporary:
        report = Path(temporary) / "results.xml"
        status = run(["-s", "res://addons/gut/gut_cmdln.gd", "-gdir=",
                      "-gtest=" + ",".join("res://" + p for p in selected), "-gexit",
                      "-gjunit_xml_file=" + str(report)])
        if report.exists():
            suites = ET.parse(report).getroot().findall("testsuite")
            executed = {s.attrib["name"] for s in suites if int(s.attrib["tests"]) > 0}
            missing = set(selected) - executed
            if missing:
                print("ERROR: selected scripts did not run: " + ", ".join(sorted(missing)))
                status = 1
            slowest = sorted(suites, key=lambda s: float(s.attrib["time"]), reverse=True)[:5]
            for suite in slowest:
                print(f"  {float(suite.attrib['time']):.2f}s  {suite.attrib['name']}")
        else:
            print("ERROR: GUT produced no test report")
            status = status or 1
    print(f"Validation: {len(selected)} scripts in {time.monotonic() - started:.1f}s; exit {status}")
    return status


if __name__ == "__main__":
    sys.exit(main())
