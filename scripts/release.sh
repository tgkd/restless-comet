#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."

lsregister=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
app_name="Restless Comet"
built="build/DerivedData/Build/Products/Release/$app_name.app"
destination="/Applications/$app_name.app"

xcodegen generate --spec project.yml --quiet
xcodebuild -project RestlessComet.xcodeproj -scheme RestlessComet -configuration Release \
  -destination 'platform=macOS,arch=arm64' -derivedDataPath build/DerivedData -quiet build

was_running=false
if pgrep -x "$app_name" >/dev/null; then
  was_running=true
  pkill -x "$app_name"
  while pgrep -x "$app_name" >/dev/null; do
    sleep 0.2
  done
fi

rm -rf "$destination"
ditto "$built" "$destination"
"$lsregister" -u "$built"
"$lsregister" -f "$destination"

if [[ "$was_running" == true ]]; then
  open -a "$destination" --args --quiet
fi
echo "installed $destination"
