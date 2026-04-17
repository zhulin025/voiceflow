import Foundation
import Speech
import AVFoundation

/// The 3-tier ASR strategy manager
class ASREngine: ObservableObject {
    enum Mode: String, CaseIterable {
        case builtIn = "原生模式 (Apple)"
        case cloud = "云端模式 (API)"
    }
    
    private let nativeRecognizer = AppleNativeASR()
    private var cloudStreamer: CloudStreamingASR?

    /// 启动实时流式识别
    /// - 云端模式：每 3 秒将音频块发给 API，支持中英混合，无时长限制
    /// - 原生模式：Apple 原生流式
    func startStreaming(audioEngine: AudioEngine? = nil, mode: Mode = .builtIn, onResult: @escaping (String) -> Void) throws {
        switch mode {
        case .cloud:
            guard let engine = audioEngine else { break }
            let endpoint = Configuration.shared.asrEndpoint
            guard !endpoint.isEmpty else { break }
            let streamer = CloudStreamingASR()
            cloudStreamer = streamer
            streamer.start(audioEngine: engine, endpoint: endpoint, onResult: onResult)
            return
        case .builtIn:
            break
        }
        try nativeRecognizer.start(onResult: onResult)
    }

    func stopStreaming() {
        nativeRecognizer.stop()
        cloudStreamer?.stop()
        cloudStreamer = nil
    }
    
    // Final transcription (used when recording stops) - CRITICAL for integrity
    func transcribeFinal(audioURL: URL, mode: Mode) async throws -> String {
        switch mode {
        case .builtIn:
            // 优先尝试文件全量转写（短录音更准确）
            let fileResult = (try? await nativeRecognizer.transcribeFile(audioURL: audioURL)) ?? ""
            let streamedText = nativeRecognizer.lastStreamedText.trimmingCharacters(in: .whitespaces)
            // 取内容更长的结果（文件转写有 ~1 分钟限制，长录音应使用流式累积文本）
            if fileResult.count >= streamedText.count && !fileResult.isEmpty {
                return fileResult
            }
            return streamedText.isEmpty ? fileResult : streamedText
        case .cloud:
            return try await transcribeRemote(audioURL: audioURL)
        }
    }

    private func transcribeRemote(audioURL: URL,
                                  endpointOverride: String? = nil,
                                  keyOverride: String? = nil,
                                  modelOverride: String? = nil) async throws -> String {
        let config = Configuration.shared
        let endpoint = endpointOverride ?? config.asrEndpoint
        let key = keyOverride ?? config.asrKey
        let model = modelOverride ?? config.asrModel

        // 本地服务器不需要 key，云端才需要
        if endpointOverride == nil && key.isEmpty { return "请先配置 ASR API Key" }
        guard let endpointURL = URL(string: endpoint), !endpoint.isEmpty else { return "ASR Endpoint 地址无效" }

        var request = URLRequest(url: endpointURL)
        request.httpMethod = "POST"
        if !key.isEmpty {
            request.addValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        }

        let boundary = "VoiceFlow-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        func formField(_ name: String, _ value: String) -> Data {
            var d = Data()
            d.append("--\(boundary)\r\n".data(using: .utf8)!)
            d.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            d.append(value.data(using: .utf8)!)
            d.append("\r\n".data(using: .utf8)!)
            return d
        }

        let fileData = try Data(contentsOf: audioURL)
        var body = Data()

        // 音频文件字段
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.m4a\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n".data(using: .utf8)!)

        // 模型字段（本地部署时可指定模型名，如 "Qwen3-ASR-4B"）
        if !model.isEmpty {
            body.append(formField("model", model))
        }

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let (data, _) = try await URLSession.shared.data(for: request)
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let text = json["text"] as? String {
            return text
        }
        return "远程识别失败（响应：\(String(data: data, encoding: .utf8) ?? "空")）"
    }
}

// MARK: - CloudStreamingASR

/// 云端/本地服务器实时流式 ASR
/// 核心修复：buffer 必须在 audio tap 回调中同步写入，不能异步分发（AVFoundation 会回收 buffer 内存）
/// 方案：NSLock + 在 tap 回调线程上同步完成格式转换和文件写入
class CloudStreamingASR {
    private var chunkFile: AVAudioFile?
    private var chunkURL: URL?
    private var chunkTimer: Timer?
    private var onResult: ((String) -> Void)?
    private var accumulatedText = ""
    private var endpoint = ""
    private var apiKey = ""
    private var apiModel = ""

