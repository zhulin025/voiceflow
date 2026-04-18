import SwiftUI

struct FluidWaveView: View {
    @ObservedObject var audio: AudioEngine
    @ObservedObject private var config = Configuration.shared

    private struct Theme {
        let blobs: [Color]
        let particles: [Color]
    }

    private var currentTheme: Theme {
        switch config.waveColorScheme {
        case .purple:
            return Theme(
                blobs: [
                    Color(red: 0.50, green: 0.30, blue: 0.78),
                    Color(red: 0.68, green: 0.35, blue: 0.78),
                    Color(red: 0.80, green: 0.45, blue: 0.70),
                    Color(red: 0.68, green: 0.55, blue: 0.86)
                ],
                particles: [
                    Color(red: 0.72, green: 0.48, blue: 0.88),
                    Color(red: 0.82, green: 0.40, blue: 0.72),
                    Color(red: 0.55, green: 0.35, blue: 0.80),
                    Color(red: 0.75, green: 0.55, blue: 0.85)
                ]
            )
        case .blue:
            return Theme(
                blobs: [
                    Color(red: 0.20, green: 0.40, blue: 0.85),
                    Color(red: 0.30, green: 0.55, blue: 0.90),
                    Color(red: 0.40, green: 0.70, blue: 0.95),
                    Color(red: 0.50, green: 0.80, blue: 1.00)
                ],
                particles: [
                    Color(red: 0.40, green: 0.60, blue: 1.00),
                    Color(red: 0.50, green: 0.80, blue: 1.00),
                    Color(red: 0.30, green: 0.40, blue: 0.90),
                    Color(red: 0.60, green: 0.90, blue: 1.00)
                ]
            )
        case .green:
            return Theme(
                blobs: [
                    Color(red: 0.15, green: 0.65, blue: 0.45),
                    Color(red: 0.25, green: 0.75, blue: 0.55),
                    Color(red: 0.45, green: 0.85, blue: 0.65),
                    Color(red: 0.65, green: 0.95, blue: 0.75)
                ],
                particles: [
                    Color(red: 0.35, green: 0.85, blue: 0.55),
                    Color(red: 0.55, green: 1.00, blue: 0.75),
                    Color(red: 0.25, green: 0.75, blue: 0.45),
                    Color(red: 0.45, green: 0.95, blue: 0.65)
                ]
            )
        case .aurora:
            return Theme(
                blobs: [
                    Color(red: 0.10, green: 0.80, blue: 0.70), // Teal
                    Color(red: 0.30, green: 0.20, blue: 0.80), // Indigo
                    Color(red: 0.80, green: 0.10, blue: 0.60), // Magenta
                    Color(red: 0.10, green: 0.40, blue: 0.90)  // Deep Blue
                ],
                particles: [
                    Color(red: 0.50, green: 1.00, blue: 0.90),
                    Color(red: 0.60, green: 0.40, blue: 1.00),
                    Color(red: 1.00, green: 0.40, blue: 0.80),
                    Color(red: 0.40, green: 0.70, blue: 1.00)
                ]
            )
        }
    }

    private var motionSpeed: Double {
        switch config.waveMotionScheme {
        case .fluid:    return 1.0
        case .energetic: return 1.8
        case .serene:    return 0.4
        }
    }

    private var wobbleMultiplier: Double {
        switch config.waveMotionScheme {
        case .fluid:    return 1.0
        case .energetic: return 1.5
        case .serene:    return 0.6
        }
    }

