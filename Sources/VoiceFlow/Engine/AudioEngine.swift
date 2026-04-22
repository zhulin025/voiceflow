import Foundation
import AVFoundation
import Accelerate

/// Audio capture and recording engine for VoiceFlow
class AudioEngine: ObservableObject {
    private let engine = AVAudioEngine()
    private let mixer = AVAudioMixerNode()
    
    @Published var amplitude: Float = 0.0
    @Published var isRunning = false
    
    private let sampleCount = 1024
    private var audioFile: AVAudioFile?
    private let recordingURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("voiceflow_recording.m4a")
    
    init() {
        // No immediate setup to avoid premature mic permission prompts
    }
    
    private var isSetup = false
    private func setupEngine() {
        if isSetup { return }
        isSetup = true
        
        engine.attach(mixer)
        let input = engine.inputNode
        let format = input.inputFormat(forBus: 0)
        
        engine.connect(input, to: mixer, format: format)
        engine.connect(mixer, to: engine.mainMixerNode, format: format)
        
        mixer.outputVolume = 0.0
        
        input.installTap(onBus: 0, bufferSize: AVAudioFrameCount(sampleCount), format: format) { [weak self] buffer, _ in
            self?.analyze(buffer: buffer)
            self?.record(buffer: buffer)
        }
    }
    
    private func analyze(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frames = Int(buffer.frameLength)
        
        var rms: Float = 0.0
        vDSP_rmsqv(channelData, 1, &rms, vDSP_Length(frames))
        
        let level = min(1.0, max(0.0, rms * 15.0))
        
        DispatchQueue.main.async {
            if level > self.amplitude {
                self.amplitude = self.amplitude * 0.5 + level * 0.5
            } else {
                self.amplitude = self.amplitude * 0.8 + level * 0.2
            }
        }
    }
    
    /// 每个录音 buffer 的回调，供 CloudStreamingASR 订阅实时音频数据
    var onBuffer: ((AVAudioPCMBuffer) -> Void)?

    private func record(buffer: AVAudioPCMBuffer) {
        guard let audioFile = audioFile else { return }
        try? audioFile.write(from: buffer)
        onBuffer?(buffer)
    }
    
    func start() {
        setupEngine()
        
        // Prepare file for recording
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioFile = try AVAudioFile(forWriting: recordingURL, settings: settings)
            try engine.start()
            isRunning = true
        } catch {
            print("Failed to start audio engine/recording: \(error)")
        }
    }
    
    func stop() {
        engine.stop()
        if isSetup {
            engine.inputNode.removeTap(onBus: 0)
            isSetup = false // 重置状态，下次 start 重新安装 tap
        }
        audioFile = nil // Close file
        onBuffer = nil  // 清空回调，防止悬挂引用
        isRunning = false
        amplitude = 0
    }
    
    func getRecordingURL() -> URL {
        return recordingURL
    }
}
