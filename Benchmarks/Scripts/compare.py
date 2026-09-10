#!/usr/bin/env python3
"""Compare same-machine benchmark directories; opt-in timing regression gate."""
import argparse
import json
import pathlib
import sys

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("baseline", type=pathlib.Path)
parser.add_argument("candidate", type=pathlib.Path)
parser.add_argument("--max-regression-percent", type=float, default=15)
args = parser.parse_args()
if not 0 <= args.max_regression_percent < float("inf"):
    parser.error("threshold must be finite and nonnegative")
failed = False
files = sorted(args.baseline.glob("*-*.json"))
if not files:
    parser.error("baseline contains no benchmark results")
for path in files:
    try:
        old = json.loads(path.read_text())
        new = json.loads((args.candidate / path.name).read_text())
        for key in ("schemaVersion", "fixtureVersion", "protocolVersion", "os", "processors",
                    "scene", "stage", "count", "warmup"):
            if old[key] != new[key]:
                raise ValueError(f"incompatible {key}")
        if old["profilingEnabled"] or new["profilingEnabled"]:
            raise ValueError("cannot compare profiled timing runs")
        if old["timings"].keys() != new["timings"].keys():
            raise ValueError("incompatible timing stages")
        for metric in old["timings"]:
            before = old["timings"][metric]["p50MS"]
            after = new["timings"][metric]["p50MS"]
            if before <= 0:
                raise ValueError(f"invalid baseline for {metric}")
            change = (after / before - 1) * 100
            regression = change > args.max_regression_percent
            failed |= regression
            print(f"{path.stem}/{metric}: {before:.4f} -> {after:.4f} ms ({change:+.1f}%)"
                  + (" REGRESSION" if regression else ""))
    except (OSError, ValueError, KeyError) as error:
        print(f"{path.name}: {error}", file=sys.stderr)
        failed = True
sys.exit(1 if failed else 0)
