import QtQuick

// Pièce jointe d'une conversation avec l'assistant : l'aperçu pour une image ;
// à défaut (ce n'est pas une image, ou l'aperçu est impossible), une icône du
// type de fichier (PDF, Word, tableur, archive, dossier…) avec le nom. Le petit
// bouton rond la retire.
Item {
    id: card

    property string path: ""
    property string name: ""
    property bool isDir: false
    // Fond de la pastille (fichiers qui ne sont pas des images).
    property color fill: Qt.rgba(1, 1, 1, 0.12)
    property real maxNameWidth: 150

    signal removeRequested()

    readonly property string extension: {
        var base = card.path.length > 0 ? card.path : card.name;
        var dot = base.lastIndexOf(".");
        return dot > base.lastIndexOf("/") ? base.substring(dot + 1).toLowerCase() : "";
    }
    readonly property bool isImage: !card.isDir && /^(png|jpe?g|gif|webp|bmp|tiff?)$/.test(card.extension)
    // Aperçu tant que l'image n'a pas échoué à se charger.
    readonly property bool showPreview: card.isImage && preview.status !== Image.Error
    readonly property url fileUrl: card.path.length > 0
        ? "file://" + card.path.split("/").map(encodeURIComponent).join("/") : ""

    // Étiquette et couleur de l'icône, d'après l'extension.
    readonly property var info: {
        var e = card.extension;
        if (card.isDir) {
            return { "label": i18n("Folder"), "abbr": "", "color": "#4C8FE0" };
        }
        if (e === "pdf") {
            return { "label": "PDF", "abbr": "PDF", "color": "#E5493A" };
        }
        if (["doc", "docx", "odt", "rtf"].indexOf(e) >= 0) {
            return { "label": e.toUpperCase(), "abbr": "DOC", "color": "#2F6FD6" };
        }
        if (["xls", "xlsx", "ods", "csv", "tsv"].indexOf(e) >= 0) {
            return { "label": e.toUpperCase(), "abbr": "XLS", "color": "#2E9E5B" };
        }
        if (["ppt", "pptx", "odp"].indexOf(e) >= 0) {
            return { "label": e.toUpperCase(), "abbr": "PPT", "color": "#E0792B" };
        }
        if (["zip", "tar", "gz", "xz", "bz2", "zst", "7z", "rar"].indexOf(e) >= 0) {
            return { "label": e.toUpperCase(), "abbr": "ZIP", "color": "#8E7A5C" };
        }
        if (card.isImage) {
            return { "label": e.toUpperCase(), "abbr": "IMG", "color": "#8A5CD6" };
        }
        if (["txt", "md", "log"].indexOf(e) >= 0) {
            return { "label": e.toUpperCase(), "abbr": "TXT", "color": "#76808C" };
        }
        var abbr = e.length > 0 ? e.toUpperCase().substring(0, 4) : "FILE";
        return { "label": e.length > 0 ? e.toUpperCase() : "", "abbr": abbr, "color": "#76808C" };
    }

    width: card.showPreview ? 58 : pill.contentWidth
    height: card.showPreview ? 58 : 46

    RoundedImage {
        id: preview

        visible: card.showPreview
        anchors.fill: parent
        radius: 13
        source: card.isImage ? card.fileUrl : ""
    }

    Rectangle {
        id: pill

        // Largeur nécessaire : icône, nom (ou type) et bouton de retrait.
        readonly property real contentWidth: 8 + badge.width + 8 + texts.width + 8 + 20 + 6

        visible: !card.showPreview
        anchors.fill: parent
        radius: 15
        color: card.fill

        Rectangle {
            id: badge

            x: 8
            anchors.verticalCenter: parent.verticalCenter
            width: 32
            height: 32
            radius: 9
            color: card.info.color

            SpotlightGlyph {
                visible: card.isDir
                anchors.centerIn: parent
                kind: "folder"
                size: 18
                lineWidth: 1.8
                color: "white"
            }

            Text {
                visible: !card.isDir
                anchors.centerIn: parent
                text: card.info.abbr
                font.pixelSize: card.info.abbr.length > 3 ? 9 : 11
                font.weight: Font.Bold
                color: "white"
            }
        }

        Column {
            id: texts

            x: badge.x + badge.width + 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            Text {
                width: Math.min(implicitWidth, card.maxNameWidth)
                elide: Text.ElideMiddle
                text: card.name
                font.pixelSize: 12
                color: Qt.rgba(1, 1, 1, 0.92)
            }

            Text {
                visible: text.length > 0
                text: card.info.label
                font.pixelSize: 10
                color: Qt.rgba(1, 1, 1, 0.48)
            }
        }
    }

    // Bouton de retrait : dans le coin de l'aperçu, ou à droite de la pastille.
    Rectangle {
        id: closeButton

        x: card.width - width - (card.showPreview ? 4 : 6)
        y: card.showPreview ? 4 : (card.height - height) / 2
        z: 2
        width: 20
        height: 20
        radius: 10
        color: card.showPreview ? Qt.rgba(0, 0, 0, closeMouse.containsMouse ? 0.75 : 0.5)
            : Qt.rgba(1, 1, 1, closeMouse.containsMouse ? 0.2 : 0)

        SpotlightGlyph {
            anchors.centerIn: parent
            kind: "close"
            size: 10
            lineWidth: 2.2
            color: closeMouse.containsMouse ? "white" : Qt.rgba(1, 1, 1, 0.7)
        }

        MouseArea {
            id: closeMouse

            anchors.fill: parent
            anchors.margins: -4
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: card.removeRequested()
        }
    }
}
