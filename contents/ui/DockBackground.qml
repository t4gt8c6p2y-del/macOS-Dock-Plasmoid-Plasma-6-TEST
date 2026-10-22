pragma ComponentBehavior: Bound

import QtQuick
import org.kde.kirigami as Kirigami

Kirigami.ShadowedRectangle {
    id: background

    property real surfaceOpacity: 0.55
    property bool useThemeColor: true
    property color customColor: "#20242b"
    property real requestedRadius: Kirigami.Units.cornerRadius * 2
    // Ancien réglage de bordure (opacité). Il ne sert plus qu'à déduire la
    // part éclairée tant que borderStrength n'a pas été réglé.
    property real borderOpacity: 0.22
    // Intensité de la bordure : 0 = aucune bordure, 1 = bordure pleine.
    // (Le nom borderStrength est conservé pour la compatibilité.)
    property real borderStrength: Math.min(1, Math.max(0, borderOpacity / 0.5))
    property real shadowOpacity: 0.42
    // L'ombre portée de ShadowedRectangle est dessinée sous le fond : comme
    // celui-ci est translucide, elle transparaît à l'intérieur et forme un
    // liseré sombre le long des bords. Les fenêtres du dock ont exactement la
    // taille du fond, l'ombre n'y a de toute façon pas la place de s'afficher.
    property bool showShadow: true
    property bool showHighlight: true
    // Intensité du reflet vitré : 1 = rendu d'origine, 0 = aucun reflet.
    property real highlightStrength: 1.0

    // Éclairage de la bordure. La lumière suit le pointeur quand il survole
    // le fond (lightActive) ; au repos elle est posée en haut à gauche. Une
    // seconde lumière, plus faible, se trouve au point opposé.
    property bool lightActive: false
    property real lightX: width / 2
    property real lightY: height / 2

    // Réglage de flou (0 = désactivé). Le flou lui-même est fait par KWin
    // (voir BlurRegion dans main.qml) : il floute tout ce qui se trouve
    // derrière le Dock, fenêtres comprises. Cette propriété n'est conservée
    // que pour que les fenêtres qui l'utilisent n'aient rien à changer.
    property real wallpaperBlur: 0
    // Image du fond d'écran (voir main.qml) : { source, fillMode, width, height }.
    // Elle ne sert plus qu'à teinter la bordure.
    property var wallpaperInfo: ({ "source": "", "fillMode": 2,
        "width": 0, "height": 0 })
    // WallpaperLocator (module natif) : sert à lire la couleur du fond d'écran
    // derrière le Dock pour teinter la bordure. null = bordure blanche.
    property var colorSampler: null
    // Position (en pixels écran) du coin supérieur gauche de ce fond.
    property point backdropOrigin: Qt.point(0, 0)

    readonly property color themeBackground: qtPalette.window
    readonly property color themeText: qtPalette.windowText
    readonly property color effectiveColor: useThemeColor
        ? themeBackground : customColor
    readonly property real effectiveLuminance: 0.2126 * effectiveColor.r
        + 0.7152 * effectiveColor.g + 0.0722 * effectiveColor.b

    function highlightAlpha(base) {
        return Math.min(1, Math.max(0, base * highlightStrength));
    }

    SystemPalette {
        id: qtPalette

        colorGroup: SystemPalette.Active
    }

    radius: Math.min(Math.max(0, requestedRadius),
        Math.min(width, height) / 2)
    color: Qt.rgba(effectiveColor.r, effectiveColor.g,
        effectiveColor.b, Math.min(1, Math.max(0,
            surfaceOpacity * effectiveColor.a)))

    // La bordure est dessinée par le contour éclairé plus bas, pas par la
    // bordure unie de ShadowedRectangle.
    border.width: 0

    shadow.xOffset: 0
    shadow.yOffset: showShadow ? 2 : 0
    shadow.size: showShadow ? 10 : 0
    shadow.color: showShadow
        ? Qt.rgba(0, 0, 0, Math.min(1, Math.max(0, shadowOpacity)))
        : "transparent"

    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: Math.max(0, background.radius - 1)
        color: "transparent"
        visible: background.showHighlight
            && background.highlightStrength > 0.001

        gradient: Gradient {
            orientation: Gradient.Vertical

            GradientStop {
                position: 0
                color: Qt.rgba(1, 1, 1, background.highlightAlpha(0.14))
            }

            GradientStop {
                position: 0.55
                color: Qt.rgba(1, 1, 1, background.highlightAlpha(0.025))
            }

            GradientStop {
                position: 1
                color: Qt.rgba(0, 0, 0, background.highlightAlpha(0.08))
            }
        }
    }

    // --- Bordure ---------------------------------------------------------
    // La bordure est un simple Rectangle à contour : son opacité est
    // l'intensité réglée et son épaisseur la largeur réglée. Aucun effet,
    // aucun masque : le rendu est identique sur toutes les configurations
    // graphiques et chaque réglage se voit immédiatement.
    //
    // La lumière qui suit le pointeur est dessinée à part (lightCanvas) par-
    // dessus ; si elle ne pouvait pas s'afficher, la bordure resterait visible.
    //
    // Intensité de la lumière qui suit le pointeur : 0 = aucune lumière,
    // 1 = rendu d'origine, 2 = le double.
    property real lightIntensity: 1.0
    // Largeur de la bordure en pixels.
    property real borderWidth: 1.0

    readonly property real borderIntensity:
        Math.min(1, Math.max(0, borderStrength))
    readonly property real ringWidth: Math.min(6, Math.max(0.25, borderWidth))
    readonly property bool ringVisible:
        borderIntensity > 0.001 && borderWidth > 0.01
    // 100 % = bordure presque opaque ; 0 % = aucune bordure.
    readonly property real ringAlpha: 0.9 * borderIntensity
    readonly property color ringColor: tintKnown ? tintColor : "white"

    // La lumière : un halo qui glisse le long de la bordure.
    readonly property real lightRadius:
        Math.max(80, Math.min(0.4 * width, 300))
    readonly property bool lightEnabled: lightIntensity > 0.001
    // Opacité maximale de la lumière : elle suit aussi l'intensité de la
    // bordure pour qu'une bordure très discrète le reste.
    readonly property real lightGain:
        0.7 * lightIntensity * (0.3 + 0.7 * borderIntensity)
    readonly property real restX: -0.1 * width
    readonly property real restY: -0.3 * height

    readonly property bool lightFollows: lightEnabled && lightActive
    property real fadeValue: lightFollows ? 1.0 : 0.0

    Behavior on fadeValue {
        NumberAnimation {
            duration: 220
            easing.type: Easing.OutCubic
        }
    }

    readonly property real primaryX: restX + (lightX - restX) * fadeValue
    readonly property real primaryY: restY + (lightY - restY) * fadeValue
    readonly property real secondaryX: width - primaryX
    readonly property real secondaryY: height - primaryY

    // --- Teinte de la bordure -------------------------------------------------
    // Couleur moyenne du fond d'écran derrière le Dock, ramenée à pleine
    // luminosité puis éclaircie. Tant qu'elle est inconnue (ou si le fond est
    // gris), la bordure reste blanche. Elle est appliquée en une fois à l'effet
    // final (colorization) : aucun calque supplémentaire.
    property color tintColor: Qt.rgba(1, 1, 1, 1)
    property bool tintKnown: false

    function refreshTint() {
        var colors = [];
        if (colorSampler && wallpaperInfo && wallpaperInfo.source
                && width >= 8 && height >= 8) {
            try {
                colors = colorSampler.sampleColors(
                    String(wallpaperInfo.source), wallpaperInfo.fillMode,
                    wallpaperInfo.width, wallpaperInfo.height,
                    backdropOrigin.x, backdropOrigin.y, width, height, 1, 1);
            } catch (error) {
                colors = [];
            }
        }
        if (!colors || colors.length < 1) {
            tintKnown = false;
            return;
        }
        var c = colors[0];
        var peak = Math.max(c.r, c.g, c.b);
        if (peak < 0.02) {
            tintKnown = false;
            return;
        }
        var k = 1 / peak;
        tintColor = Qt.rgba(c.r * k * 0.72 + 0.28, c.g * k * 0.72 + 0.28,
            c.b * k * 0.72 + 0.28, 1);
        tintKnown = true;
    }

    // Les mesures sont regroupées : le Dock bouge et se redimensionne souvent.
    Timer {
        id: tintTimer

        interval: 500
        repeat: false
        onTriggered: background.refreshTint()
    }

    onWallpaperInfoChanged: tintTimer.restart()
    onColorSamplerChanged: tintTimer.restart()
    onBackdropOriginChanged: tintTimer.restart()
    Component.onCompleted: tintTimer.restart()

    Rectangle {
        id: ringRectangle

        anchors.fill: parent
        visible: background.ringVisible
        color: "transparent"
        radius: background.radius
        border.width: background.ringWidth
        border.color: Qt.rgba(background.ringColor.r, background.ringColor.g,
            background.ringColor.b, background.ringAlpha)
    }

    Canvas {
        id: lightCanvas

        anchors.fill: parent
        visible: background.ringVisible && background.lightEnabled
        renderTarget: Canvas.Image
        renderStrategy: Canvas.Cooperative

        readonly property real pixelRatio: Math.max(1, Screen.devicePixelRatio)
        canvasSize: Qt.size(Math.max(1, Math.round(width * pixelRatio)),
            Math.max(1, Math.round(height * pixelRatio)))

        // Tout ce qui change l'aspect de la lumière : un seul signal pour
        // redessiner.
        readonly property string paintKey: [
            background.primaryX.toFixed(1), background.primaryY.toFixed(1),
            background.lightGain.toFixed(3), background.ringWidth.toFixed(2),
            background.radius.toFixed(1), background.lightRadius.toFixed(1),
            String(background.ringColor)
        ].join("|")

        onPaintKeyChanged: requestPaint()
        onCanvasSizeChanged: requestPaint()
        onVisibleChanged: {
            if (visible) {
                requestPaint();
            }
        }
        Component.onCompleted: requestPaint()

        function roundedPath(ctx, x, y, w, h, r) {
            r = Math.max(0, Math.min(r, Math.min(w, h) / 2));
            ctx.beginPath();
            if (r < 0.01) {
                ctx.rect(x, y, w, h);
                return;
            }
            ctx.moveTo(x + r, y);
            ctx.lineTo(x + w - r, y);
            ctx.arc(x + w - r, y + r, r, -Math.PI / 2, 0, false);
            ctx.lineTo(x + w, y + h - r);
            ctx.arc(x + w - r, y + h - r, r, 0, Math.PI / 2, false);
            ctx.lineTo(x + r, y + h);
            ctx.arc(x + r, y + h - r, r, Math.PI / 2, Math.PI, false);
            ctx.lineTo(x, y + r);
            ctx.arc(x + r, y + r, r, Math.PI, 1.5 * Math.PI, false);
            ctx.closePath();
        }

        function strokeLight(ctx, cx, cy, peak) {
            var color = background.ringColor;
            var red = Math.round(color.r * 255);
            var green = Math.round(color.g * 255);
            var blue = Math.round(color.b * 255);
            var radius = background.lightRadius;
            var gradient = ctx.createRadialGradient(cx, cy, 0, cx, cy, radius);
            var positions = [0, 0.1, 0.22, 0.4, 0.65, 1];
            for (var i = 0; i < positions.length; ++i) {
                var p = positions[i];
                // Chute de la lumière : exp(-3 d), d allant de 0 (centre)
                // à 1 (bord du halo, où elle s'éteint).
                var alpha = p >= 1 ? 0 : Math.min(1, peak * Math.exp(-3 * p));
                gradient.addColorStop(p, "rgba(" + red + "," + green + ","
                    + blue + "," + alpha.toFixed(3) + ")");
            }
            var half = background.ringWidth / 2;
            ctx.strokeStyle = gradient;
            ctx.lineWidth = background.ringWidth;
            roundedPath(ctx, half, half, background.width - 2 * half,
                background.height - 2 * half, background.radius - half);
            ctx.stroke();
        }

        onPaint: {
            var ctx = getContext("2d");
            if (!ctx) {
                return;
            }
            ctx.setTransform(1, 0, 0, 1, 0, 0);
            ctx.clearRect(0, 0, canvasSize.width, canvasSize.height);
            if (!background.ringVisible || !background.lightEnabled
                    || width < 4 || height < 4) {
                return;
            }
            var scale = canvasSize.width / width;
            ctx.scale(scale, scale);
            strokeLight(ctx, background.primaryX, background.primaryY,
                background.lightGain);
            strokeLight(ctx, background.secondaryX, background.secondaryY,
                0.9 * background.lightGain);
        }
    }
}
