#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

command -v swiftformat >/dev/null 2>&1 || { echo "error: SwiftFormat is not installed"; exit 1; }
command -v swiftlint >/dev/null 2>&1 || { echo "error: SwiftLint is not installed"; exit 1; }

swiftformat MedSim MedSimTests MedSimUITests apps --config .swiftformat
swiftlint --fix --config .swiftlint.yml --force-exclude
swiftlint lint --strict --config .swiftlint.yml --force-exclude --no-cache
