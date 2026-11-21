import QtQuick
import org.kde.layershell as LayerShell

// Capture d'écran « Demander à Siri » : l'écran est figé, on trace la zone à
// envoyer, et une barre avec un seul bouton « Demander à Siri » apparaît. Le
// bouton ouvre la fenêtre de conversation du Spotlight, avec la zone capturée
// jointe au-dessus de la barre d'écriture (voir SpotlightWindow.openWithImage).
//
// La capture elle-même est faite par Spectacle en arrière-plan, sans son
// interface (« spectacle -b -n -m -o fichier ») : un plasmoïde ne peut pas lire
// l'écran lui-même sous Wayland, et la barre d'outils de Spectacle (annotations)
// n'est pas modifiable. Déclenchée par D-Bus :
//   dbus-send --session --type=method_call --dest=org.macosdock.Spotlight \
//       /Spotlight org.macosdock.Spotlight.screenshot
// ou depuis le menu « + » de la fenêtre de conversation du Spotlight.
Window {
    id: win

    property var backend: null
    readonly property color accent: "#007AFF"

    // La zone choisie, enregistrée en PNG : son chemin.
    signal imageReady(string path)

    // 0 = repos, 1 = capture en cours, 2 = l'écran figé est affiché.
    property int phase: 0
    property string shotPath: ""
    property int captureProcess: -1
    property bool retriedFullscreen: false

    // Sélection : point d'appui et point courant (pixels de la fenêtre).
    property real anchorX: 0
    property real anchorY: 0
    property real pointX: 0
    property real pointY: 0
    property bool dragging: false

    readonly property real selX: Math.min(anchorX, pointX)
    readonly property real selY: Math.min(anchorY, pointY)
    readonly property real selW: Math.abs(pointX - anchorX)
    readonly property real selH: Math.abs(pointY - anchorY)
    readonly property bool hasSelection: selW >= 8 && selH >= 8
    // Zone choisie et relâchée : la barre est affichée.
    readonly property bool ready: hasSelection && !dragging

    flags: Qt.FramelessWindowHint
    color: "transparent"
    visible: false
    title: "Screenshot"
    width: screen ? screen.width : 1920
    height: screen ? screen.height : 1080

    LayerShell.Window.scope: "macosdock-screenshot"
    LayerShell.Window.anchors: LayerShell.Window.AnchorTop
        | LayerShell.Window.AnchorBottom
        | LayerShell.Window.AnchorLeft
        | LayerShell.Window.AnchorRight
    LayerShell.Window.exclusionZone: -1
    LayerShell.Window.layer: LayerShell.Window.LayerOverlay
    LayerShell.Window.keyboardInteractivity:
        LayerShell.Window.KeyboardInteractivityExclusive
    LayerShell.Window.activateOnShow: true
    LayerShell.Window.wantsToBeOnActiveScreen: true

    // --- Déroulement -------------------------------------------------------------
    function start() {
        if (!backend || phase !== 0) {
            return;
        }
        if (backend.findExecutable("spectacle").length === 0) {
            notify(i18n("Spectacle is needed to take screenshots, but it was not found."));
            return;
        }
        phase = 1;
        retriedFullscreen = false;
        // Laisse le temps à la fenêtre qui vient d'être fermée (le Spotlight) de
        // disparaître de l'écran avant la capture.
        startTimer.restart();
    }

    Timer {
        id: startTimer

        interval: 300
        onTriggered: win.capture(false)
    }

    function capture(fullscreen) {
        shotPath = backend.newCapturePath();
        captureProcess = backend.runProcess("spectacle",
            ["-b", "-n", fullscreen ? "-f" : "-m", "-o", shotPath], 20000);
    }

    Connections {
        target: win.backend
        ignoreUnknownSignals: true

        function onProcessFinished(id, exitCode, standardOutput, standardError, timedOut) {
            if (id !== win.captureProcess) {
                return;
            }
            win.captureProcess = -1;
            if (exitCode !== 0 && !win.retriedFullscreen) {
                // Version de Spectacle sans l'option « écran courant » : tout l'écran.
                win.retriedFullscreen = true;
                win.capture(true);
                return;
            }
            if (exitCode !== 0) {
                win.fail(i18n("The screenshot failed."));
                return;
            }
            // Le fichier est chargé ; la fenêtre s'ouvre quand l'image est prête.
            win.phase = 2;
        }
    }

    function reset() {
        visible = false;
        phase = 0;
        dragging = false;
        anchorX = 0;
        anchorY = 0;
        pointX = 0;
        pointY = 0;
        shotPath = "";
    }

    function cancel() {
        if (backend) {
            backend.discardCapture();
        }
        reset();
    }

    function fail(message) {
        cancel();
        notify(message);
    }

    // Découpe la zone choisie (tout l'écran sans sélection) et la donne au Spotlight.
    function askSiri() {
        if (phase !== 2 || !backend) {
            return;
        }
        var path = hasSelection
            ? backend.cropCapture(selX / width, selY / height, selW / width, selH / height)
            : backend.cropCapture(0, 0, 1, 1);
        reset();
        if (path.length > 0) {
            imageReady(path);
        } else {
            notify(i18n("The screenshot failed."));
        }
    }

    function notify(message) {
        if (backend) {
            backend.runProcess("notify-send",
                ["-a", "macOS Dock", "-i", "camera-photo", i18n("Screenshot"), message], 5000);
        }
    }

    function clamp(value, low, high) {
        return Math.max(low, Math.min(high, value));
    }

    // --- Écran figé ---------------------------------------------------------------
    Item {
        id: stage

        anchors.fill: parent
        focus: true

        Keys.onPressed: function (event) {
            if (event.key === Qt.Key_Escape) {
                win.cancel();
                event.accepted = true;
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                win.askSiri();
                event.accepted = true;
            }
        }

        Image {
            id: shot

            anchors.fill: parent
            // Chaque capture a son propre fichier : pas de cache à contourner.
            source: win.phase === 2 && win.shotPath.length > 0
                ? "file://" + win.shotPath.split("/").map(encodeURIComponent).join("/") : ""
            asynchronous: true
            cache: false
            smooth: true

            // L'écran figé n'apparaît qu'une fois l'image décodée : pas de
            // fenêtre noire pendant le chargement.
            onStatusChanged: {
                if (status === Image.Ready && win.phase === 2 && !win.visible) {
                    win.visible = true;
                    win.requestActivate();
                    stage.forceActiveFocus();
                } else if (status === Image.Error && win.phase === 2) {
                    win.fail(i18n("The screenshot failed."));
                }
            }
        }

        // Voile sombre sur tout l'écran, ou autour de la zone choisie.
        Rectangle {
            visible: !win.hasSelection
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.35)
        }

        Rectangle {
            visible: win.hasSelection
            x: 0
            y: 0
            width: stage.width
            height: win.selY
            color: Qt.rgba(0, 0, 0, 0.35)
        }

        Rectangle {
            visible: win.hasSelection
            x: 0
            y: win.selY + win.selH
            width: stage.width
            height: stage.height - (win.selY + win.selH)
            color: Qt.rgba(0, 0, 0, 0.35)
        }

        Rectangle {
            visible: win.hasSelection
            x: 0
            y: win.selY
            width: win.selX
            height: win.selH
            color: Qt.rgba(0, 0, 0, 0.35)
        }

        Rectangle {
            visible: win.hasSelection
            x: win.selX + win.selW
            y: win.selY
            width: stage.width - (win.selX + win.selW)
            height: win.selH
            color: Qt.rgba(0, 0, 0, 0.35)
        }

        // Contour de la zone.
        Rectangle {
            visible: win.hasSelection
            x: win.selX
            y: win.selY
            width: win.selW
            height: win.selH
            color: "transparent"
            border.width: 1.5
            border.color: Qt.rgba(1, 1, 1, 0.92)
        }

        // Taille de la zone, en pixels de l'écran.
        Rectangle {
            visible: win.hasSelection
            x: win.clamp(win.selX, 8, stage.width - width - 8)
            y: win.selY >= height + 8 ? win.selY - height - 6 : win.selY + 6
            width: sizeText.implicitWidth + 16
            height: 24
            radius: 12
            color: Qt.rgba(0, 0, 0, 0.62)

            Text {
                id: sizeText

                anchors.centerIn: parent
                text: Math.round(win.selW * shot.implicitWidth / Math.max(1, win.width))
                    + " × " + Math.round(win.selH * shot.implicitHeight / Math.max(1, win.height))
                font.pixelSize: 12
                color: "white"
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.CrossCursor
            onPressed: function (mouse) {
                win.anchorX = win.clamp(mouse.x, 0, stage.width);
                win.anchorY = win.clamp(mouse.y, 0, stage.height);
                win.pointX = win.anchorX;
                win.pointY = win.anchorY;
                win.dragging = true;
            }
            onPositionChanged: function (mouse) {
                if (win.dragging) {
                    win.pointX = win.clamp(mouse.x, 0, stage.width);
                    win.pointY = win.clamp(mouse.y, 0, stage.height);
                }
            }
            onReleased: win.dragging = false
        }

        // Consigne, tant qu'aucune zone n'est choisie.
        Rectangle {
            visible: !win.hasSelection && !win.dragging
            anchors.horizontalCenter: parent.horizontalCenter
            y: 28
            width: hintText.implicitWidth + 32
            height: 38
            radius: 19
            color: Qt.rgba(0.1, 0.1, 0.12, 0.88)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.14)

            Text {
                id: hintText

                anchors.centerIn: parent
                text: i18n("Drag to choose an area · Enter: whole screen · Esc: cancel")
                font.pixelSize: 14
                color: "white"
            }
        }

        // La barre : un seul bouton « Demander à Siri » (et la croix pour annuler).
        Rectangle {
            id: toolbar

            readonly property real below: win.selY + win.selH + 14

            visible: win.ready
            z: 3
            width: toolbarRow.implicitWidth + 16
            height: 52
            radius: 26
            x: win.clamp(win.selX + win.selW / 2 - width / 2, 12, stage.width - width - 12)
            y: below + height <= stage.height - 8
                ? below
                : (win.selY - 14 - height >= 8 ? win.selY - 14 - height
                    : stage.height - height - 24)
            color: Qt.rgba(0.1, 0.1, 0.12, 0.94)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.16)

            // Un clic sur le fond de la barre ne commence pas une nouvelle zone.
            MouseArea {
                anchors.fill: parent
            }

            Row {
                id: toolbarRow

                anchors.centerIn: parent
                spacing: 8

                Rectangle {
                    width: askRow.implicitWidth + 32
                    height: 38
                    radius: 19
                    color: askMouse.containsMouse ? Qt.lighter(win.accent, 1.15) : win.accent

                    Row {
                        id: askRow

                        anchors.centerIn: parent
                        spacing: 8

                        SpotlightGlyph {
                            anchors.verticalCenter: parent.verticalCenter
                            kind: "sparkle"
                            size: 18
                            lineWidth: 1.8
                            color: "white"
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: i18n("Ask Siri")
                            font.pixelSize: 15
                            font.weight: Font.DemiBold
                            color: "white"
                        }
                    }

                    MouseArea {
                        id: askMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: win.askSiri()
                    }
                }

                Rectangle {
                    width: 38
                    height: 38
                    radius: 19
                    color: Qt.rgba(1, 1, 1, closeMouse.containsMouse ? 0.22 : 0.12)

                    SpotlightGlyph {
                        anchors.centerIn: parent
                        kind: "close"
                        size: 14
                        lineWidth: 2.2
                        color: "white"
                    }

                    MouseArea {
                        id: closeMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: win.cancel()
                    }
                }
            }
        }
    }
}
