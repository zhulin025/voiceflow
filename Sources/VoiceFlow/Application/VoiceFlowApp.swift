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
            self?.toggleRecording()
        }
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name("ToggleVoiceFlowRecording"), object: nil, queue: .main) { [weak self] _ in
            self?.toggleRecording()
        }
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name("OpenVoiceFlowSettings"), object: nil, queue: .main) { [weak self] _ in
            self?.openSettingsManual()
        }
        
        // Check Accessibility Permissions
        recorder.isAccessibilityTrusted = TextInserter.checkPermissions()
        
        // Setup a timer to re-check if not trusted, so the UI updates automatically
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if !self.recorder.isAccessibilityTrusted {
                let trusted = TextInserter.checkPermissions()
                if trusted != self.recorder.isAccessibilityTrusted {
                    self.recorder.isAccessibilityTrusted = trusted
                }
            }
        }
    }
    
    private func toggleRecording() {
        if recorder.isRecording { stopRecording() } else { startRecording() }
    }
    
    private var lastInjectedPartial = ""

    private func startRecording() {
        lastInjectedPartial = ""

        recorder.isRecording = true
        recorder.transcript = "开始听..."
        audio.start()
        let mode = Configuration.shared.asrMode
        try? asr.startStreaming(audioEngine: audio, mode: mode) { [weak self] partial in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.recorder.transcript = partial
                // Using smart differential injection, pass both strings to TextInserter
                TextInserter.insertRealTime(partial, previous: self.lastInjectedPartial)
                self.lastInjectedPartial = partial
            }
        }
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
            recorder.transcript = "正在全量转写..."
            let fullTranscript = (try? await asr.transcribeFinal(audioURL: audioURL, mode: Configuration.shared.asrMode)) ?? ""

            if fullTranscript.isEmpty {
                recorder.transcript = "未识别到语音"
                return
            }

            if asrErrorPrefixes.contains(where: { fullTranscript.hasPrefix($0) }) {
                recorder.transcript = "⚠️ \(fullTranscript)"
                return
            }

            recorder.transcript = "大模型优化中..."
            let result = (try? await llm.process(fullTranscript, mode: recorder.selectedMode)) ?? fullTranscript

            DispatchQueue.main.async {
                self.recorder.transcript = result
                // Erase the streamed characters then insert the LLM-cleaned result.
                // This preserves any text that was in the field BEFORE this recording.
                TextInserter.finalInsert(result, replacing: streamedText)
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
