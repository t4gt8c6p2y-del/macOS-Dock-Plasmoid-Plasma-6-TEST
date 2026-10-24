import QtQuick

// Une extrémité arrondie (gauche ou droite) de la bordure du Dock : le bout
// d'un rectangle arrondi à contour, découpé à la largeur de l'extrémité.
//
// L'extrémité est coupée en morceaux (coin du haut, côté droit en plusieurs
// parties, coin du bas). Chaque morceau reçoit sa propre lumière selon sa
// distance au pointeur : la lumière reste donc localisée, elle n'élargit pas
// tout le côté ni les angles.
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
        }
    }
}
