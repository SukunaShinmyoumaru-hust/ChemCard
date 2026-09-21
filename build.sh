#!/usr/bin/env bash
# 化学扑克牌 —— 构建并打包 macOS .app
#   bash build.sh            # release 构建 → dist/ChemCards.app
#   bash build.sh debug      # debug 构建（更快，未优化）
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="ChemCards"
DISPLAY_NAME="化学扑克牌"
BUNDLE_ID="cn.chemcards.app"
VERSION="1.0.0"
BUILD_NUMBER="1"

CONFIG="${1:-release}"
DIST="dist"
APP="$DIST/$APP_NAME.app"

echo "▸ swift build -c $CONFIG"
swift build -c "$CONFIG"
BIN_DIR="$(swift build -c "$CONFIG" --show-bin-path)"

echo "▸ 组装 $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/$APP_NAME" "$APP/Contents/MacOS/$APP_NAME"
chmod +x "$APP/Contents/MacOS/$APP_NAME"

# SwiftPM 不会把散落的 PNG 放进可运行 bundle，这里手动拷进 Contents/Resources
if [ -d Resources ]; then
  cp -R Resources/. "$APP/Contents/Resources/"
fi

if [ -f build/AppIcon.icns ]; then
  cp build/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
fi

printf 'APPL????' > "$APP/Contents/PkgInfo"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>              <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>       <string>$DISPLAY_NAME</string>
    <key>CFBundleExecutable</key>        <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>        <string>$BUNDLE_ID</string>
    <key>CFBundlePackageType</key>       <string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key>           <string>$BUILD_NUMBER</string>
    <key>CFBundleIconFile</key>          <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>    <string>13.0</string>
    <key>NSHighResolutionCapable</key>   <true/>
    <key>NSPrincipalClass</key>          <string>NSApplication</string>
    <key>NSSupportsAutomaticGraphicsSwitching</key><true/>
    <key>LSApplicationCategoryType</key> <string>public.app-category.puzzle-games</string>
    <key>NSHumanReadableCopyright</key>  <string>化学扑克牌 v$VERSION · 同人原创学习游戏</string>
    <key>CFBundleDevelopmentRegion</key> <string>zh_CN</string>
    <key>CFBundleLocalizations</key>     <array><string>zh_CN</string><string>en</string></array>
</dict>
</plist>
PLIST

echo "▸ ad-hoc 签名"
codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || codesign --force --sign - "$APP"

echo "✓ 完成：$APP"
echo "  运行： open $APP"
