import AppKit
import Carbon

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var keyMonitor: KeyMonitor?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusBar()
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(updateStatusTitle),
            name: NSNotification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String),
            object: nil
        )

        keyMonitor = KeyMonitor()
        checkAndStartMonitor()
        updateStatusTitle()
    }

    private func checkAndStartMonitor() {
        if keyMonitor!.start() {
            updateStatusTitle()
        } else {
            // 権限がなければシステム設定を開いて、2秒ごとに再チェック
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
            Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] timer in
                guard let self else { timer.invalidate(); return }
                if self.keyMonitor!.start() {
                    timer.invalidate()
                    self.updateStatusTitle()
                }
            }
        }
    }

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "KeyboardTool を終了", action: #selector(quit), keyEquivalent: "q"))
        statusItem?.menu = menu
    }

    @objc private func updateStatusTitle() {
        DispatchQueue.main.async {
            self.statusItem?.button?.title = InputSwitcher.isJapanese() ? "日" : "英"
        }
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
