import QtQuick

// Une extrémité arrondie (gauche ou droite) de la bordure du Dock : le bout
// d'un rectangle arrondi à contour, découpé à la largeur de l'extrémité. C'est
// le trait de base ; la lumière est dessinée par BorderLight.
Item {
    id: cap

    property bool leftSide: true
    // Largeur totale du Dock : on dessine le contour entier, découpé ensuite.
    property real fullWidth: 0
    property real ringRadius: 12
    property real ringWidth: 1
    property color ringColor: "white"
    property real baseOpacity: 0.5

    clip: true

    Rectangle {
        x: cap.leftSide ? 0 : cap.width - cap.fullWidth
        y: 0
        width: cap.fullWidth
        height: cap.height
        radius: cap.ringRadius
        color: "transparent"
        visible: cap.baseOpacity > 0.003
        opacity: cap.baseOpacity
        border.width: cap.ringWidth
        border.color: cap.ringColor
    }
}
