import Carbon.HIToolbox
import Foundation

private func hotKeyHandler(
    _ nextHandler: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    let passToNext: () -> OSStatus = {
        if let nextHandler {
            return CallNextEventHandler(nextHandler, event)
        }
        return OSStatus(eventNotHandledErr)
    }

    guard let userData else {
        return passToNext()
    }

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

    guard status == noErr else {
        return passToNext()
    }

    let manager = Unmanaged<GlobalHotKeyManager>.fromOpaque(userData).takeUnretainedValue()
    guard manager.matches(hotKeyID: hotKeyID) else {
        return passToNext()
    }

    manager.onTrigger?()
    return noErr
}

final class GlobalHotKeyManager {
    var onTrigger: (() -> Void)?

    private let hotKeySignature: OSType
    private let hotKeyIdentifier: UInt32
    private var eventHandlerRef: EventHandlerRef?
    private var hotKeyRef: EventHotKeyRef?
    private var registeredHotKeyID: EventHotKeyID?
    private var registeredShortcut: HotKeyShortcut?
    private(set) var isSuspendedForMenu = false

    init(
        signature: OSType = 0x43425048, // "CBPH"
        identifier: UInt32 = 1
    ) {
        self.hotKeySignature = signature
        self.hotKeyIdentifier = identifier
    }

    @discardableResult
    func register(shortcut: HotKeyShortcut) -> Bool {
        unregister()

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let userData = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        let handlerStatus = InstallEventHandler(
            // Use the dispatcher for normal global delivery; menu tracking uses
            // local key events while these registrations are suspended.
            GetEventDispatcherTarget(),
            hotKeyHandler,
            1,
            &eventType,
            userData,
            &eventHandlerRef
        )
        if handlerStatus != noErr {
            NSLog("ClipPin failed to install hotkey handler: \(handlerStatus)")
            return false
        }

        let hotKeyID = EventHotKeyID(signature: hotKeySignature, id: hotKeyIdentifier)
        registeredHotKeyID = hotKeyID
        registeredShortcut = shortcut
        if isSuspendedForMenu { return true }
        let hotkeyStatus = RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.modifiers,
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &hotKeyRef
        )
        if hotkeyStatus != noErr {
            NSLog("ClipPin failed to register global hotkey: \(hotkeyStatus)")
            unregister()
            return false
        }

        return true
    }

    func setSuspendedForMenu(_ suspended: Bool) {
        guard suspended != isSuspendedForMenu else { return }
        isSuspendedForMenu = suspended
        if suspended {
            if let hotKeyRef { UnregisterEventHotKey(hotKeyRef); self.hotKeyRef = nil }
        } else if let shortcut = registeredShortcut, let id = registeredHotKeyID {
            let status = RegisterEventHotKey(shortcut.keyCode, shortcut.modifiers, id,
                GetEventDispatcherTarget(), 0, &hotKeyRef)
            if status != noErr { NSLog("ClipPin failed to resume hotkey: \(status)") }
        }
    }

    deinit {
        unregister()
    }

    fileprivate func matches(hotKeyID: EventHotKeyID) -> Bool {
        guard let registeredHotKeyID else {
            return false
        }
        return hotKeyID.signature == registeredHotKeyID.signature
            && hotKeyID.id == registeredHotKeyID.id
    }

    private func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }

        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
        }

        registeredHotKeyID = nil
        registeredShortcut = nil
    }
}
