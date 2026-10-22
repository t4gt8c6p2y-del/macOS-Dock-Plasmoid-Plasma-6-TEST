import QtQuick

// Un halo de lumière posé sur un côté de la bordure : un dégradé horizontal
// blanc, plus vif au centre. Seule sa position (centerX) et son opacité
// (strength) changent quand la souris bouge, le dégradé lui-même est fixe.
Rectangle {
    id: glow

    property real centerX: 0
    property real radius: 140
    // Opacité maximale du halo (0..1).
    property real strength: 0

    x: centerX - radius
    width: 2 * radius
    height: parent ? parent.height : 0
    visible: strength > 0.01
    opacity: Math.min(1, strength)

    gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0) }
        GradientStop { position: 0.175; color: Qt.rgba(1, 1, 1, 0.142) }
        GradientStop { position: 0.3; color: Qt.rgba(1, 1, 1, 0.301) }
        GradientStop { position: 0.39; color: Qt.rgba(1, 1, 1, 0.517) }
        GradientStop { position: 0.45; color: Qt.rgba(1, 1, 1, 0.741) }
        GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 1) }
        GradientStop { position: 0.55; color: Qt.rgba(1, 1, 1, 0.741) }
        GradientStop { position: 0.61; color: Qt.rgba(1, 1, 1, 0.517) }
        GradientStop { position: 0.7; color: Qt.rgba(1, 1, 1, 0.301) }
        GradientStop { position: 0.825; color: Qt.rgba(1, 1, 1, 0.142) }
        GradientStop { position: 1; color: Qt.rgba(1, 1, 1, 0) }
    }
}
