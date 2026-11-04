import QtQuick

// Menu « verre » dessiné dans une fenêtre du Dock (Spotlight, Siri IA) : même
// fond que les bulles du Dock (GlassSurface) et pastille de survol bleue,
// comme les menus du thème Liquid Glass. Il recouvre toute la fenêtre pour
// que le clic hors du menu le ferme.
//
// entries : [{ id, text, glyph, checked, shortcut, separator, enabled }]
Item {
    id: menu

    property var entries: []
    property var theme: ({})
    property bool opened: false
    property color accent: "#007AFF"

    signal activated(string entryId)
    signal dismissed()

    // Rectangle du menu en coordonnées de la fenêtre (pour le flou de KWin).
    readonly property rect boxRect: Qt.rect(box.x, box.y, box.width, box.height)
    readonly property real rowHeight: 30
    readonly property real separatorHeight: 11

    anchors.fill: parent
    visible: opened
    z: 1000

    // Ouvre le menu : (x, y) est son coin haut-droit si rightAligned, sinon
    // son coin haut-gauche.
    function openAt(x, y, rightAligned) {
        var width = box.width;
        var left = rightAligned ? x - width : x;
        box.x = Math.max(8, Math.min(menu.width - width - 8, left));
        box.y = Math.max(8, Math.min(menu.height - box.height - 8, y));
        opened = true;
    }

    function close() {
        if (opened) {
            opened = false;
            dismissed();
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onPressed: menu.close()
    }

    GlassSurface {
        id: box

        theme: menu.theme
        radius: 14
        width: 250
        height: entriesColumn.implicitHeight + 12

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
        }

        Column {
            id: entriesColumn

            x: 6
            y: 6
            width: parent.width - 12

            Repeater {
                model: menu.entries

                delegate: Item {
                    id: entryRow

                    required property var modelData

                    readonly property bool isSeparator: modelData.separator === true
                    readonly property bool isEnabled: modelData.enabled !== false

                    width: entriesColumn.width
                    height: isSeparator ? menu.separatorHeight : menu.rowHeight

                    Rectangle {
                        visible: entryRow.isSeparator
                        anchors.verticalCenter: parent.verticalCenter
                        x: 8
                        width: parent.width - 16
                        height: 1
                        color: Qt.rgba(1, 1, 1, 0.14)
                    }

                    Rectangle {
                        visible: !entryRow.isSeparator
                        anchors.fill: parent
                        radius: 8
                        color: rowMouse.containsMouse && entryRow.isEnabled
                            ? menu.accent : "transparent"
                    }

                    SpotlightGlyph {
                        visible: !entryRow.isSeparator
                        x: 8
                        anchors.verticalCenter: parent.verticalCenter
                        kind: entryRow.modelData.checked === true
                            ? "check" : (entryRow.modelData.glyph || "")
                        size: 15
                        lineWidth: 1.8
                        color: Qt.rgba(1, 1, 1, entryRow.isEnabled ? 0.95 : 0.35)
                    }

                    Text {
                        visible: !entryRow.isSeparator
                        x: 32
                        width: parent.width - 32 - shortcutLabel.width - 14
                        anchors.verticalCenter: parent.verticalCenter
                        text: entryRow.modelData.text || ""
                        elide: Text.ElideRight
                        font.pixelSize: 13.5
                        color: Qt.rgba(1, 1, 1, entryRow.isEnabled ? 0.95 : 0.35)
                    }

                    Text {
                        id: shortcutLabel

                        visible: !entryRow.isSeparator
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: entryRow.modelData.shortcut || ""
                        font.pixelSize: 12
                        color: Qt.rgba(1, 1, 1, 0.5)
                    }

                    MouseArea {
                        id: rowMouse

                        anchors.fill: parent
                        enabled: !entryRow.isSeparator && entryRow.isEnabled
                        hoverEnabled: true
                        onClicked: {
                            var id = entryRow.modelData.id;
                            menu.opened = false;
                            menu.activated(id);
                            menu.dismissed();
                        }
                    }
                }
            }
        }
    }
}
