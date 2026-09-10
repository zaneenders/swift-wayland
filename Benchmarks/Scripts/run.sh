#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
out=${1:-Benchmarks/results}
mkdir -p "$out"
swift build --package-path Benchmarks -c release --product RenderBenchmark
bin=$(swift build --package-path Benchmarks -c release --show-bin-path)/RenderBenchmark
swift --version > "$out/toolchain.txt"
git rev-parse HEAD > "$out/revision.txt"
git status --short > "$out/worktree.txt"
# Timing runs must not include sampler overhead.
unset PROFILE_RECORDER_SERVER_URL_PATTERN PROFILE_RECORDER_SERVER_URL
for scene in shapes text clipped images; do
  "$bin" --scene "$scene" --stage wire > "$out/$scene-wire.json"
  if [ "$(uname -s)" = Darwin ] && [ "${METAL:-0}" = 1 ]; then
    "$bin" --scene "$scene" --stage metal > "$out/$scene-metal.json"
    "$bin" --scene "$scene" --stage pipeline > "$out/$scene-pipeline.json"
  fi
done
