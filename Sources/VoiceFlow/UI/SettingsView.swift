import SwiftUI

struct SettingsView: View {
    @ObservedObject var config = Configuration.shared
    @EnvironmentObject var recorder: RecorderState

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Background Layer
            RoundedRectangle(cornerRadius: 32)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 32)
                        .stroke(.white.opacity(0.1), lineWidth: 1)
                )

            // Close Button
            Button(action: {
                NSApp.windows.first(where: { $0.title == "VoiceFlow 设置" })?.close()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.white.opacity(0.3))
            }
            .buttonStyle(.plain)
            .padding(16)

            VStack(alignment: .leading, spacing: 20) {
                Text("VoiceFlow 偏好设置")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.bottom, 8)

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {

                        // ── ASR Section ──
                        VStack(alignment: .leading, spacing: 12) {
                            Text("ASR 引擎设置")
                                .font(.headline).foregroundStyle(.white)

                            Picker("", selection: $config.asrMode) {
                                ForEach(ASREngine.Mode.allCases, id: \.self) { mode in
                                    Text(mode.rawValue).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)

                            // 云端 API 模式
                            if config.asrMode == .cloud {
                                Group {
                                    CustomTextField(label: "API Endpoint", text: $config.asrEndpoint)
                                    CustomSecureField(label: "API Key", text: $config.asrKey)
                                    CustomTextField(
                                        label: "模型名称（如 whisper-1 / Qwen3-ASR-4B）",
                                        text: $config.asrModel
                                    )
                                }
                                Text("本地部署示例：Endpoint 填 http://127.0.0.1:8000/v1/audio/transcriptions，模型填对应模型名")
                                    .font(.caption2).foregroundStyle(.white.opacity(0.4))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }

                        Divider().opacity(0.1)

                        // ── LLM Section ──
                        VStack(alignment: .leading, spacing: 12) {
                            Text("LLM 智能修正设置")
                                .font(.headline).foregroundStyle(.white)

                            CustomTextField(label: "API Endpoint", text: $config.llmEndpoint)
                            CustomTextField(label: "Model Name", text: $config.llmModel)
                            CustomSecureField(label: "API Key", text: $config.llmKey)
                        }

                        Divider().opacity(0.1)

                        // ── 外观设置 ──
                        VStack(alignment: .leading, spacing: 12) {
                            Text("外观设置")
                                .font(.headline).foregroundStyle(.white)

                            VStack(alignment: .leading, spacing: 6) {
                                let blurText = blurLabel(config.waveBlurRadius)
                                HStack {
                                    Text("声纹动画模糊度")
                                        .font(.caption).opacity(0.7)
                                    Spacer()
                                    Text(blurText)
                                        .font(.caption).foregroundStyle(.white.opacity(0.5))
                                        .frame(width: 60, alignment: .trailing)
                                }
                                HStack(spacing: 8) {
                                    Text("清晰").font(.caption2).opacity(0.4)
                                    Slider(value: $config.waveBlurRadius, in: 0...15, step: 0.5)
                                        .tint(.purple)
                                    Text("模糊").font(.caption2).opacity(0.4)
                                }
                            }
                        }
                    }
                    .padding(.trailing, 8)
                }
            }
            .padding(24)
        }
        .frame(width: 480, height: 520)
        .preferredColorScheme(.dark)
    }

    private func blurLabel(_ v: Double) -> String {
        switch v {
        case 0: return "无模糊"
        case 0..<4: return String(format: "轻微 (%.1f)", v)
        case 4..<9: return String(format: "适中 (%.1f)", v)
        default:   return String(format: "模糊 (%.1f)", v)
        }
    }
}

struct CustomTextField: View {
    let label: String
    @Binding var text: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption2).opacity(0.5)
            TextField("", text: $text)
                .textFieldStyle(.plain)
                .padding(8)
                .background(.white.opacity(0.05))
                .cornerRadius(8)
        }
    }
}

struct CustomSecureField: View {
    let label: String
    @Binding var text: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption2).opacity(0.5)
            SecureField("", text: $text)
                .textFieldStyle(.plain)
                .padding(8)
                .background(.white.opacity(0.05))
                .cornerRadius(8)
        }
    }
}
