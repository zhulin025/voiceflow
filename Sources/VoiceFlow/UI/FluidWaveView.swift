import SwiftUI

struct FluidWaveView: View {
    @ObservedObject var audio: AudioEngine
    @ObservedObject private var config = Configuration.shared

    var body: some View {
        TimelineView(.animation) { context in
            Canvas { ctx, size in
                let t   = context.date.timeIntervalSince1970
                let amp = Double(audio.amplitude)
                let cx  = size.width  / 2
                let cy  = size.height / 2

                // bx/by tuned to maximize use of the 320x85 canvas
                let bx = size.width  * 0.18
                let by = size.height * 0.21

                // ── Four overlapping aurora blobs (Scaled down to 0.9 of previous 1.8x) ────────────
                let scale = 1.62
                drawBlob(ctx, cx: cx - bx*0.08, cy: cy + by*0.06,
                         bx: bx * scale * (0.78 + amp * 0.57), by: by * scale * (0.78 + amp * 0.42),
                         phase: t * 1.6, wobbleFreq: 5,
                         color: Color(red: 0.50, green: 0.30, blue: 0.78), opacity: 0.88)

                drawBlob(ctx, cx: cx + bx*0.11, cy: cy - by*0.07,
                         bx: bx * scale * (0.68 + amp * 0.50), by: by * scale * (0.68 + amp * 0.38),
                         phase: t * 1.3 + 2.0, wobbleFreq: 4,
                         color: Color(red: 0.68, green: 0.35, blue: 0.78), opacity: 0.76)

                drawBlob(ctx, cx: cx - bx*0.05, cy: cy - by*0.10,
                         bx: bx * scale * (0.55 + amp * 0.42), by: by * scale * (0.55 + amp * 0.33),
                         phase: t * 2.0 + 1.1, wobbleFreq: 6,
                         color: Color(red: 0.80, green: 0.45, blue: 0.70), opacity: 0.66)

                drawBlob(ctx, cx: cx + bx*0.06, cy: cy + by*0.12,
                         bx: bx * scale * (0.42 + amp * 0.33), by: by * scale * (0.42 + amp * 0.26),
                         phase: t * 1.1 + 3.5, wobbleFreq: 3,
                         color: Color(red: 0.68, green: 0.55, blue: 0.86), opacity: 0.56)

                // ── Particle ring — Layout restored, bounding strictly inside screen ──
                let particleCount = 200
                for i in 0..<particleCount {
                    let fi    = Double(i)
                    let phi   = fi * 2.39996               // golden angle
                    let speed = i % 2 == 0 ? 0.35 : -0.25
                    let angle = phi + t * speed
                    // Base ring sits tightly around the blob to remain visible inside the UI
                    let ring  = 1.25 + sin(fi * 1.13 + t * 0.55) * 0.15
                    // Modest expansion during speech so half the particles remain visible
                    let dist  = bx * ring * scale * (1.0 + amp * 0.25)
                    let px    = cx + cos(angle) * dist
                    let py    = cy + sin(angle) * dist * (by / bx)   // elliptical to match blobs
                    let ps    = 1.1 + sin(fi * 2.31 + t * 0.9) * 0.75
                    let pa    = min((0.20 + sin(fi * 1.73 + t * 0.75) * 0.1) * (1.0 + amp * 1.6), 0.50)
                    let pc: Color
                    switch i % 4 {
                    case 0:  pc = Color(red: 0.72, green: 0.48, blue: 0.88)
                    case 1:  pc = Color(red: 0.82, green: 0.40, blue: 0.72)
                    case 2:  pc = Color(red: 0.55, green: 0.35, blue: 0.80)
                    default: pc = Color(red: 0.75, green: 0.55, blue: 0.85)
                    }
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
            let ex = bx * (1.0 + w * 1.0 ) * cos(θ)   // x deforms more
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
