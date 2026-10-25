pragma ComponentBehavior: Bound

import QtQuick

// Les fenêtres placées derrière le Dock, redessinées en direct.
//
// Chaque fenêtre qui touche la zone lue par le verre est capturée par PipeWire
// (le flux qui sert déjà aux aperçus au survol des icônes) et posée à sa
// position réelle, du dessous au dessus. Le fond reste transparent : GlassPane
// relit cette scène et la pose sur le fond d'écran. Rien ne passe par KWin :
// aucun effet du bureau n'est touché.
Item {
    id: scene

    // [{ id, x, y, w, h }] en coordonnées écran, du dessous au dessus.
    property var windows: []
    // Coin supérieur gauche de la zone lue (coordonnées écran).
    property real regionX: 0
    property real regionY: 0
    // Faux : aucun flux n'est ouvert (fenêtre du Dock masquée).
    property bool running: true

    // Nombre de fenêtres qui touchent réellement la zone.
    readonly property int activeCount: running ? countTouching() : 0

    function touches(entry) {
        return entry !== undefined && entry !== null
            && String(entry.id).length > 0
            && entry.w > 1 && entry.h > 1
            && entry.x < regionX + width && entry.x + entry.w > regionX
            && entry.y < regionY + height && entry.y + entry.h > regionY;
    }

    function countTouching() {
        var count = 0;
        var list = windows || [];
        for (var i = 0; i < list.length; ++i) {
            if (touches(list[i])) {
                ++count;
            }
        }
        return count;
    }

    Repeater {
        model: scene.windows

        delegate: Item {
            id: entry

            required property var modelData
            required property int index

            x: entry.modelData.x - scene.regionX
            y: entry.modelData.y - scene.regionY
            width: entry.modelData.w
            height: entry.modelData.h
            z: entry.index

            Loader {
                anchors.fill: parent
                active: scene.running && scene.touches(entry.modelData)
                sourceComponent: PipeWireThumbnail {
                    windowId: entry.modelData.id
                }
            }
        }
    }
}
