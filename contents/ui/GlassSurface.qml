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

    color: highlighted
        ? Qt.rgba(1, 1, 1, 0.14)
        : Qt.rgba(fillColor.r, fillColor.g, fillColor.b, fillOpacity)

    // Liseré tout autour : côtés un peu moins brillants que les angles.
    GlassRim {
        anchors.fill: parent
        radius: root.radius
        theme: root.theme
    }
}
