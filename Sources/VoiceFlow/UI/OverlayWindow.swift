import AppKit
import SwiftUI

/// A custom NSPanel that floats at the bottom of the screen.
class OverlayWindow: NSPanel {
    init(contentView: some View) {
        let screen = NSScreen.main?.visibleFrame ?? .zero
        
        let width: CGFloat = 380
        let height: CGFloat = 120
        let rect = NSRect(
            x: (screen.width - width) / 2,
            y: screen.minY + 40,
            width: width,
            height: height
        )
        
        super.init(
            contentRect: rect,
            styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        // Deep Transparency Fixes
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .stationary]
        self.backgroundColor = NSColor.clear
        self.isOpaque = false
        self.hasShadow = false // Disable native shadow to avoid "grey rectangle" ghosting
        self.ignoresMouseEvents = false
        self.isMovableByWindowBackground = true // User can move the bar, but it's clear
        
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        self.contentView = hostingView
    }
}
