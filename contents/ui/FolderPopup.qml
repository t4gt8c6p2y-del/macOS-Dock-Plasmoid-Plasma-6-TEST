pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.layershell as LayerShell
import org.kde.plasma.core as PlasmaCore

// Contenu d'un dossier du Dock, à la manière de macOS : les fichiers sortent
// de l'icône du dossier et se déplient en éventail, légèrement en diagonale
// vers la droite, du plus récent au plus ancien. Un bouton « Ouvrir dans le
// Finder » (le gestionnaire de fichiers) est tout en haut. À la fermeture,
// les fichiers se replient dans l'icône du dossier avec un léger décalage de
// l'un à l'autre.
//
// La fenêtre est transparente : seuls les fichiers et les boutons sont
// dessinés.
Window {
    id: root

    property var folderModel: null
    property Item visualParent: null
    property url rootFolderUrl: ""
    property int location: PlasmaCore.Types.BottomEdge
    property real screenEdgeMargin: 0
    property real surfaceOpacity: 0.82
    property bool useThemeColor: true
    property color customColor: "#20242b"
    property real requestedRadius: 18
    property real borderStrength: 0.44
    property real borderOpacity: 0.22
    property real shadowOpacity: 0.42
    property bool showHighlight: true
    property real highlightStrength: 1.0
    property real hoverScale: 1.06

    // Le popup est « déplié » entre showPopup() et dismiss() ; la fenêtre
    // reste visible pendant l'animation de repliement.
    property bool expanded: false

    // --- Géométrie de l'éventail -------------------------------------------
    readonly property int maxItems: 10
    readonly property real iconSize: 44
    readonly property real step: 52
    readonly property real pad: 12
    readonly property real gap: 10
    readonly property real labelMaxWidth: 220
    readonly property real pillHeight: 26
    readonly property real foldDistance: 34

    readonly property bool isVertical:
        location === PlasmaCore.Types.LeftEdge
        || location === PlasmaCore.Types.RightEdge
    // Les noms sont à gauche des icônes, sauf quand le Dock est à gauche de
    // l'écran (il n'y aurait pas la place).
    readonly property bool labelsLeft: location !== PlasmaCore.Types.LeftEdge
    // Sens du décalage latéral : vers la droite, sauf Dock à droite.
    readonly property int driftSign:
        location === PlasmaCore.Types.RightEdge ? -1 : 1
    // Sens de l'empilement : vers le haut, sauf Dock en haut.
    readonly property int stackSign:
        location === PlasmaCore.Types.TopEdge ? 1 : -1

    function drift(slot) {
        return 3.4 * slot + 0.6 * slot * slot;
    }

    readonly property real driftMax: drift(maxItems)
    readonly property real windowWidth:
        2 * pad + labelMaxWidth + gap + iconSize + driftMax
    readonly property real originX: {
        if (!labelsLeft) {
            return pad + iconSize / 2;
        }
        return driftSign > 0
            ? pad + labelMaxWidth + gap + iconSize / 2
            : windowWidth - pad - iconSize / 2;
    }

    // Place disponible (en pixels) du côté de l'éventail ; mis à jour par
    // positionPopup().
    property real availableSpan: 520
    readonly property int entryCount: fanRepeater.count
    readonly property int shownCount: Math.max(0, Math.min(maxItems,
        entryCount,
        Math.floor((availableSpan - 2 * pad - iconSize) / step) - 1))
    // Lignes occupées par les fichiers (au moins une : message « dossier
    // vide »), la ligne des boutons venant s'ajouter au bout.
    readonly property int rows: Math.max(1, shownCount)

    readonly property bool atRootFolder:
        normalizedUrl(folderModel ? folderModel.resolvedUrl : "")
            === normalizedUrl(rootFolderUrl)

    // Point d'attache : le centre de la première icône.
    function slotX(slot) {
        return originX + driftSign * drift(slot);
    }

    function slotY(slot) {
        return stackSign < 0
            ? height - pad - iconSize / 2 - slot * step
            : pad + iconSize / 2 + slot * step;
    }

    // Les fichiers se replient vers l'icône du dossier : un point situé du
    // côté du Dock par rapport à la première icône.
    readonly property real foldX: {
        if (location === PlasmaCore.Types.LeftEdge) {
            return slotX(0) - foldDistance;
        }
        if (location === PlasmaCore.Types.RightEdge) {
            return slotX(0) + foldDistance;
        }
        return slotX(0);
    }

    readonly property real foldY: {
        if (isVertical) {
            return slotY(0);
        }
        return slotY(0) - stackSign * foldDistance;
    }

    // --- Chronologie -------------------------------------------------------
    // Toute l'animation découle d'UNE seule valeur, « timeline » (0 = replié,
    // timelineMax = entièrement déplié). La position de chaque fichier est
    // calculée à partir d'elle : rien ne peut rester bloqué à mi-course, et
    // le repli est exactement le dépli à l'envers (les fichiers les plus
    // éloignés partent les premiers, avec un léger recul avant de plonger).
    readonly property real timelineMax: 520
    readonly property real slotDelay: 16
    readonly property real slotDuration: 340
    property real timeline: 0

    function easeOutBack(t) {
        var c1 = 1.25;
        var c3 = c1 + 1;
        var u = t - 1;
        return 1 + c3 * u * u * u + c1 * u * u;
    }

    // Avancement (0..1, avec dépassement) du fichier de rang « slot ».
    function slotProgress(slot) {
        return easeOutBack(clamp01((timeline - slot * slotDelay)
            / slotDuration));
    }

    // Avancement de la ligne des boutons : elle arrive en dernier.
    readonly property real buttonProgress: easeOutBack(clamp01(
        (timeline - (rows * slotDelay + 50)) / 300))

    function clamp01(value) {
        return Math.max(0, Math.min(1, value));
    }

    // Vrai quand le pointeur est sur une ligne de l'éventail (et pas dans la
    // partie transparente de la fenêtre).
    function pointOverFan(px, py) {
        if (!expanded) {
            return false;
        }
        for (var slot = 0; slot <= rows; ++slot) {
            if (Math.abs(py - slotY(slot)) > step / 2) {
                continue;
            }
            var x = slotX(slot);
            var left = labelsLeft
                ? x - iconSize / 2 - gap - labelMaxWidth : x - iconSize / 2;
            var right = labelsLeft
                ? x + iconSize / 2 : x + iconSize / 2 + gap + labelMaxWidth;
            if (px >= left && px <= right) {
                return true;
            }
        }
        return false;
    }

    readonly property bool hovered: popupHover.hovered
        && pointOverFan(popupHover.point.position.x,
            popupHover.point.position.y)

    signal openFolderRequested(url folderUrl)

    width: windowWidth
    height: 2 * pad + iconSize + rows * step
    flags: Qt.FramelessWindowHint
    color: "transparent"
    visible: false

    property real placementLeft: 0
    property real placementTop: 0
    property real placementRight: 0
    property real placementBottom: 0
    property bool positionPending: false

    LayerShell.Window.scope: "macosdock-folder-popup"
    LayerShell.Window.anchors: {
        if (root.location === PlasmaCore.Types.LeftEdge) {
            return LayerShell.Window.AnchorLeft
                | LayerShell.Window.AnchorTop;
        }
        if (root.location === PlasmaCore.Types.RightEdge) {
            return LayerShell.Window.AnchorRight
                | LayerShell.Window.AnchorTop;
        }
        if (root.location === PlasmaCore.Types.TopEdge) {
            return LayerShell.Window.AnchorLeft
                | LayerShell.Window.AnchorTop;
        }
        return LayerShell.Window.AnchorLeft
            | LayerShell.Window.AnchorBottom;
    }
    LayerShell.Window.margins.left: placementLeft
    LayerShell.Window.margins.top: placementTop
    LayerShell.Window.margins.right: placementRight
    LayerShell.Window.margins.bottom: placementBottom
    LayerShell.Window.exclusionZone: -1
    LayerShell.Window.layer: LayerShell.Window.LayerTop
    LayerShell.Window.keyboardInteractivity:
        LayerShell.Window.KeyboardInteractivityOnDemand
    LayerShell.Window.activateOnShow: true
    LayerShell.Window.wantsToBeOnActiveScreen: true

    function normalizedUrl(value) {
        return String(value || "").replace(/\/$/, "");
    }

    function activateEntry(index, isDirectory) {
        if (!folderModel) {
            return;
        }
        if (isDirectory) {
            folderModel.cd(index);
        } else {
            folderModel.run(index);
            dismiss(false);
        }
    }

    function showPopup() {
        closeTimer.stop();
        positionPopup();
        visible = true;
        expanded = true;
        runTimeline(timelineMax, Math.max(1, timelineMax - timeline));
        requestActivate();
        schedulePositionPopup();
    }

    // Replie l'éventail puis cache la fenêtre. immediate = true cache tout de
    // suite (changement de dossier).
    function dismiss(immediate) {
        if (!visible) {
            return;
        }
        if (immediate === true) {
            closeTimer.stop();
            timelineAnimation.stop();
            timeline = 0;
            expanded = false;
            visible = false;
            return;
        }
        if (!expanded) {
            return;
        }
        expanded = false;
        var duration = Math.max(120, timeline * 0.8);
        runTimeline(0, duration);
        closeTimer.interval = duration + 40;
        closeTimer.restart();
    }

    function runTimeline(target, duration) {
        timelineAnimation.stop();
        timelineAnimation.to = target;
        timelineAnimation.duration = duration;
        timelineAnimation.start();
    }

    NumberAnimation {
        id: timelineAnimation

        target: root
        property: "timeline"
        easing.type: Easing.Linear
    }

    Timer {
        id: closeTimer

        repeat: false
        onTriggered: root.visible = false
    }

    onVisibleChanged: {
        if (!visible) {
            closeTimer.stop();
            timelineAnimation.stop();
            timeline = 0;
            expanded = false;
        }
    }

    function schedulePositionPopup() {
        if (!visible || positionPending) {
            return;
        }
        positionPending = true;
        Qt.callLater(runScheduledPositionPopup);
    }

    function runScheduledPositionPopup() {
        positionPending = false;
        if (visible) {
            positionPopup();
        }
    }

    function positionPopup() {
        if (!visualParent) {
            return;
        }
        var owningWindow = visualParent.Window.window;
        if (!owningWindow || !owningWindow.contentItem) {
            return;
        }
        var targetScreen = owningWindow.screen || root.screen;
        if (!targetScreen) {
            return;
        }

        var localTopLeft = visualParent.mapToItem(
            owningWindow.contentItem, 0, 0);
        var screenLeft = targetScreen.virtualX;
        var screenTop = targetScreen.virtualY;
        var screenRight = screenLeft + targetScreen.width;
        var screenBottom = screenTop + targetScreen.height;
        var windowLeft;
        var windowTop;
        if (root.isVertical) {
            windowLeft = root.location === PlasmaCore.Types.LeftEdge
                ? screenLeft + root.screenEdgeMargin
                : screenRight - root.screenEdgeMargin - owningWindow.width;
            windowTop = screenTop
                + (targetScreen.height - owningWindow.height) / 2;
        } else {
            windowLeft = screenLeft
                + (targetScreen.width - owningWindow.width) / 2;
            windowTop = root.location === PlasmaCore.Types.TopEdge
                ? screenTop + root.screenEdgeMargin
                : screenBottom - root.screenEdgeMargin - owningWindow.height;
        }
        var itemTopLeft = Qt.point(windowLeft + localTopLeft.x,
            windowTop + localTopLeft.y);
        var spacing = Kirigami.Units.largeSpacing;

        placementLeft = 0;
        placementTop = 0;
        placementRight = 0;
        placementBottom = 0;

        if (root.isVertical) {
            // La première icône est à la hauteur de l'icône du dossier ;
            // l'éventail monte à partir de là.
            var centerY = itemTopLeft.y - screenTop + visualParent.height / 2;
            availableSpan = centerY + iconSize / 2 + pad - spacing;
            placementTop = Math.max(spacing,
                Math.min(targetScreen.height - height - spacing,
                    centerY - (height - pad - iconSize / 2)));
            if (root.location === PlasmaCore.Types.LeftEdge) {
                placementLeft = itemTopLeft.x - screenLeft
                    + visualParent.width + spacing;
            } else {
                placementRight = screenRight - itemTopLeft.x + spacing;
            }
        } else {
            var centerX = itemTopLeft.x - screenLeft + visualParent.width / 2;
            placementLeft = Math.max(spacing,
                Math.min(targetScreen.width - width - spacing,
                    centerX - originX));
            if (root.location === PlasmaCore.Types.TopEdge) {
                var iconBottom = itemTopLeft.y - screenTop
                    + visualParent.height;
                availableSpan = targetScreen.height - iconBottom - spacing;
                placementTop = iconBottom + spacing;
            } else {
                var iconTop = itemTopLeft.y - screenTop;
                availableSpan = iconTop - spacing;
                placementBottom = screenBottom - itemTopLeft.y + spacing;
            }
        }
    }

    onVisualParentChanged: if (visible) schedulePositionPopup()
    onWidthChanged: if (visible) schedulePositionPopup()
    onHeightChanged: if (visible) schedulePositionPopup()
    onScreenChanged: if (visible) schedulePositionPopup()
    onLocationChanged: if (visible) schedulePositionPopup()
    onScreenEdgeMarginChanged: if (visible) schedulePositionPopup()

    Connections {
        target: root.visualParent
        enabled: root.visible
        function onXChanged() { root.schedulePositionPopup(); }
        function onYChanged() { root.schedulePositionPopup(); }
        function onWidthChanged() { root.schedulePositionPopup(); }
        function onHeightChanged() { root.schedulePositionPopup(); }
    }

    Connections {
        target: root.visualParent ? root.visualParent.Window.window : null
        enabled: root.visible
        function onWidthChanged() { root.schedulePositionPopup(); }
        function onHeightChanged() { root.schedulePositionPopup(); }
        function onScreenChanged() { root.schedulePositionPopup(); }
    }

    Shortcut {
        sequences: [StandardKey.Cancel]
        enabled: root.visible
        onActivated: root.dismiss(false)
    }

    // --- Apparence des pastilles ------------------------------------------
    SystemPalette {
        id: palette

        colorGroup: SystemPalette.Active
    }

    readonly property color pillColor: {
        var base = useThemeColor ? palette.window : customColor;
        return Qt.rgba(base.r, base.g, base.b, 0.94);
    }
    readonly property color pillTextColor: {
        var base = useThemeColor ? palette.window : customColor;
        var luminance = 0.2126 * base.r + 0.7152 * base.g + 0.0722 * base.b;
        return useThemeColor ? palette.windowText
            : (luminance > 0.5 ? "#1b1b1b" : "#f5f5f5");
    }
    readonly property color pillBorderColor:
        Qt.rgba(1, 1, 1, 0.22)

    HoverHandler {
        id: popupHover
    }

    // Un clic dans la partie transparente de la fenêtre referme l'éventail.
    TapHandler {
        onTapped: (eventPoint) => {
            if (!root.pointOverFan(eventPoint.position.x,
                    eventPoint.position.y)) {
                root.dismiss(false);
            }
        }
    }

    // Les lignes sont dessinées dans ce conteneur (voir le délégué).
    Item {
        id: fanStage

        anchors.fill: parent
    }

    // --- Fichiers ----------------------------------------------------------
    // Chaque délégué est un Loader : seuls les premiers fichiers (shownCount)
    // créent réellement leur ligne. Sa position ne dépend que de « timeline ».
    Repeater {
        id: fanRepeater

        parent: fanStage
        model: root.visible ? root.folderModel : null

        delegate: Loader {
            id: fanDelegate

            required property int index
            required property bool isDir
            required property string display
            required property var decoration

            x: 0
            y: 0
            active: index < root.shownCount
            sourceComponent: fanRow

            // 0 = replié dans l'icône du dossier, 1 = à sa place dans
            // l'éventail (peut dépasser 1 pendant le rebond).
            readonly property real prog: root.slotProgress(index)
            readonly property real slotX: root.slotX(index)
            readonly property real slotY: root.slotY(index)
            readonly property real centerX:
                root.foldX + (slotX - root.foldX) * prog
            readonly property real centerY:
                root.foldY + (slotY - root.foldY) * prog
            readonly property real iconOpacity: root.clamp01(prog / 0.3)
            readonly property real labelOpacity:
                root.clamp01((prog - 0.45) / 0.4)
            readonly property real hoverFactor:
                1 + (root.hoverScale - 1) * 2.5

            Component {
                id: fanRow

                Item {
                    id: row

                    x: 0
                    y: fanDelegate.centerY - root.step / 2
                    width: root.width
                    height: root.step

                    // Zone cliquable : de la pastille à l'icône.
                    Item {
                        id: hitArea

                        readonly property real iconLeft:
                            fanDelegate.centerX - root.iconSize / 2
                        x: root.labelsLeft
                            ? iconLeft - root.gap - pill.width : iconLeft
                        width: root.iconSize + root.gap + pill.width
                        height: root.step
                        enabled: root.expanded

                        HoverHandler {
                            id: rowHover

                            cursorShape: Qt.PointingHandCursor
                        }

                        TapHandler {
                            onTapped: root.activateEntry(fanDelegate.index,
                                fanDelegate.isDir)
                        }
                    }

                    Rectangle {
                        id: pill

                        width: Math.min(root.labelMaxWidth,
                            pillLabel.implicitWidth + 20)
                        height: root.pillHeight
                        radius: height / 2
                        x: root.labelsLeft
                            ? fanDelegate.centerX - root.iconSize / 2
                                - root.gap - width
                            : fanDelegate.centerX + root.iconSize / 2
                                + root.gap
                        y: (root.step - height) / 2
                        color: rowHover.hovered
                            ? Qt.tint(root.pillColor,
                                Qt.rgba(palette.highlight.r,
                                    palette.highlight.g,
                                    palette.highlight.b, 0.35))
                            : root.pillColor
                        border.width: 1
                        border.color: root.pillBorderColor
                        opacity: fanDelegate.labelOpacity

                        QQC2.Label {
                            id: pillLabel

                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            width: parent.width - 20
                            text: fanDelegate.display
                            color: root.pillTextColor
                            font.pixelSize: 12
                            font.weight: Font.Medium
                            elide: Text.ElideMiddle
                        }
                    }

                    Kirigami.Icon {
                        id: fileIcon

                        width: root.iconSize
                        height: root.iconSize
                        x: fanDelegate.centerX - width / 2
                        y: (root.step - height) / 2
                        source: fanDelegate.decoration
                        opacity: fanDelegate.iconOpacity
                        scale: (0.35 + 0.65 * Math.min(1.08,
                                Math.max(0, fanDelegate.prog)))
                            * (rowHover.hovered
                                ? fanDelegate.hoverFactor : 1.0)

                        Behavior on scale {
                            enabled: root.expanded
                            NumberAnimation {
                                duration: 140
                                easing.type: Easing.OutCubic
                            }
                        }
                    }
                }
            }
        }
    }

    // --- Dossier vide ------------------------------------------------------
    Rectangle {
        id: emptyPill

        readonly property real progress: root.buttonProgress
        readonly property real centerX: root.foldX
            + (root.slotX(0) - root.foldX) * progress
        readonly property real centerY: root.foldY
            + (root.slotY(0) - root.foldY) * progress

        visible: root.entryCount === 0
        width: Math.min(root.labelMaxWidth, emptyLabel.implicitWidth + 24)
        height: root.pillHeight
        radius: height / 2
        color: root.pillColor
        border.width: 1
        border.color: root.pillBorderColor
        opacity: root.clamp01(progress)
        x: root.labelsLeft
            ? centerX + root.iconSize / 2 - width
            : centerX - root.iconSize / 2
        y: centerY - height / 2

        QQC2.Label {
            id: emptyLabel

            anchors.centerIn: parent
            width: parent.width - 24
            horizontalAlignment: Text.AlignHCenter
            text: root.folderModel && root.folderModel.errorString.length > 0
                ? root.folderModel.errorString : i18n("This folder is empty")
            color: root.pillTextColor
            font.pixelSize: 12
            elide: Text.ElideRight
        }
    }

    // --- Ligne des boutons : retour et « Ouvrir dans le Finder » -----------
    Item {
        id: buttonRow

        readonly property real progress: root.buttonProgress
        readonly property real slot: root.rows
        readonly property real targetX: root.slotX(slot)
        readonly property real targetY: root.slotY(slot)
        readonly property real centerX:
            root.foldX + (targetX - root.foldX) * progress
        readonly property real centerY:
            root.foldY + (targetY - root.foldY) * progress

        x: 0
        y: centerY - root.step / 2
        width: root.width
        height: root.step
        opacity: root.clamp01(progress)
        enabled: root.expanded

        Rectangle {
            id: openPill

            width: openLabel.implicitWidth + 28
            height: root.pillHeight + 2
            radius: height / 2
            x: root.labelsLeft
                ? buttonRow.centerX + root.iconSize / 2 - width
                : buttonRow.centerX - root.iconSize / 2
            y: (root.step - height) / 2
            color: openHover.hovered
                ? Qt.tint(root.pillColor,
                    Qt.rgba(palette.highlight.r, palette.highlight.g,
                        palette.highlight.b, 0.35))
                : root.pillColor
            border.width: 1
            border.color: root.pillBorderColor
            scale: openHover.hovered ? 1.04 : 1.0

            Behavior on scale {
                NumberAnimation {
                    duration: 120
                    easing.type: Easing.OutCubic
                }
            }

            QQC2.Label {
                id: openLabel

                anchors.centerIn: parent
                text: i18n("Open in Finder")
                color: root.pillTextColor
                font.pixelSize: 12
                font.weight: Font.DemiBold
            }

            HoverHandler {
                id: openHover

                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                onTapped: {
                    root.openFolderRequested(root.folderModel
                        && root.folderModel.resolvedUrl
                            ? root.folderModel.resolvedUrl
                            : root.rootFolderUrl);
                    root.dismiss(false);
                }
            }
        }

        Rectangle {
            id: backPill

            visible: !root.atRootFolder
            width: root.pillHeight + 2
            height: width
            radius: width / 2
            x: root.labelsLeft
                ? openPill.x - root.gap / 2 - width
                : openPill.x + openPill.width + root.gap / 2
            y: (root.step - height) / 2
            color: backHover.hovered
                ? Qt.tint(root.pillColor,
                    Qt.rgba(palette.highlight.r, palette.highlight.g,
                        palette.highlight.b, 0.35))
                : root.pillColor
            border.width: 1
            border.color: root.pillBorderColor

            Kirigami.Icon {
                anchors.centerIn: parent
                width: 16
                height: 16
                source: "go-previous"
                color: root.pillTextColor
            }

            HoverHandler {
                id: backHover

                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                onTapped: {
                    if (root.folderModel) {
                        root.folderModel.up();
                    }
                }
            }
        }
    }
}
