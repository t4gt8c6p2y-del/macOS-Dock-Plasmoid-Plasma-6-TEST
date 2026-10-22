import QtQuick

// Un côté droit (haut ou bas) de la bordure du Dock.
//
// Sa couleur est un dégradé horizontal construit à partir des couleurs du
// fond d'écran derrière chaque zone du Dock (colors) : chaque partie de la
// bordure a donc sa propre couleur. Deux halos de lumière (BorderGlow) sont
// posés par-dessus.
Item {
    id: edge

    // Couleurs échantillonnées de gauche à droite ; vide = blanc.
    property var colors: []
    property real baseOpacity: 0.5
    property real lightX1: 0
    property real lightStrength1: 0
    property real lightX2: 0
    property real lightStrength2: 0
    property real lightRadius: 140

    // Le halo dépasse du côté : on le découpe aux limites du côté.
    clip: true

    function colorAt(index) {
        return colors && colors.length > index ? colors[index] : "white";
    }

    Rectangle {
        anchors.fill: parent
        visible: edge.baseOpacity > 0.003
        opacity: edge.baseOpacity

        gradient: Gradient {
            orientation: Gradient.Horizontal
                GradientStop { position: 0.00000; color: edge.colorAt(0) }
                GradientStop { position: 0.03125; color: edge.colorAt(0) }
                GradientStop { position: 0.09375; color: edge.colorAt(1) }
                GradientStop { position: 0.15625; color: edge.colorAt(2) }
                GradientStop { position: 0.21875; color: edge.colorAt(3) }
                GradientStop { position: 0.28125; color: edge.colorAt(4) }
                GradientStop { position: 0.34375; color: edge.colorAt(5) }
                GradientStop { position: 0.40625; color: edge.colorAt(6) }
                GradientStop { position: 0.46875; color: edge.colorAt(7) }
                GradientStop { position: 0.53125; color: edge.colorAt(8) }
                GradientStop { position: 0.59375; color: edge.colorAt(9) }
                GradientStop { position: 0.65625; color: edge.colorAt(10) }
                GradientStop { position: 0.71875; color: edge.colorAt(11) }
                GradientStop { position: 0.78125; color: edge.colorAt(12) }
                GradientStop { position: 0.84375; color: edge.colorAt(13) }
                GradientStop { position: 0.90625; color: edge.colorAt(14) }
                GradientStop { position: 0.96875; color: edge.colorAt(15) }
                GradientStop { position: 1.00000; color: edge.colorAt(15) }
        }
    }

    BorderGlow {
        centerX: edge.lightX1
        strength: edge.lightStrength1
        radius: edge.lightRadius
    }

    BorderGlow {
        centerX: edge.lightX2
        strength: edge.lightStrength2
        radius: edge.lightRadius
    }
}
