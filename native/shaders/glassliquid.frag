#version 440

// Liquid Glass du menu d'applications du Spotlight.
//
// Porté du dépôt liquidglass-kde-widgets (liquidglass.frag), lui-même inspiré de
// iyinchao/liquid-glass-studio :
//   * forme : rectangle à coins « squircle » (superellipse), distance signée
//     et normale calculées analytiquement ;
//   * réfraction des bords par la loi de Snell sur un dôme :
//         sin(thetaI) = (1 - t)^2    avec t = 0..1 dans la bande du bord
//         thetaT      = asin(sin(thetaI) / indice)
//         décalage    = tan(thetaI - thetaT)
//     l'image floutée est lue plus à l'intérieur, d'autant plus près du bord ;
//   * franges de couleur : le rouge et le bleu sont lus un peu plus loin ;
//   * reflet des bords : fin liseré clair + reflet de coin qui suit le curseur
//     (et un second, symétrique, plus faible) ;
//   * liseré coloré optionnel pris dans ce qui est derrière (réglages du bord).
//
// L'image lue (« source ») est la scène floutée (fond d'écran et fenêtres) avec
// une marge autour du verre : qt_TexCoord0 couvre la zone lue, le verre est au
// centre. Compilé par install.sh avec « qsb --qt6 ».

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    // Taille de la zone lue (le verre plus sa marge) et du verre, en pixels.
    vec2 regionSize;
    vec2 glassSize;
    // Rayon des coins (px) et exposant de la superellipse : 2 = cercle,
    // 5 environ = squircle iOS.
    float glassRadius;
    float glassRoundness;
    // Bande de réfraction du bord (px), indice du verre, force (px de
    // décalage maximal), franges de couleur 0..1.
    float refractThickness;
    float refractIOR;
    float refractScale;
    float chromaStrength;
    // Teinte posée sur le verre : rgb + opacité.
    vec4 tint;
    // Curseur en coordonnées locales 0..1 (-1 = absent), fondu 0..1, intensité
    // du reflet des bords 0..1.
    vec2 mousePos;
    float mouseFade;
    float specStrength;
    // Liseré coloré : largeur (px) et intensité (0 = aucun).
    float ringWidth;
    float ringStrength;
} ubuf;

layout(binding = 1) uniform sampler2D source;

// Distance signée au squircle et normale sortante : vec3(d, nx, ny).
vec3 shapeSDF(vec2 p)
{
    vec2 b = ubuf.glassSize * 0.5;
    float n = max(ubuf.glassRoundness, 2.0);
    float r = clamp(ubuf.glassRadius, 0.0, min(b.x, b.y));

    vec2 q = abs(p) - b + vec2(r);
    float qx = max(q.x, 0.0);
    float qy = max(q.y, 0.0);

    float d;
    vec2 nrm;

    if (qx <= 0.0 && qy <= 0.0) {
        // Intérieur : le bord le plus proche est droit.
        d = max(q.x, q.y) - r;
        nrm = q.x >= q.y ? vec2(1.0, 0.0) : vec2(0.0, 1.0);
    } else if (qx == 0.0) {
        d = qy - r;
        nrm = vec2(0.0, 1.0);
    } else if (qy == 0.0) {
        d = qx - r;
        nrm = vec2(1.0, 0.0);
    } else {
        // Coin : norme p de la superellipse et gradient analytique.
        float arc = pow(pow(qx, n) + pow(qy, n), 1.0 / n);
        float gx = pow(qx / arc, n - 1.0);
        float gy = pow(qy / arc, n - 1.0);
        float gradLen = max(sqrt(gx * gx + gy * gy), 0.001);
        d = (arc - r) / gradLen;
        nrm = vec2(gx, gy) / gradLen;
    }

    // q utilise abs(p) : on rend à la normale le signe de p.
    vec2 sg = vec2(p.x < 0.0 ? -1.0 : 1.0, p.y < 0.0 ? -1.0 : 1.0);
    nrm *= sg;
    return vec3(d, nrm);
}

vec3 sampleSource(vec2 uv)
{
    return texture(source, clamp(uv, vec2(0.0), vec2(1.0))).rgb;
}

