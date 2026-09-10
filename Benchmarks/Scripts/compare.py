#!/usr/bin/env python3
"""Compare single runs or repeated baseline directories on the same hardware."""
import argparse
import json
import math
import pathlib
import statistics
import sys

CONFIG = ("schemaVersion", "fixtureVersion", "protocolVersion", "os", "processors",
          "scene", "stage", "count", "warmup", "frames", "sequenceFrames",
          "commandCountMin", "commandCountMax")
METADATA = ("toolchain.txt", "hardware.txt", "dependencies.json")


def load(root):
    trials = sorted(root.glob("trial-*")) or [root]
    results = {}
    metadata = None
    configs = {}
    expected_files = None
    for trial in trials:
        current_metadata = {name: (trial / name).read_text() for name in METADATA}
        if metadata is not None and metadata != current_metadata:
            raise ValueError("metadata differs between trials")
        metadata = current_metadata
        files = sorted(trial.glob("*-*.json"))
        names = {p.name for p in files}
        if not names or (expected_files is not None and names != expected_files):
            raise ValueError("empty or inconsistent trial workloads")
        expected_files = names
        for path in files:
            report = json.loads(path.read_text())
            if report["profilingEnabled"]:
                raise ValueError("cannot compare profiled timings")
            config = {k: report[k] for k in CONFIG}
            if path.name in configs and configs[path.name] != config:
                raise ValueError(f"incompatible trial configuration: {path.name}")
            configs[path.name] = config
            metrics = {}
            for phase, timing in report["timings"].items():
                for percentile in ("p50MS", "p95MS"):
                    value = timing[percentile]
                    if not math.isfinite(value) or value <= 0:
                        raise ValueError(f"invalid timing: {path.name}/{phase}")
                    metrics[f"{phase}/{percentile}"] = value
            results.setdefault(path.name, []).append(metrics)
    return results, configs, metadata


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("baseline", type=pathlib.Path)
    parser.add_argument("candidate", type=pathlib.Path)
    parser.add_argument("--max-regression-percent", type=float, default=15)
    args = parser.parse_args()
    if not math.isfinite(args.max_regression_percent) or args.max_regression_percent < 0:
        parser.error("threshold must be finite and nonnegative")
    try:
        old, old_config, old_meta = load(args.baseline)
        new, new_config, new_meta = load(args.candidate)
        if old_config != new_config or old_meta != new_meta:
            raise ValueError("incompatible workloads, configuration, toolchain, dependencies or hardware")
        failed = False
        print("Medians across trials; spread is (max-min)/median, not a confidence interval.")
        for name in sorted(old):
            keys = set(old[name][0])
            if any(set(t) != keys for t in old[name] + new[name]):
                raise ValueError(f"incompatible timing phases: {name}")
            for metric in sorted(keys):
                before = [t[metric] for t in old[name]]
                after = [t[metric] for t in new[name]]
                a, b = statistics.median(before), statistics.median(after)
                change = (b / a - 1) * 100
                spread_a = (max(before) - min(before)) / a * 100
                spread_b = (max(after) - min(after)) / b * 100
                regression = change > args.max_regression_percent
                failed |= regression
                print(f"{name}/{metric}: {a:.4f} -> {b:.4f} ms ({change:+.1f}%) "
                      f"spread {spread_a:.1f}%/{spread_b:.1f}% trials {len(before)}/{len(after)}"
                      + (" REGRESSION" if regression else ""))
        return int(failed)
    except (OSError, ValueError, KeyError, TypeError) as error:
        print(error, file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
