#version 440

// Image clipped to a squircle / rounded rectangle with an analytic
// anti-aliased edge, plus an optional black gradient overlay.
//
// The edge is computed from a signed distance in pixels, so it is smooth
// whatever the scale factor, instead of depending on a rasterised mask
// texture. The SDF is the same one liquidglass.frag uses for the widget
// silhouette, so a full-widget image lines up with the glass exactly.
//
// qt_TexCoord0 is item-local UV (0..1).

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4  qt_Matrix;
    float qt_Opacity;
    vec2  size;        // item size in px
    float radius;      // corner radius in px
    float roundness;   // superellipse exponent; 2 = circular corner
    float gradientOn;  // 1 = darken towards the bottom (square layout)
};

layout(binding = 1) uniform sampler2D source;

float sdf(vec2 p) {
    vec2 b = size * 0.5;
    float n = max(roundness, 2.0);
    float r = clamp(radius, 0.0, min(b.x, b.y));

    vec2 q = abs(p) - b + vec2(r);
    float qx = max(q.x, 0.0);
    float qy = max(q.y, 0.0);

    if (qx <= 0.0 && qy <= 0.0) return max(q.x, q.y) - r;
    if (qx == 0.0) return qy - r;
    if (qy == 0.0) return qx - r;

    float arc = pow(pow(qx, n) + pow(qy, n), 1.0 / n);
    float gx = pow(qx / arc, n - 1.0);
    float gy = pow(qy / arc, n - 1.0);
    float gradLen = sqrt(gx * gx + gy * gy);
    return (arc - r) / max(gradLen, 1e-3);
}

void main() {
    vec2 uv = qt_TexCoord0;
    vec4 col = texture(source, uv);

    if (gradientOn > 0.5) {
        // Black overlay, same stops as the former QML gradient.
        float a = mix(0.35, 0.45, smoothstep(0.0, 0.35, uv.y));
        a = mix(a, 0.90, smoothstep(0.35, 0.85, uv.y));
        a = mix(a, 0.97, smoothstep(0.85, 1.0, uv.y));
        col.rgb *= (1.0 - a);
    }

    float d = sdf((uv - 0.5) * size);
    float mask = 1.0 - smoothstep(-0.5, 0.5, d);

    fragColor = col * mask * qt_Opacity;
}
