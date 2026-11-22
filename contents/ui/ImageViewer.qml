import QtQuick

// Visionneuse d'image : l'image en grand sur un voile sombre, comme dans ChatGPT
// ou Claude. Un clic en dehors de l'image, la croix ou Échap la referment. À
// placer par-dessus tout le contenu de la fenêtre (anchors.fill + un z élevé) ;
// show(chemin) l'ouvre, et le signal closed() permet de rendre le focus au champ
// de saisie.
Item {
    id: viewer

    property string path: ""
    // Dernière image montrée : elle reste affichée pendant le fondu de sortie.
    property string shownPath: ""

    signal closed()

    readonly property bool open: path.length > 0

    function show(imagePath) {
        shownPath = String(imagePath);
        path = shownPath;
        forceActiveFocus();
    }

    function close() {
        if (!open) {
            return;
        }
        path = "";
        closed();
    }

    visible: opacity > 0.01
    opacity: open ? 1 : 0

    Behavior on opacity {
        NumberAnimation {
            duration: 170
            easing.type: Easing.OutCubic
        }
    }

    // Tant que la visionneuse est ouverte, aucune touche n'atteint le reste de
    // la fenêtre (ni le champ de saisie, ni les raccourcis).
    Keys.onPressed: function (event) {
        if (viewer.open && event.key === Qt.Key_Escape) {
            viewer.close();
        }
        event.accepted = viewer.open;
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.84)
    }

    // Un clic n'importe où (hors de l'image) referme.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onClicked: viewer.close()
    }

    Image {
        id: picture

        // Taille de l'image : elle tient dans la fenêtre sans jamais être
        // agrandie au-delà de sa taille réelle (pas de flou).
        readonly property real fit: implicitWidth > 0 && implicitHeight > 0
            ? Math.min(1, (viewer.width * 0.9) / implicitWidth,
                (viewer.height * 0.86) / implicitHeight) : 1

        anchors.centerIn: parent
        width: implicitWidth * fit
        height: implicitHeight * fit
        source: viewer.shownPath.length > 0
            ? "file://" + viewer.shownPath.split("/").map(encodeURIComponent).join("/") : ""
        asynchronous: true
        smooth: true
        mipmap: true
        fillMode: Image.PreserveAspectFit
        // Les très grandes captures sont réduites au décodage.
        sourceSize: Qt.size(2400, 2400)
        scale: viewer.open ? 1 : 0.96

        Behavior on scale {
            NumberAnimation {
                duration: 170
                easing.type: Easing.OutCubic
            }
        }
    }

    // Un clic sur l'image elle-même ne la referme pas.
    MouseArea {
        anchors.centerIn: picture
        width: picture.width
        height: picture.height
    }

    // Image introuvable (fichier supprimé).
    Text {
        visible: picture.status === Image.Error
        anchors.centerIn: parent
        text: i18n("Image not found")
        font.pixelSize: 15
        color: Qt.rgba(1, 1, 1, 0.7)
    }

    Rectangle {
        id: closeButton

        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 22
        anchors.rightMargin: 22
        width: 38
        height: 38
        radius: 19
        color: Qt.rgba(1, 1, 1, closeMouse.containsMouse ? 0.26 : 0.14)

        SpotlightGlyph {
            anchors.centerIn: parent
            kind: "close"
            size: 16
            lineWidth: 2.2
            color: "white"
        }

        MouseArea {
            id: closeMouse

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: viewer.close()
        }
    }
}
