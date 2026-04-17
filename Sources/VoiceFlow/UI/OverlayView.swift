import SwiftUI

struct OverlayView: View {
    @ObservedObject var audio: AudioEngine
    @EnvironmentObject var recorder: RecorderState

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Main Glass Capsule
            HStack(spacing: 12) {
                // 1. Mic Button (Left)
                Button(action: {
                    if !recorder.isAccessibilityTrusted {
                        if TextInserter.checkPermissions() {
                            recorder.isAccessibilityTrusted = true
                            NotificationCenter.default.post(name: NSNotification.Name("ToggleVoiceFlowRecording"), object: nil)
                        } else {
                            TextInserter.requestPermissions()
                            let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
                            NSWorkspace.shared.open(url)
                        }
                    } else {
                        NotificationCenter.default.post(name: NSNotification.Name("ToggleVoiceFlowRecording"), object: nil)
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(recorder.isRecording ? Color.red.opacity(0.3) : Color.white.opacity(0.1))
                            .frame(width: 44, height: 44)

                        if !recorder.isAccessibilityTrusted {
                            Image(systemName: "hand.raised.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(.orange)
                        } else {
                            Image(systemName: recorder.isRecording ? "stop.fill" : "mic.fill")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(recorder.isRecording ? .red : .white)
                        }
                    }
                }
                .buttonStyle(.plain)
                .padding(.leading, 8)

                // 2. Center: Audio Visualization + Scrolling Text
                ZStack {
                    FluidWaveView(audio: audio)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    ScrollingTextView(text: recorder.transcript)
                        .modifier(FadingMask())
                        .frame(width: 125, height: 40)
                }
                .frame(maxWidth: .infinity)

                // 3. Right: Sparkles Menu (Simplified Modes)
                Menu {
                    Section("转换模式") {
                        ForEach(LLMProcessor.Mode.allCases, id: \.self) { mode in
                            Button(mode.rawValue) {
                                recorder.selectedMode = mode
                            }
                        }
                    }

                    Divider()

                    Button(action: {
                        NotificationCenter.default.post(name: NSNotification.Name("OpenVoiceFlowSettings"), object: nil)
                    }) {
                        Label("应用设置...", systemImage: "gearshape.fill")
                    }
                } label: {
                    Image(systemName: "sparkles")
                        .font(.system(size: 18))
                        .foregroundStyle(.purple)
                        .frame(width: 44, height: 44)
                        .background(.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .menuStyle(.borderlessButton)
                .buttonStyle(.plain)
                .padding(.trailing, 10)
            }
            .padding(.horizontal, 4)
            .frame(width: 380, height: 85)
            .background(
                RoundedRectangle(cornerRadius: 32)
                    .fill(.ultraThinMaterial)
                    .opacity(0.60) // High transparency as requested
                    .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
            )
            .clipShape(RoundedRectangle(cornerRadius: 32))

            // Floating Close Button
            Button(action: {
                NSApp.terminate(nil)
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.red.opacity(0.6))
            }
            .buttonStyle(.plain)
            .offset(x: -4, y: -4)
        }
        .frame(width: 410, height: 110)
        .background(Color.clear)
    }
}
