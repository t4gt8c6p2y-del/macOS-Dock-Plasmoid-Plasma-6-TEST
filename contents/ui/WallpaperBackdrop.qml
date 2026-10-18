pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import org.kde.plasma.plasmoid

// Flou réel du fond d'écran derrière le Dock (expérimental).
//
// KWin ne permet pas de régler l'intensité du flou fenêtre par fenêtre ; on
// reproduit donc le flou ici : l'image du fond d'écran du bureau est chargée
// une seconde fois dans la fenêtre du Dock, recadrée à l'endroit exact où se
// trouve le Dock, puis floutée avec MultiEffect. Seul le fond d'écran est
// flouté : les fenêtres qui se trouveraient derrière le Dock ne le sont pas.
//
// Si le fond d'écran n'est pas une image trouvable (couleur unie, fond animé),
// ce composant ne dessine rien.
Item {
    id: backdrop

    // 0..1, fourni par DockBackground.
    property real strength: 0
    // Position (pixels écran) du coin supérieur gauche de ce composant.
    property point origin: Qt.point(0, 0)
    property real cornerRadius: 0

    // Marge supplémentaire autour du Dock : le flou échantillonne au-delà des
    // bords, sans elle les bords seraient assombris.
    readonly property real pad: 48

    property var wallpaperItem: null
    property string imageSource: ""
    property int imageFillMode: Image.PreserveAspectCrop
    readonly property real wallpaperWidth:
        wallpaperItem && wallpaperItem.width > 0 ? wallpaperItem.width : 0
    readonly property real wallpaperHeight:
        wallpaperItem && wallpaperItem.height > 0 ? wallpaperItem.height : 0
    readonly property bool ready: imageSource.length > 0
        && wallpaperWidth > 0 && wallpaperHeight > 0
        && wallpaperImage.status === Image.Ready

    // Cherche l'Image en cours d'affichage dans l'arbre du fond d'écran.
    function findImage(node, depth) {
        if (!node || depth > 10) {
            return null;
        }
        if (node.source !== undefined && node.fillMode !== undefined
                && String(node.source).length > 0) {
            return node;
        }
        var found = null;
        if (node.item !== undefined && node.item !== null) {
            found = findImage(node.item, depth + 1);
            if (found) {
                return found;
            }
        }
        if (node.currentItem !== undefined && node.currentItem !== null) {
            found = findImage(node.currentItem, depth + 1);
            if (found) {
                return found;
            }
        }
        var children = node.children;
        if (children) {
            for (var i = 0; i < children.length; ++i) {
                found = findImage(children[i], depth + 1);
                if (found) {
                    return found;
                }
            }
        }
        return null;
    }

    function resolveWallpaper() {
        var containment = Plasmoid.containment;
        var wallpaper = containment ? containment.wallpaperGraphicsObject : null;
        if (!wallpaper) {
            wallpaperItem = null;
            imageSource = "";
            return;
        }
        wallpaperItem = wallpaper;

        var source = "";
        var fillMode = Image.PreserveAspectCrop;
        var image = findImage(wallpaper, 0);
        if (image) {
            source = String(image.source);
            fillMode = Number(image.fillMode);
        } else {
            try {
                var configuration = wallpaper.configuration;
                if (configuration && configuration.Image) {
                    source = String(configuration.Image);
                    if (configuration.FillMode !== undefined) {
                        fillMode = Number(configuration.FillMode);
                    }
                }
            } catch (error) {
                source = "";
            }
        }
        if (source.length > 0 && source.indexOf("://") < 0
                && source.charAt(0) === "/") {
            source = "file://" + source;
        }
        if (source !== imageSource) {
            imageSource = source;
        }
        if (fillMode !== imageFillMode) {
            imageFillMode = fillMode;
        }
    }

    Component.onCompleted: resolveWallpaper()

    // Le fond d'écran peut changer (diaporama, nouveau fond) : on relit de
    // temps en temps. Rien ne tourne tant que le flou est désactivé, ce
    // composant n'étant alors pas chargé.
    Timer {
        interval: 4000
        repeat: true
        running: true
        onTriggered: backdrop.resolveWallpaper()
    }

    // Source du flou : le fond d'écran à l'échelle de l'écran, décalé pour que
    // l'angle du Dock (moins la marge) tombe en (0, 0).
    Item {
        id: viewport

        anchors.fill: parent
        clip: true
        visible: false

        Item {
            id: padded

            x: -backdrop.pad
            y: -backdrop.pad
            width: viewport.width + 2 * backdrop.pad
            height: viewport.height + 2 * backdrop.pad

            Item {
                id: wallpaperLayer

                anchors.fill: parent
                visible: false

                Image {
                    id: wallpaperImage

                    x: backdrop.pad - backdrop.origin.x
                    y: backdrop.pad - backdrop.origin.y
                    width: backdrop.wallpaperWidth
                    height: backdrop.wallpaperHeight
                    source: backdrop.imageSource
                    fillMode: backdrop.imageFillMode
                    asynchronous: true
                    cache: true
                    smooth: true
                    sourceSize.width: backdrop.wallpaperWidth
                    sourceSize.height: backdrop.wallpaperHeight
                }
            }

            MultiEffect {
                anchors.fill: parent
                source: wallpaperLayer
                blurEnabled: true
                blur: backdrop.strength
                blurMax: 64
            }
        }
    }

    // Masque aux coins arrondis du Dock.
    Item {
        id: maskItem

        anchors.fill: parent
        layer.enabled: true
        visible: false

        Rectangle {
            anchors.fill: parent
            radius: backdrop.cornerRadius
            color: "black"
        }
    }

    MultiEffect {
        anchors.fill: parent
        source: viewport
        visible: backdrop.ready
        maskEnabled: true
        maskSource: maskItem
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1.0
    }
}
