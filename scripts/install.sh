#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."

lsregister=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
app_name="Restless Comet.app"
products=build/DerivedData/Build/Products
destination="$HOME/Applications/$app_name"

xcodegen generate --spec project.yml --quiet
xcodebuild -project RestlessComet.xcodeproj -scheme RestlessComet -configuration Release \
  -destination 'platform=macOS,arch=arm64' -derivedDataPath build/DerivedData -quiet build

pkill -x "Restless Comet" || true
mkdir -p "$HOME/Applications"
rm -rf "$destination"
ditto "$products/Release/$app_name" "$destination"

for configuration in Debug Release; do
  if [[ -d "$products/$configuration/$app_name" ]]; then
    "$lsregister" -u "$products/$configuration/$app_name"
  fi
done
"$lsregister" -f "$destination"
echo "installed $destination"
