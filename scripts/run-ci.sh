#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Use the currently selected Xcode by default.
# Override manually only if you know the exact app bundle path exists.
export DEVELOPER_DIR="$(xcode-select -p | sed 's#/Contents/Developer##')/Contents/Developer"

export IOS_SIMULATOR_DESTINATION="platform=iOS Simulator,name=iPhone 17 Pro"
export XCODE_PROJECT="MedSim.xcodeproj"
export XCODE_SCHEME="MedSim"
export CLONED_SOURCE_PACKAGES_DIR="/tmp/cloned-source-packages"
export DERIVED_DATA_BUILD="/tmp/derived-data-build"
export DERIVED_DATA_UNIT="/tmp/derived-data-unit"
export DERIVED_DATA_UI="/tmp/derived-data-ui"

cd "$ROOT_DIR"

echo "== Toolchain =="
xcode-select -p
xcodebuild -version
swift --version

echo "== SwiftFormat =="
swiftformat --version
swiftformat MedSim MedSimTests MedSimUITests apps \
  --config .swiftformat \
  --lint

echo "== SwiftLint =="
swiftlint version
swiftlint lint --strict --config .swiftlint.yml --force-exclude --no-cache

echo "== SPM: TrainerLabiOS =="
(
  cd apps/trainerlab-ios
  swift package resolve
  swift test
)

echo "== SPM: ChatLabiOS =="
(
  cd apps/chatlab-ios
  swift package resolve
  swift test
)

echo "== SPM: MedSimShelliOS =="
(
  cd apps/medsim-shell-ios
  swift package resolve
  swift build
)

echo "== Xcode package resolve =="
mkdir -p "$CLONED_SOURCE_PACKAGES_DIR"
xcodebuild -resolvePackageDependencies \
  -project "$XCODE_PROJECT" \
  -scheme "$XCODE_SCHEME" \
  -clonedSourcePackagesDirPath "$CLONED_SOURCE_PACKAGES_DIR"

echo "== iOS Build =="
xcodebuild build-for-testing \
  -project "$XCODE_PROJECT" \
  -scheme "$XCODE_SCHEME" \
  -destination "$IOS_SIMULATOR_DESTINATION" \
  -derivedDataPath "$DERIVED_DATA_BUILD" \
  -clonedSourcePackagesDirPath "$CLONED_SOURCE_PACKAGES_DIR" \
  CODE_SIGNING_ALLOWED=NO

echo "== iOS Unit Tests =="
xcodebuild test \
  -project "$XCODE_PROJECT" \
  -scheme "$XCODE_SCHEME" \
  -destination "$IOS_SIMULATOR_DESTINATION" \
  -derivedDataPath "$DERIVED_DATA_UNIT" \
  -clonedSourcePackagesDirPath "$CLONED_SOURCE_PACKAGES_DIR" \
  -enableCodeCoverage YES \
  -only-testing:MedSimTests \
  CODE_SIGNING_ALLOWED=NO

echo "== iOS UI Smoke Tests =="
xcodebuild test \
  -project "$XCODE_PROJECT" \
  -scheme "$XCODE_SCHEME" \
  -destination "$IOS_SIMULATOR_DESTINATION" \
  -derivedDataPath "$DERIVED_DATA_UI" \
  -clonedSourcePackagesDirPath "$CLONED_SOURCE_PACKAGES_DIR" \
  -only-testing:MedSimUITests/testLaunchShowsMedSimBrandingOnAuthGate \
  CODE_SIGNING_ALLOWED=NO
