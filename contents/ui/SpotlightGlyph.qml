import QtQuick
import QtQuick.Shapes

// Pictogramme à trait fin (style SF Symbols) du Spotlight et de Siri IA. Le
// tracé vient d'une grille de 24 x 24 ; « kind » choisit la forme.
Item {
    id: glyph

    property string kind: "search"
    property color color: "white"
    property real size: 20
    property real lineWidth: 1.6
    // Forme pleine (étoile des favoris).
    property bool filled: false

    implicitWidth: size
    implicitHeight: size
    width: size
    height: size

    readonly property var paths: ({
        "apps": "M12.6 4.2 L19 17.2 M11.4 4.2 L5 17.2 M7.7 14 H16.3 M5.4 20 H9",
        "files": "M7 3.6 H13.4 L18.2 8.4 V19 A1.4 1.4 0 0 1 16.8 20.4 H7 A1.4 1.4 0 0 1 5.6 19 V5 A1.4 1.4 0 0 1 7 3.6 Z M13.4 3.6 V8.4 H18.2",
        "clipboard": "M9 5.2 H7 A1.6 1.6 0 0 0 5.4 6.8 V19 A1.6 1.6 0 0 0 7 20.6 H17 A1.6 1.6 0 0 0 18.6 19 V6.8 A1.6 1.6 0 0 0 17 5.2 H15 M9.6 3.4 H14.4 A1 1 0 0 1 15.4 4.4 V5.6 A1 1 0 0 1 14.4 6.6 H9.6 A1 1 0 0 1 8.6 5.6 V4.4 A1 1 0 0 1 9.6 3.4 Z",
        "star": "M12 3.8 L14.5 9.1 L20.3 9.8 L16 13.8 L17.2 19.6 L12 16.7 L6.8 19.6 L8 13.8 L3.7 9.8 L9.5 9.1 Z",
        "search": "M4.6 10.6 A6 6 0 1 0 16.6 10.6 A6 6 0 1 0 4.6 10.6 M15.2 15.2 L20 20",
        "compose": "M11.5 4.6 H7 A2.4 2.4 0 0 0 4.6 7 V17 A2.4 2.4 0 0 0 7 19.4 H17 A2.4 2.4 0 0 0 19.4 17 V12.5 M17.6 3.9 A1.7 1.7 0 0 1 20 6.3 L12.4 13.9 L9.2 14.6 L9.9 11.4 Z",
        "send": "M12 19 V6 M6.6 11.4 L12 6 L17.4 11.4",
        "plus": "M12 5 V19 M5 12 H19",
        "copy": "M9.5 8.4 H16.5 A1.6 1.6 0 0 1 18.1 10 V18 A1.6 1.6 0 0 1 16.5 19.6 H9.5 A1.6 1.6 0 0 1 7.9 18 V10 A1.6 1.6 0 0 1 9.5 8.4 Z M15.4 8.4 V6.2 A1.6 1.6 0 0 0 13.8 4.6 H7.2 A1.6 1.6 0 0 0 5.6 6.2 V14 A1.6 1.6 0 0 0 7.2 15.6 H7.9",
        "trash": "M5 7 H19 M9.5 7 V5 A1 1 0 0 1 10.5 4 H13.5 A1 1 0 0 1 14.5 5 V7 M7 7 L7.8 18.6 A1.4 1.4 0 0 0 9.2 20 H14.8 A1.4 1.4 0 0 0 16.2 18.6 L17 7 M10.2 10.5 V16.5 M13.8 10.5 V16.5",
        "check": "M5.4 12.8 L10 17.4 L18.8 7",
        "chevronDown": "M6.4 9.4 L12 15 L17.6 9.4",
        "chevronRight": "M9.4 6.4 L15 12 L9.4 17.6",
        "expand": "M13.5 4.6 H19.4 V10.5 M19.4 4.6 L12.6 11.4 M10.5 19.4 H4.6 V13.5 M4.6 19.4 L11.4 12.6",
        "pin": "M9 4.4 H15 M10.2 4.4 V10 L7.4 13.4 H16.6 L13.8 10 V4.4 M12 13.4 V19.8",
        "close": "M6 6 L18 18 M18 6 L6 18",
        "sparkle": "M12 3.6 L13.9 9.5 L19.8 11.4 L13.9 13.3 L12 19.2 L10.1 13.3 L4.2 11.4 L10.1 9.5 Z"
    })

    Shape {
        width: glyph.size
        height: glyph.size
        layer.enabled: true
        layer.samples: 4

        ShapePath {
            scale: Qt.size(glyph.size / 24, glyph.size / 24)
            strokeColor: glyph.color
            strokeWidth: glyph.lineWidth * glyph.size / 24
            fillColor: glyph.filled ? glyph.color : "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin

            PathSvg {
                path: glyph.paths[glyph.kind] !== undefined
                    ? glyph.paths[glyph.kind] : ""
            }
        }
    }
}
