#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."

app_name="Restless Comet Dev"

xcodegen generate --spec project.yml --quiet
xcodebuild -project RestlessComet.xcodeproj -scheme RestlessComet -configuration Debug \
  -destination 'platform=macOS,arch=arm64' -derivedDataPath build/DerivedData -quiet build

pkill -x "$app_name" || true
while pgrep -x "$app_name" >/dev/null; do
  sleep 0.2
done
open "build/DerivedData/Build/Products/Debug/$app_name.app"
