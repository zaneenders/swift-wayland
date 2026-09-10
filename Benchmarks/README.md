# Rendering benchmarks

A standalone package so the profiling dependencies never become dependencies of
Chroma library consumers. Replays deterministic, versioned display lists across
the logic/rendering boundary, without an application graph, window, network, or
random/clock-driven scene generation.

## Run

From the repository root:

```sh
# Correctness tests (also run in macOS and Linux CI)
swift test --package-path Benchmarks -c release

# Four wire-codec fixtures, JSON plus revision/toolchain metadata
Benchmarks/Scripts/run.sh Benchmarks/results/baseline

# Also run offscreen Metal and wire -> decode -> Metal on a Mac with a GPU
METAL=1 Benchmarks/Scripts/run.sh Benchmarks/results/baseline

# Individual workload
swift run --package-path Benchmarks -c release RenderBenchmark \
  --scene text --stage metal --count 2000 --frames 300 --warmup 30
```

Scenes: `shapes` (rounded shapes), `text` (128 repeating strings), `clipped`
(partially visible shapes), and `images` (many references to one checker image).
All use a 1100x720 viewport and 1x raster scale. Count controls commands, not
visible commands or glyphs. Fixtures intentionally preserve offscreen commands
so Metal's production culling path is exercised. Wire timing encodes the supplied
list without a server culling pass.

Stages:

- `wire`: encode and decode only, with persistent sender/receiver image caches.
- `metal`: replay the original list through `MetalDisplayListRenderer`.
- `pipeline`: encode, decode, then render the decoded list; reports each phase
  separately, **not** an end-to-end frame latency.

JSON reports first-frame phase timings, warm mean/p50/p95, frame counts, image
cold/steady wire bytes, OS, processor count, and fixture/protocol versions.
Initialization, shader compilation, fixture construction, and first-frame
round-trip validation are outside the timed phases. First replay is reported
separately; 30 additional frames warm caches before the 300 measured frames.

Metal CPU timing covers `encode` plus `endEncoding`, including renderer culling,
instance preparation and buffer uploads. It excludes command creation,
commit, and completion waits. GPU time comes from completed command-buffer
timestamps. Replay waits for each command buffer before reusing pooled buffers;
this is intentionally serial, **not** a maximum-throughput/presentation benchmark.
Failures to create/use Metal are errors, never silently reported as zero work.

The tests verify fixture determinism, exact protocol round trips across repeated
cached frames, image wire reuse, and culling idempotence. These are not pixel
snapshot tests. The harness does not yet exercise image revision/eviction,
resizing, unique-string cache churn, or Wayland GPU rendering. Existing Chroma
and protocol tests remain the broader correctness suite.

## Automated sampling with the existing profiler

```sh
Benchmarks/Scripts/profile.sh Benchmarks/results/profile text metal
# For codec-only profiling (also suitable for Linux):
Benchmarks/Scripts/profile.sh Benchmarks/results/wire-profile shapes wire
```

The script builds release, starts a 20-second replay with a unique local profiler
socket, waits for readiness and warmup, captures 500 samples at 10ms, waits for
completion, and cleans up the process/socket. Open `samples.perf` in Speedscope.
`recorder.log` contains diagnostics; `profile-run.json` is explicitly marked as
profiled and must not be used as a timing baseline. No sudo is needed.

For manual capture, launch with `PROFILE_RECORDER_SERVER_URL_PATTERN` as in
Scribe, and use `--seconds 20` (or longer). Frame count and duration are both
minimums. The recorder samples all threads, including waits: sampled stack
frequency is not itself CPU utilization. Offscreen Metal profiles will include
intentional GPU completion waits; inspect active encoding stacks separately.

## Regression comparisons

```sh
METAL=1 Benchmarks/Scripts/run.sh Benchmarks/results/candidate
python3 Benchmarks/Scripts/compare.py \
  Benchmarks/results/baseline Benchmarks/results/candidate \
  --max-regression-percent 15
```

Compares p50 for each phase and exits nonzero on a regression, missing result,
incompatible fixture/configuration, or profiled timing input. Keep hardware,
power mode, toolchain, dependency versions, viewport, and workload identical;
OS/processor metadata checks alone cannot identify equivalent hardware. Inspect
`revision.txt`, `worktree.txt`, and `toolchain.txt` with results. Run multiple
trials on a quiet machine before accepting a regression or claimed speedup.
GPU timings in particular vary with contention and power state.

Separate macOS and Arch Linux benchmark jobs wait for **both** existing platform
validation jobs to pass (including their prerequisite hygiene checks). They then
run correctness tests and upload platform-specific wire timing JSON artifacts
without timing thresholds. Build/test/execution failures still fail the benchmark
job. GPU runs and regression gating are opt-in on controlled hardware.
This harness isolates rendering; keep the existing demo `--benchmark` for graph
construction/draw/cull measurements, and live Scribe profiles for real workloads.
