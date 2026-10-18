pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
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
    // Un anneau d'1,4 px rempli par deux dégradés radiaux : l'un centré sur la
    // lumière (pointeur ou position de repos), l'autre, plus faible, sur le
    // point opposé. La luminosité décroît de façon exponentielle avec la
    // distance : la bordure est vive près des lumières et s'efface ailleurs.
    // borderStrength règle la PART du tour qui est éclairée (et non la
    // luminosité) : à 0 il n'y a plus de bordure, à 1 tout le tour est éclairé.
    readonly property real ringThickness: 1.4
    readonly property real litShare: Math.min(1, Math.max(0, borderStrength))
    readonly property real perimeter: 2 * (width + height)
    // Rayon d'étalement (distance où la lumière tombe à 1/e).
    readonly property real taper: Math.max(1, litShare * perimeter / 5.5)
    // Au-delà de 70 %, un niveau minimal monte progressivement jusqu'à 1 :
    // la bordure devient uniforme à 100 %.
    readonly property real litFloor:
        Math.pow(Math.max(0, (litShare - 0.7) / 0.3), 2)
    readonly property real peakAlpha: 0.55
    readonly property real restX: -0.1 * width
    readonly property real restY: -0.3 * height

    // Position lissée de la lumière.
    property real fadeValue: lightActive ? 1.0 : 0.0
    property real followX: lightX
    property real followY: lightY

    Behavior on fadeValue {
        NumberAnimation {
            duration: 220
            easing.type: Easing.OutCubic
        }
    }

    Behavior on followX {
        NumberAnimation {
            duration: 80
            easing.type: Easing.OutQuad
        }
    }

    Behavior on followY {
        NumberAnimation {
            duration: 80
            easing.type: Easing.OutQuad
        }
    }

    readonly property real primaryX: restX + (followX - restX) * fadeValue
    readonly property real primaryY: restY + (followY - restY) * fadeValue
    readonly property real secondaryX: width - primaryX
    readonly property real secondaryY: height - primaryY

    function litAlpha(position) {
        return litFloor + (1 - litFloor) * Math.exp(-3 * position);
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

    Shape {
        anchors.fill: parent
        visible: background.litShare > 0.001
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillRule: ShapePath.OddEvenFill
            strokeWidth: -1
            strokeColor: "transparent"

            fillGradient: RadialGradient {
                centerX: background.primaryX
                centerY: background.primaryY
                centerRadius: Math.max(1, 3 * background.taper)
                focalX: background.primaryX
                focalY: background.primaryY

                GradientStop {
                    position: 0.0
                    color: Qt.rgba(1, 0.98, 0.94, background.peakAlpha
                        * background.litAlpha(0.0))
                }
                GradientStop {
                    position: 0.08
                    color: Qt.rgba(1, 0.98, 0.94, background.peakAlpha
                        * background.litAlpha(0.08))
                }
                GradientStop {
                    position: 0.18
                    color: Qt.rgba(1, 0.98, 0.94, background.peakAlpha
                        * background.litAlpha(0.18))
                }
                GradientStop {
                    position: 0.3
                    color: Qt.rgba(1, 0.98, 0.94, background.peakAlpha
                        * background.litAlpha(0.3))
                }
                GradientStop {
                    position: 0.45
                    color: Qt.rgba(1, 0.98, 0.94, background.peakAlpha
                        * background.litAlpha(0.45))
                }
                GradientStop {
                    position: 0.65
                    color: Qt.rgba(1, 0.98, 0.94, background.peakAlpha
                        * background.litAlpha(0.65))
                }
                GradientStop {
                    position: 1.0
                    color: Qt.rgba(1, 0.98, 0.94, background.peakAlpha
                        * background.litFloor)
                }
            }

            PathSvg {
                path: background.ringPath
            }
        }

        ShapePath {
            fillRule: ShapePath.OddEvenFill
            strokeWidth: -1
            strokeColor: "transparent"

            fillGradient: RadialGradient {
                centerX: background.secondaryX
                centerY: background.secondaryY
                centerRadius: Math.max(1, 3 * background.taper)
                focalX: background.secondaryX
                focalY: background.secondaryY

                GradientStop {
                    position: 0.0
                    color: Qt.rgba(1, 0.98, 0.94, 0.65 * background.peakAlpha
                        * background.litAlpha(0.0))
                }
                GradientStop {
                    position: 0.08
                    color: Qt.rgba(1, 0.98, 0.94, 0.65 * background.peakAlpha
                        * background.litAlpha(0.08))
                }
                GradientStop {
                    position: 0.18
                    color: Qt.rgba(1, 0.98, 0.94, 0.65 * background.peakAlpha
                        * background.litAlpha(0.18))
                }
                GradientStop {
                    position: 0.3
                    color: Qt.rgba(1, 0.98, 0.94, 0.65 * background.peakAlpha
                        * background.litAlpha(0.3))
                }
                GradientStop {
                    position: 0.45
                    color: Qt.rgba(1, 0.98, 0.94, 0.65 * background.peakAlpha
                        * background.litAlpha(0.45))
                }
                GradientStop {
                    position: 0.65
                    color: Qt.rgba(1, 0.98, 0.94, 0.65 * background.peakAlpha
                        * background.litAlpha(0.65))
                }
                GradientStop {
                    position: 1.0
                    color: Qt.rgba(1, 0.98, 0.94, 0.65 * background.peakAlpha
                        * background.litFloor)
                }
            }

            PathSvg {
                path: background.ringPath
            }
        }
    }
}
