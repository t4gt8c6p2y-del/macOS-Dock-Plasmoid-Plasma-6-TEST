import QtQuick

// Liseré fin des bulles « verre » : les côtés droits sont un peu moins
// brillants que les angles. Un trait d'un pixel semble naturellement plus
// pâle dans les courbes (il y est lissé) : on baisse donc les côtés et on
// garde les angles à pleine valeur pour que le tour paraisse uniforme.
// Les valeurs viennent du thème Liquid Glass (GlassBlur.theme()).
Item {
    id: rim

    property real radius: 12
    property var theme: ({})
    // Part de l'intensité des angles que gardent les côtés droits.
    property real sideFactor: 0.6

    readonly property real lineWidth: Math.max(1, theme.rimWidth !== undefined
        ? Number(theme.rimWidth) : 1)
    readonly property real cornerAlpha: Math.min(1, 2.7 * (theme.rimTop !== undefined
        ? Number(theme.rimTop) : 0.1))
    readonly property real sideAlpha: cornerAlpha * sideFactor
    // Opacité à ajouter dans les angles, par-dessus celle des côtés, pour
    // obtenir exactement cornerAlpha une fois les deux traits superposés.
    readonly property real boostAlpha: sideAlpha < 1
        ? 1 - (1 - cornerAlpha) / (1 - sideAlpha) : 0
    readonly property real cornerSize: Math.min(Math.ceil(radius),
        Math.floor(Math.min(width, height) / 2))

    Rectangle {
        anchors.fill: parent
        radius: rim.radius
        color: "transparent"
        border.width: rim.lineWidth
        border.color: Qt.rgba(1, 1, 1, rim.sideAlpha)
    }

    Repeater {
        model: 4

        Item {
            required property int index

            width: rim.cornerSize
            height: rim.cornerSize
            x: index % 2 === 0 ? 0 : rim.width - width
            y: index < 2 ? 0 : rim.height - height
            clip: true

            Rectangle {
                x: -parent.x
                y: -parent.y
                width: rim.width
                height: rim.height
                radius: rim.radius
                color: "transparent"
                border.width: rim.lineWidth
                border.color: Qt.rgba(1, 1, 1, rim.boostAlpha)
            }
        }
    }
}
