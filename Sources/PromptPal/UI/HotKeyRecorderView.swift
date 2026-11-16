import AppKit
import Carbon.HIToolbox
import PromptPalCore
import SwiftUI

struct HotKeyRecorderView: View {
    let config: HotKeyConfig
    let onChange: (HotKeyConfig) -> Void

    @State private var isRecording = false
    @State private var monitor: Any?

    var body: some View {
        Button {
            if isRecording {
                stopRecording()
            } else {
                startRecording()
            }
        } label: {
            Text(isRecording ? "请按下快捷键... (Esc 取消)" : config.displayString)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .frame(minWidth: 160)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
        }
        .buttonStyle(.bordered)
        .tint(isRecording ? .accentColor : .secondary)
        .onDisappear {
            stopRecording()
        }
    }

    private func startRecording() {
        stopRecording()
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if event.keyCode == UInt16(kVK_Escape), flags.isEmpty {
                stopRecording()
                return nil
            }
            let carbonMods = HotKeyConfig.carbonModifiers(from: flags)
            guard carbonMods != 0 else {
                NSSound.beep()
                return nil
            }
            let newConfig = HotKeyConfig(
                keyCode: UInt32(event.keyCode),
                carbonModifiers: carbonMods
            )
            stopRecording()
            onChange(newConfig)
            return nil
        }
    }

    private func stopRecording() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
        isRecording = false
    }
}
