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
    // La bordure est faite de pièces simples (Rectangle, dégradés) : aucun
    // effet, aucun masque, aucun Canvas. Le rendu est donc le même sur toutes
    // les configurations graphiques.
    //  - Intensité : opacité de la bordure.
    //  - Largeur : épaisseur du trait.
    //  - Couleur : chaque partie prend la couleur du fond d'écran qui se
    //    trouve derrière elle (désactivable : bordure blanche).
    //  - Lumière : deux halos blancs qui glissent le long de la bordure et
    //    suivent le pointeur.
    //
    // Intensité de la lumière qui suit le pointeur : 0 = aucune lumière,
    // 1 = rendu d'origine, 2 = le double.
    property real lightIntensity: 1.0
    // Largeur de la bordure en pixels.
    property real borderWidth: 1.0
    // Couleur de la bordure : celle du fond d'écran derrière chaque partie.
    property bool colorFromWallpaper: true

    readonly property real borderIntensity:
        Math.min(1, Math.max(0, borderStrength))
    readonly property real ringWidth: Math.min(6, Math.max(0.25, borderWidth))
    // Un trait de moins d'un pixel est dessiné à un pixel, moins opaque.
    readonly property real drawnWidth: Math.max(1, ringWidth)
    readonly property real ringAlpha:
        0.75 * borderIntensity * Math.min(1, ringWidth)
    // Largeur des extrémités arrondies ; les côtés droits sont entre elles.
    readonly property real capWidth:
        Math.ceil(Math.max(radius, drawnWidth))
    readonly property real edgeWidth: Math.max(0, width - 2 * capWidth)

    // La lumière.
    readonly property real lightRadius:
        Math.max(80, Math.min(0.4 * width, 300))
    readonly property bool lightEnabled: lightIntensity > 0.001
    readonly property real lightPeak: lightEnabled
        ? Math.min(1, 0.8 * lightIntensity) : 0
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
    // La seconde lumière, plus faible, est au point opposé.
    readonly property real secondaryX: width - primaryX
    readonly property real secondaryY: height - primaryY
    readonly property real secondaryScale: 0.6

    // Force d'un halo sur un côté droit : plus le pointeur est loin du côté
    // (en hauteur), plus la lumière est faible.
    function edgeLight(pointerY, edgeY, scale) {
        return lightPeak * scale
            * Math.exp(-2.5 * Math.abs(pointerY - edgeY) / lightRadius);
    }

    // Force de la lumière sur une extrémité, selon sa distance au pointeur.
    function capLight(pointerX, pointerY, centerX, centerY, scale) {
        var dx = pointerX - centerX;
        var dy = pointerY - centerY;
        var distance = Math.sqrt(dx * dx + dy * dy);
        return lightPeak * scale
            * Math.exp(-3 * Math.min(1, distance / lightRadius));
    }

    // --- Couleurs de la bordure ----------------------------------------------
    // Le fond d'écran derrière le Dock est découpé en colorColumns zones, de
    // gauche à droite ; chaque zone donne la couleur de la bordure à cet
    // endroit (ramenée à pleine luminosité puis éclaircie). Tant que les
    // couleurs sont inconnues, ou si l'option est désactivée, la bordure est
    // blanche.
    readonly property int colorColumns: 16
    property var edgeColors: []

    function refreshTint() {
        var colors = [];
        if (colorFromWallpaper && colorSampler && wallpaperInfo
                && wallpaperInfo.source && width >= 8 && height >= 8) {
            try {
                colors = colorSampler.sampleColors(
                    String(wallpaperInfo.source), wallpaperInfo.fillMode,
                    wallpaperInfo.width, wallpaperInfo.height,
                    backdropOrigin.x, backdropOrigin.y, width, height,
                    colorColumns, 1);
            } catch (error) {
                colors = [];
            }
        }
        if (!colors || colors.length < colorColumns) {
            edgeColors = [];
            return;
        }
        var result = [];
        for (var i = 0; i < colorColumns; ++i) {
            var c = colors[i];
            var peak = Math.max(c.r, c.g, c.b);
            if (peak < 0.02) {
                result.push(Qt.rgba(1, 1, 1, 1));
            } else {
                var k = 1 / peak;
                result.push(Qt.rgba(c.r * k * 0.72 + 0.28,
                    c.g * k * 0.72 + 0.28, c.b * k * 0.72 + 0.28, 1));
            }
        }
        edgeColors = result;
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
    onColorFromWallpaperChanged: refreshTint()
    Component.onCompleted: tintTimer.restart()

    // Côté haut.
    BorderEdge {
        x: background.capWidth
        y: 0
        width: background.edgeWidth
        height: background.drawnWidth
        colors: background.edgeColors
        baseOpacity: background.ringAlpha
        lightRadius: background.lightRadius
        lightX1: background.primaryX - background.capWidth
        lightStrength1: background.edgeLight(background.primaryY, 0, 1)
        lightX2: background.secondaryX - background.capWidth
        lightStrength2: background.edgeLight(background.secondaryY, 0,
            background.secondaryScale)
    }

    // Côté bas.
    BorderEdge {
        x: background.capWidth
        y: background.height - background.drawnWidth
        width: background.edgeWidth
        height: background.drawnWidth
        colors: background.edgeColors
        baseOpacity: background.ringAlpha
        lightRadius: background.lightRadius
        lightX1: background.primaryX - background.capWidth
        lightStrength1: background.edgeLight(background.primaryY,
            background.height, 1)
        lightX2: background.secondaryX - background.capWidth
        lightStrength2: background.edgeLight(background.secondaryY,
            background.height, background.secondaryScale)
    }

    // Extrémité gauche.
    BorderCap {
        x: 0
        y: 0
        width: background.capWidth
        height: background.height
        leftSide: true
        fullWidth: background.width
        ringRadius: background.radius
        ringWidth: background.drawnWidth
        ringColor: background.edgeColors.length > 0
            ? background.edgeColors[0] : "white"
        baseOpacity: background.ringAlpha
        lightStrength: background.capLight(background.primaryX,
                background.primaryY, background.capWidth / 2,
                background.height / 2, 1)
            + background.capLight(background.secondaryX,
                background.secondaryY, background.capWidth / 2,
                background.height / 2, background.secondaryScale)
    }

    // Extrémité droite.
    BorderCap {
        x: background.width - background.capWidth
        y: 0
        width: background.capWidth
        height: background.height
        leftSide: false
        fullWidth: background.width
        ringRadius: background.radius
        ringWidth: background.drawnWidth
        ringColor: background.edgeColors.length > 0
            ? background.edgeColors[background.edgeColors.length - 1]
            : "white"
        baseOpacity: background.ringAlpha
        lightStrength: background.capLight(background.primaryX,
                background.primaryY, background.width - background.capWidth / 2,
                background.height / 2, 1)
            + background.capLight(background.secondaryX,
                background.secondaryY,
                background.width - background.capWidth / 2,
                background.height / 2, background.secondaryScale)
    }
}
