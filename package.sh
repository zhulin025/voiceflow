#!/bin/bash
set -e  # 遇到任何错误立即停止

# VoiceFlow App Packaging Script (Universal Binary Edition)
# ------------------------------

APP_NAME="VoiceFlow"
APP_BUNDLE="${APP_NAME}.app"
CONTENTS="${APP_BUNDLE}/Contents"
MACOS="${CONTENTS}/MacOS"
RESOURCES="${CONTENTS}/Resources"

echo "🎨 正在准备编译 VoiceFlow (通用二进制)..."

# 1. 彻底清理环境
echo "🧹 正在清理旧的编译产物与缓存..."
rm -rf .build
rm -rf "${APP_BUNDLE}"

# 2. 编译 Swift 二进制文件 (双架构)
echo "📦 正在编译二进制文件 (Apple Silicon)..."
swift build -c release --triple arm64-apple-macosx --disable-sandbox

echo "📦 正在编译二进制文件 (Intel)..."
swift build -c release --triple x86_64-apple-macosx --disable-sandbox

# 3. 准备 App Bundle 结构
echo "📂 正在创建 App Bundle 目录结构..."
mkdir -p "${MACOS}"
mkdir -p "${RESOURCES}"

# 4. 合并为通用二进制
echo "🚚 正在合并为通用二进制 (Universal Binary)..."
ARM_BIN=".build/arm64-apple-macosx/release/${APP_NAME}"
X64_BIN=".build/x86_64-apple-macosx/release/${APP_NAME}"
lipo -create "${ARM_BIN}" "${X64_BIN}" -output "${MACOS}/${APP_NAME}"

# 5. 拷贝 Info.plist 与资源
echo "📝 正在生成 Info.plist 与图标..."
cp "Sources/VoiceFlow/System/Info.plist" "${CONTENTS}/Info.plist"
cp "Resources/AppIcon.icns" "${RESOURCES}/AppIcon.icns"

# 6. 核心修复：对通用二进制进行深度自签名 (Ad-hoc Sign)
# 这是解决通用二进制辅助功能权限失效的关键步骤
echo "🔐 正在进行深度自签名以稳定权限系统..."
codesign --force --deep --sign - "${APP_BUNDLE}"

echo "✅ 打包完成: ${APP_BUNDLE} (支持 Intel & M1/M2/M3)"
echo "------------------------------------------------"
echo "🚀 您现在可以运行应用了！"
echo "💡 提示：您可以直接将此 ${APP_BUNDLE} 拷贝给其他 Mac 用户使用。"
echo "   - 环境要求：macOS 14.0+ (Sonoma 或更高版本)"
echo "   - 首次运行：由于未签名，其他用户需「右键 -> 打开」进行授权。"
echo "------------------------------------------------"
echo "运行命令: open ${APP_BUNDLE}"
