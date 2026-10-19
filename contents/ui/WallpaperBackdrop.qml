pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects

// Flou réel du fond d'écran derrière le Dock (expérimental).
//
// KWin ne permet pas de régler l'intensité du flou fenêtre par fenêtre ; on
// reproduit donc le flou ici : l'image du fond d'écran est chargée une
// seconde fois dans la fenêtre du Dock, recadrée à l'endroit exact où se
// trouve le Dock, puis floutée avec MultiEffect. Seul le fond d'écran est
// flouté : les fenêtres qui se trouveraient derrière le Dock ne le sont pas.
//
// Les informations sur le fond d'écran (image, mode de remplissage, taille)
// sont trouvées par main.qml et transmises par DockBackground.
Item {
    id: backdrop

    // 0..1, fourni par DockBackground.
    property real strength: 0
    // Position (pixels écran) du coin supérieur gauche de ce composant.
    property point origin: Qt.point(0, 0)
    property real cornerRadius: 0
    // { source, fillMode, width, height }
    property var info: ({ "source": "", "fillMode": Image.PreserveAspectCrop,
        "width": 0, "height": 0 })

    // Marge autour du Dock : le flou échantillonne au-delà des bords, sans
    // elle les bords seraient assombris.
    readonly property real pad: 48
    readonly property bool ready: String(info.source).length > 0
        && info.width > 0 && info.height > 0
        && wallpaperImage.status === Image.Ready

    // Source du flou : le fond d'écran à l'échelle de l'écran, décalé pour que
    // l'angle du Dock (moins la marge) tombe en (0, 0).
    Item {
        id: wallpaperLayer

        x: -backdrop.pad
        y: -backdrop.pad
        width: backdrop.width + 2 * backdrop.pad
        height: backdrop.height + 2 * backdrop.pad
        visible: false

        Image {
            id: wallpaperImage

            x: backdrop.pad - backdrop.origin.x
            y: backdrop.pad - backdrop.origin.y
            width: backdrop.info.width
            height: backdrop.info.height
            source: String(backdrop.info.source)
            fillMode: backdrop.info.fillMode
            asynchronous: true
            cache: true
            smooth: true
            sourceSize.width: backdrop.info.width
            sourceSize.height: backdrop.info.height
        }
    }

    // Masque aux coins arrondis du Dock (même taille que la source).
    Item {
        id: maskItem

        x: -backdrop.pad
        y: -backdrop.pad
        width: wallpaperLayer.width
        height: wallpaperLayer.height
        layer.enabled: true
        visible: false

        Rectangle {
            anchors.fill: parent
            anchors.margins: backdrop.pad
            radius: backdrop.cornerRadius
            color: "black"
        }
    }

    // Un seul effet : flou + masque. Il déborde du Dock de « pad » de chaque
    // côté, le masque ne laisse voir que l'intérieur du Dock.
    MultiEffect {
        x: -backdrop.pad
        y: -backdrop.pad
        width: wallpaperLayer.width
        height: wallpaperLayer.height
        visible: backdrop.ready
        source: wallpaperLayer
        autoPaddingEnabled: false
        blurEnabled: true
        blur: backdrop.strength
        blurMax: 64
        maskEnabled: true
        maskSource: maskItem
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1.0
    }
}
