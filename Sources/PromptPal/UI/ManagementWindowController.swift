import AppKit
import PromptPalCore
import SwiftUI

@MainActor
public final class ManagementWindowController {
    private let store: PromptStore
    private let hotKeyManager: HotKeyManager
    private let navState = ManagementNavigationState()
    private var window: NSWindow?

    public init(store: PromptStore, hotKeyManager: HotKeyManager) {
        self.store = store
        self.hotKeyManager = hotKeyManager
    }

    public func show(initialTab: ManagementTab = .prompts, createNew: Bool = false) {
        navState.selectedTab = initialTab
        if createNew {
            let created = store.addPrompt(title: "", content: "")
            navState.selectedPromptID = created.id
        } else if navState.selectedPromptID == nil {
            navState.selectedPromptID = store.prompts.first?.id
        }

        let window = ensureWindow()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func ensureWindow() -> NSWindow {
        if let window { return window }

        let view = ManagementView(
            store: store,
            hotKeyManager: hotKeyManager,
            navState: navState
        )
        let hostingController = NSHostingController(rootView: view)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "PromptPal 管理"
        window.setContentSize(NSSize(width: 780, height: 520))
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.isReleasedWhenClosed = false
        window.center()
        self.window = window
        return window
    }
}
