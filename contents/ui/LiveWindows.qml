pragma ComponentBehavior: Bound

import QtQuick

// Les fenêtres placées derrière le Dock, redessinées en direct.
//
// Chaque fenêtre qui s'approche de la zone lue par le verre est capturée par
// PipeWire (le flux qui sert déjà aux aperçus au survol des icônes) et posée à
// sa position réelle, du dessous au dessus. Le fond reste transparent : le
// verre relit cette scène et la pose sur le fond d'écran. Rien ne passe par
// KWin : aucun effet du bureau n'est touché.
//
// Important : la liste reçue est recréée à chaque pas d'un déplacement de
// fenêtre. Si elle servait directement de modèle à un Repeater, toutes les
// vignettes seraient détruites puis recréées à chaque pas, et leur flux de
// capture redémarrerait à chaque fois (donc rien à l'écran pendant le
// mouvement). On la recopie donc dans un ListModel stable, identifié par
// l'identifiant de fenêtre : une fenêtre qui bouge garde sa vignette et son flux,
// seules sa position et sa taille changent.
Item {
    id: scene

    // [{ id, x, y, w, h }] en coordonnées écran, du dessous au dessus.
    property var windows: []
    // Coin supérieur gauche de la zone lue (coordonnées écran).
    property real regionX: 0
    property real regionY: 0
    // Faux : aucun flux n'est ouvert (fenêtre du Dock masquée).
    property bool running: true
    // Une fenêtre commence à être capturée un peu avant d'atteindre la zone,
    // pour que son image soit déjà là quand elle passe sous le Dock.
    property real prefetchMargin: 240

    // Nombre de fenêtres qui touchent réellement la zone.
    property int touchingCount: 0
    readonly property int activeCount: running ? touchingCount : 0
    // Diagnostic : visible dans le journal (journalctl --user -b).
    onActiveCountChanged: console.log("macOS Dock: live windows behind the Dock:",
        activeCount)

    // Identifiant brut de chaque fenêtre (clé texte -> identifiant), tel que le
    // fournit le gestionnaire de tâches. Modifié sur place, jamais remplacé :
    // le ListModel ne conserve que la clé et la géométrie.
    property var rawIds: ({})

    function keyOf(entry) {
        return String(entry.id);
    }

    function usable(entry) {
        return entry !== undefined && entry !== null
            && String(entry.id).length > 0
            && entry.w > 1 && entry.h > 1;
    }

    function intersects(x, y, w, h, margin) {
        return x < regionX + width + margin && x + w > regionX - margin
            && y < regionY + height + margin && y + h > regionY - margin;
    }

    function syncModel() {
        var list = windows || [];
        var wanted = [];
        var wantedKeys = ({});
        var ids = ({});
        var i;
        for (i = 0; i < list.length; ++i) {
            if (!usable(list[i])) {
                continue;
            }
            var key = keyOf(list[i]);
            if (wantedKeys[key] === true) {
                continue;
            }
            wantedKeys[key] = true;
            ids[key] = list[i].id;
            wanted.push(list[i]);
        }
        // Les identifiants bruts d'abord : un nouveau délégué les lit à sa création.
        for (var rawKey in ids) {
            rawIds[rawKey] = ids[rawKey];
        }

        // 1. Retirer les fenêtres disparues.
        for (i = rowModel.count - 1; i >= 0; --i) {
            if (wantedKeys[rowModel.get(i).key] !== true) {
                delete rawIds[rowModel.get(i).key];
                rowModel.remove(i);
            }
        }

        // 2. Ajouter, ordonner et mettre à jour les autres.
        var touching = 0;
        for (i = 0; i < wanted.length; ++i) {
            var entry = wanted[i];
            var entryKey = keyOf(entry);
            if (i < rowModel.count && rowModel.get(i).key === entryKey) {
                // déjà à sa place
            } else {
                var found = -1;
                for (var j = i + 1; j < rowModel.count; ++j) {
                    if (rowModel.get(j).key === entryKey) {
                        found = j;
                        break;
                    }
                }
                if (found >= 0) {
                    rowModel.move(found, i, 1);
                } else {
                    rowModel.insert(i, {
                        "key": entryKey,
                        "wx": entry.x,
                        "wy": entry.y,
                        "ww": entry.w,
                        "wh": entry.h
                    });
                }
            }
            var row = rowModel.get(i);
            if (row.wx !== entry.x) {
                rowModel.setProperty(i, "wx", entry.x);
            }
            if (row.wy !== entry.y) {
                rowModel.setProperty(i, "wy", entry.y);
            }
            if (row.ww !== entry.w) {
                rowModel.setProperty(i, "ww", entry.w);
            }
            if (row.wh !== entry.h) {
                rowModel.setProperty(i, "wh", entry.h);
            }
            if (intersects(entry.x, entry.y, entry.w, entry.h, 0)) {
                ++touching;
            }
        }
        touchingCount = touching;
    }

    // Le compte des fenêtres qui touchent dépend aussi de la zone lue.
    function recount() {
        var list = windows || [];
        var touching = 0;
        for (var i = 0; i < list.length; ++i) {
            if (usable(list[i]) && intersects(list[i].x, list[i].y,
                    list[i].w, list[i].h, 0)) {
                ++touching;
            }
        }
        touchingCount = touching;
    }

    onWindowsChanged: syncModel()
    onRegionXChanged: recount()
    onRegionYChanged: recount()
    onWidthChanged: recount()
    onHeightChanged: recount()
    Component.onCompleted: syncModel()

    ListModel {
        id: rowModel
    }

    Repeater {
        model: rowModel

        delegate: Item {
            id: slot

            required property int index
            required property string key
            required property real wx
            required property real wy
            required property real ww
            required property real wh

            // Lu une seule fois, à la création : le flux de capture n'est jamais
            // relancé tant que la fenêtre existe.
            readonly property var windowId: scene.rawIds[slot.key]

            x: slot.wx - scene.regionX
            y: slot.wy - scene.regionY
            width: slot.ww
            height: slot.wh
            z: slot.index

            Loader {
                anchors.fill: parent
                active: scene.running && slot.windowId !== undefined
                    && scene.intersects(slot.wx, slot.wy, slot.ww, slot.wh,
                        scene.prefetchMargin)
                sourceComponent: PipeWireThumbnail {
                    windowId: slot.windowId
                }
            }
        }
    }
}
