import Foundation

/// Handles the 3 simplified LLM transformation modes
class LLMProcessor: ObservableObject {
    enum Mode: String, CaseIterable {
        case precise = "基础纠错"
        case polished = "智能润色"
        case structured = "深度提炼"
        
        var prompt: String {
            switch self {
            case .precise:
                return "仅修正以下ASR转写的文字错误、错别字及冗余语气词，保留原意，严禁添加任何解释，直接输出修正后的正文：\n"
            case .polished:
                return "将以下内容润色为流畅、自然的文字。自动修正术语、逻辑断句并优化表达风格（正式且专业）。直接输出润色后的正文，严禁废话：\n"
            case .structured:
                return "对以下文本进行深度提炼，将其转化为结构化的要点、总结或Markdown格式。直接输出提炼后的架构正文，严禁带引导语：\n"
            }
        }
    }
    
    func process(_ text: String, mode: Mode) async throws -> String {
        let config = Configuration.shared
        guard !config.llmKey.isEmpty else { return "请先配置 LLM API Key" }
        
        var request = URLRequest(url: URL(string: "\(config.llmEndpoint)/chat/completions")!)
        request.httpMethod = "POST"
        request.addValue("Bearer \(config.llmKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "model": config.llmModel,
            "messages": [
                ["role": "system", "content": "你是一个无声的文字处理器。接收用户转写文本，按指定模式处理后，只输出处理后的纯净结果。严禁输出任何解释、道歉、礼貌用语（如‘好的’、‘没问题’）或前缀。如果无法处理，请原样输出。"],
                ["role": "user", "content": mode.prompt + text]
            ],
            "stream": false
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let choices = json["choices"] as? [[String: Any]],
           let message = choices.first?["message"] as? [String: Any],
           let content = message["content"] as? String {
            return content.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        return " 处理失败，请检查配置或网络 "
    }
}