// Reflet de coin : une source principale suit le curseur (au repos, en bas à
// gauche), une seconde apparaît à l'opposé à 65 % ; chacune s'atténue de façon
// exponentielle avec la distance.
vec3 cornerSpec(vec2 p, float depthPx)
{
    if (ubuf.specStrength <= 0.0) {
        return vec3(0.0);
    }

    const float MAX_STROKE_PX = 3.0;
    const float FEATHER_PX = 2.0;
    const float SECONDARY_INT = 0.65;

    vec2 b = ubuf.glassSize * 0.5;
    vec2 restLight = vec2(-b.x, b.y) * 1.2;
    bool hovering = ubuf.mouseFade > 0.0 && ubuf.mousePos.x >= 0.0
        && ubuf.mousePos.y >= 0.0;
    vec2 cursorPx = (ubuf.mousePos - vec2(0.5)) * ubuf.glassSize;
    vec2 lightPx = hovering ? mix(restLight, cursorPx, ubuf.mouseFade) : restLight;
    vec2 antiLight = -lightPx;

    float taper = max(ubuf.glassSize.x, ubuf.glassSize.y) * 0.7;
    float primaryAtt = exp(-distance(p, lightPx) / taper);
    float secondaryAtt = exp(-distance(p, antiLight) / taper) * SECONDARY_INT;

    float tPx = max(primaryAtt, secondaryAtt) * MAX_STROKE_PX;
    float stroke = 1.0 - smoothstep(tPx - FEATHER_PX, tPx, depthPx);

    float intensity = stroke * ubuf.specStrength * 0.55;
    return vec3(1.0, 0.98, 0.94) * intensity;
}

// Fin liseré clair sur tout le contour, plus vif côté haut gauche.
vec3 edgeSpec(vec2 ndir, float depthPx)
{
    if (ubuf.specStrength <= 0.0) {
        return vec3(0.0);
    }

    float lip = 1.0 - smoothstep(0.0, 3.0, max(depthPx, 0.0));
    vec2 lightDir = normalize(vec2(-0.45, 0.90));
    float facing = 0.35 + 0.65 * clamp(dot(ndir, lightDir) * 0.5 + 0.5, 0.0, 1.0);
    float intensity = lip * facing * ubuf.specStrength * 0.10;
    return vec3(1.0, 0.98, 0.94) * intensity;
}

void main()
{
    vec2 uv = qt_TexCoord0;
    vec2 p = (uv - vec2(0.5)) * ubuf.regionSize;
    vec3 dn = shapeSDF(p);
    float d = dn.x;
    vec2 ndir = dn.yz;

    // Hors de la forme (au-delà du fondu du bord) : transparent.
    if (d > 1.5) {
        fragColor = vec4(0.0);
        return;
    }

    float depthPx = -d;
    vec3 col;

    if (ubuf.refractThickness <= 0.0 || depthPx >= ubuf.refractThickness) {
        // Intérieur : verre plat, l'image floutée telle quelle.
        col = sampleSource(uv);
    } else {
        // Bande du bord : Snell sur un dôme. t est borné pour que la fine
        // bande de fondu (d > 0) reste valide ; le masque final l'estompe.
        float t = clamp(depthPx / ubuf.refractThickness, 0.0, 1.0);
        float sinThetaI = (1.0 - t) * (1.0 - t);
        float thetaI = asin(clamp(sinThetaI, 0.0, 1.0));
        float sinThetaT = sinThetaI / max(ubuf.refractIOR, 1.0);
        float thetaT = asin(clamp(sinThetaT, 0.0, 1.0));
        float edgeMag = tan(thetaI - thetaT);

        vec2 displaceUV = -ndir * edgeMag * ubuf.refractScale / ubuf.regionSize;

        float edgeWeight = 1.0 - t;
        float chromaPx = ubuf.chromaStrength * ubuf.refractThickness * 0.35 * edgeWeight;
        vec2 chromaUV = -ndir * chromaPx / ubuf.regionSize;

        col.r = sampleSource(uv + displaceUV + chromaUV).r;
        col.g = sampleSource(uv + displaceUV).g;
        col.b = sampleSource(uv + displaceUV - chromaUV).b;
    }

    vec3 backdrop = col;
    col = mix(col, ubuf.tint.rgb, clamp(ubuf.tint.a, 0.0, 1.0));

    if (ubuf.ringStrength > 0.0 && ubuf.ringWidth > 0.0) {
        // Liseré : chaque point prend la couleur de ce qui est derrière,
        // saturée et lumineuse ; un fond gris donne un liseré blanc.
        float m = clamp(ubuf.ringWidth - depthPx, 0.0, 1.0);
        float mx = max(backdrop.r, max(backdrop.g, backdrop.b));
        vec3 c = backdrop / max(mx, 0.05);
        float l = dot(c, vec3(0.299, 0.587, 0.114));
        c = clamp(mix(vec3(l), c, 1.4), 0.0, 1.0) * 0.95;
        col = mix(col, c, m * clamp(ubuf.ringStrength, 0.0, 1.0));
    }

    col += edgeSpec(ndir, depthPx);
    col += cornerSpec(p, depthPx);

    // Fondu de ~1 px centré sur le bord géométrique. Qt attend de l'alpha
    // prémultiplié : la couleur est multipliée par le masque.
    float mask = 1.0 - smoothstep(-0.5, 0.5, d);
    fragColor = vec4(col * mask, mask) * ubuf.qt_Opacity;
}
