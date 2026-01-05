import Foundation
import Carbon
import AppKit

/// Service for registering and handling global hotkeys using Carbon API
final class HotkeyService {
    static let shared = HotkeyService()
    
    private var hotkeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var hotkeyCallback: (() -> Void)?
    
    /// Hotkey signature for identification
    private let hotkeySignature: OSType = {
        let chars = "STKS".utf8
        var result: OSType = 0
        for char in chars {
            result = (result << 8) | OSType(char)
        }
        return result
    }()
    
    private let hotkeyID: UInt32 = 1
    
    private init() {}
    
    deinit {
        unregisterHotkey()
    }
    
    /// Register the global hotkey (Option + Command + P)
    /// - Parameter callback: The closure to call when hotkey is pressed
    func registerHotkey(callback: @escaping () -> Void) {
        self.hotkeyCallback = callback
        
        // Unregister existing hotkey if any
        unregisterHotkey()
        
        // Define the hotkey: Option + Command + P
        // Key code for 'P' is 35
        let keyCode: UInt32 = 35
        let modifiers: UInt32 = UInt32(optionKey | cmdKey)
        
        // Create hotkey ID
        let hotKeyID = EventHotKeyID(signature: hotkeySignature, id: hotkeyID)
        
        // Install event handler
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        
        let handlerResult = InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, event, userData) -> OSStatus in
                guard let userData = userData else { return OSStatus(eventNotHandledErr) }
                
                let service = Unmanaged<HotkeyService>.fromOpaque(userData).takeUnretainedValue()
                
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
                
                if status == noErr && hotKeyID.id == service.hotkeyID {
                    DispatchQueue.main.async {
                        service.hotkeyCallback?()
                    }
                }
                
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )
        
        guard handlerResult == noErr else {
            print("Failed to install event handler: \(handlerResult)")
            return
        }
        
        // Register the hotkey
        let registerResult = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotkeyRef
        )
        
        if registerResult != noErr {
            print("Failed to register hotkey: \(registerResult)")
        }
    }
    
    /// Unregister the global hotkey
    func unregisterHotkey() {
        if let hotkeyRef = hotkeyRef {
            UnregisterEventHotKey(hotkeyRef)
            self.hotkeyRef = nil
        }
        
        if let eventHandler = eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
    }
}

