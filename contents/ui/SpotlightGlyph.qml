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

    // Formes pleines (sans trait) : le logo « Applications » est le contour
    // du pictogramme de la capture macOS, vectorisé à partir de l'image.
    readonly property var solidPaths: ({
        "apps": "M5.69 17.83 L5.16 17.73 L4.65 17.86 L4.26 18.20 L3.85 18.84 L3.66 19.33 L3.67 19.77 L3.90 20.19 L4.28 20.51 L4.76 20.60 L5.24 20.38 L5.77 19.85 L6.22 19.07 L6.39 18.66 L6.36 18.36 L6.11 18.07 Z M13.93 9.13 L13.71 9.35 L13.57 9.67 L13.51 10.82 L13.65 11.62 L14.14 12.69 L15.74 15.59 L18.19 19.73 L18.61 20.22 L18.98 20.50 L19.37 20.60 L19.74 20.52 L19.99 20.33 L20.16 20.07 L20.26 19.73 L20.27 19.33 L20.13 18.75 L19.52 17.59 L19.45 17.29 L19.50 17.00 L19.66 16.78 L19.92 16.63 L21.10 16.47 L21.53 16.28 L21.73 16.04 L21.86 15.71 L21.88 15.41 L21.79 15.11 L21.47 14.73 L21.02 14.54 L20.17 14.44 L18.35 14.41 L17.95 14.30 L17.59 14.09 L16.96 13.40 L14.56 9.42 L14.25 9.13 Z M14.21 3.54 L13.84 3.37 L13.37 3.41 L13.06 3.58 L12.47 4.11 L12.10 4.22 L11.63 4.09 L10.84 3.56 L10.50 3.42 L10.07 3.45 L9.69 3.68 L9.51 4.02 L9.54 4.45 L10.44 6.20 L10.59 6.68 L10.58 7.30 L10.32 7.92 L7.65 12.38 L6.70 13.83 L6.23 14.19 L5.65 14.41 L3.38 14.45 L2.94 14.51 L2.56 14.65 L2.23 14.93 L2.08 15.32 L2.13 15.80 L2.38 16.20 L2.89 16.46 L3.74 16.52 L12.91 16.52 L13.48 16.46 L13.83 16.27 L13.98 15.96 L13.92 15.54 L13.71 15.13 L13.37 14.81 L13.00 14.63 L12.47 14.51 L10.55 14.41 L10.16 14.34 L9.75 14.06 L9.63 13.83 L9.59 13.53 L9.65 13.22 L9.81 12.87 L14.30 4.94 L14.44 4.54 L14.47 4.14 L14.40 3.81 Z"
    })

    readonly property var paths: ({
        "files": "M7 3.6 H13.4 L18.2 8.4 V19 A1.4 1.4 0 0 1 16.8 20.4 H7 A1.4 1.4 0 0 1 5.6 19 V5 A1.4 1.4 0 0 1 7 3.6 Z M13.4 3.6 V8.4 H18.2",
        "clipboard": "M9 5.2 H7 A1.6 1.6 0 0 0 5.4 6.8 V19 A1.6 1.6 0 0 0 7 20.6 H17 A1.6 1.6 0 0 0 18.6 19 V6.8 A1.6 1.6 0 0 0 17 5.2 H15 M9.6 3.4 H14.4 A1 1 0 0 1 15.4 4.4 V5.6 A1 1 0 0 1 14.4 6.6 H9.6 A1 1 0 0 1 8.6 5.6 V4.4 A1 1 0 0 1 9.6 3.4 Z",
        "star": "M12 3.8 L14.5 9.1 L20.3 9.8 L16 13.8 L17.2 19.6 L12 16.7 L6.8 19.6 L8 13.8 L3.7 9.8 L9.5 9.1 Z",
        "search": "M4.6 10.6 A6 6 0 1 0 16.6 10.6 A6 6 0 1 0 4.6 10.6 M15.2 15.2 L20 20",
        "compose": "M11.5 4.6 H7 A2.4 2.4 0 0 0 4.6 7 V17 A2.4 2.4 0 0 0 7 19.4 H17 A2.4 2.4 0 0 0 19.4 17 V12.5 M17.6 3.9 A1.7 1.7 0 0 1 20 6.3 L12.4 13.9 L9.2 14.6 L9.9 11.4 Z",
        "send": "M12 19 V6 M6.6 11.4 L12 6 L17.4 11.4",
        "plus": "M12 5 V19 M5 12 H19",
        "mic": "M9 6.6 A3 3 0 0 1 15 6.6 V12 A3 3 0 0 1 9 12 Z M6 11.4 A6 6 0 0 0 18 11.4 M12 17.4 V20.2",
        "copy": "M9.5 8.4 H16.5 A1.6 1.6 0 0 1 18.1 10 V18 A1.6 1.6 0 0 1 16.5 19.6 H9.5 A1.6 1.6 0 0 1 7.9 18 V10 A1.6 1.6 0 0 1 9.5 8.4 Z M15.4 8.4 V6.2 A1.6 1.6 0 0 0 13.8 4.6 H7.2 A1.6 1.6 0 0 0 5.6 6.2 V14 A1.6 1.6 0 0 0 7.2 15.6 H7.9",
        "trash": "M5 7 H19 M9.5 7 V5 A1 1 0 0 1 10.5 4 H13.5 A1 1 0 0 1 14.5 5 V7 M7 7 L7.8 18.6 A1.4 1.4 0 0 0 9.2 20 H14.8 A1.4 1.4 0 0 0 16.2 18.6 L17 7 M10.2 10.5 V16.5 M13.8 10.5 V16.5",
        "check": "M5.4 12.8 L10 17.4 L18.8 7",
        "chevronDown": "M6.4 9.4 L12 15 L17.6 9.4",
        "chevronRight": "M9.4 6.4 L15 12 L9.4 17.6",
        "expand": "M13.5 4.6 H19.4 V10.5 M19.4 4.6 L12.6 11.4 M10.5 19.4 H4.6 V13.5 M4.6 19.4 L11.4 12.6",
        "pin": "M9 4.4 H15 M10.2 4.4 V10 L7.4 13.4 H16.6 L13.8 10 V4.4 M12 13.4 V19.8",
        "close": "M6 6 L18 18 M18 6 L6 18",
        "sparkle": "M12 3.6 L13.9 9.5 L19.8 11.4 L13.9 13.3 L12 19.2 L10.1 13.3 L4.2 11.4 L10.1 9.5 Z",
        "globe": "M3.6 12 A8.4 8.4 0 1 0 20.4 12 A8.4 8.4 0 1 0 3.6 12 M3.9 9.6 H20.1 M3.9 14.4 H20.1 M12 3.6 C9.2 6.4 9.2 17.6 12 20.4 M12 3.6 C14.8 6.4 14.8 17.6 12 20.4",
        "folder": "M4 7.4 A1.8 1.8 0 0 1 5.8 5.6 H9.6 L11.6 7.8 H18.2 A1.8 1.8 0 0 1 20 9.6 V17 A1.8 1.8 0 0 1 18.2 18.8 H5.8 A1.8 1.8 0 0 1 4 17 Z",
        "folderPlus": "M12.4 18.8 H5.8 A1.8 1.8 0 0 1 4 17 V7.4 A1.8 1.8 0 0 1 5.8 5.6 H9.6 L11.6 7.8 H18.2 A1.8 1.8 0 0 1 20 9.6 V12 M17.2 14.6 V20 M14.5 17.3 H19.9"
    })

    Shape {
        width: glyph.size
        height: glyph.size
        layer.enabled: true
        layer.samples: 4

        ShapePath {
            scale: Qt.size(glyph.size / 24, glyph.size / 24)
            strokeColor: "transparent"
            strokeWidth: 0
            fillColor: glyph.color
            fillRule: ShapePath.WindingFill

            PathSvg {
                path: glyph.solidPaths[glyph.kind] !== undefined
                    ? glyph.solidPaths[glyph.kind] : ""
            }
        }

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
