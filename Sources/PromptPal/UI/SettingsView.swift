import PromptPalCore
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    let hotKeyManager: HotKeyManager

    @State private var currentHotKey: HotKeyConfig = HotKeyConfig.load()
    @State private var hotKeyError: String?
    @State private var launchAtLogin: Bool = SMAppService.mainApp.status == .enabled
    @State private var launchError: String?

    var body: some View {
        Form {
            Section("全局快捷键") {
                HStack {
                    Text("呼出快速选择面板")
                    Spacer()
                    HotKeyRecorderView(config: currentHotKey) { newConfig in
                        applyHotKey(newConfig)
                    }
                    Button("恢复默认") {
                        applyHotKey(.defaultHotKey)
                    }
                    .disabled(currentHotKey == .defaultHotKey)
                }

                if let hotKeyError {
                    Text(hotKeyError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section("启动") {
                Toggle("开机自动启动", isOn: Binding(
                    get: { launchAtLogin },
                    set: { setLaunchAtLogin($0) }
                ))

                if let launchError {
                    Text(launchError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section("存储位置") {
                Text(PromptStore.defaultFileURL().path)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func applyHotKey(_ newConfig: HotKeyConfig) {
        switch hotKeyManager.register(newConfig) {
        case .success:
            newConfig.save()
            currentHotKey = newConfig
            hotKeyError = nil
        case .failure(let error):
            hotKeyError = error.localizedDescription
            _ = hotKeyManager.register(currentHotKey)
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchAtLogin = SMAppService.mainApp.status == .enabled
            launchError = nil
        } catch {
            launchAtLogin = SMAppService.mainApp.status == .enabled
            launchError = "设置开机启动失败（打包为 .app 后生效）：\(error.localizedDescription)"
        }
    }
}
