#include <metal_stdlib>
using namespace metal;

// ── Utility ────────────────────────────────────────────────────────────────

float hash(float n) { return fract(sin(n) * 43758.5453123); }

float noise(float2 x) {
    float2 p = floor(x);
    float2 f = fract(x);
    f = f * f * (3.0 - 2.0 * f);
    float n = p.x + p.y * 57.0;
    return mix(mix(hash(n),      hash(n + 1.0),  f.x),
               mix(hash(n + 57.0), hash(n + 58.0), f.x), f.y);
}

float fbm(float2 p) {
    float f = 0.0;
    float w = 0.5;
    for (int i = 0; i < 5; i++) {
        f += w * noise(p);
        p  = p * 2.01 + float2(0.31, 0.17);
        w *= 0.5;
    }
    return f;
}

// ── Main Shader ─────────────────────────────────────────────────────────────
// Three overlapping FBM blobs — aurora palette (deep purple → violet → magenta → pink)

[[ stitchable ]] half4 fluidWave(float2 position, half4 color,
                                  float2 size, float time, float amplitude) {
    // Aspect-corrected UV so blob stays circular regardless of view shape
    float aspect = size.x / size.y;
    float2 uv = float2((position.x / size.x - 0.5) * aspect,
                        position.y / size.y - 0.5);

    float amp = clamp(amplitude, 0.0, 1.0);

    // ── Blob 1: Deep purple/violet (back layer) ───────────────────────────
    float2 q1 = float2(fbm(uv * 2.1 + time * 0.09),
                        fbm(uv * 2.1 + float2(1.9, 0.7) + time * 0.07));
    float2 r1 = float2(fbm(uv * 1.8 + 3.2 * q1 + time * 0.11),
                        fbm(uv * 1.8 + 3.2 * q1 + float2(3.3, 1.4) + time * 0.08));
    float n1  = fbm(uv * 1.5 + 4.0 * r1);

    float baseR1  = 0.22 + amp * 0.18;
    float d1      = length(uv + float2(-0.06, 0.02) * aspect + 0.28 * q1);
    float blob1   = smoothstep(baseR1 + 0.22 + n1 * 0.12, baseR1 - 0.04, d1);

    // ── Blob 2: Magenta/pink (mid layer, offset right) ────────────────────
    float2 q2 = float2(fbm(uv * 2.4 + float2(2.1, 0.8) + time * 0.07),
                        fbm(uv * 2.4 + float2(0.6, 2.3) + time * 0.09));
    float2 r2 = float2(fbm(uv * 2.0 + 3.0 * q2 + float2(1.6, 0.9) + time * 0.10),
                        fbm(uv * 2.0 + 3.0 * q2 + float2(4.1, 2.3)));
    float n2  = fbm(uv * 1.7 + 4.0 * r2 + time * 0.05);

    float baseR2  = 0.17 + amp * 0.14;
    float2 c2off  = float2(0.12 * aspect, -0.04);
    float d2      = length(uv - c2off + 0.22 * q2);
    float blob2   = smoothstep(baseR2 + 0.18 + n2 * 0.10, baseR2 - 0.03, d2);

    // ── Blob 3: Soft lavender highlight (front, upper-left) ───────────────
    float2 q3 = float2(fbm(uv * 3.0 + float2(3.2, 2.1) + time * 0.05),
                        fbm(uv * 3.0 + float2(0.8, 3.2) + time * 0.04));
    float n3  = fbm(uv * 2.5 + 3.0 * q3 + time * 0.03);

    float baseR3  = 0.12 + amp * 0.09;
    float2 c3off  = float2(-0.10 * aspect, 0.07);
    float d3      = length(uv - c3off + 0.18 * q3);
    float blob3   = smoothstep(baseR3 + 0.14 + n3 * 0.08, baseR3 - 0.02, d3);

    // ── Color palette ─────────────────────────────────────────────────────
    float3 c_violet  = float3(0.38, 0.10, 0.80);   // deep violet
    float3 c_purple  = float3(0.55, 0.15, 0.88);   // purple
    float3 c_magenta = float3(0.82, 0.22, 0.68);   // magenta
    float3 c_pink    = float3(0.95, 0.38, 0.58);   // pink
    float3 c_peach   = float3(0.98, 0.60, 0.75);   // peach
    float3 c_lavender= float3(0.72, 0.52, 0.96);   // lavender

    float3 col1 = mix(c_violet,   c_purple,  clamp(n1 * 2.0, 0.0, 1.0));
    float3 col2 = mix(c_magenta,  c_pink,    clamp(n2 * 2.5, 0.0, 1.0));
    float3 col3 = mix(c_lavender, c_peach,   clamp(n3 * 3.0, 0.0, 1.0));

    // ── Composite front-to-back (over operator) ───────────────────────────
    float a1 = clamp(blob1 * 0.82, 0.0, 1.0);
    float3 out = col1;
    float  outA = a1;

    float a2 = clamp(blob2 * 0.76, 0.0, 1.0);
    out  = out  * (1.0 - a2) + col2 * a2;
    outA = outA + a2 * (1.0 - outA);

    float a3 = clamp(blob3 * 0.58, 0.0, 1.0);
    out  = out  * (1.0 - a3) + col3 * a3;
    outA = outA + a3 * (1.0 - outA);

    // ── Grain texture (nebula aesthetic) ─────────────────────────────────
    float grain = fract(sin(dot(position * 0.25, float2(12.9898, 78.233))) * 43758.5453);
    outA *= (0.87 + 0.13 * grain);
    outA  = clamp(outA, 0.0, 1.0);

    return half4(half3(out), half(outA));
}
