#!/bin/bash
set -e

APP_NAME="KeyboardTool"
BUNDLE="${APP_NAME}.app"

echo "▶ Building ${APP_NAME}..."
swift build -c release

BINARY=".build/release/${APP_NAME}"
if [ ! -f "$BINARY" ]; then
    echo "Error: binary not found at $BINARY"
    exit 1
fi

echo "▶ Creating app bundle..."
rm -rf "${BUNDLE}"
mkdir -p "${BUNDLE}/Contents/MacOS"
mkdir -p "${BUNDLE}/Contents/Resources"

cp "$BINARY" "${BUNDLE}/Contents/MacOS/${APP_NAME}"
cp "Resources/Info.plist" "${BUNDLE}/Contents/Info.plist"

# アドホック署名（ローカル実行に必要）
echo "▶ Code signing (ad-hoc)..."
codesign --force --deep --sign - "${BUNDLE}"

echo ""
echo "✅ ${BUNDLE} が作成されました。"
echo ""
echo "インストール手順:"
echo "  1. cp -r ${BUNDLE} /Applications/"
echo "  2. open /Applications/${BUNDLE}"
echo "  3. システム設定 → プライバシーとセキュリティ → アクセシビリティ で KeyboardTool を許可"
echo "  4. KeyboardTool を再起動"
