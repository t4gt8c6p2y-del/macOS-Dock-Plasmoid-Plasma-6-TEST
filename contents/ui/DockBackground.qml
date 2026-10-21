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

    // Réglage de flou (0 = désactivé). Le flou lui-même est fait par KWin
    // (voir BlurRegion dans main.qml) : il floute tout ce qui se trouve
    // derrière le Dock, fenêtres comprises. Cette propriété n'est conservée
    // que pour que les fenêtres qui l'utilisent n'aient rien à changer.
    property real wallpaperBlur: 0
    // Image du fond d'écran (voir main.qml) : { source, fillMode, width, height }.
    // Elle ne sert plus qu'à teinter la bordure.
    property var wallpaperInfo: ({ "source": "", "fillMode": 2,
        "width": 0, "height": 0 })
    // WallpaperLocator (module natif) : sert à lire les couleurs du fond
    // d'écran derrière le Dock pour teinter la bordure. null = bordure blanche.
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

    // --- Contour éclairé ---------------------------------------------------
    // Un filet d'un pixel, continu sur tout le tour, comme le bord d'une vitre.
    // Il est modulé par un masque : un niveau de base (litFloor) partout, plus
    // une lumière qui suit le pointeur et une seconde, au point opposé.
    // borderStrength règle la PART du tour qui est éclairée : à 0 il n'y a plus
    // de bordure, à 1 tout le tour est éclairé uniformément.
    //
    // Légèreté : le filet (un simple rectangle à bord fin) et sa teinte sont
    // dessinés une seule fois ; seul le masque de lumière bouge avec la souris,
    // et les reflets sont des formes de taille FIXE qu'on déplace et qu'on
    // agrandit (une transformation, aucun recalcul de forme ni de dégradé à
    // chaque image). Les surfaces de calcul gardent une taille « arrondie » :
    // elles ne sont pas recréées à chaque image quand le Dock grandit.
    //
    // Intensité de la lumière qui suit le pointeur : 0 = aucune lumière (le
    // contour reste au niveau de base et rien n'est recalculé), 1 = rendu
    // d'origine, 2 = le double.
    property real lightIntensity: 1.0

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
    readonly property bool lightEnabled: lightIntensity > 0.001
    // Opacité du reflet principal : 70 % à 100 % d'intensité (rendu
    // d'origine). Elle sature à ~143 % ; au-delà, c'est l'étalement qui grandit.
    readonly property real lightOpacity: Math.min(1, 0.7 * lightIntensity)
    readonly property real lightSpread:
        1 + 0.35 * Math.max(0, lightIntensity - 1)
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

    // Taille des surfaces de calcul : arrondie, pour qu'elles ne changent pas
    // à chaque image pendant que le Dock grossit.
    readonly property real layerWidth: Math.ceil(Math.max(1, width) / 64) * 64
    readonly property real layerHeight: Math.ceil(Math.max(1, height) / 16) * 16

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

        interval: 400
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
    // ramenée à pleine luminosité puis éclaircie (blanc si le fond est gris
    // ou inconnu).
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

    // Un reflet : un dégradé radial de taille fixe (128 px, rayon 64), dont
    // l'opacité et l'échelle sont réglées de l'extérieur. Le dégradé suit
    // exp(-3 d), d allant de 0 (centre) à 1 (bord).
    component LightBlob: Item {
        id: blob

        property real blobOpacity: 0
        property real blobScale: 1

        width: 128
        height: 128
        opacity: blob.blobOpacity
        scale: blob.blobScale
        transformOrigin: Item.Center
        visible: blob.blobOpacity > 0.001

        Shape {
            anchors.fill: parent

            ShapePath {
                strokeWidth: -1
                strokeColor: "transparent"

                fillGradient: RadialGradient {
                    centerX: 64
                    centerY: 64
                    centerRadius: 64
                    focalX: 64
                    focalY: 64

                    GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 1.0) }
                    GradientStop { position: 0.1; color: Qt.rgba(1, 1, 1, 0.7408) }
                    GradientStop { position: 0.22; color: Qt.rgba(1, 1, 1, 0.5169) }
                    GradientStop { position: 0.4; color: Qt.rgba(1, 1, 1, 0.3012) }
                    GradientStop { position: 0.65; color: Qt.rgba(1, 1, 1, 0.1423) }
                    GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0) }
                }

                PathSvg {
                    path: "M0,0 H128 V128 H0 Z"
                }
            }
        }
    }

    Item {
        id: glow

        anchors.fill: parent
        visible: background.litShare > 0.001

        // 1. La forme du filet : un rectangle à bord fin, blanc, opaque.
        //    Jamais affiché tel quel.
        Item {
            id: ringShape

            width: background.layerWidth
            height: background.layerHeight
            layer.enabled: true
            visible: false

            Rectangle {
                width: background.width
                height: background.height
                radius: background.radius
                color: "transparent"
                border.width: background.ringThickness
                border.color: "white"
                antialiasing: true
            }
        }

        // 2. Les couleurs du fond d'écran le long du Dock : une suite de
        //    petits dégradés bout à bout (blanc tant que rien n'est mesuré).
        Item {
            id: tintStrip

            width: background.layerWidth
            height: background.layerHeight
            layer.enabled: true
            visible: false

            Repeater {
                model: background.tintStopCount - 1

                delegate: Rectangle {
                    id: strip

                    required property int index

                    readonly property real step: (background.tintVertical
                        ? background.height : background.width)
                        / (background.tintStopCount - 1)

                    x: background.tintVertical ? 0 : strip.index * strip.step
                    y: background.tintVertical ? strip.index * strip.step : 0
                    // +1 : évite un trait entre deux dégradés voisins.
                    width: background.tintVertical
                        ? background.width : strip.step + 1
                    height: background.tintVertical
                        ? strip.step + 1 : background.height

                    gradient: Gradient {
                        orientation: background.tintVertical
                            ? Gradient.Vertical : Gradient.Horizontal

                        GradientStop {
                            position: 0
                            color: background.tintColor(strip.index)
                        }

                        GradientStop {
                            position: 1
                            color: background.tintColor(strip.index + 1)
                        }
                    }
                }
            }
        }

        // 3. Le filet teinté : les couleurs, découpées par la forme du filet.
        //    Recalculé seulement quand la taille ou les couleurs changent.
        Item {
            id: tintedRing

            width: background.layerWidth
            height: background.layerHeight
            layer.enabled: true
            visible: false

            MultiEffect {
                anchors.fill: parent
                source: tintStrip
                autoPaddingEnabled: false
                maskEnabled: true
                maskSource: ringShape
                maskThresholdMin: 0.0
                maskSpreadAtMin: 1.0
            }
        }

        // 4. Le masque de lumière : niveau de base + deux reflets. C'est la
        //    seule surface qui est redessinée quand la souris bouge.
        Item {
            id: lightMask

            width: background.layerWidth
            height: background.layerHeight
            layer.enabled: true
            visible: false

            Rectangle {
                width: background.width
                height: background.height
                color: Qt.rgba(1, 1, 1, background.litFloor)
            }

            LightBlob {
                x: background.primaryX - 64
                y: background.primaryY - 64
                blobOpacity: background.lightOpacity
                blobScale: background.lightRadius / 64 * background.lightSpread
            }

            LightBlob {
                x: background.secondaryX - 64
                y: background.secondaryY - 64
                blobOpacity: 0.9 * background.lightOpacity
                blobScale: background.lightRadius / 64 * background.lightSpread
            }
        }

        // 5. Le résultat : le filet teinté, visible là où le masque l'éclaire.
        MultiEffect {
            width: background.layerWidth
            height: background.layerHeight
            source: tintedRing
            autoPaddingEnabled: false
            maskEnabled: true
            maskSource: lightMask
            maskThresholdMin: 0.0
            maskSpreadAtMin: 1.0
        }
    }
}
