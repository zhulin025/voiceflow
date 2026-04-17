import AppKit
import Carbon

/// Global hotkey manager.
/// Captures Command + Shift + Space to toggle recording.
class KeyboardManager: ObservableObject {
    private var eventMonitor: Any?
    var onToggle: (() -> Void)?
    
    init() {
        setupGlobalMonitor()
    }
    
    private func setupGlobalMonitor() {
        // We use Command + Shift + Space as the global toggle
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.modifierFlags.contains([.command, .shift]), event.keyCode == 49 { // 49 is Space
                DispatchQueue.main.async {
                    self?.onToggle?()
                }
            }
        }
    }
    
    deinit {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}
