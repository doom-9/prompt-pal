import AppKit
import Carbon.HIToolbox
import PromptPalCore
import SwiftUI

private final class PickerPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
public final class FloatingPanelController: NSObject, NSWindowDelegate {
    private let store: PromptStore
    private let viewModel = PickerViewModel()
    private let onOpenManagement: () -> Void
    private let onCreateNewPrompt: () -> Void

    private var panel: PickerPanel?
    private var keyMonitor: Any?

    public init(
        store: PromptStore,
        onOpenManagement: @escaping () -> Void,
        onCreateNewPrompt: @escaping () -> Void
    ) {
        self.store = store
        self.onOpenManagement = onOpenManagement
        self.onCreateNewPrompt = onCreateNewPrompt
        super.init()
    }

    public func toggle() {
        if let panel, panel.isVisible {
            hide()
        } else {
            show()
        }
    }

    public func show() {
        let panel = ensurePanel()
        viewModel.reset()
        positionOnActiveScreen(panel)

        // The nonactivating panel takes keyboard focus without deactivating the current app.
        panel.makeKeyAndOrderFront(nil)
        installKeyMonitor()
    }

    private func hide() {
        removeKeyMonitor()
        panel?.orderOut(nil)
    }

    public func windowDidResignKey(_ notification: Notification) {
        hide()
    }

    private func ensurePanel() -> PickerPanel {
        if let panel { return panel }

        let width: CGFloat = 620
        let height: CGFloat = 420
        let panel = PickerPanel(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.delegate = self

        let visualEffect = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        visualEffect.material = .hudWindow
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 12
        visualEffect.layer?.masksToBounds = true
        visualEffect.autoresizingMask = [.width, .height]

        let pickerView = PickerView(
            store: store,
            viewModel: viewModel,
            onSelect: { [weak self] item in
                self?.copyAndDismiss(item)
            },
            onOpenManagement: { [weak self] in
                self?.hide()
                self?.onOpenManagement()
            },
            onCreateNew: { [weak self] in
                self?.hide()
                self?.onCreateNewPrompt()
            }
        )
        let hostingView = NSHostingView(rootView: pickerView)
        hostingView.frame = visualEffect.bounds
        hostingView.autoresizingMask = [.width, .height]
        visualEffect.addSubview(hostingView)

        panel.contentView = visualEffect
        self.panel = panel
        return panel
    }

    private func positionOnActiveScreen(_ panel: NSPanel) {
        let mouseLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) ?? NSScreen.main
        guard let visibleFrame = screen?.visibleFrame else {
            panel.center()
            return
        }
        let x = visibleFrame.midX - panel.frame.width / 2
        let y = visibleFrame.midY - panel.frame.height / 2 + visibleFrame.height * 0.1
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func copyAndDismiss(_ item: PromptItem) {
        ClipboardService.copy(item.content)
        store.recordUsage(id: item.id)
        hide()
    }

    private func installKeyMonitor() {
        removeKeyMonitor()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.panel?.isVisible == true else { return event }
            return self.handleKeyDown(event) ? nil : event
        }
    }

    private func removeKeyMonitor() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
    }

    private func handleKeyDown(_ event: NSEvent) -> Bool {
        if let inputClient = panel?.firstResponder as? NSTextInputClient, inputClient.hasMarkedText() {
            return false
        }

        let items = store.filteredPrompts(query: viewModel.query)
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        if modifiers == .command {
            let quickSlotKeyCodes: [UInt16] = [
                UInt16(kVK_ANSI_1),
                UInt16(kVK_ANSI_2),
                UInt16(kVK_ANSI_3),
                UInt16(kVK_ANSI_4),
                UInt16(kVK_ANSI_5)
            ]
            if let slotIndex = quickSlotKeyCodes.firstIndex(of: event.keyCode) {
                if slotIndex < items.count {
                    copyAndDismiss(items[slotIndex])
                }
                return true
            }
            if event.keyCode == UInt16(kVK_ANSI_N) {
                hide()
                onCreateNewPrompt()
                return true
            }
            if event.keyCode == UInt16(kVK_ANSI_Comma) {
                hide()
                onOpenManagement()
                return true
            }
        }

        switch Int(event.keyCode) {
        case kVK_Escape:
            hide()
            return true
        case kVK_DownArrow:
            viewModel.moveSelection(delta: 1, count: items.count)
            return true
        case kVK_UpArrow:
            viewModel.moveSelection(delta: -1, count: items.count)
            return true
        case kVK_Return, kVK_ANSI_KeypadEnter:
            if !items.isEmpty {
                let index = min(max(viewModel.selectedIndex, 0), items.count - 1)
                copyAndDismiss(items[index])
            }
            return true
        default:
            return false
        }
    }
}
