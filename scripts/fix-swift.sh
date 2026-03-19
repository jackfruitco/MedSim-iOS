#
//  fix-swift.sh
//  MedSim
//
//  Created by Tyler Johnson on 3/19/26.
//

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

swiftformat "$ROOT_DIR" --config "$ROOT_DIR/.swiftformat"
swiftlint --fix --config "$ROOT_DIR/.swiftlint.yml"
swiftlint --config "$ROOT_DIR/.swiftlint.yml"
