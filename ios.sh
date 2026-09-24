#!/usr/bin/env bash
# iPhone 闭环：生成工程 → 编译 → 装机 → 启动 → 截图。
# 模拟器：bash ios.sh build（不需要签名）。
# 真机：bash ios.sh device —— 需要钥匙串里有 Apple Development 证书，
#       且 ios/signing.xcconfig 里填了 DEVELOPMENT_TEAM。
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT="$ROOT/ios/ChemCardsiOS.xcodeproj"
DERIVED="$ROOT/ios-derived"
APP="$DERIVED/Build/Products/Debug-iphonesimulator/ChemCards.app"
DEVICE_DERIVED="$ROOT/ios-device"
DEVICE_APP="$DEVICE_DERIVED/Build/Products/Debug-iphoneos/ChemCards.app"
BUNDLE="cn.chemcards.ios"
DEVICE="${DEVICE:-iPhone 14}"

# 只挑可用的同名模拟器，取 UDID
CMD="${1:-all}"
UDID="$(xcrun simctl list devices available | grep -E "^\s+$DEVICE \(" \
    | head -1 | sed -E 's/.*\(([0-9A-F-]+)\).*/\1/' || true)"
if [[ -z "${UDID:-}" && "$CMD" != "gen" && "$CMD" != "phone" && "$CMD" != "device" ]]; then
    echo "✗ 找不到模拟器「$DEVICE」，用 DEVICE='iPhone 14 Pro' bash ios.sh 指定" >&2
    exit 1
fi

gen() { python3 "$ROOT/ios/make-ios-project.py"; }

boot() {
    [[ "$(xcrun simctl list devices | grep "$UDID" | sed -E 's/.*\((Booted|Shutdown|.*\?*)\).*/\1/')" == "Booted" ]] \
        || xcrun simctl boot "$UDID" 2>/dev/null || true
    open -a Simulator || true
}

build() {
    gen
    xcodebuild -project "$PROJECT" -scheme ChemCards \
        -destination 'generic/platform=iOS Simulator' \
        -derivedDataPath "$DERIVED" CODE_SIGNING_ALLOWED=NO build \
        | grep -E "warning:|error:|BUILD" || true
    [[ -d "$APP" ]] || { echo "✗ 没产出 $APP" >&2; exit 1; }
    boot
    xcrun simctl install "$UDID" "$APP"
    echo "✓ 已装机：$DEVICE"
}

# 真机包：编译成 arm64 + 自动签名，然后直接装到连着的 iPhone 上
device() {
    gen
    xcodebuild -project "$PROJECT" -scheme ChemCards \
        -destination 'generic/platform=iOS' \
        -derivedDataPath "$DEVICE_DERIVED" build \
        | grep -E "warning:|error:|BUILD" || true
    [[ -d "$DEVICE_APP" ]] || { echo "✗ 没产出 $DEVICE_APP" >&2; exit 1; }
    local udid
    udid="$(xcrun devicectl list devices 2>/dev/null | awk '/connected/ \
        {for (i = 1; i <= NF; i++) if ($i ~ /^[0-9A-F]{8}(-[0-9A-F]{4}){3}-[0-9A-F]{12}$/) {print $i; exit}}')"
    if [[ -z "$udid" ]]; then
        echo "✓ 已编译：$DEVICE_APP"
        echo "  没检测到已连接的 iPhone，插上并信任这台电脑后再跑一次"
        return
    fi
    xcrun devicectl device install app --device "$udid" "$DEVICE_APP" 2>&1 | grep -E "App installed|error" || true
    echo "✓ 已装机：$DEVICE_APP"
}

launch() {
    boot
    xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
    xcrun simctl launch "$UDID" "$BUNDLE" "$@" >/dev/null
    sleep "${LAUNCH_WAIT:-4}"
    echo "✓ 已启动 ${*:-（默认场景）}"
}

shot() {
    local path="${1:-docs/preview-ios.png}"
    mkdir -p "$(dirname "$path")"
    xcrun simctl io "$UDID" screenshot "$path" >/dev/null
    echo "✓ 截图：$path"
}

# --stdout= 在这版 simctl 上不落文件，只有 --console 能拿到 print
smoke() {
    boot
    ( sleep 30; pkill -f "simctl launch --terminate-running-process --console" 2>/dev/null ) &
    local watchdog=$!
    xcrun simctl launch --terminate-running-process --console "$UDID" "$BUNDLE" --smoke-test \
        | grep -E "SMOKE|error" || true
    kill "$watchdog" 2>/dev/null || true
}

# 脚本没法在屏幕上点，每个界面都得让 app 自己启动过去
shots() {
    local tag="${TAG:-}"
    for scene in menu rules table banner log result; do
        # 横幅几秒就走，这一格得抢在它消失之前截
        if [[ "$scene" == "banner" ]]; then
            LAUNCH_WAIT=2 launch "--scene=$scene"
        else
            launch "--scene=$scene"
        fi
        shot "docs/preview-ios$tag-$scene.png"
    done
}

# 真机装不装得上去，只卡两件事：钥匙串里有没有证书、xcconfig 里有没有 Team ID
phone() {
    local identities
    identities="$(security find-identity -v -p codesigning 2>/dev/null | grep -c '"Apple Development"' || true)"
    if [[ "$identities" == "0" ]]; then
        echo "✗ 钥匙串里没有可用的 Apple Development 证书"
        echo "  → 打开 Xcode → Settings → Accounts → 登录 Apple ID → Manage Certificates → +（Apple Development）"
    else
        echo "✓ 找到 $identities 张签名证书："
        security find-identity -v -p codesigning | grep '"Apple Development"' | sed 's/^/    /'
    fi

    local team
    team="$(grep -E '^DEVELOPMENT_TEAM' "$ROOT/ios/signing.xcconfig" | sed -E 's/.*= *//' | tr -d ';//' || true)"
    if [[ -z "$team" ]]; then
        echo "✗ ios/signing.xcconfig 里 DEVELOPMENT_TEAM 还空着"
        echo "  → 在 Xcode 里打开 ios/ChemCardsiOS.xcodeproj，选中 ChemCards target →"
        echo "    Signing & Capabilities → Team 选自己的 Apple ID；"
        echo "    下次 bash ios.sh build 重新生成工程时会把选好的 Team 抄回这个文件，不会丢"
    else
        echo "✓ DEVELOPMENT_TEAM = $team"
    fi

    echo "之后：Xcode 里把设备插上并信任 → scheme 选这台 iPhone → ⌘R。"
    echo "免费账号签的包 7 天过期，过期后重跑一次 ⌘R 即可。"
}

case "${1:-all}" in
    gen)    gen ;;
    build)  build ;;
    device) device ;;
    launch) shift; launch "$@" ;;
    shot)   shift; shot "${1:-docs/preview-ios.png}" ;;
    shots)  shots ;;
    phone)  phone ;;
    smoke)  smoke ;;
    all)    build; launch; shot docs/preview-ios.png ;;
    *)      echo "用法：bash ios.sh [gen|build|device|launch [参数]|shot [路径]|shots|phone|smoke|all]" >&2; exit 2 ;;
esac
