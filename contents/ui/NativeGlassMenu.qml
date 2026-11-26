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
        "folder": "folder",
        "attach": "document-open",
        "search": "edit-find"
    })

    // Entrées avec sous-menu : { text, children: [...] } (sans « id »).
    function nativeItems() {
        return convertEntries(entries);
    }

    function convertEntries(list) {
        var items = [];
        for (var i = 0; i < list.length; ++i) {
            var entry = list[i];
            if (entry.separator) {
                items.push({ "separator": true });
                continue;
            }
            var icon = entry.glyph ? (iconNames[entry.glyph] || "")
                : (entry.id === "settings" ? "configure"
                    : (entry.id === "open" ? "document-open" : ""));
            var item = { "id": entry.id, "text": entry.text, "icon": icon,
                "enabled": entry.enabled !== false };
            if (entry.children && entry.children.length > 0) {
                item.children = convertEntries(entry.children);
            }
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
    // direction (facultatif) : "up", "down", "left"… ; sinon « down » (ou « left » si rightAligned).
    function openAt(x, y, rightAligned, direction) {
        if (!window || !nativeMenu.available) {
            return;
        }
        // Sans le liseré blanc lumineux, réservé aux menus du Dock.
        nativeMenu.popup(window, x, y, direction ? direction : (rightAligned ? "left" : "down"),
            nativeItems(), false, false);
    }

    // Ouvre le menu SUR le bouton qui l'a déclenché : il part de la taille du
    // bouton et s'agrandit, comme si le bouton devenait le menu. Le menu s'accroche
    // au coin haut gauche du bouton (rightAligned : haut droit ; direction "up" :
    // bas gauche, il s'ouvre alors vers le haut).
    function openFrom(item, rightAligned, direction) {
        if (!window || !nativeMenu.available || !item) {
            return;
        }
        var origin = item.mapToItem(null, 0, 0);
        var dir = direction ? direction : (rightAligned ? "left" : "down");
        var x = dir === "left" ? origin.x + item.width : origin.x;
        var y = dir === "up" ? origin.y + item.height : origin.y;
        nativeMenu.popup(window, x, y, dir, nativeItems(), false, false,
            Qt.rect(origin.x, origin.y, item.width, item.height));
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
