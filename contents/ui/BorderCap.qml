pragma ComponentBehavior: Bound

import QtQuick

// Une extrémité arrondie (gauche ou droite) de la bordure du Dock : le bout
// d'un rectangle arrondi à contour, découpé à la largeur de l'extrémité.
//
// L'extrémité est coupée en morceaux (coin du haut, côté droit en plusieurs
// parties, coin du bas). Chaque morceau reçoit sa propre lumière selon sa
// distance au pointeur : la lumière reste donc localisée, elle n'élargit pas
// tout le côté ni les angles. Comme sur les côtés droits (BorderEdge), une
// lueur plus douce s'étend vers l'intérieur : des contours concentriques de
// 1 pixel, de plus en plus transparents.
Item {
    id: cap

    property bool leftSide: true
    // Largeur totale du Dock : on dessine le contour entier, découpé ensuite.
    property real fullWidth: 0
    property real ringRadius: 12
    property real ringWidth: 1
    property color ringColor: "white"
    property real baseOpacity: 0.5

    // Lumière : force maximale, étendue, et position (dans le Dock) des deux
    // sources, la seconde étant plus faible (secondaryScale).
    property real lightPeak: 0
    property real lightRadius: 140
    property real lightX1: 0
    property real lightY1: 0
    property real lightX2: 0
    property real lightY2: 0
    property real secondaryScale: 0.6
    // Profondeur (en pixels) de la lueur intérieure et force de sa première
    // rangée, par rapport au trait (comme BorderEdge).
    property int glowDepth: 0
    property real glowScale: 0.55

    readonly property real cornerHeight: Math.min(ringRadius, height / 2)
    readonly property real middleHeight: Math.max(0, height - 2 * cornerHeight)
    readonly property int middleCount:
        middleHeight > 0 ? Math.max(1, Math.ceil(middleHeight / 24)) : 0
    // Centre horizontal de l'extrémité, dans le repère du Dock.
    readonly property real centerX: x + width / 2

    function pieceY(index) {
        if (index === 0) {
            return 0;
        }
        if (index === middleCount + 1) {
            return height - cornerHeight;
        }
        return cornerHeight + (index - 1) * middleHeight / middleCount;
    }

    function pieceHeight(index) {
        return index === 0 || index === middleCount + 1
            ? cornerHeight : middleHeight / middleCount;
    }

    function lightAt(sourceX, sourceY, centerY, scale) {
        var dx = sourceX - centerX;
        var dy = sourceY - centerY;
        return lightPeak * scale
            * Math.exp(-2.2 * (dx * dx + dy * dy) / (lightRadius * lightRadius));
    }

    // Force de la rangée « index » de la lueur intérieure.
    function rowFactor(index) {
        var t = 1 - index / Math.max(1, glowDepth);
        return glowScale * t * t;
    }

    Repeater {
        model: cap.middleCount + 2

        delegate: Item {
            id: piece

            required property int index

            y: cap.pieceY(index)
            width: cap.width
            height: cap.pieceHeight(index)
            clip: true
            visible: height > 0.5

            readonly property real strength: Math.min(1,
                cap.lightAt(cap.lightX1, cap.lightY1, y + height / 2, 1)
                + cap.lightAt(cap.lightX2, cap.lightY2, y + height / 2,
                    cap.secondaryScale))

            Rectangle {
                x: cap.leftSide ? 0 : cap.width - cap.fullWidth
                y: -piece.y
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
                y: -piece.y
                width: cap.fullWidth
                height: cap.height
                radius: cap.ringRadius
                color: "transparent"
                visible: piece.strength > 0.01
                opacity: piece.strength
                border.width: cap.ringWidth
                border.color: "white"
            }

            // La lueur vers l'intérieur : un contour de 1 pixel par pas de
            // profondeur, chacun un peu plus petit et plus transparent.
            Repeater {
                model: cap.glowDepth

                delegate: Rectangle {
                    id: glowRing

                    required property int index

                    // Distance entre ce contour et le bord extérieur du Dock.
                    readonly property real inset: cap.ringWidth + index

                    x: (cap.leftSide ? 0 : cap.width - cap.fullWidth) + inset
                    y: -piece.y + inset
                    width: Math.max(0, cap.fullWidth - 2 * inset)
                    height: Math.max(0, cap.height - 2 * inset)
                    radius: Math.max(0, cap.ringRadius - inset)
                    color: "transparent"
                    visible: width > 2 && height > 2
                        && opacity > 0.01
                    opacity: piece.strength * cap.rowFactor(index)
                    border.width: 1
                    border.color: "white"
                }
            }
        }
    }
}
