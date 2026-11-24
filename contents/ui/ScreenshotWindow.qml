import QtQuick
import org.kde.layershell as LayerShell

// Capture d'écran « Demander à Siri » : l'écran est figé, on trace la zone à
// envoyer (puis on la redimensionne par ses poignées ou on la déplace en la
// glissant), et une barre avec un seul bouton « Demander à Siri » apparaît. Le
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

    // --- Ajuster la zone une fois tracée ------------------------------------------
    // Les poignées des bords et des coins la redimensionnent ; la glisser par
    // l'intérieur la déplace. Une fois la zone normalisée (beginAdjust), le
    // point d'appui est son coin haut gauche et le point courant son coin bas
    // droit.
    readonly property real minSelection: 24
    property real moveWidth: 0
    property real moveHeight: 0
    property real moveOriginX: 0
    property real moveOriginY: 0

    function beginAdjust() {
        var x = selX;
        var y = selY;
        var w = selW;
        var h = selH;
        anchorX = x;
        anchorY = y;
        pointX = x + w;
        pointY = y + h;
        moveWidth = w;
        moveHeight = h;
        moveOriginX = x;
        moveOriginY = y;
    }

    // edges : combinaison de Qt.LeftEdge, RightEdge, TopEdge et BottomEdge ;
    // (px, py) : position du pointeur dans la fenêtre.
    function adjustEdges(edges, px, py) {
        var x = clamp(px, 0, width);
        var y = clamp(py, 0, height);
        if (edges & Qt.LeftEdge) {
            anchorX = Math.min(x, pointX - minSelection);
        }
        if (edges & Qt.RightEdge) {
            pointX = Math.max(x, anchorX + minSelection);
        }
        if (edges & Qt.TopEdge) {
            anchorY = Math.min(y, pointY - minSelection);
        }
        if (edges & Qt.BottomEdge) {
            pointY = Math.max(y, anchorY + minSelection);
        }
    }

    function moveSelection(dx, dy) {
        var x = clamp(moveOriginX + dx, 0, Math.max(0, width - moveWidth));
        var y = clamp(moveOriginY + dy, 0, Math.max(0, height - moveHeight));
        anchorX = x;
        anchorY = y;
        pointX = x + moveWidth;
        pointY = y + moveHeight;
    }

    // Poignée de la zone : un point (coin) ou une bande (bord) à saisir.
    component SelHandle: MouseArea {
        id: handle

        required property int edges

        readonly property bool corner:
            (edges & (Qt.LeftEdge | Qt.RightEdge)) !== 0
            && (edges & (Qt.TopEdge | Qt.BottomEdge)) !== 0

        visible: win.ready
        z: 2
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        cursorShape: {
            if (edges === (Qt.LeftEdge | Qt.TopEdge)
                    || edges === (Qt.RightEdge | Qt.BottomEdge)) {
                return Qt.SizeFDiagCursor;
            }
            if (corner) {
                return Qt.SizeBDiagCursor;
            }
            return (edges & (Qt.LeftEdge | Qt.RightEdge)) !== 0
                ? Qt.SizeHorCursor : Qt.SizeVerCursor;
        }

        onPressed: win.beginAdjust()
        onPositionChanged: function (mouse) {
            if (pressed) {
                var point = handle.mapToItem(null, mouse.x, mouse.y);
                win.adjustEdges(handle.edges, point.x, point.y);
            }
        }

        // Point visible : aux coins et au milieu de chaque bord.
        Rectangle {
            anchors.centerIn: parent
            width: handle.corner ? 12 : 10
            height: width
            radius: width / 2
            color: "white"
            border.width: 1
            border.color: Qt.rgba(0, 0, 0, 0.35)
        }
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

        // Glisser la zone par l'intérieur la déplace.
        MouseArea {
            id: moveArea

            property real startX: 0
            property real startY: 0

            visible: win.ready
            z: 1
            x: win.selX
            y: win.selY
            width: win.selW
            height: win.selH
            acceptedButtons: Qt.LeftButton
            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.SizeAllCursor
            onPressed: function (mouse) {
                win.beginAdjust();
                var point = mapToItem(null, mouse.x, mouse.y);
                startX = point.x;
                startY = point.y;
            }
            onPositionChanged: function (mouse) {
                if (pressed) {
                    var point = mapToItem(null, mouse.x, mouse.y);
                    win.moveSelection(point.x - startX, point.y - startY);
                }
            }
        }

        // Poignées : les quatre coins, puis le milieu de chaque bord (bandes
        // qui longent le bord, pour l'attraper facilement).
        SelHandle {
            edges: Qt.LeftEdge | Qt.TopEdge
            x: win.selX - 11
            y: win.selY - 11
            width: 22
            height: 22
        }

        SelHandle {
            edges: Qt.RightEdge | Qt.TopEdge
            x: win.selX + win.selW - 11
            y: win.selY - 11
            width: 22
            height: 22
        }

        SelHandle {
            edges: Qt.LeftEdge | Qt.BottomEdge
            x: win.selX - 11
            y: win.selY + win.selH - 11
            width: 22
            height: 22
        }

        SelHandle {
            edges: Qt.RightEdge | Qt.BottomEdge
            x: win.selX + win.selW - 11
            y: win.selY + win.selH - 11
            width: 22
            height: 22
        }

        SelHandle {
            edges: Qt.TopEdge
            x: win.selX + win.selW / 2 - 18
            y: win.selY - 9
            width: 36
            height: 18
        }

        SelHandle {
            edges: Qt.BottomEdge
            x: win.selX + win.selW / 2 - 18
            y: win.selY + win.selH - 9
            width: 36
            height: 18
        }

        SelHandle {
            edges: Qt.LeftEdge
            x: win.selX - 9
            y: win.selY + win.selH / 2 - 18
            width: 18
            height: 36
        }

        SelHandle {
            edges: Qt.RightEdge
            x: win.selX + win.selW - 9
            y: win.selY + win.selH / 2 - 18
            width: 18
            height: 36
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
