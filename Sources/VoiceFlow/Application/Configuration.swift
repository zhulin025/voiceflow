import Foundation
import AppKit

/// Simple configuration manager using UserDefaults
class Configuration: ObservableObject {
    static let shared = Configuration()
    
    @Published var asrMode: ASREngine.Mode {
        didSet {
            UserDefaults.standard.set(asrMode.rawValue, forKey: "asrMode")
        }
    }
    
    @Published var asrEndpoint: String {
        didSet { UserDefaults.standard.set(asrEndpoint, forKey: "asrEndpoint") }
    }

    @Published var asrKey: String {
        didSet { UserDefaults.standard.set(asrKey, forKey: "asrKey") }
    }

    /// 云端 ASR 使用的模型名称（Whisper 兼容 API 中作为 form-data 的 model 字段）
    @Published var asrModel: String {
        didSet { UserDefaults.standard.set(asrModel, forKey: "asrModel") }
    }

    /// 声纹动画模糊半径（0 = 无模糊，15 = 完全模糊）
    @Published var waveBlurRadius: Double {
        didSet { UserDefaults.standard.set(waveBlurRadius, forKey: "waveBlurRadius") }
    }
    
    @Published var llmEndpoint: String {
        didSet { UserDefaults.standard.set(llmEndpoint, forKey: "llmEndpoint") }
    }
    
    @Published var llmKey: String {
        didSet { UserDefaults.standard.set(llmKey, forKey: "llmKey") }
    }
    
    @Published var llmModel: String {
        didSet { UserDefaults.standard.set(llmModel, forKey: "llmModel") }
    }
    
    init() {
        let savedMode = UserDefaults.standard.string(forKey: "asrMode") ?? ASREngine.Mode.builtIn.rawValue
        self.asrMode = ASREngine.Mode(rawValue: savedMode) ?? .builtIn
        self.asrEndpoint = UserDefaults.standard.string(forKey: "asrEndpoint") ?? "https://api.openai.com/v1/audio/transcriptions"
        self.asrKey = UserDefaults.standard.string(forKey: "asrKey") ?? ""
        self.asrModel = UserDefaults.standard.string(forKey: "asrModel") ?? "whisper-1"
        self.waveBlurRadius = UserDefaults.standard.object(forKey: "waveBlurRadius") as? Double ?? 1.5
        
        // Default to DeepSeek official endpoint as a helpful placeholder
        self.llmEndpoint = UserDefaults.standard.string(forKey: "llmEndpoint") ?? "https://api.deepseek.com/v1"
        self.llmKey = UserDefaults.standard.string(forKey: "llmKey") ?? ""
        self.llmModel = UserDefaults.standard.string(forKey: "llmModel") ?? "deepseek-chat"
    }
}
