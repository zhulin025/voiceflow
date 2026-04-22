import SwiftUI
import AppKit

@main
struct VoiceFlowApp: App {
    @StateObject private var config = Configuration.shared
    @StateObject private var recorder = RecorderState()
    
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            // This scene is still registered but we launch manually from the gear icon
            SettingsView()
                .environmentObject(recorder)
        }
    }
}

class RecorderState: ObservableObject {
    @Published var transcript: String = "等待录音..."
    @Published var isRecording: Bool = false
    @Published var selectedMode: LLMProcessor.Mode = .precise
    @Published var isAccessibilityTrusted: Bool = true
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var overlayWindow: OverlayWindow?
    var settingsWindow: NSWindow?
    
    var keyboardManager = KeyboardManager()
    var audio = AudioEngine()
    var recorder = RecorderState()
    var asr = ASREngine()
    var llm = LLMProcessor()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        let overlayView = OverlayView(audio: audio)
            .environmentObject(recorder)
        
        overlayWindow = OverlayWindow(contentView: overlayView)
        overlayWindow?.orderFrontRegardless()
        
        keyboardManager.onToggle = { [weak self] in
            Task { @MainActor in self?.toggleRecording() }
        }
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name("ToggleVoiceFlowRecording"), object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.toggleRecording() }
        }
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name("OpenVoiceFlowSettings"), object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.openSettingsManual() }
        }
        
        // Check Accessibility Permissions
        recorder.isAccessibilityTrusted = TextInserter.checkPermissions()
        
        // Setup a timer to re-check if not trusted, so the UI updates automatically
        // Setup a timer to re-check the trust status, so the UI updates automatically
        Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                let currentStatus = TextInserter.checkPermissions()
                if currentStatus != self.recorder.isAccessibilityTrusted {
                    self.recorder.isAccessibilityTrusted = currentStatus
                }
            }
        }
    }
    
    private func toggleRecording() {
        if recorder.isRecording { stopRecording() } else { startRecording() }
    }
    
    private var lastInjectedPartial = ""

    private func startRecording() {
        // Reset state
        lastInjectedPartial = ""
        
        recorder.transcript = "开始听..."
        audio.start()
        let config = Configuration.shared
        let mode = config.isAIEnabled ? config.asrMode : .builtIn
        try? asr.startStreaming(audioEngine: audio, mode: mode) { [weak self] partial in
            DispatchQueue.main.async {
                self?.recorder.transcript = partial
                
                // 关键修复：只有在非兼容模式下才尝试实时注入，并记录已注入内容
                if !TextInserter.isCompatibilityMode() {
                    TextInserter.insertRealTime(partial, previous: self?.lastInjectedPartial ?? "")
                    self?.lastInjectedPartial = partial
                }
            }
        }
        recorder.isRecording = true
    }
    
    // 已知 ASR 失败时的返回前缀
    private let asrErrorPrefixes = [
        "远程识别失败", "本地识别出错", "Qwen3-ASR 未安装",
        "请先配置 ASR", "ASR Endpoint", "ASR 不可用"
    ]

    private func stopRecording() {
        // Snapshot what streaming injected so we can replace it with the clean LLM result.
        let streamedText = lastInjectedPartial

        recorder.isRecording = false
        audio.stop()
        asr.stopStreaming()

        let audioURL = audio.getRecordingURL()

        Task {
            let config = Configuration.shared
            let finalTranscript = (try? await asr.transcribeFinal(audioURL: audioURL, mode: config.isAIEnabled ? config.asrMode : .builtIn)) ?? ""

            if finalTranscript.isEmpty {
                recorder.transcript = "未识别到语音"
                return
            }

            if asrErrorPrefixes.contains(where: { finalTranscript.hasPrefix($0) }) {
                recorder.transcript = "⚠️ \(finalTranscript)"
                return
            }

            let result: String
            if config.isAIEnabled {
                recorder.transcript = "大模型优化中..."
                result = (try? await llm.process(finalTranscript, mode: recorder.selectedMode)) ?? finalTranscript
            } else {
                result = finalTranscript
            }

            DispatchQueue.main.async {
                self.recorder.transcript = result
                
                // 优化：修复关闭 AI 时的重复输入问题
                // 1. 如果开启了 AI，必须执行 finalInsert（因为需要用 LLM 优化后的结果替换流式识别的草稿）
                // 2. 如果关闭了 AI，则仅在“流式输出为空”时执行（例如在 Warp/VSCode 等不支持实时输出的应用中）
                //    如果在 Antigravity/备忘录等支持实时输出的应用中，且已经有内容了，则不再重复插入
                if config.isAIEnabled || streamedText.isEmpty {
                    TextInserter.finalInsert(result, replacing: streamedText)
                }
            }
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if !self.recorder.isRecording { self.recorder.transcript = "等待录音..." }
        }
    }
    
    func openSettingsManual() {
        if let window = settingsWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        // Create a borderless Glass Settings Window
        let settingsView = SettingsView().environmentObject(recorder)
        let hostingView = NSHostingView(rootView: settingsView)
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 480),
            styleMask: [.titled, .fullSizeContentView, .closable],
            backing: .buffered,
            defer: false
        )
        
        window.center()
        window.title = "VoiceFlow 设置"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        
        window.isReleasedWhenClosed = false
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.level = .floating
        window.contentView = hostingView
        window.isMovableByWindowBackground = true
        window.canHide = false
        
        self.settingsWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
