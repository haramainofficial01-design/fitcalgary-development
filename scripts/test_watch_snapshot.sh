#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
build_dir="$(mktemp -d)"
cleanup() {
  if [[ -f "$build_dir/smoke" ]]; then unlink "$build_dir/smoke"; fi
  rmdir "$build_dir"
}
trap cleanup EXIT

swiftc \
  "$project_root/apps/watch/FitCalgaryWatch/Models/WatchSnapshot.swift" \
  "$project_root/apps/watch/Tests/WatchSnapshotCodecSmoke.swift" \
  -o "$build_dir/smoke"
"$build_dir/smoke"
