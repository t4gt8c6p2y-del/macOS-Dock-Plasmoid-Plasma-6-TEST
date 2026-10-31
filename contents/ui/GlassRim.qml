import QtQuick

// Liseré fin des bulles « verre » : une seule couleur, donc la même
// luminosité sur les côtés, les angles et partout ailleurs. Il est adouci par
// rapport au thème (strength) car KWin ajoute déjà sa propre lumière sur la
// forme. Les valeurs viennent du thème Liquid Glass (GlassBlur.theme()).
Rectangle {
    id: rim

    property var theme: ({})
    // Part de l'intensité du liseré du thème utilisée pour les bulles
    // (même valeur que bubbleRimStrength dans native/dockmenu.cpp).
    property real strength: 0.5

    color: "transparent"
    border.width: Math.max(1, theme.rimWidth !== undefined
        ? Number(theme.rimWidth) : 1)
    border.color: Qt.rgba(1, 1, 1, Math.min(1, 2.7 * strength
        * (theme.rimTop !== undefined ? Number(theme.rimTop) : 0.1)))
}
