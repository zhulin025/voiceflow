#!/bin/bash

# VoiceFlow App Packaging Script
# ------------------------------

APP_NAME="VoiceFlow"
APP_BUNDLE="${APP_NAME}.app"
CONTENTS="${APP_BUNDLE}/Contents"
MACOS="${CONTENTS}/MacOS"
RESOURCES="${CONTENTS}/Resources"

echo "🎨 正在准备编译 VoiceFlow..."

# 1. 确保目录结构
mkdir -p "${MACOS}"
mkdir -p "${RESOURCES}"

# 2. 编译 Swift 二进制文件 (Release 模式)
echo "📦 正在编译二进制文件 (Release)..."
swift build -c release --disable-sandbox

if [ $? -ne 0 ]; then
    echo "❌ 编译失败，请检查代码或依赖。"
    exit 1
fi

echo "🚚 正在拷贝二进制文件与资源..."
cp ".build/release/${APP_NAME}" "${MACOS}/${APP_NAME}"

# 3. 拷贝 Info.plist 与图标
echo "📝 正在生成 Info.plist 与图标..."
cp "Sources/VoiceFlow/System/Info.plist" "${CONTENTS}/Info.plist"
cp "Resources/AppIcon.icns" "${RESOURCES}/AppIcon.icns"

echo "✅ 打包完成: ${APP_BUNDLE}"
echo "------------------------------------------------"
echo "🚀 您现在可以运行应用了！"
echo "💡 注意：本应用需要麦克风和辅助功能权限。"
echo "   请在 '系统设置 -> 隐私与安全性' 中授予相关权限。"
echo "------------------------------------------------"
echo "运行命令: open ${APP_BUNDLE}"
