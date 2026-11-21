import QtQuick
import QtQuick.Effects

// Image aux coins arrondis (un masque en rectangle arrondi), sur un fond
// discret qui reste visible pendant le chargement ou si l'image est introuvable.
// L'image est décodée à taille réduite : une capture d'écran en 4K ne pèse pas
// 33 Mo en mémoire pour une miniature.
Item {
    id: root

    property url source
    property real radius: 12
    property int fillMode: Image.PreserveAspectCrop
    // Plus grand côté décodé (pixels).
    property int decodeSize: 360
    readonly property int status: image.status

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: Qt.rgba(1, 1, 1, 0.08)
    }

    Image {
        id: image

        anchors.fill: parent
        source: root.source
        asynchronous: true
        smooth: true
        fillMode: root.fillMode
        sourceSize: Qt.size(root.decodeSize, root.decodeSize)
        visible: status === Image.Ready
        layer.enabled: visible
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: mask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1.0
        }
    }

    // Masque des coins arrondis.
    Item {
        id: mask

        visible: false
        layer.enabled: true
        width: root.width
        height: root.height

        Rectangle {
            anchors.fill: parent
            radius: root.radius
            color: "black"
        }
    }
}
