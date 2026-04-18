import Foundation
import AppKit
import SwiftUI

/// Simple configuration manager using UserDefaults
class Configuration: ObservableObject {
    static let shared = Configuration()
    
    var themeColor: Color {
        switch waveColorScheme {
        case .purple: return .purple
        case .blue:   return Color(red: 0.20, green: 0.40, blue: 0.85)
        case .green:  return Color(red: 0.15, green: 0.65, blue: 0.45)
        case .aurora: return Color(red: 0.10, green: 0.80, blue: 0.70)
        }
    }
    
    enum WaveColorScheme: String, CaseIterable {
        case purple  = "紫罗兰"
        case blue    = "深海蓝"
        case green   = "翡翠绿"
        case aurora  = "极光"
    }
    
    enum WaveMotionScheme: String, CaseIterable {
        case fluid    = "流畅"
        case energetic = "活力"
        case serene    = "宁静"
    }
    
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
    
    @Published var overlayScale: Double {
        didSet { UserDefaults.standard.set(overlayScale, forKey: "overlayScale") }
    }
    
    @Published var waveColorScheme: WaveColorScheme {
        didSet { UserDefaults.standard.set(waveColorScheme.rawValue, forKey: "waveColorScheme") }
    }
    
    @Published var waveMotionScheme: WaveMotionScheme {
        didSet { UserDefaults.standard.set(waveMotionScheme.rawValue, forKey: "waveMotionScheme") }
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
        self.overlayScale = UserDefaults.standard.object(forKey: "overlayScale") as? Double ?? 1.0
        
        let savedColorScheme = UserDefaults.standard.string(forKey: "waveColorScheme") ?? WaveColorScheme.purple.rawValue
        self.waveColorScheme = WaveColorScheme(rawValue: savedColorScheme) ?? .purple
        
        let savedMotionScheme = UserDefaults.standard.string(forKey: "waveMotionScheme") ?? WaveMotionScheme.fluid.rawValue
        self.waveMotionScheme = WaveMotionScheme(rawValue: savedMotionScheme) ?? .fluid
    }
}
