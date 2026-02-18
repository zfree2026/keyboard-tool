# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 概要

macOS メニューバーアプリ。**左右どちらかのコマンドキーを単独で押す**たびに、日本語 (ひらがな) と英字 (ローマ字) の入力モードをトグルで切り替える。

### 対象環境

- JIS 配列 Mac (内蔵キーボード) + HHKB ANSI 配列キーボード (外付け)
- 入力ソース: Kotoeri (ことえり) の RomajiTyping モード
  - 日本語: `com.apple.inputmethod.Kotoeri.RomajiTyping.Japanese`
  - 英字: `com.apple.inputmethod.Kotoeri.RomajiTyping.Roman`

### 動作仕様

| 操作 | 結果 |
|------|------|
| コマンドキー単独押し (左右どちらも) | 日本語 ⇔ 英字をトグル切り替え |
| Cmd+C などの組み合わせ | 通常通り動作 (切り替えなし) |
| 0.5 秒以上の長押し | 切り替えなし |

メニューバーに現在の入力モードを表示: `英` (英字) / `日` (日本語)

## Build & Install

```bash
cd "$(git rev-parse --show-toplevel)"
./build.sh                          # ビルド → KeyboardTool.app を生成
cp -r KeyboardTool.app /Applications/
launchctl kickstart -k gui/$(id -u)/com.local.keyboard-tool  # 再起動
```

**注意: リビルドするたびにアクセシビリティ権限が無効になる。**
リビルド後は必ず再登録:
システム設定 → プライバシーとセキュリティ → アクセシビリティ → KeyboardTool を `-` で削除 → `+` で再追加

### 初回インストール

```bash
./build.sh
cp -r KeyboardTool.app /Applications/
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.local.keyboard-tool.plist
```

アクセシビリティ権限付与後、アプリが自動でキー監視を開始する (2秒ごとにポーリング)。

## Architecture

```
Sources/KeyboardTool/
├── main.swift          # NSApplication エントリポイント
├── AppDelegate.swift   # ステータスバー、入力ソース変更通知、アクセシビリティ権限チェック
├── KeyMonitor.swift    # CGEventTap でコマンドキーの単独押しを検出
└── InputSwitcher.swift # 英数/かなキーシミュレートで入力切り替え
Resources/
└── Info.plist          # LSUIElement=YES (Dock 非表示)
~/Library/LaunchAgents/com.local.keyboard-tool.plist  # ログイン時自動起動
```

### キー検出ロジック (KeyMonitor)

- `CGEventTap` を `cgSessionEventTap` / `headInsertEventTap` で設定
- 左コマンド = keyCode 55、右コマンド = keyCode 54
- `flagsChanged` でコマンドキー押下を記録。押下中に別キーが来たら `otherKeyPressed = true`
- 離し時に「0.5 秒以内 かつ 他キー未押下」なら `InputSwitcher.toggle()` を発火

**実装の注意点**: CGEventTap コールバックは Swift のクロージャをそのまま使えない（C 関数ポインタが必要）。ファイルスコープの `let` でキャプチャなしのクロージャとして定義し、`userInfo` に `Unmanaged.passUnretained(self).toOpaque()` で `self` を渡す。

```swift
private let tapCallback: CGEventTapCallBack = { _, type, event, userInfo in
    guard let userInfo else { return Unmanaged.passRetained(event) }
    Unmanaged<KeyMonitor>.fromOpaque(userInfo).takeUnretainedValue().handle(type: type, event: event)
    return Unmanaged.passRetained(event)
}
```

### 入力切り替え (InputSwitcher)

`TISSelectInputSource` は Kotoeri の実際の入力モードを変えないため、キーイベントシミュレートを使用:

- **英字へ**: 英数キー (keyCode `0x66`) を JIS キーボードタイプ (`keyboardType = 198`) 指定でシミュレート
  - HHKB (ANSI) 接続時も JIS タイプを明示しないと Kotoeri が英数キーと認識しない
- **日本語へ**: かなキー (keyCode `0x68`) をシミュレート

日本語判定 (`isJapanese()`) は `TISCopyCurrentKeyboardInputSource()` の ID で行う:
- `id.hasSuffix(".Japanese")` → Kotoeri 日本語モード
- `id.lowercased().contains("atok")` → ATOK
- `id.lowercased().contains("google") && languages.contains("ja")` → Google 日本語入力

入力ソース変更通知 (`kTISNotifySelectedKeyboardInputSourceChanged`) でメニューバーの `英`/`日` を更新。

### アクセシビリティ権限

- 起動時に `AXIsProcessTrusted()` でチェック (プロンプトなし — `kAXTrustedCheckOptionPrompt: true` にするとループする)
- 未許可時はシステム設定を開き、2 秒ごとに再チェック
- 権限取得後、自動で CGEventTap を開始
- リビルドするたびにバイナリのハッシュが変わり権限が失効する

### 起動方式

`open` コマンドは Gatekeeper にブロックされるため、LaunchAgent 経由で Aqua セッションとして起動する。

- `launchctl load` は deprecated で動作しない → `launchctl bootstrap gui/$(id -u) <plist>` を使う
- 再起動は `launchctl kickstart -k gui/$(id -u)/com.local.keyboard-tool`
- LaunchAgent plist は `~/Library/LaunchAgents/com.local.keyboard-tool.plist` に配置:

```xml
<key>Label</key><string>com.local.keyboard-tool</string>
<key>ProgramArguments</key><array><string>/Applications/KeyboardTool.app/Contents/MacOS/KeyboardTool</string></array>
<key>RunAtLoad</key><true/>
```

`KeepAlive` は設定しない（設定すると権限未取得時に再起動ループが起きる）。
