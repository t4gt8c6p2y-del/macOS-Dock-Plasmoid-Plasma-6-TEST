import QtQuick

// Fond « verre » des bulles du Dock : presque transparent, avec un liseré fin
// tout autour, comme les menus du thème Liquid Glass. Les valeurs viennent du
// thème de l'utilisateur (GlassBlur.theme()) : si le thème change, les bulles
// suivent. Le flou et le Liquid Glass eux-mêmes sont demandés à KWin sur la
// fenêtre (voir GlassBlur).
Rectangle {
    id: root

    property bool highlighted: false
    // Réglages du thème (voir GlassBlur.theme()).
    property var theme: ({})

    readonly property color fillColor: theme.fillColor !== undefined
        ? theme.fillColor : "#1c1c1e"
    readonly property real fillOpacity: theme.fillOpacity !== undefined
        ? Number(theme.fillOpacity) : 0.06

    // Réglages facultatifs (les bulles du Dock gardent les valeurs par défaut).
    // darkening : voile noir ajouté pour un fond plus sombre.
    property real darkening: 0
    // rimScale : multiplie l'intensité du liseré (1 = celui des bulles).
    property real rimScale: 1
    // bezelSize : largeur (px) d'un bord intérieur lumineux qui s'estompe vers
    // le centre ; il épaissit visuellement le rebord « liquide ».
    property int bezelSize: 0
    property real bezelStrength: 0.12
    // Teinte du bord (blanc par défaut, un peu de bleu pour le Spotlight).
    property color bezelColor: "white"

    color: highlighted
        ? Qt.rgba(1, 1, 1, 0.14)
        : Qt.rgba(fillColor.r, fillColor.g, fillColor.b, fillOpacity)

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        visible: root.darkening > 0
        color: Qt.rgba(0, 0, 0, root.darkening)
    }

    // Bord intérieur : des liserés de 1 px de plus en plus transparents.
    Repeater {
        model: root.bezelSize

        delegate: Rectangle {
            required property int index

            anchors.fill: parent
            anchors.margins: index
            radius: Math.max(0, root.radius - index)
            color: "transparent"
            border.width: 1
            border.color: Qt.rgba(root.bezelColor.r, root.bezelColor.g,
                root.bezelColor.b, root.bezelStrength
                    * Math.pow(1 - index / Math.max(1, root.bezelSize), 2))
        }
    }

    // Liseré tout autour : côtés un peu moins brillants que les angles.
    GlassRim {
        anchors.fill: parent
        radius: root.radius
        theme: root.theme
        strength: 0.42 * root.rimScale
    }
}
