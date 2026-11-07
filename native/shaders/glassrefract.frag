#version 440

// Liquid Glass : déforme, sur les bords du Dock, l'image déjà floutée qui se
// trouve derrière (réfraction, franges de couleur, reflet des bords). Même
// calcul que GlassPane (chemin processeur), mais fait par la carte graphique, à
// chaque image affichée. Compilé par install.sh avec « qsb --qt6 ».

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    // Taille de la zone lue (le Dock plus sa marge) et du Dock, en pixels.
    vec2 regionSize;
    vec2 dockSize;
    float cornerRadius;
    float thickness;
    float strength;
    float dispersion;
    float profile;
    float rim;
} ubuf;

layout(binding = 1) uniform sampler2D source;

void main()
{
    vec2 p = qt_TexCoord0 * ubuf.regionSize - ubuf.regionSize * 0.5;
    vec2 halfSize = ubuf.dockSize * 0.5;
    float radius = min(ubuf.cornerRadius, min(halfSize.x, halfSize.y));
    vec2 q = abs(p) - (halfSize - vec2(radius));
    vec2 o = max(q, vec2(0.0));
    float outside = length(o);
    // Distance signée au rectangle arrondi (négative à l'intérieur).
    float dist = outside + min(max(q.x, q.y), 0.0) - radius;
    float coverage = clamp(0.5 - dist, 0.0, 1.0);
    if (coverage <= 0.0) {
        fragColor = vec4(0.0);
        return;
    }

    // Normale sortante du bord le plus proche.
    vec2 s = vec2(p.x < 0.0 ? -1.0 : 1.0, p.y < 0.0 ? -1.0 : 1.0);
    vec2 n = vec2(0.0);
    if (outside > 0.0001) {
        n = s * o / outside;
    } else if (q.x > q.y) {
        n = vec2(s.x, 0.0);
    } else {
        n = vec2(0.0, s.y);
    }

    float depth = -dist;
    float displacement = 0.0;
    float thick = max(ubuf.thickness, 2.0);
    if (ubuf.strength > 0.001 && depth < thick) {
        float e = 1.0 - depth / thick;
        float smoothed = e * e * (3.0 - 2.0 * e);
        displacement = ubuf.strength * thick * pow(smoothed, ubuf.profile);
    }

    // Chaque couleur est déviée un peu différemment : franges colorées.
    vec2 offset = n * displacement / ubuf.regionSize;
    float kr = 1.0 + ubuf.dispersion * 0.4 * -1.0;
    float kb = 1.0 + ubuf.dispersion * 0.4 * 1.0;
    vec4 sr = texture(source, qt_TexCoord0 + offset * kr);
    vec4 sg = texture(source, qt_TexCoord0 + offset);
    vec4 sb = texture(source, qt_TexCoord0 + offset * kb);
    vec3 rgb = vec3(sr.r, sg.g, sb.b);
    float alpha = sg.a;

    if (ubuf.rim > 0.0) {
        // Reflet : plus vif sur les bords tournés vers le haut gauche.
        float glow = exp(-depth / 2.5);
        float facing = abs(n.x * -0.5 + n.y * -0.85);
        float add = clamp(ubuf.rim * 0.35 * glow * (0.3 + 0.7 * facing), 0.0, 1.0);
        rgb += (vec3(alpha) - rgb) * add;
    }

    fragColor = vec4(rgb, alpha) * coverage * ubuf.qt_Opacity;
}
