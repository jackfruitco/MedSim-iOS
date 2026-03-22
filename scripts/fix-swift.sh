#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! command -v swiftformat >/dev/null 2>&1; then
  echo "error: SwiftFormat is not installed"
  exit 1
fi

if ! command -v swiftlint >/dev/null 2>&1; then
  echo "error: SwiftLint is not installed"
  exit 1
fi

cd "$ROOT_DIR"

swiftformat MedSim MedSimTests MedSimUITests apps --config .swiftformat
swiftlint --fix --config .swiftlint.yml --force-exclude
swiftlint lint --strict --config .swiftlint.yml --force-exclude --no-cache
fi

swiftformat "$ROOT_DIR" --config "$ROOT_DIR/.swiftformat"
swiftlint --fix --config "$ROOT_DIR/.swiftlint.yml"
swiftlint --config "$ROOT_DIR/.swiftlint.yml"