    var body: some View {
        TimelineView(.animation) { context in
            Canvas { ctx, size in
                let t   = context.date.timeIntervalSince1970 * motionSpeed
                let ampRaw = Double(audio.amplitude)
                // Adjust amplitude reaction based on motion scheme
                let amp = config.waveMotionScheme == .serene ? ampRaw * 0.6 : (config.waveMotionScheme == .energetic ? ampRaw * 1.3 : ampRaw)
                
                let cx  = size.width  / 2
                let cy  = size.height / 2
                let bx  = size.width  * 0.18
                let by  = size.height * 0.21
                let scale = 1.62
                let theme = currentTheme

                // ── Draw Blobs ──
                drawBlob(ctx, cx: cx - bx*0.08, cy: cy + by*0.06,
                         bx: bx * scale * (0.78 + amp * 0.57), by: by * scale * (0.78 + amp * 0.42),
                         phase: t * 1.6, wobbleFreq: Int(Double(5) * wobbleMultiplier),
                         color: theme.blobs[0], opacity: 0.88)

                drawBlob(ctx, cx: cx + bx*0.11, cy: cy - by*0.07,
                         bx: bx * scale * (0.68 + amp * 0.50), by: by * scale * (0.68 + amp * 0.38),
                         phase: t * 1.3 + 2.0, wobbleFreq: Int(Double(4) * wobbleMultiplier),
                         color: theme.blobs[1], opacity: 0.76)

                drawBlob(ctx, cx: cx - bx*0.05, cy: cy - by*0.10,
                         bx: bx * scale * (0.55 + amp * 0.42), by: by * scale * (0.55 + amp * 0.33),
                         phase: t * 2.0 + 1.1, wobbleFreq: Int(Double(6) * wobbleMultiplier),
                         color: theme.blobs[2], opacity: 0.66)

                drawBlob(ctx, cx: cx + bx*0.06, cy: cy + by*0.12,
                         bx: bx * scale * (0.42 + amp * 0.33), by: by * scale * (0.42 + amp * 0.26),
                         phase: t * 1.1 + 3.5, wobbleFreq: Int(Double(3) * wobbleMultiplier),
                         color: theme.blobs[3], opacity: 0.56)

                // ── Particle ring ──
                let particleCount = 200
                for i in 0..<particleCount {
                    let fi    = Double(i)
                    let phi   = fi * 2.39996
                    let speed = (i % 2 == 0 ? 0.35 : -0.25) * motionSpeed
                    let angle = phi + t * speed
                    let ring  = 1.25 + sin(fi * 1.13 + t * 0.55) * 0.15
                    let dist  = bx * ring * scale * (1.0 + amp * 0.25)
                    let px    = cx + cos(angle) * dist
                    let py    = cy + sin(angle) * dist * (by / bx)
                    let ps    = 1.1 + sin(fi * 2.31 + t * 0.9) * 0.75
                    let pa    = min((0.20 + sin(fi * 1.73 + t * 0.75) * 0.1) * (1.0 + amp * 1.6), 0.50)
                    let pc    = theme.particles[i % 4]
                    
                    ctx.fill(
                        Path(ellipseIn: CGRect(x: px - ps, y: py - ps,
                                               width: ps * 2, height: ps * 2)),
                        with: .color(pc.opacity(pa))
                    )
                }
            }
            .blur(radius: config.waveBlurRadius)
        }
    }

    private func drawBlob(_ ctx: GraphicsContext,
                          cx: Double, cy: Double,
                          bx: Double, by: Double,
                          phase: Double, wobbleFreq: Int,
                          color: Color, opacity: Double) {
        let steps = 72
        var pts: [CGPoint] = []
        for i in 0...steps {
            let θ  = Double(i) / Double(steps) * .pi * 2
            let w1 = sin(θ * Double(wobbleFreq)     + phase)        * 0.28
            let w2 = sin(θ * Double(wobbleFreq + 2) - phase * 0.66) * 0.14
            let w3 = sin(θ * Double(wobbleFreq + 4) + phase * 0.44) * 0.07
            let w  = w1 + w2 + w3
            let ex = bx * (1.0 + w * 1.0 ) * cos(θ)
            let ey = by * (1.0 + w * 0.48) * sin(θ)
            pts.append(CGPoint(x: cx + ex, y: cy + ey))
        }
        var path = Path()
        path.move(to: pts[0])
        for i in 1..<pts.count - 1 {
            let mid = CGPoint(x: (pts[i].x + pts[i+1].x) / 2,
                               y: (pts[i].y + pts[i+1].y) / 2)
            path.addQuadCurve(to: mid, control: pts[i])
        }
        path.closeSubpath()
        ctx.fill(path, with: .color(color.opacity(opacity)))
    }
}
