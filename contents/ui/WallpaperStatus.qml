import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import "effects" as DockEffects

// Montre le fond d'écran que le Dock a détecté et les couleurs qu'il lit
// dessus, le long du bas de l'écran. Chargé à part (Loader) par la page de
// configuration : si le module natif manquait, seule cette ligne disparaîtrait.
ColumnLayout {
    id: status

    // Image choisie à la main (vide = détection automatique).
    property string manualImage: ""
    property string source: ""
    property var colors: []

    function refresh() {
        var found = "";
        var fillMode = 2;
        if (manualImage.length > 0) {
            found = manualImage.indexOf("://") < 0 && manualImage.charAt(0) === "/"
                ? "file://" + manualImage : manualImage;
        } else {
            var info = locator.currentWallpaper(0);
            if (info && info.source) {
                found = String(info.source);
                fillMode = Number(info.fillMode);
            }
        }
        source = found;
        var list = [];
        if (found.length > 0) {
            var screen = Qt.application.screens.length > 0
                ? Qt.application.screens[0] : null;
            var width = screen ? screen.width : 1920;
            var height = screen ? screen.height : 1080;
            list = locator.sampleColors(found, fillMode, width, height,
                0, height - 90, width, 80, 16, 1);
        }
        colors = list ? list : [];
    }

    onManualImageChanged: refresh()

    DockEffects.WallpaperLocator {
        id: locator
    }

    RowLayout {
        Layout.fillWidth: true

        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: Text.WrapAnywhere
            text: status.source.length === 0
                ? i18n("No wallpaper detected: choose the image yourself.")
                : (status.colors.length === 0
                    ? i18n("Wallpaper found but unreadable: %1",
                        status.source.replace("file://", ""))
                    : status.source.replace("file://", ""))
        }

        QQC2.Button {
            icon.name: "view-refresh"
            onClicked: status.refresh()

            QQC2.ToolTip.visible: hovered
            QQC2.ToolTip.text: i18n("Check again")
        }
    }

    // Les couleurs lues au bas de l'écran, de gauche à droite : c'est ce que
    // la bordure du Dock reprend.
    Row {
        Layout.fillWidth: true
        visible: status.colors.length > 0
        spacing: 0

        Repeater {
            model: status.colors

            delegate: Rectangle {
                required property var modelData

                width: 14
                height: 14
                color: modelData
            }
        }
    }

    Component.onCompleted: refresh()
}
