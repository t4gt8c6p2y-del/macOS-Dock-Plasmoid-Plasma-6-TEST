import QtQuick
import "effects" as DockEffects

// Menu des fenêtres Spotlight et Siri IA : le même menu natif que le clic
// droit du Dock (DockMenu, un vrai QMenu). Il est donc une fenêtre à part
// pour KWin : il reçoit son propre flou et son propre effet Liquid Glass,
// avec ses propres bords. Un menu dessiné dans la fenêtre fusionnerait avec
// le panneau en dessous et n'aurait aucun bord réfractant.
//
// entries : [{ id, text, glyph, checked, shortcut, separator, enabled }]
QtObject {
    id: menu

    property var entries: []
    // Gardé pour la compatibilité avec l'ancien GlassMenu (thème du verre).
    property var theme: ({})
    // Fenêtre qui porte le menu (obligatoire).
    property var window: null
    property bool opened: false

    signal activated(string entryId)
    signal dismissed()

    readonly property var iconNames: ({
        "apps": "applications-all",
        "files": "folder",
        "clipboard": "edit-paste",
        "star": "starred-symbolic",
        "compose": "document-new",
        "expand": "view-fullscreen",
        "copy": "edit-copy",
        "trash": "edit-delete",
        "pin": "pin",
        "search": "edit-find"
    })

    function nativeItems() {
        var items = [];
        for (var i = 0; i < entries.length; ++i) {
            var entry = entries[i];
            if (entry.separator) {
                items.push({ "separator": true });
                continue;
            }
            var icon = entry.glyph ? (iconNames[entry.glyph] || "")
                : (entry.id === "settings" ? "configure"
                    : (entry.id === "open" ? "document-open" : ""));
            var item = { "id": entry.id, "text": entry.text, "icon": icon,
                "enabled": entry.enabled !== false };
            if (entry.checked !== undefined) {
                item.checked = entry.checked === true;
            }
            if (entry.shortcut) {
                item.shortcut = entry.shortcut;
            }
            items.push(item);
        }
        return items;
    }

    // Ouvre le menu : (x, y) est son coin haut-droit si rightAligned, sinon
    // son coin haut-gauche (coordonnées de la fenêtre).
    function openAt(x, y, rightAligned) {
        if (!window || !nativeMenu.available) {
            return;
        }
        nativeMenu.popup(window, x, y, rightAligned ? "left" : "down",
            nativeItems(), false);
    }

    function close() {
        nativeMenu.close();
    }

    readonly property DockEffects.DockMenu nativeMenu: DockEffects.DockMenu {
        onTriggered: (entryId) => menu.activated(entryId)
        onOpened: menu.opened = true
        onClosed: {
            menu.opened = false;
            menu.dismissed();
        }
    }
}
