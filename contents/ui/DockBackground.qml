pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
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
    // Part de la bordure qui est éclairée : 0 = aucune bordure, 1 = bordure
    // éclairée sur tout le tour.
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

    // Flou réel du fond d'écran (0 = désactivé). backdropOrigin est la
    // position (en pixels écran) du coin supérieur gauche de ce fond.
    property real wallpaperBlur: 0
    // Image du fond d'écran (voir main.qml) : { source, fillMode, width, height }
    property var wallpaperInfo: ({ "source": "", "fillMode": 2,
        "width": 0, "height": 0 })
    // WallpaperLocator (module natif) : sert à lire les couleurs du fond
    // d'écran derrière le Dock pour teinter la bordure. null = bordure blanche.
    property var colorSampler: null
    property point backdropOrigin: Qt.point(0, 0)
    // Vrai quand l'image floutée du fond d'écran est chargée et affichée.
    // main.qml s'en sert pour demander le flou de KWin quand ce n'est pas le
    // cas (fond non trouvé), afin que le réglage ait toujours un effet.
    readonly property bool backdropReady: backdropLoader.item !== null
        && Boolean(backdropLoader.item["ready"])

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

    // Flou du fond d'écran : chargé seulement quand il est demandé, pour
    // qu'une erreur éventuelle dans ce composant ne touche pas le reste du
    // Dock.
    Loader {
        id: backdropLoader

        // z négatif : dessiné sous la couleur de fond translucide.
        z: -1
        anchors.fill: parent
        active: background.wallpaperBlur > 0.001
        source: "WallpaperBackdrop.qml"

        Binding {
            target: backdropLoader.item
            property: "strength"
            value: background.wallpaperBlur
            when: backdropLoader.item !== null
        }

        Binding {
            target: backdropLoader.item
            property: "info"
            value: background.wallpaperInfo
            when: backdropLoader.item !== null
        }

        Binding {
            target: backdropLoader.item
            property: "origin"
            value: background.backdropOrigin
            when: backdropLoader.item !== null
        }

        Binding {
            target: backdropLoader.item
            property: "cornerRadius"
            value: background.radius
            when: backdropLoader.item !== null
        }
    }

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

    // --- Contour éclairé ---------------------------------------------------
    // Un filet d'un pixel, continu sur tout le tour, comme le bord d'une vitre.
    // Il est modulé par un masque : un niveau de base (litFloor) partout, plus
    // une lumière qui suit le pointeur et une seconde, au point opposé, aussi
    // vive. borderStrength règle la PART du tour qui est éclairée : à 0 il n'y
    // a plus de bordure, à 1 tout le tour est éclairé uniformément.
    //
    // Le filet est dessiné une fois (une seule forme) ; seul le masque bouge,
    // ce qui est très léger pour le GPU : la lumière suit la souris en
    // continu, sans attendre qu'elle s'arrête. Sa couleur est un dégradé
    // calculé à partir du fond d'écran derrière le Dock (voir tintColor) :
    // la bordure brille de la couleur de l'arrière-plan.
    // Faux : la lumière reste à sa position de repos au lieu de suivre le
    // pointeur.
    property bool followMouse: true

    readonly property real ringThickness: 1.0
    readonly property real litShare: Math.min(1, Math.max(0, borderStrength))
    readonly property real perimeter: 2 * (width + height)
    // Étalement de la lumière : plus la part éclairée est grande, plus elle
    // couvre de bordure.
    readonly property real taper: Math.max(1, litShare * perimeter / 5.5)
    readonly property real lightRadius: Math.max(8, 3 * taper)
    // Niveau de base de la bordure : très discret, puis il monte jusqu'à 1
    // (bordure uniforme) quand la part éclairée approche 100 %.
    readonly property real litFloor: 0.15 * litShare
        + 0.85 * Math.pow(litShare, 8)
    // Les reflets dépassent le niveau de base d'une part fixe du reste.
    readonly property real lightGain: 0.7
    readonly property real restX: -0.1 * width
    readonly property real restY: -0.3 * height

    readonly property bool lightFollows: followMouse && lightActive
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
    // Couleurs du fond d'écran le long du Dock (tintStopCount mesures). Le
    // dégradé suit l'axe long du Dock.
    readonly property int tintStopCount: 12
    readonly property bool tintVertical: height > width
    property var tintColors: []

    function refreshTintColors() {
        if (!colorSampler || !wallpaperInfo || !wallpaperInfo.source
                || width < 8 || height < 8) {
            tintColors = [];
            return;
        }
        var colors = [];
        try {
            colors = colorSampler.sampleColors(String(wallpaperInfo.source),
                wallpaperInfo.fillMode, wallpaperInfo.width,
                wallpaperInfo.height, backdropOrigin.x, backdropOrigin.y,
                width, height, tintVertical ? 1 : tintStopCount,
                tintVertical ? tintStopCount : 1);
        } catch (error) {
            colors = [];
        }
        tintColors = colors || [];
    }

    // Les mesures sont regroupées : le Dock bouge et se redimensionne souvent.
    Timer {
        id: tintTimer

        interval: 250
        repeat: false
        onTriggered: background.refreshTintColors()
    }

    onWallpaperInfoChanged: tintTimer.restart()
    onColorSamplerChanged: tintTimer.restart()
    onBackdropOriginChanged: tintTimer.restart()
    onWidthChanged: tintTimer.restart()
    onHeightChanged: tintTimer.restart()
    Component.onCompleted: tintTimer.restart()

    // Couleur du dégradé au point « index » : la teinte du fond d'écran,
    // ramenée à pleine luminosité puis éclaircie (blanc si le fond est gris).
    function tintColor(index) {
        var list = tintColors;
        if (!list || list.length < tintStopCount) {
            return Qt.rgba(1, 1, 1, 1);
        }
        var c = list[index];
        var peak = Math.max(c.r, c.g, c.b);
        if (peak < 0.02) {
            return Qt.rgba(1, 1, 1, 1);
        }
        var k = 1 / peak;
        return Qt.rgba(c.r * k * 0.72 + 0.28, c.g * k * 0.72 + 0.28,
            c.b * k * 0.72 + 0.28, 1);
    }

    function roundedRectPath(x, y, w, h, r) {
        r = Math.max(0, Math.min(r, Math.min(w, h) / 2));
        if (r < 0.01) {
            return "M" + x + "," + y + " H" + (x + w) + " V" + (y + h)
                + " H" + x + " Z";
        }
        return "M" + (x + r) + "," + y
            + " H" + (x + w - r)
            + " A" + r + "," + r + " 0 0 1 " + (x + w) + "," + (y + r)
            + " V" + (y + h - r)
            + " A" + r + "," + r + " 0 0 1 " + (x + w - r) + "," + (y + h)
            + " H" + (x + r)
            + " A" + r + "," + r + " 0 0 1 " + x + "," + (y + h - r)
            + " V" + (y + r)
            + " A" + r + "," + r + " 0 0 1 " + (x + r) + "," + y + " Z";
    }

    readonly property string ringPath: width > 4 && height > 4
        ? roundedRectPath(0, 0, width, height, radius) + " "
            + roundedRectPath(ringThickness, ringThickness,
                width - 2 * ringThickness, height - 2 * ringThickness,
                radius - ringThickness)
        : ""

    // Chute de la lumière : exp(-3 d), d allant de 0 (centre) à 1 (bord).
    function lightAlpha(position, strength) {
        return strength * Math.exp(-3 * position);
    }

    Item {
        id: glow

        anchors.fill: parent
        visible: background.litShare > 0.001

        // Le filet : teinté, opaque, jamais affiché tel quel.
        Item {
            id: ringSource

            anchors.fill: parent
            layer.enabled: true
            visible: false

            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    fillRule: ShapePath.OddEvenFill
                    strokeWidth: -1
                    strokeColor: "transparent"

                    fillGradient: LinearGradient {
                        x1: 0
                        y1: 0
                        x2: background.tintVertical ? 0 : background.width
                        y2: background.tintVertical ? background.height : 0

                        GradientStop {
                            position: 0.0
                            color: background.tintColor(0)
                        }
                        GradientStop {
                            position: 0.090909
                            color: background.tintColor(1)
                        }
                        GradientStop {
                            position: 0.181818
                            color: background.tintColor(2)
                        }
                        GradientStop {
                            position: 0.272727
                            color: background.tintColor(3)
                        }
                        GradientStop {
                            position: 0.363636
                            color: background.tintColor(4)
                        }
                        GradientStop {
                            position: 0.454545
                            color: background.tintColor(5)
                        }
                        GradientStop {
                            position: 0.545455
                            color: background.tintColor(6)
                        }
                        GradientStop {
                            position: 0.636364
                            color: background.tintColor(7)
                        }
                        GradientStop {
                            position: 0.727273
                            color: background.tintColor(8)
                        }
                        GradientStop {
                            position: 0.818182
                            color: background.tintColor(9)
                        }
                        GradientStop {
                            position: 0.909091
                            color: background.tintColor(10)
                        }
                        GradientStop {
                            position: 1.0
                            color: background.tintColor(11)
                        }
                    }

                    PathSvg {
                        path: background.ringPath
                    }
                }
            }
        }

        // Le masque : niveau de base + deux lumières.
        Item {
            id: lightMask

            anchors.fill: parent
            layer.enabled: true
            visible: false

            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(1, 1, 1, background.litFloor)
            }

            Shape {
                x: background.primaryX - background.lightRadius
                y: background.primaryY - background.lightRadius
                width: 2 * background.lightRadius
                height: 2 * background.lightRadius

                ShapePath {
                    strokeWidth: -1
                    strokeColor: "transparent"

                    fillGradient: RadialGradient {
                        centerX: background.lightRadius
                        centerY: background.lightRadius
                        centerRadius: background.lightRadius
                        focalX: background.lightRadius
                        focalY: background.lightRadius

                        GradientStop {
                            position: 0.0
                            color: Qt.rgba(1, 1, 1, background.lightAlpha(
                                0.0, background.lightGain))
                        }
                        GradientStop {
                            position: 0.1
                            color: Qt.rgba(1, 1, 1, background.lightAlpha(
                                0.1, background.lightGain))
                        }
                        GradientStop {
                            position: 0.22
                            color: Qt.rgba(1, 1, 1, background.lightAlpha(
                                0.22, background.lightGain))
                        }
                        GradientStop {
                            position: 0.4
                            color: Qt.rgba(1, 1, 1, background.lightAlpha(
                                0.4, background.lightGain))
                        }
                        GradientStop {
                            position: 0.65
                            color: Qt.rgba(1, 1, 1, background.lightAlpha(
                                0.65, background.lightGain))
                        }
                        GradientStop {
                            position: 1.0
                            color: Qt.rgba(1, 1, 1, 0)
                        }
                    }

                    PathSvg {
                        path: "M0,0 H" + (2 * background.lightRadius)
                            + " V" + (2 * background.lightRadius) + " H0 Z"
                    }
                }
            }

            Shape {
                x: background.secondaryX - background.lightRadius
                y: background.secondaryY - background.lightRadius
                width: 2 * background.lightRadius
                height: 2 * background.lightRadius

                ShapePath {
                    strokeWidth: -1
                    strokeColor: "transparent"

                    fillGradient: RadialGradient {
                        centerX: background.lightRadius
                        centerY: background.lightRadius
                        centerRadius: background.lightRadius
                        focalX: background.lightRadius
                        focalY: background.lightRadius

                        GradientStop {
                            position: 0.0
                            color: Qt.rgba(1, 1, 1, background.lightAlpha(
                                0.0, 0.9 * background.lightGain))
                        }
                        GradientStop {
                            position: 0.1
                            color: Qt.rgba(1, 1, 1, background.lightAlpha(
                                0.1, 0.9 * background.lightGain))
                        }
                        GradientStop {
                            position: 0.22
                            color: Qt.rgba(1, 1, 1, background.lightAlpha(
                                0.22, 0.9 * background.lightGain))
                        }
                        GradientStop {
                            position: 0.4
                            color: Qt.rgba(1, 1, 1, background.lightAlpha(
                                0.4, 0.9 * background.lightGain))
                        }
                        GradientStop {
                            position: 0.65
                            color: Qt.rgba(1, 1, 1, background.lightAlpha(
                                0.65, 0.9 * background.lightGain))
                        }
                        GradientStop {
                            position: 1.0
                            color: Qt.rgba(1, 1, 1, 0)
                        }
                    }

                    PathSvg {
                        path: "M0,0 H" + (2 * background.lightRadius)
                            + " V" + (2 * background.lightRadius) + " H0 Z"
                    }
                }
            }
        }

        MultiEffect {
            anchors.fill: parent
            source: ringSource
            autoPaddingEnabled: false
            maskEnabled: true
            maskSource: lightMask
            maskThresholdMin: 0.0
            maskSpreadAtMin: 1.0
        }
    }
}
