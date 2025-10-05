#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
if [ $# -eq 0 ]; then
  echo "Usage: bash make.sh <target> [ARGS]" >&2
  echo "Common targets: run-worker, sync, test" >&2
  exit 1
fi
make -C "$ROOT_DIR" "$@"


