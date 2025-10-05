#!/usr/bin/env bash
set -euo pipefail

# Forward all args to the repo root Makefile
ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"

if [ $# -eq 0 ]; then
  echo "Usage: bash make.sh <target> [ARGS]" >&2
  echo "Common targets: run-api, run-web, test, sync, tflocal-apply" >&2
  exit 1
fi
make -C "$ROOT_DIR" "$@"


