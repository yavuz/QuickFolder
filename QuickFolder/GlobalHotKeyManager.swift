import Carbon
import Foundation

final class GlobalHotKeyManager {
    var onHotKey: (@MainActor () -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var eventHandler: EventHandlerUPP?
    private let signature = OSType("QFHK".fourCharCode)

    init() {
        installEventHandler()
    }

    deinit {
        unregister()
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }
    }

    func register(_ config: HotKeyConfig) -> OSStatus {
        unregister()

        guard let keyCode = config.keyCode else {
            return OSStatus(eventHotKeyInvalidErr)
        }

        let hotKeyID = EventHotKeyID(signature: signature, id: 1)
        return RegisterEventHotKey(
            keyCode,
            config.carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }

    private func installEventHandler() {
        eventHandler = { _, _, userData in
            guard let userData else { return noErr }
            let manager = Unmanaged<GlobalHotKeyManager>.fromOpaque(userData).takeUnretainedValue()

            Task { @MainActor in
                manager.onHotKey?()
            }

            return noErr
        }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        InstallEventHandler(
            GetApplicationEventTarget(),
            eventHandler,
            1,
            &eventType,
            UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
            &eventHandlerRef
        )
    }
}

private extension String {
    var fourCharCode: FourCharCode {
        unicodeScalars.reduce(0) { result, scalar in
            (result << 8) + FourCharCode(scalar.value)
        }
    }
}
