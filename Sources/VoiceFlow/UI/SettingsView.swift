import SwiftUI

struct SettingsView: View {
    @ObservedObject var config = Configuration.shared
    @EnvironmentObject var recorder: RecorderState
    
    @State private var selectedTab: SettingsTab = .model
    
    enum SettingsTab: String, CaseIterable {
        case model = "模型设置"
        case ui = "UI设置"
    }

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

            VStack(alignment: .leading, spacing: 16) {
                Text("VoiceFlow 偏好设置")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.top, 8)

                // Tab Picker
                Picker("", selection: $selectedTab) {
                    ForEach(SettingsTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 40)
                .padding(.top, 8)

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        if selectedTab == .model {
                            modelSettings
                        } else {
                            uiSettings
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

    private var modelSettings: some View {
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
        }
    }

    private var uiSettings: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("界面与动画设置")
                .font(.headline).foregroundStyle(.white)

            // 配色方案
            VStack(alignment: .leading, spacing: 8) {
                Text("声纹配色方案").font(.caption).opacity(0.7)
                Picker("", selection: $config.waveColorScheme) {
                    ForEach(Configuration.WaveColorScheme.allCases, id: \.self) { scheme in
                        Text(scheme.rawValue).tag(scheme)
                    }
                }
                .pickerStyle(.segmented)
            }

            // 动效方案
            VStack(alignment: .leading, spacing: 8) {
                Text("声纹动效方案").font(.caption).opacity(0.7)
                Picker("", selection: $config.waveMotionScheme) {
                    ForEach(Configuration.WaveMotionScheme.allCases, id: \.self) { scheme in
                        Text(scheme.rawValue).tag(scheme)
                    }
                }
                .pickerStyle(.segmented)
            }

            Divider().opacity(0.1)

            // 模糊度
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
                        .tint(config.themeColor)
                    Text("模糊").font(.caption2).opacity(0.4)
                }
            }

            // 界面大小
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("界面大小")
                        .font(.caption).opacity(0.7)
                    Spacer()
                    Text(String(format: "%.0f%%", config.overlayScale * 100))
                        .font(.caption).foregroundStyle(.white.opacity(0.5))
                }
                HStack(spacing: 8) {
                    Text("较小").font(.caption2).opacity(0.4)
                    Slider(value: $config.overlayScale, in: 0.5...2.0, step: 0.1)
                        .tint(config.themeColor)
                    Text("较大").font(.caption2).opacity(0.4)
                }
            }
        }
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
