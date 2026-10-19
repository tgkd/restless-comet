#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."

core() {
  swift test --package-path Packages/RestlessCore
}

app() {
  xcodegen generate --spec project.yml --quiet
  xcodebuild -project RestlessComet.xcodeproj -scheme RestlessComet -configuration Debug \
    -destination 'platform=macOS,arch=arm64' -derivedDataPath build/DerivedData -quiet build
  /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
    -u "build/DerivedData/Build/Products/Debug/Restless Comet.app"
}

case "${1:-all}" in
  core) core ;;
  app) app ;;
  all) core; app ;;
  *) echo "usage: scripts/check.sh [core|app|all]" >&2; exit 2 ;;
esac
