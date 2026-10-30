import QtQuick

// Fond « verre » des bulles du Dock : presque transparent, avec un liseré fin,
// comme les menus du thème Liquid Glass (Kvantum). Le flou et le Liquid Glass
// eux-mêmes sont demandés à KWin sur la fenêtre (voir GlassBlur).
Rectangle {
    property bool highlighted: false

    color: highlighted ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(0.11, 0.11, 0.118, 0.09)
    border.width: 1
    border.color: Qt.rgba(1, 1, 1, 0.16)
}
