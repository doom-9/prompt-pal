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

private final class CarbonHotKeyStorage: @unchecked Sendable {
    var hotKeyRef: EventHotKeyRef?
    var eventHandlerRef: EventHandlerRef?

    func unregisterHotKey() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }

    deinit {
        unregisterHotKey()
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }
    }
}

@MainActor
public final class HotKeyManager {
    private let storage = CarbonHotKeyStorage()
    private let onHotKeyPressed: @MainActor () -> Void

    private static let hotKeySignature: OSType = 0x5050414C // "PPAL"
    private static let hotKeyID: UInt32 = 1

    public init(onHotKeyPressed: @escaping @MainActor () -> Void) {
        self.onHotKeyPressed = onHotKeyPressed
    }

    @discardableResult
    public func register(_ config: HotKeyConfig) -> Result<Void, HotKeyError> {
        unregister()

        if storage.eventHandlerRef == nil {
            var eventType = EventTypeSpec(
                eventClass: OSType(kEventClassKeyboard),
                eventKind: UInt32(kEventHotKeyPressed)
            )
            let userData = Unmanaged.passUnretained(self).toOpaque()
            var handlerRef: EventHandlerRef?
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
                    guard status == noErr,
                          pressedID.signature == HotKeyManager.hotKeySignature,
                          pressedID.id == HotKeyManager.hotKeyID else {
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
                &handlerRef
            )
            if installStatus != noErr {
                return .failure(.eventHandlerInstallFailed(installStatus))
            }
            storage.eventHandlerRef = handlerRef
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
        storage.hotKeyRef = ref
        return .success(())
    }

    public func unregister() {
        storage.unregisterHotKey()
    }
}
