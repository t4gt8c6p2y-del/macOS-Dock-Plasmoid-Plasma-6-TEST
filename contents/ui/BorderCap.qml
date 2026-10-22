import QtQuick

// Une extrémité arrondie (gauche ou droite) de la bordure du Dock : le bout
// d'un rectangle arrondi à contour, découpé à la largeur de l'extrémité.
Item {
    id: cap

    property bool leftSide: true
    // Largeur totale du Dock : on dessine le contour entier, découpé ensuite.
    property real fullWidth: 0
    property real ringRadius: 12
    property real ringWidth: 1
    property color ringColor: "white"
    property real baseOpacity: 0.5
    property real lightStrength: 0

    clip: true

    Rectangle {
        x: cap.leftSide ? 0 : cap.width - cap.fullWidth
        width: cap.fullWidth
        height: cap.height
        radius: cap.ringRadius
        color: "transparent"
        visible: cap.baseOpacity > 0.003
        opacity: cap.baseOpacity
        border.width: cap.ringWidth
        border.color: cap.ringColor
    }

    Rectangle {
        x: cap.leftSide ? 0 : cap.width - cap.fullWidth
        width: cap.fullWidth
        height: cap.height
        radius: cap.ringRadius
        color: "transparent"
        visible: cap.lightStrength > 0.01
        opacity: Math.min(1, cap.lightStrength)
        border.width: cap.ringWidth
        border.color: "white"
    }
}
