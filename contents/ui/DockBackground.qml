pragma ComponentBehavior: Bound

import QtQuick
import org.kde.kirigami as Kirigami

Kirigami.ShadowedRectangle {
    id: background

    property real surfaceOpacity: 0.55
    property bool useThemeColor: true
    property color customColor: "#20242b"
    property real requestedRadius: Kirigami.Units.cornerRadius * 2
    property real borderOpacity: 0.22
    property real shadowOpacity: 0.42
    // L'ombre portée de ShadowedRectangle est dessinée sous le fond : comme
    // celui-ci est translucide, elle transparaît à l'intérieur et forme un
    // liseré sombre le long des bords. Les fenêtres du dock ont exactement la
    // taille du fond, l'ombre n'y a de toute façon pas la place de s'afficher.
    property bool showShadow: true
    property bool showHighlight: true
    // Intensité du reflet vitré : 1 = rendu d'origine, 0 = aucun reflet.
    property real highlightStrength: 1.0

    readonly property color themeBackground: qtPalette.window
    readonly property color themeText: qtPalette.windowText
    readonly property color effectiveColor: useThemeColor
        ? themeBackground : customColor
    readonly property real effectiveLuminance: 0.2126 * effectiveColor.r
        + 0.7152 * effectiveColor.g + 0.0722 * effectiveColor.b
    readonly property color borderReference: useThemeColor
        ? themeText : (effectiveLuminance > 0.55 ? "black" : "white")

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

    border.width: borderOpacity > 0.001 ? 1 : 0
    border.color: Qt.rgba(borderReference.r, borderReference.g,
        borderReference.b, Math.min(1, Math.max(0, borderOpacity)))

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
}
