import AppKit
import PromptPalCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var store: PromptStore!
    private var hotKeyManager: HotKeyManager!
    private var floatingPanelController: FloatingPanelController!
    private var managementWindowController: ManagementWindowController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        store = PromptStore()
        hotKeyManager = HotKeyManager { [weak self] in
            self?.floatingPanelController.toggle()
        }
        managementWindowController = ManagementWindowController(
            store: store,
            hotKeyManager: hotKeyManager
        )
        floatingPanelController = FloatingPanelController(
            store: store,
            onOpenManagement: { [weak self] in
                self?.managementWindowController.show(initialTab: .prompts, createNew: false)
            },
            onCreateNewPrompt: { [weak self] in
                self?.managementWindowController.show(initialTab: .prompts, createNew: true)
            }
        )

        setupStatusItem()

        let config = HotKeyConfig.load()
        if case .failure(let error) = hotKeyManager.register(config) {
            let alert = NSAlert()
            alert.messageText = "全局快捷键注册失败"
            alert.informativeText = "\(error.localizedDescription)\n请打开「偏好设置」重新设置快捷键。"
            alert.alertStyle = .warning
            alert.runModal()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotKeyManager?.unregister()
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            let image = NSImage(systemSymbolName: "text.quote", accessibilityDescription: "PromptPal")
            image?.isTemplate = true
            button.image = image
            button.toolTip = "PromptPal (\(HotKeyConfig.load().displayString))"
        }

        let menu = NSMenu()
        let openPicker = NSMenuItem(
            title: "打开快速选择",
            action: #selector(togglePicker),
            keyEquivalent: ""
        )
        openPicker.target = self

        let manageItem = NSMenuItem(
            title: "管理 Prompt...",
            action: #selector(openManagement),
            keyEquivalent: ","
        )
        manageItem.target = self

        let newItem = NSMenuItem(
            title: "新建 Prompt...",
            action: #selector(createNewPrompt),
            keyEquivalent: "n"
        )
        newItem.target = self

        let settingsItem = NSMenuItem(
            title: "偏好设置...",
            action: #selector(openSettings),
            keyEquivalent: ""
        )
        settingsItem.target = self

        let quitItem = NSMenuItem(
            title: "退出 PromptPal",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self

        menu.addItem(openPicker)
        menu.addItem(.separator())
        menu.addItem(manageItem)
        menu.addItem(newItem)
        menu.addItem(settingsItem)
        menu.addItem(.separator())
        menu.addItem(quitItem)

        item.menu = menu
        statusItem = item
    }

    @objc private func togglePicker() {
        floatingPanelController.toggle()
    }

    @objc private func openManagement() {
        managementWindowController.show(initialTab: .prompts, createNew: false)
    }

    @objc private func createNewPrompt() {
        managementWindowController.show(initialTab: .prompts, createNew: true)
    }

    @objc private func openSettings() {
        managementWindowController.show(initialTab: .settings, createNew: false)
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
