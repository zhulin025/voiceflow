import AppKit
import SwiftUI
import Combine

/// A custom NSPanel that floats at the bottom of the screen.
class OverlayWindow: NSPanel {
    private var cancellables = Set<AnyCancellable>()
    
    // Base dimensions from OverlayView
    private let baseWidth: CGFloat = 410
    private let baseHeight: CGFloat = 110

    init(contentView: some View) {
        let scale = Configuration.shared.overlayScale
        let screen = NSScreen.main?.visibleFrame ?? .zero
        
        let width = baseWidth * CGFloat(scale)
        let height = baseHeight * CGFloat(scale)
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
        self.hasShadow = false
        self.ignoresMouseEvents = false
        self.isMovableByWindowBackground = true
        
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        self.contentView = hostingView
        
        setupScaleObserver()
    }
    
    private func setupScaleObserver() {
        Configuration.shared.$overlayScale
            .receive(on: RunLoop.main)
            .sink { [weak self] scale in
                self?.updateFrame(scale: scale)
            }
            .store(in: &cancellables)
    }
    
    private func updateFrame(scale: Double) {
        let screen = NSScreen.main?.visibleFrame ?? .zero
        let width = baseWidth * CGFloat(scale)
        let height = baseHeight * CGFloat(scale)
        
        let newX = (screen.width - width) / 2
        let newY = screen.minY + 40
        
        let newFrame = NSRect(x: newX, y: newY, width: width, height: height)
        self.setFrame(newFrame, display: true, animate: false)
    }
}
