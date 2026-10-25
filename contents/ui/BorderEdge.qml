pragma ComponentBehavior: Bound

import QtQuick

// Un côté droit (haut ou bas) de la bordure du Dock.
//
// Sa couleur est un dégradé horizontal construit à partir des couleurs du
// fond d'écran derrière chaque zone du Dock (colors) : chaque partie de la
// bordure a donc sa propre couleur. Deux halos de lumière (BorderGlow) sont
// posés par-dessus le trait, puis une lueur plus douce s'étend de quelques
// pixels vers l'intérieur du Dock (rangées de 1 pixel de plus en plus
// transparentes) : c'est elle qui rend la lumière bien visible.
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

    // Épaisseur du trait de bordure.
    property real lineHeight: 1
    // Profondeur (en pixels) de la lueur qui s'étend vers l'intérieur.
    property int glowDepth: 0
    // Vrai : le trait est en haut de l'élément et la lueur descend. Faux : le
    // trait est en bas et la lueur monte.
    property bool inwardDown: true
    // Force de la première rangée de la lueur, par rapport au trait (0..1).
    property real glowScale: 0.55

    readonly property real lineY: inwardDown ? 0 : glowDepth

    // Le halo dépasse du côté : on le découpe aux limites du côté.
    clip: true

    function colorAt(index) {
        return colors && colors.length > index ? colors[index] : "white";
    }

    // Force de la rangée « index » de la lueur : elle s'estompe vers l'intérieur.
    function rowFactor(index) {
        var t = 1 - index / Math.max(1, glowDepth);
        return glowScale * t * t;
    }

    Rectangle {
        x: 0
        y: edge.lineY
        width: edge.width
        height: edge.lineHeight
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

    // Le trait lui-même, éclairé par les deux halos.
    BorderGlow {
        centerX: edge.lightX1
        strength: edge.lightStrength1
        radius: edge.lightRadius
        y: edge.lineY
        height: edge.lineHeight
    }

    BorderGlow {
        centerX: edge.lightX2
        strength: edge.lightStrength2
        radius: edge.lightRadius
        y: edge.lineY
        height: edge.lineHeight
    }

    // La lueur vers l'intérieur : une rangée de 1 pixel par halo et par pas de
    // profondeur.
    Repeater {
        model: edge.glowDepth

        delegate: BorderGlow {
            required property int index

            centerX: edge.lightX1
            strength: edge.lightStrength1 * edge.rowFactor(index)
            radius: edge.lightRadius
            y: edge.inwardDown
                ? edge.lineHeight + index
                : edge.glowDepth - 1 - index
            height: 1
        }
    }

    Repeater {
        model: edge.glowDepth

        delegate: BorderGlow {
            required property int index

            centerX: edge.lightX2
            strength: edge.lightStrength2 * edge.rowFactor(index)
            radius: edge.lightRadius
            y: edge.inwardDown
                ? edge.lineHeight + index
                : edge.glowDepth - 1 - index
            height: 1
        }
    }
}