    // 格式转换：输入 → 16kHz float32 mono（Whisper 标准输入格式）
    private var converter: AVAudioConverter?
    private let targetFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: 16000,
        channels: 1,
        interleaved: false
    )!

    // NSLock 保护 chunkFile/chunkURL，在 audio tap 线程（高优先级）和 Timer 线程（主线程）之间同步
    private let fileLock = NSLock()

    func start(audioEngine: AudioEngine, endpoint: String, onResult: @escaping (String) -> Void) {
        self.endpoint = endpoint
        self.onResult = onResult
        self.accumulatedText = ""
        let cfg = Configuration.shared
        self.apiKey = cfg.asrKey
        self.apiModel = cfg.asrModel

        // ⚡ 关键：onBuffer 在 audio tap 的实时线程上同步调用
        // 必须在这里完成转换+写入，不能 async 分发（buffer 内存随后被 AVFoundation 回收）
        audioEngine.onBuffer = { [weak self] buffer in
            self?.writeBufferSynchronously(buffer)
        }

        // 每 1.5 秒切换 chunk 文件并发送旧的 (提高实时性)
        chunkTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            self?.rollChunk()
        }
    }

    func stop() {
        chunkTimer?.invalidate()
        chunkTimer = nil
        onResult = nil
        fileLock.lock()
        chunkFile = nil
        if let url = chunkURL { try? FileManager.default.removeItem(at: url) }
        chunkURL = nil
        fileLock.unlock()
    }

    // MARK: - 音频写入（在 realtime audio tap 线程调用，必须快速完成）

    private func writeBufferSynchronously(_ buffer: AVAudioPCMBuffer) {
        // 懒加载格式转换器（一次性创建，维持内部滤波器状态实现连续转换）
        if converter == nil {
            converter = AVAudioConverter(from: buffer.format, to: targetFormat)
        }
        guard let conv = converter else { return }

        // 转换当前 buffer 到 16kHz float32 mono
        let ratio = targetFormat.sampleRate / buffer.format.sampleRate
        let outCap = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 4
        guard let outBuf = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: outCap) else { return }

        var inputConsumed = false
        conv.convert(to: outBuf, error: nil) { _, outStatus in
            if inputConsumed { outStatus.pointee = .noDataNow; return nil }
            inputConsumed = true
            outStatus.pointee = .haveData
            return buffer
        }
        guard outBuf.frameLength > 0 else { return }

        // 写入 chunk 文件（fileLock 保护与 Timer 线程的并发访问）
        fileLock.lock()
        if chunkFile == nil { openNewChunkFileLocked() }
        try? chunkFile?.write(from: outBuf)
        fileLock.unlock()
    }

    private func openNewChunkFileLocked() {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("vf_chunk_\(UUID().uuidString).wav")
        // float32 WAV：关闭（nil）即完成写入，无需额外 finalize 步骤
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 16000.0,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsBigEndianKey: false
        ]
        chunkFile = try? AVAudioFile(forWriting: url, settings: settings)
        chunkURL = url
    }

    // MARK: - Chunk 滚动与发送（在主线程 Timer 回调中调用）

    private func rollChunk() {
        fileLock.lock()
        let urlToSend = chunkURL
        chunkFile = nil  // 置 nil = deinit = WAV 文件正确关闭
        chunkURL = nil   // 下一帧 buffer 到来时自动创建新文件
        fileLock.unlock()

        guard let url = urlToSend else { return }

        // 快照当前配置（避免 Task 内再读 self 导致线程问题）
        let ep = endpoint, key = apiKey, mdl = apiModel
        Task { [weak self] in
            defer { try? FileManager.default.removeItem(at: url) }
            guard let self = self,
                  let text = try? await self.sendChunk(url: url, endpoint: ep, key: key, model: mdl),
                  !text.isEmpty else { return }

            // Ensure we read the LATEST accumulated text after the network request finishes,
            // avoiding race conditions when chunks complete out of order.
            let currentPrev = self.accumulatedText
            let updated = currentPrev.isEmpty ? text : currentPrev + " " + text
            self.accumulatedText = updated
            DispatchQueue.main.async { self.onResult?(updated) }
        }
    }

    private func sendChunk(url: URL, endpoint: String, key: String, model: String) async throws -> String {
        guard !endpoint.isEmpty, let endpointURL = URL(string: endpoint) else { return "" }

        var request = URLRequest(url: endpointURL)
        request.timeoutInterval = 8
        request.httpMethod = "POST"
        if !key.isEmpty { request.addValue("Bearer \(key)", forHTTPHeaderField: "Authorization") }

        let boundary = "VFChunk-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let fileData = try Data(contentsOf: url)
        var body = Data()
        body += "--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"chunk.wav\"\r\nContent-Type: audio/wav\r\n\r\n".data(using: .utf8)!
        body += fileData
        body += "\r\n".data(using: .utf8)!
        if !model.isEmpty {
            body += "--\(boundary)\r\nContent-Disposition: form-data; name=\"model\"\r\n\r\n\(model)\r\n".data(using: .utf8)!
        }
        body += "--\(boundary)--\r\n".data(using: .utf8)!
        request.httpBody = body

        let (data, _) = try await URLSession.shared.data(for: request)
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let text = json["text"] as? String {
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return ""
    }
}

