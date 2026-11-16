import Carbon.HIToolbox
import Foundation

public enum HotKeyError: Error, LocalizedError {
    case eventHandlerInstallFailed(OSStatus)
    case registrationFailed(OSStatus)

    public var errorDescription: String? {
        switch self {
        case .eventHandlerInstallFailed(let status):
            return "无法安装全局快捷键监听器 (OSStatus: \(status))"
        case .registrationFailed(let status):
            return "快捷键注册失败，可能与系统或其他应用冲突 (OSStatus: \(status))"
        }
    }
}

@MainActor
public final class HotKeyManager {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private let onHotKeyPressed: @MainActor () -> Void

    private static let hotKeySignature: OSType = 0x5050414C // "PPAL"
    private static let hotKeyID: UInt32 = 1

    public init(onHotKeyPressed: @escaping @MainActor () -> Void) {
        self.onHotKeyPressed = onHotKeyPressed
    }

    @discardableResult
    public func register(_ config: HotKeyConfig) -> Result<Void, HotKeyError> {
        unregister()

        if eventHandlerRef == nil {
            var eventType = EventTypeSpec(
                eventClass: OSType(kEventClassKeyboard),
                eventKind: UInt32(kEventHotKeyPressed)
            )
            let userData = Unmanaged.passUnretained(self).toOpaque()
            let installStatus = InstallEventHandler(
                GetApplicationEventTarget(),
                { _, event, userData -> OSStatus in
                    guard let event, let userData else { return OSStatus(eventNotHandledErr) }
                    var pressedID = EventHotKeyID()
                    let status = GetEventParameter(
                        event,
                        EventParamName(kEventParamDirectObject),
                        EventParamType(typeEventHotKeyID),
                        nil,
                        MemoryLayout<EventHotKeyID>.size,
                        nil,
                        &pressedID
                    )
                    guard status == noErr, pressedID.id == HotKeyManager.hotKeyID else {
                        return OSStatus(eventNotHandledErr)
                    }
                    let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
                    Task { @MainActor in
                        manager.onHotKeyPressed()
                    }
                    return noErr
                },
                1,
                &eventType,
                userData,
                &eventHandlerRef
            )
            if installStatus != noErr {
                return .failure(.eventHandlerInstallFailed(installStatus))
            }
        }

        let id = EventHotKeyID(signature: Self.hotKeySignature, id: Self.hotKeyID)
        var ref: EventHotKeyRef?
        let regStatus = RegisterEventHotKey(
            config.keyCode,
            config.carbonModifiers,
            id,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        guard regStatus == noErr, let ref else {
            return .failure(.registrationFailed(regStatus))
        }
        hotKeyRef = ref
        return .success(())
    }

    public func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }
}
