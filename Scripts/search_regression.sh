#!/bin/zsh

# 灵嗅搜索回归门禁：编译、安装并重复启动应用，检查每一轮是否出现
# SwiftUI 异步渲染器、libdispatch 主线程断言或崩溃日志。

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
XCODE_APP="${XCODE_APP:-/Users/hualong/Downloads/Xcode 2.app}"
DEVELOPER_DIR="$XCODE_APP/Contents/Developer"
DEVICE_ID="${DEVICE_ID:-5F0CA002-A0A9-4B83-94AA-8A555A6CB265}"
DERIVED_DATA="${DERIVED_DATA:-$PROJECT_DIR/.deriveddata/SearchRegression}"
APP_PATH="$DERIVED_DATA/Build/Products/Debug-iphonesimulator/LingXiu.app"
LOG_PREDICATE='process == "LingXiu" AND (eventMessage CONTAINS[c] "BUG IN CLIENT OF LIBDISPATCH" OR eventMessage CONTAINS[c] "AsyncRenderer" OR eventMessage CONTAINS[c] "fatal error" OR eventMessage CONTAINS[c] "crash")'

export DEVELOPER_DIR

mkdir -p "$DERIVED_DATA"

if [[ ! -d "$DEVELOPER_DIR" ]]; then
    print -u2 "找不到 Xcode：$XCODE_APP"
    exit 2
fi

# Swift 6's default MainActor isolation makes a locally-created UIKit dynamic
# color provider unsafe for SwiftUI's AsyncRenderer on iOS 26.1. Keep this
# regression guard next to the search test because search dismissal is where
# the renderer assertion was first exposed.
if rg -n 'UIColor[[:space:]]*\{' "$PROJECT_DIR/LingXiu" --glob '*.swift'; then
    print -u2 "检测到自定义 UIColor 动态颜色闭包；请改用 Apple 系统动态颜色或非闭包资产色。"
    exit 1
fi

print "[1/3] 编译并运行单元测试"
xcodebuild test \
    -project "$PROJECT_DIR/LingXiu.xcodeproj" \
    -scheme LingXiu \
    -sdk iphonesimulator \
    -destination "platform=iOS Simulator,id=$DEVICE_ID" \
    -derivedDataPath "$DERIVED_DATA" \
    CODE_SIGNING_ALLOWED=NO \
    | tee "$DERIVED_DATA/search-test.log" \
    | tail -n 24

print "[2/3] 安装最新构建"
xcrun simctl boot "$DEVICE_ID" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$DEVICE_ID" -b >/dev/null
xcrun simctl install "$DEVICE_ID" "$APP_PATH"

print "[3/3] 执行 8 轮启动/终止与崩溃日志检查"
for round in {1..8}; do
    xcrun simctl terminate "$DEVICE_ID" com.hualong.LingXiu >/dev/null 2>&1 || true
    xcrun simctl launch "$DEVICE_ID" com.hualong.LingXiu >/dev/null
    sleep 1

    errors="$(xcrun simctl spawn "$DEVICE_ID" log show --last 3s --style compact --predicate "$LOG_PREDICATE" 2>/dev/null || true)"
    if [[ -n "$errors" && "$errors" != *"Timestamp               Ty Process[PID:TID]" ]]; then
        print -u2 "第 $round 轮发现搜索相关崩溃日志："
        print -u2 "$errors"
        exit 1
    fi

    print "  第 $round/8 轮通过"
done

print "搜索回归通过：编译、单元测试、8 轮启动和崩溃日志检查均成功。"
