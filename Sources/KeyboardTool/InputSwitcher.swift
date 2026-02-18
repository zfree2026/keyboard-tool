import Carbon

enum InputSwitcher {
    static func toggle() {
        if isJapanese() {
            switchToEnglish()
        } else {
            switchToJapanese()
        }
    }

    static func isJapanese() -> Bool {
        guard let src = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else { return false }
        let id = sourceID(src)
        return id.hasSuffix(".Japanese") ||
               id.lowercased().contains("atok") ||
               (id.lowercased().contains("google") && sourceLanguages(src).contains("ja"))
    }

    // MARK: - Private

    private static func switchToEnglish() {
        // JIS キーボードタイプを明示して英数キーをシミュレート
        // (HHKB など ANSI キーボードから発火した場合でも正しく認識される)
        let src = CGEventSource(stateID: .hidSystemState)
        src?.keyboardType = 198  // JIS keyboard type
        CGEvent(keyboardEventSource: src, virtualKey: 0x66, keyDown: true)?.post(tap: .cgSessionEventTap)
        CGEvent(keyboardEventSource: src, virtualKey: 0x66, keyDown: false)?.post(tap: .cgSessionEventTap)
    }

    private static func switchToJapanese() {
        // かなキーをシミュレート
        let src = CGEventSource(stateID: .hidSystemState)
        CGEvent(keyboardEventSource: src, virtualKey: 0x68, keyDown: true)?.post(tap: .cgSessionEventTap)
        CGEvent(keyboardEventSource: src, virtualKey: 0x68, keyDown: false)?.post(tap: .cgSessionEventTap)
    }

    private static func sourceID(_ src: TISInputSource) -> String {
        guard let ptr = TISGetInputSourceProperty(src, kTISPropertyInputSourceID) else { return "" }
        return Unmanaged<CFString>.fromOpaque(ptr).takeUnretainedValue() as String
    }

    private static func sourceLanguages(_ src: TISInputSource) -> [String] {
        guard let ptr = TISGetInputSourceProperty(src, kTISPropertyInputSourceLanguages) else { return [] }
        return Unmanaged<CFArray>.fromOpaque(ptr).takeUnretainedValue() as? [String] ?? []
    }
}
