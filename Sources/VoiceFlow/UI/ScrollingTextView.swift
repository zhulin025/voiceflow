import SwiftUI

/// Two-line HUD text area.
/// Short content (≤2 lines) is vertically centered; overflow auto-scrolls to bottom.
/// Top 20% fades out for a natural scroll-exit effect.
struct ScrollingTextView: View {
    let text: String

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    Text(text)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                        .lineLimit(nil)
                        .padding(.horizontal, 4)
                        .id("bottom")
                    Spacer(minLength: 0)
                }
                // minHeight equals the container so Spacers center short text;
                // when text overflows this height, ScrollView scrolls automatically.
                .frame(minHeight: 40)
            }
            .onChange(of: text) {
                withAnimation(.easeOut(duration: 0.15)) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
        }
    }
}

/// Gradient mask: top 20% fades to clear for natural scroll-exit appearance.
struct FadingMask: ViewModifier {
    func body(content: Content) -> some View {
        content
            .mask(
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: .black, location: 0.2),
                        .init(color: .black, location: 1.0)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
    }
}
