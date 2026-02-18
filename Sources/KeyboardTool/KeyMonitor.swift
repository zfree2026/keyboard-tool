import CoreGraphics
import AppKit

// CGEventTap コールバック（キャプチャなしの C 関数ポインタとして渡せる）
private let tapCallback: CGEventTapCallBack = { _, type, event, userInfo in
    guard let userInfo else { return Unmanaged.passRetained(event) }
    Unmanaged<KeyMonitor>.fromOpaque(userInfo).takeUnretainedValue().handle(type: type, event: event)
    return Unmanaged.passRetained(event)
}

class KeyMonitor {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    // 単独コマンドキー判定用の状態
    private var cmdDownTime: Date?
    private var cmdKeyCode: CGKeyCode?
    private var otherKeyPressed = false

    /// イベントタップを開始する。アクセシビリティ権限がない場合は false を返す。
    func start() -> Bool {
        guard eventTap == nil else { return true }  // すでに起動済み
        guard AXIsProcessTrusted() else { return false }

        let mask: CGEventMask = (1 << CGEventType.flagsChanged.rawValue) |
                                (1 << CGEventType.keyDown.rawValue)

        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: tapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )

        guard let tap = eventTap else { return false }

        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    /// イベントを処理する（tapCallback から呼ばれる）
    fileprivate func handle(type: CGEventType, event: CGEvent) {
        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        let isLeftCmd  = keyCode == 55  // kVK_Command
        let isRightCmd = keyCode == 54  // kVK_RightCommand
        let isCmd = isLeftCmd || isRightCmd

        switch type {
        case .flagsChanged:
            let cmdDown = event.flags.contains(.maskCommand)

            if isCmd && cmdDown && cmdDownTime == nil {
                // コマンドキーが押し下げられた
                cmdDownTime = Date()
                cmdKeyCode = keyCode
                otherKeyPressed = false

            } else if isCmd && !cmdDown, let downTime = cmdDownTime, cmdKeyCode == keyCode {
                // コマンドキーが離された
                let elapsed = Date().timeIntervalSince(downTime)
                if elapsed < 0.5 && !otherKeyPressed {
                    DispatchQueue.main.async {
                        InputSwitcher.toggle()
                    }
                }
                cmdDownTime = nil
                cmdKeyCode = nil

            } else if cmdDownTime != nil && !isCmd {
                // コマンドを押したまま別の修飾キーが押された
                otherKeyPressed = true
            }

        case .keyDown:
            // コマンドを押したまま通常キーが押された
            if cmdDownTime != nil {
                otherKeyPressed = true
            }

        default:
            break
        }
    }
}