// MARK: - Apple Native ASR

/// Tier-1: Apple Native Streaming & File ASR (Upgraded with Task Rotation)
class AppleNativeASR {
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    private(set) var accumulatedText = ""
    private var latestCurrentText = "" 
    /// 录音结束后保存的流式累积文本，用于 transcribeFinal 兜底
    private(set) var lastStreamedText = ""
    private var isRecording = false
    private var resultHandler: ((String) -> Void)?
    /// 任务代次：每次 startNewTask 递增，旧回调检测到代次不匹配则直接丢弃，防止无限重入
    private var taskGeneration = 0

    func start(onResult: @escaping (String) -> Void) throws {
        stop() // Reset
        self.isRecording = true
        self.accumulatedText = ""
        self.latestCurrentText = ""
        self.resultHandler = onResult

        try startNewTask()

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
    }

    private func startNewTask() throws {
        taskGeneration += 1
        let myGeneration = taskGeneration
        self.latestCurrentText = ""

        let oldTask = recognitionTask
        let oldRequest = recognitionRequest

        let newRequest = SFSpeechAudioBufferRecognitionRequest()
        newRequest.shouldReportPartialResults = true
        newRequest.requiresOnDeviceRecognition = true
        recognitionRequest = newRequest

        recognitionTask = recognizer?.recognitionTask(with: newRequest) { [weak self] result, error in
            guard let self = self, myGeneration == self.taskGeneration else { return }

            if let result = result {
                let currentText = result.bestTranscription.formattedString
                self.latestCurrentText = currentText
                self.resultHandler?(self.accumulatedText + currentText)

                if result.isFinal {
                    self.accumulatedText += currentText + " "
                    self.latestCurrentText = ""
                    if self.isRecording {
                        try? self.startNewTask()
                    }
                    return 
                }
            }

            if error != nil && self.isRecording {
                if !self.latestCurrentText.isEmpty {
                    self.accumulatedText += self.latestCurrentText + " "
                    self.latestCurrentText = ""
                }
                try? self.startNewTask()
            }
        }

        oldRequest?.endAudio()
        oldTask?.cancel()
    }

    func stop() {
        isRecording = false
        // 停止前保存累积文本，供 transcribeFinal 兜底使用
        lastStreamedText = accumulatedText + latestCurrentText

        audioEngine.stop()
        if audioEngine.inputNode.numberOfInputs > 0 {
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()

        recognitionRequest = nil
        recognitionTask = nil
    }
    
    func transcribeFile(audioURL: URL) async throws -> String {
        guard let recognizer = recognizer, recognizer.isAvailable else { return "ASR 不可用" }
        let request = SFSpeechURLRecognitionRequest(url: audioURL)
        // 不强制本地识别：允许使用云端，解除约 1 分钟的时长限制
        
        return try await withCheckedThrowingContinuation { continuation in
            var fullText = ""
            recognizer.recognitionTask(with: request) { result, error in
                if let error = error {
                    // Sometimes transcription finishes with an error but has results
                    if !fullText.isEmpty { continuation.resume(returning: fullText) }
                    else { continuation.resume(throwing: error) }
                    return
                }
                if let result = result {
                    fullText = result.bestTranscription.formattedString
                    if result.isFinal {
                        continuation.resume(returning: fullText)
                    }
                }
            }
        }
    }
}
