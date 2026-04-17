import AppKit

/// Utility to insert text into the currently active application.
/// Improved version with target-element snapshotting and smart application compatibility.
struct TextInserter {
    
    private static let compatibilityBlacklist = [
        "dev.warp.Warp-Stable",
        "com.microsoft.VSCode",
        "com.googlecode.iterm2",
        "com.sublimetext.4",
        "com.visualstudio.code.oss"
    ]
    
    static func getFocusedElement() -> AXUIElement? {
        let systemWideElement = AXUIElementCreateSystemWide()
        var focusedElement: AnyObject?
        let result = AXUIElementCopyAttributeValue(systemWideElement, kAXFocusedUIElementAttribute as CFString, &focusedElement)
        
        guard result == .success else { return nil }
        return (focusedElement as! AXUIElement)
    }

    /// Final injection after LLM processing.
    /// Erases the streaming text character-by-character, then appends the clean result.
    /// This preserves any pre-existing text in the field (from before the recording started).
    static func finalInsert(_ result: String, replacing original: String) {
        let element = getFocusedElement()

        // 1. If the final LLM result is identical to the streamed text, we do nothing!
        // The streamed text is already perfectly typed on the screen.
        let cleanResult = result.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanOriginal = original.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanResult == cleanOriginal {
            return
        }

        // 2. Erase the streamed intermediate characters
        let originalCharsCount = Array(original).count
        if originalCharsCount > 0 {
            sendBackspaces(count: originalCharsCount)
        }

        // 3. Inject the final result
        if let el = element, let bundleID = getBundleID(for: el) {
            if compatibilityBlacklist.contains(bundleID) {
                insertViaPasteboard(result, target: el)
                return
            }
        }
        
        // We only use selected text replacement (or typing) now to avoid clearing entire documents
        if insertViaAccessibility(result, mode: .appendOnly, into: element) {
            return
        }
        
        insertViaPasteboard(result, target: element)
    }

    static func insert(_ text: String, into target: AXUIElement? = nil) {
        let element = target ?? getFocusedElement()
        
        if let el = element, let bundleID = getBundleID(for: el) {
            if compatibilityBlacklist.contains(bundleID) {
                insertViaPasteboard(text, target: el)
                return
            }
        }
        
        if insertViaAccessibility(text, into: element) {
            return
        }
        
        insertViaPasteboard(text, target: element)
    }
    
    /// REAL-TIME streaming injection — smart differential injection.
    static func insertRealTime(_ text: String, previous: String) {
        let element = getFocusedElement()
        if let el = element, let bundleID = getBundleID(for: el),
           compatibilityBlacklist.contains(bundleID) { return }

        // Trim leading spaces from both to prevent anomalous zero-prefix matches
        let cleanText = text.trimmingCharacters(in: .whitespaces)
        let cleanPrev = previous.trimmingCharacters(in: .whitespaces)

        var commonPrefixLength = 0
        let textChars = Array(cleanText)
        let prevChars = Array(cleanPrev)
        let minLength = min(textChars.count, prevChars.count)

        for i in 0..<minLength {
            if textChars[i] == prevChars[i] {
                commonPrefixLength += 1
            } else {
                break
            }
        }

        let backspacesNeeded = prevChars.count - commonPrefixLength
        let delta = String(textChars.dropFirst(commonPrefixLength))

        // Safeguard: If ASR glitch causes a complete mismatch, don't delete everything.
        // Just append the difference to avoid destroying user's work.
        if backspacesNeeded > 0 {
            if backspacesNeeded >= prevChars.count && prevChars.count > 0 {
                // Total mismatch! (e.g., ASR task restarted and generated completely different string)
                // Fallback to purely appending
                let safeDelta = cleanText.count > cleanPrev.count ? String(textChars.dropFirst(cleanPrev.count)) : cleanText
                if !safeDelta.isEmpty {
                    sendKeystrokes(safeDelta)
                }
                return
            } else {
                sendBackspaces(count: backspacesNeeded)
            }
        }

        if !delta.isEmpty {
            sendKeystrokes(delta)
        }
    }
    
    private enum InjectionMode {
        case fullReplace
        case appendOnly
    }
    
    private static func getBundleID(for element: AXUIElement) -> String? {
        var pid: pid_t = 0
        let result = AXUIElementGetPid(element, &pid)
        guard result == .success else { return nil }
        
        let app = NSRunningApplication(processIdentifier: pid)
        return app?.bundleIdentifier
    }
    
    private static func insertViaAccessibility(_ text: String, mode: InjectionMode = .fullReplace, into element: AXUIElement?) -> Bool {
        guard let element = element else { return false }
        
        if mode == .fullReplace {
            let valueResult = AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, text as CFTypeRef)
            if valueResult == .success { return true }
        }
        
        // Strategy B: Replace selected text (or insert at cursor)
        let selectedResult = AXUIElementSetAttributeValue(element, kAXSelectedTextAttribute as CFString, text as CFTypeRef)
        return selectedResult == .success
    }
    
    /// Sends a sequence of backspaces to the current application.
    private static func sendBackspaces(count: Int) {
        guard count > 0 else { return }
        let source = CGEventSource(stateID: .combinedSessionState)
        // Allow up to 3000 backspaces for long dictated paragraphs
        let safeCount = min(count, 3000)
        for _ in 0..<safeCount {
            let bDown = CGEvent(keyboardEventSource: source, virtualKey: 0x33, keyDown: true)
            let bUp   = CGEvent(keyboardEventSource: source, virtualKey: 0x33, keyDown: false)
            bDown?.post(tap: .cgAnnotatedSessionEventTap)
            bUp?.post(tap: .cgAnnotatedSessionEventTap)
        }
    }

    /// Simulates Unicode keystrokes character by character via CGEvent.
    /// Works in any app that accepts keyboard input, including Electron/web-based editors
    /// (e.g. Antigravity) that block AX attribute injection.
    private static func sendKeystrokes(_ text: String) {
        guard !text.isEmpty else { return }
        let source = CGEventSource(stateID: .combinedSessionState)
        for scalar in text.unicodeScalars {
            guard scalar.value <= 0xFFFF else { continue }
            var uni = UniChar(scalar.value)
            if let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true) {
                down.keyboardSetUnicodeString(stringLength: 1, unicodeString: &uni)
                down.post(tap: .cgAnnotatedSessionEventTap)
            }
            if let up = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) {
                up.keyboardSetUnicodeString(stringLength: 1, unicodeString: &uni)
                up.post(tap: .cgAnnotatedSessionEventTap)
            }
        }
    }
    
    private static func insertViaPasteboard(_ text: String, target: AXUIElement?) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        
        if let targetElement = target {
            var pid: pid_t = 0
            if AXUIElementGetPid(targetElement, &pid) == .success {
                let app = NSRunningApplication(processIdentifier: pid)
                app?.activate(options: .activateIgnoringOtherApps)
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            let source = CGEventSource(stateID: .combinedSessionState)
            let vDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
            vDown?.flags = .maskCommand
            let vUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
            vUp?.flags = .maskCommand
            
            vDown?.post(tap: .cgAnnotatedSessionEventTap)
            vUp?.post(tap: .cgAnnotatedSessionEventTap)
        }
    }
    
    static func checkPermissions() -> Bool {
        return AXIsProcessTrusted()
    }
    
    static func requestPermissions() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
}
