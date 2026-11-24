import QtQuick

// Raccourcis de prompts : une rangée de pastilles rondes au-dessus de la zone
// de saisie. Chaque pastille porte le symbole (ou l'image) choisi dans les
// réglages (onglet « Prompts ») ; un clic envoie son texte dans la zone de
// saisie. La rangée n'occupe aucune place (hauteur nulle) tant qu'aucun prompt
// n'est défini.
Item {
    id: bar

    // Liste de { icon, image, title, text }.
    property var prompts: []
    property color fill: Qt.rgba(1, 1, 1, 0.12)
    property color hoverFill: Qt.rgba(1, 1, 1, 0.24)

    // Texte du prompt choisi.
    signal promptChosen(string text)

    readonly property bool shown: prompts && prompts.length > 0
    readonly property real chipSize: 34

    height: shown ? chipSize + 4 : 0
    visible: shown

    // Bulle d'aide (titre du prompt) : dessinée ici, hors du Flickable qui
    // rogne son contenu.
    property string tipText: ""
    property real tipX: 0

    Flickable {
        id: flick

        anchors.fill: parent
        contentWidth: row.width
        contentHeight: height
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.HorizontalFlick

        // La molette fait défiler la rangée quand elle déborde.
        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: function (event) {
                var delta = event.angleDelta.x !== 0 ? event.angleDelta.x : event.angleDelta.y;
                flick.contentX = Math.max(0, Math.min(
                    flick.contentWidth - flick.width, flick.contentX - delta / 2));
            }
        }

        Row {
            id: row

            // Centrée tant qu'elle tient dans la largeur.
            x: Math.max(0, (flick.width - width) / 2)
            y: 2
            spacing: 8

            Repeater {
                model: bar.prompts

                delegate: Rectangle {
                    id: chip

                    required property var modelData

                    readonly property bool hasImage:
                        String(modelData.image || "").length > 0
                        && picture.status !== Image.Error

                    width: bar.chipSize
                    height: bar.chipSize
                    radius: width / 2
                    color: chipMouse.containsMouse ? bar.hoverFill : bar.fill

                    Image {
                        id: picture

                        anchors.centerIn: parent
                        width: parent.width - 12
                        height: parent.height - 12
                        visible: chip.hasImage
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        smooth: true
                        sourceSize.width: 96
                        sourceSize.height: 96
                        source: {
                            var path = String(chip.modelData.image || "");
                            if (path.length === 0) {
                                return "";
                            }
                            return path.indexOf("://") >= 0 ? path : "file://" + path;
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: !chip.hasImage
                        width: parent.width - 6
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: {
                            var icon = String(chip.modelData.icon || "");
                            if (icon.length > 0) {
                                return icon;
                            }
                            var title = String(chip.modelData.title || "").trim();
                            return title.length > 0 ? title.charAt(0).toUpperCase() : "•";
                        }
                        font.pixelSize: 17
                        color: "white"
                    }

                    MouseArea {
                        id: chipMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: bar.promptChosen(String(chip.modelData.text || ""))
                        onContainsMouseChanged: {
                            if (containsMouse) {
                                var title = String(chip.modelData.title || "").trim();
                                bar.tipText = title.length > 0 ? title
                                    : String(chip.modelData.text || "").substring(0, 60);
                                bar.tipX = chip.mapToItem(bar, chip.width / 2, 0).x;
                            } else {
                                bar.tipText = "";
                            }
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        visible: bar.tipText.length > 0
        z: 5
        radius: 8
        color: Qt.rgba(0, 0, 0, 0.82)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.16)
        width: Math.min(tipLabel.implicitWidth + 16, 280)
        height: tipLabel.implicitHeight + 8
        x: Math.max(0, Math.min(bar.width - width, bar.tipX - width / 2))
        y: -height - 4

        Text {
            id: tipLabel

            anchors.centerIn: parent
            width: parent.width - 16
            elide: Text.ElideRight
            text: bar.tipText
            font.pixelSize: 12
            color: "white"
        }
    }
}
