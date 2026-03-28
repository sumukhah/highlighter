import AppKit
import Carbon

@MainActor
final class HotKeyController {
    var onTrigger: (() -> Void)?

    private var hotKeyReference: EventHotKeyRef?
    private var eventHandlerReference: EventHandlerRef?
    private let hotKeySignature: OSType = 0x484C5452
    private let hotKeyIdentifier: UInt32 = 1

    init() {
        installEventHandler()
    }

    func updateRegistration(with configuration: HotKeyConfiguration) {
        unregisterCurrentHotKey()

        let hotKeyID = EventHotKeyID(signature: hotKeySignature, id: hotKeyIdentifier)
        RegisterEventHotKey(
            configuration.keyCode,
            carbonFlags(from: configuration.modifiers),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyReference
        )
    }

    private func installEventHandler() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else { return noErr }

                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )

                guard status == noErr else { return status }

                let controller = Unmanaged<HotKeyController>.fromOpaque(userData).takeUnretainedValue()

                if hotKeyID.signature == controller.hotKeySignature, hotKeyID.id == controller.hotKeyIdentifier {
                    Task { @MainActor in
                        controller.onTrigger?()
                    }
                    return noErr
                }

                return OSStatus(eventNotHandledErr)
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandlerReference
        )
    }

    private func unregisterCurrentHotKey() {
        if let hotKeyReference {
            UnregisterEventHotKey(hotKeyReference)
            self.hotKeyReference = nil
        }
    }

    private func carbonFlags(from modifiers: NSEvent.ModifierFlags) -> UInt32 {
        var flags: UInt32 = 0

        if modifiers.contains(.command) { flags |= UInt32(cmdKey) }
        if modifiers.contains(.shift) { flags |= UInt32(shiftKey) }
        if modifiers.contains(.option) { flags |= UInt32(optionKey) }
        if modifiers.contains(.control) { flags |= UInt32(controlKey) }

        return flags
    }
}
