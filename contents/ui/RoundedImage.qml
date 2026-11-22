import QtQuick

// Image dans un cadre arrondi : l'image est posée un peu en retrait dans le
// cadre (le retrait suit le rayon, pour que ses coins ne dépassent pas de
// l'arrondi). Aucun effet graphique : l'image s'affiche toujours. Pendant le
// chargement, ou si elle est introuvable, le cadre reste visible.
// L'image est décodée à taille réduite : une capture d'écran en 4K ne pèse pas
// 33 Mo en mémoire pour une miniature.
Item {
    id: root

    property url source
    property real radius: 12
    // PreserveAspectCrop remplit le cadre (miniature) ; PreserveAspectFit
    // montre l'image entière.
    property int fillMode: Image.PreserveAspectCrop
    // Plus grand côté décodé (pixels).
    property int decodeSize: 360
    readonly property real inset: Math.ceil(root.radius * 0.3)
    readonly property int status: image.status

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: Qt.rgba(1, 1, 1, 0.1)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.16)
    }

    // Image introuvable (fichier supprimé) : un pictogramme dans le cadre.
    SpotlightGlyph {
        visible: image.status === Image.Error
        anchors.centerIn: parent
        kind: "files"
        size: Math.max(14, Math.min(30, root.height * 0.45))
        lineWidth: 1.6
        color: Qt.rgba(1, 1, 1, 0.38)
    }

    Image {
        id: image

        anchors.fill: parent
        anchors.margins: root.inset
        source: root.source
        asynchronous: true
        smooth: true
        clip: true
        fillMode: root.fillMode
        sourceSize: Qt.size(root.decodeSize, root.decodeSize)
    }
}
