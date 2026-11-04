import QtQuick
import org.kde.layershell as LayerShell
import "effects" as DockEffects

// « Siri IA » : l'application de conversation du Dock, à la manière de
// l'app Siri de macOS 27. À gauche, l'historique des discussions (liste
// façon Messages, recherche, épinglage) ; à droite, la conversation en cours
// avec Gemini, GLM ou le fournisseur personnalisé. L'historique est partagé
// avec les réponses données depuis le Spotlight.
//
// La fenêtre est un calque de Plasma (comme les autres bulles du Dock) : elle
// n'ajoute donc pas d'entrée parasite au gestionnaire de tâches. Elle se
// déplace en glissant la barre du haut.
Window {
    id: win

    property var backend: null
    property var chat: null
    property var glassTheme: ({})

    signal settingsRequested()

    readonly property color accent: "#0A84FF"
    readonly property real screenWidth: screen ? screen.width : 1920
    readonly property real screenHeight: screen ? screen.height : 1080
    property bool large: false
    property real posX: 0
    property real posY: 0
    property string contextConversation: ""
    property bool searching: false

    readonly property real normalWidth: Math.min(940, screenWidth - 40)
    readonly property real normalHeight: Math.min(620, screenHeight - 60)
    readonly property real sidebarWidth: 280
    readonly property real titleBarHeight: 52

    flags: Qt.FramelessWindowHint
    color: "transparent"
    visible: false
    title: "Siri IA"
    width: large ? Math.min(screenWidth - 80, 1280) : normalWidth
    height: large ? Math.min(screenHeight - 100, 860) : normalHeight

    LayerShell.Window.scope: "macosdock-siri"
    LayerShell.Window.anchors: LayerShell.Window.AnchorTop | LayerShell.Window.AnchorLeft
    LayerShell.Window.margins.left: Math.round(posX)
    LayerShell.Window.margins.top: Math.round(posY)
    LayerShell.Window.exclusionZone: -1
    LayerShell.Window.layer: LayerShell.Window.LayerTop
    LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityOnDemand
    LayerShell.Window.activateOnShow: true
    LayerShell.Window.wantsToBeOnActiveScreen: true

    DockEffects.GlassBlur {
        id: glassBlur
    }

    function clampPosition() {
        posX = Math.max(0, Math.min(screenWidth - width, posX));
        posY = Math.max(0, Math.min(screenHeight - height, posY));
    }

    function openSiri(freshConversation) {
        glassTheme = glassBlur.theme();
        if (chat && freshConversation) {
            chat.startNew();
        }
        if (!visible) {
            posX = (screenWidth - width) / 2;
            posY = Math.max(24, (screenHeight - height) / 2 - 20);
            visible = true;
        }
        requestActivate();
        Qt.callLater(focusInput);
    }

    function closeSiri() {
        menu.opened = false;
        visible = false;
    }

    function toggleSiri() {
        if (visible) {
            closeSiri();
        } else {
            openSiri(false);
        }
    }

    function focusInput() {
        input.forceActiveFocus();
    }

    onWidthChanged: clampPosition()
    onHeightChanged: clampPosition()

    onVisibleChanged: {
        if (!visible) {
            glassKey = "";
            glassBlur.clear(win);
        }
    }

    function send() {
        var text = input.text.trim();
        if (!chat || text.length === 0 || chat.busy) {
            return;
        }
        input.text = "";
        chat.ask(text, chat.activeProvider);
    }

    function dateLabel(milliseconds) {
        var date = new Date(milliseconds);
        var now = new Date();
        if (date.toDateString() === now.toDateString()) {
            return Qt.formatTime(date, "HH:mm");
        }
        if ((now.getTime() - date.getTime()) / 86400000 < 6) {
            return Qt.formatDate(date, "dddd");
        }
        return Qt.formatDate(date, Locale.ShortFormat);
    }

    function lastText(conversation) {
        for (var i = conversation.messages.length - 1; i >= 0; --i) {
            if (!conversation.messages[i].error) {
                return String(conversation.messages[i].text).replace(/\s+/g, " ").trim();
            }
        }
        return "";
    }

    // --- Menus ------------------------------------------------------------------
    // 0 = fournisseurs, 1 = conversation (clic droit)
    property int menuKind: 0

    function openProviderMenu() {
        menuKind = 0;
        var entries = [];
        for (var i = 0; i < chat.providerCount; ++i) {
            entries.push({ "id": "provider" + i, "text": chat.providerName(i),
                "glyph": "sparkle", "checked": chat.activeProvider === i });
        }
        entries.push({ "separator": true });
        entries.push({ "id": "settings", "text": i18n("Credentials…"), "glyph": "" });
        menu.entries = entries;
        var anchor = providerChip.mapToItem(null, providerChip.width, providerChip.height + 6);
        menu.openAt(anchor.x, anchor.y, true);
    }

    function openConversationMenu(conversationId, sceneX, sceneY) {
        menuKind = 1;
        contextConversation = conversationId;
        var conversation = chat.conversationById(conversationId);
        menu.entries = [
            { "id": "pin", "text": conversation && conversation.pinned ? i18n("Unpin") : i18n("Pin"),
              "glyph": "pin" },
            { "id": "copy", "text": i18n("Copy Conversation"), "glyph": "copy" },
            { "separator": true },
            { "id": "delete", "text": i18n("Delete"), "glyph": "trash" }
        ];
        menu.openAt(sceneX, sceneY, false);
    }

    function handleMenu(id) {
        if (menuKind === 0) {
            if (id.indexOf("provider") === 0) {
                chat.setActiveProvider(Number(id.substring(8)));
            } else if (id === "settings") {
                settingsRequested();
            }
        } else if (id === "pin") {
            chat.togglePin(contextConversation);
        } else if (id === "delete") {
            chat.deleteConversation(contextConversation);
        } else if (id === "copy") {
            var conversation = chat.conversationById(contextConversation);
            if (conversation && backend) {
                backend.setClipboardText(conversation.messages.map(function (message) {
                    return (message.role === "user" ? "> " : "") + message.text;
                }).join("\n\n"));
            }
        }
        focusInput();
    }

    function providerColors(index) {
        if (index === 0) {
            return ["#4285F4", "#9B72F2"];
        }
        if (index === 1) {
            return ["#19B38F", "#2F80ED"];
        }
        return ["#8E8E93", "#636366"];
    }

    // --- Flou demandé à KWin ---------------------------------------------------------
    property string glassKey: ""
    property int glassTicks: 0

    function updateGlass() {
        if (!visible) {
            return;
        }
        var rects = [{ "x": 0, "y": 0, "width": Math.round(win.width),
            "height": Math.round(win.height), "radius": 22 }];
        if (menu.opened) {
            rects.push({ "x": Math.round(menu.boxRect.x), "y": Math.round(menu.boxRect.y),
                "width": Math.round(menu.boxRect.width), "height": Math.round(menu.boxRect.height),
                "radius": 14 });
        }
        var key = JSON.stringify(rects);
        if (key === glassKey && (++glassTicks % 15) !== 0) {
            return;
        }
        glassKey = key;
        glassBlur.apply(win, rects);
    }

    Timer {
        interval: 33
        repeat: true
        running: win.visible
        onTriggered: win.updateGlass()
    }

    // --- Interface ----------------------------------------------------------------------
    GlassSurface {
        id: frame

        anchors.fill: parent
        theme: win.glassTheme
        radius: 22

        Keys.onEscapePressed: win.closeSiri()

        // Voile léger pour que le texte reste lisible sur un fond clair.
        Rectangle {
            anchors.fill: parent
            radius: frame.radius
            color: Qt.rgba(0, 0, 0, 0.18)
        }

        // ---- Barre du haut : boutons de fenêtre et déplacement ----
        Item {
            id: titleBar

            x: 0
            y: 0
            width: parent.width
            height: win.titleBarHeight

            MouseArea {
                id: dragArea

                property real pressX: 0
                property real pressY: 0

                anchors.fill: parent
                acceptedButtons: Qt.LeftButton
                onPressed: function (mouse) {
                    pressX = mouse.x;
                    pressY = mouse.y;
                }
                onPositionChanged: function (mouse) {
                    if (pressed) {
                        win.posX += mouse.x - pressX;
                        win.posY += mouse.y - pressY;
                        win.clampPosition();
                    }
                }
                onDoubleClicked: win.large = !win.large
            }

            Row {
                x: 18
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                Repeater {
                    model: [
                        { "color": "#FF5F57", "action": "close" },
                        { "color": "#FEBC2E", "action": "hide" },
                        { "color": "#28C840", "action": "zoom" }
                    ]

                    delegate: Rectangle {
                        id: light

                        required property var modelData

                        width: 14
                        height: 14
                        radius: 7
                        color: modelData.color
                        border.width: 1
                        border.color: Qt.rgba(0, 0, 0, 0.18)

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -3
                            onClicked: {
                                if (light.modelData.action === "zoom") {
                                    win.large = !win.large;
                                } else {
                                    win.closeSiri();
                                }
                            }
                        }
                    }
                }
            }

            // Titre de la conversation, au-dessus du volet de droite.
            Text {
                x: win.sidebarWidth + 24
                width: parent.width - win.sidebarWidth - 24 - 170
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideRight
                text: win.chat && win.chat.current ? win.chat.current.title : "Siri IA"
                font.pixelSize: 15
                font.weight: Font.DemiBold
                color: Qt.rgba(1, 1, 1, 0.92)
            }

            // Fournisseur utilisé pour la prochaine question.
            Rectangle {
                id: providerChip

                anchors.right: parent.right
                anchors.rightMargin: 18
                anchors.verticalCenter: parent.verticalCenter
                height: 30
                width: chipRow.implicitWidth + 24
                radius: 15
                color: Qt.rgba(1, 1, 1, chipMouse.containsMouse || menu.opened ? 0.2 : 0.11)

                Row {
                    id: chipRow

                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: win.chat ? win.chat.providerName(win.chat.activeProvider) : ""
                        font.pixelSize: 13
                        color: Qt.rgba(1, 1, 1, 0.92)
                    }

                    SpotlightGlyph {
                        anchors.verticalCenter: parent.verticalCenter
                        kind: "chevronDown"
                        size: 12
                        lineWidth: 2
                        color: Qt.rgba(1, 1, 1, 0.7)
                    }
                }

                MouseArea {
                    id: chipMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (menu.opened) {
                            menu.close();
                        } else {
                            win.openProviderMenu();
                        }
                    }
                }
            }
        }

        // ---- Barre latérale : recherche et historique ----
        Item {
            id: sidebar

            x: 0
            y: win.titleBarHeight
            width: win.sidebarWidth
            height: parent.height - win.titleBarHeight

            Row {
                id: sidebarHeader

                x: 14
                y: 0
                width: parent.width - 28
                height: 36
                spacing: 8

                Rectangle {
                    width: parent.width - 36 - 8
                    height: 34
                    radius: 17
                    color: Qt.rgba(1, 1, 1, 0.1)

                    SpotlightGlyph {
                        x: 11
                        anchors.verticalCenter: parent.verticalCenter
                        kind: "search"
                        size: 15
                        color: Qt.rgba(1, 1, 1, 0.55)
                    }

                    TextInput {
                        id: searchField

                        x: 34
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 34 - 12
                        color: "white"
                        selectionColor: Qt.rgba(1, 1, 1, 0.3)
                        font.pixelSize: 13.5
                        clip: true

                        Text {
                            visible: searchField.text.length === 0
                            text: i18n("Search")
                            font: searchField.font
                            color: Qt.rgba(1, 1, 1, 0.45)
                        }
                    }
                }

                // Nouvelle conversation.
                Rectangle {
                    width: 34
                    height: 34
                    radius: 17
                    color: Qt.rgba(1, 1, 1, newMouse.containsMouse ? 0.2 : 0.1)

                    SpotlightGlyph {
                        anchors.centerIn: parent
                        kind: "compose"
                        size: 17
                        color: Qt.rgba(1, 1, 1, 0.9)
                    }

                    MouseArea {
                        id: newMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (win.chat) {
                                win.chat.startNew();
                            }
                            win.focusInput();
                        }
                    }
                }
            }

            ListView {
                id: conversationList

                x: 8
                y: 46
                width: parent.width - 16
                height: parent.height - 46 - 8
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                spacing: 2
                model: {
                    if (!win.chat) {
                        return [];
                    }
                    void win.chat.conversations;
                    return win.chat.sortedConversations(searchField.text);
                }

                delegate: Item {
                    id: conversationRow

                    required property var modelData

                    readonly property bool selected: !!win.chat && win.chat.currentId === modelData.id

                    width: conversationList.width
                    height: 70

                    Rectangle {
                        anchors.fill: parent
                        radius: 14
                        color: conversationRow.selected ? Qt.rgba(1, 1, 1, 0.16)
                            : (rowMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent")
                    }

                    Rectangle {
                        x: 10
                        anchors.verticalCenter: parent.verticalCenter
                        width: 38
                        height: 38
                        radius: 19
                        gradient: Gradient {
                            GradientStop {
                                position: 0
                                color: win.providerColors(conversationRow.modelData.messages.length > 0
                                    && conversationRow.modelData.messages[0].provider !== undefined
                                    ? conversationRow.modelData.messages[0].provider : 0)[0]
                            }
                            GradientStop {
                                position: 1
                                color: win.providerColors(conversationRow.modelData.messages.length > 0
                                    && conversationRow.modelData.messages[0].provider !== undefined
                                    ? conversationRow.modelData.messages[0].provider : 0)[1]
                            }
                        }

                        SpotlightGlyph {
                            anchors.centerIn: parent
                            kind: "sparkle"
                            size: 18
                            filled: true
                            lineWidth: 1
                            color: "white"
                        }
                    }

                    Column {
                        x: 58
                        y: 10
                        width: parent.width - 58 - 10
                        spacing: 2

                        Row {
                            width: parent.width
                            spacing: 6

                            SpotlightGlyph {
                                visible: Boolean(conversationRow.modelData.pinned)
                                anchors.verticalCenter: parent.verticalCenter
                                kind: "pin"
                                size: 12
                                color: Qt.rgba(1, 1, 1, 0.6)
                            }

                            Text {
                                width: parent.width - (conversationRow.modelData.pinned ? 18 : 0) - dateText.implicitWidth - 6
                                elide: Text.ElideRight
                                text: conversationRow.modelData.title
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                                color: "white"
                            }

                            Text {
                                id: dateText

                                text: win.dateLabel(conversationRow.modelData.updated)
                                font.pixelSize: 12
                                color: Qt.rgba(1, 1, 1, 0.5)
                            }
                        }

                        Text {
                            width: parent.width
                            height: 30
                            wrapMode: Text.WordWrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                            text: win.lastText(conversationRow.modelData)
                            font.pixelSize: 12.5
                            color: Qt.rgba(1, 1, 1, 0.55)
                        }
                    }

                    MouseArea {
                        id: rowMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: function (mouse) {
                            if (mouse.button === Qt.RightButton) {
                                var point = conversationRow.mapToItem(null, mouse.x, mouse.y);
                                win.openConversationMenu(conversationRow.modelData.id, point.x, point.y);
                            } else if (win.chat) {
                                win.chat.select(conversationRow.modelData.id);
                                win.focusInput();
                            }
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: conversationList.count === 0
                    width: parent.width - 40
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    text: searchField.text.length > 0 ? i18n("No conversations found")
                        : i18n("Your conversations will appear here")
                    font.pixelSize: 13
                    color: Qt.rgba(1, 1, 1, 0.45)
                }
            }
        }

        Rectangle {
            x: win.sidebarWidth
            y: win.titleBarHeight
            width: 1
            height: parent.height - win.titleBarHeight
            color: Qt.rgba(1, 1, 1, 0.12)
        }

        // ---- Volet de droite : la conversation ----
        Item {
            id: conversationPane

            x: win.sidebarWidth + 1
            y: win.titleBarHeight
            width: parent.width - win.sidebarWidth - 1
            height: parent.height - win.titleBarHeight

            // Écran d'accueil : l'orbe de Siri.
            Item {
                visible: !!win.chat && win.chat.currentMessages.length === 0 && !win.chat.currentBusy
                anchors.horizontalCenter: parent.horizontalCenter
                y: (parent.height - 110 - 130) / 2
                width: 200
                height: 130

                Item {
                    id: orb

                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 76
                    height: 76

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: "#7B61FF" }
                            GradientStop { position: 0.5; color: "#35A7FF" }
                            GradientStop { position: 1.0; color: "#FF5FA2" }
                        }

                        RotationAnimation on rotation {
                            from: 0
                            to: 360
                            duration: 9000
                            loops: Animation.Infinite
                            running: orb.visible && win.visible
                        }
                    }

                    Rectangle {
                        x: 12
                        y: 8
                        width: 38
                        height: 20
                        radius: 10
                        color: Qt.rgba(1, 1, 1, 0.28)
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 90
                    text: i18n("How can I help?")
                    font.pixelSize: 20
                    font.weight: Font.DemiBold
                    color: Qt.rgba(1, 1, 1, 0.92)
                }
            }

            ChatTranscript {
                id: transcript

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: inputBar.top
                anchors.leftMargin: 20
                anchors.rightMargin: 20
                anchors.bottomMargin: 8
                accent: win.accent
                messages: win.chat ? win.chat.currentMessages : []
                busy: win.chat ? win.chat.currentBusy : false
                providerNames: win.chat
                    ? [win.chat.providerName(0), win.chat.providerName(1), win.chat.providerName(2)]
                    : ["Gemini", "GLM", ""]
                onCopyRequested: function (text) {
                    if (win.backend) {
                        win.backend.setClipboardText(text);
                    }
                }
            }

            // Zone de saisie.
            Rectangle {
                id: inputBar

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.leftMargin: 20
                anchors.rightMargin: 20
                anchors.bottomMargin: 18
                height: Math.max(48, Math.min(150, input.contentHeight + 24))
                radius: Math.min(24, height / 2)
                color: Qt.rgba(1, 1, 1, 0.11)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, input.activeFocus ? 0.3 : 0.14)

                TextEdit {
                    id: input

                    x: 18
                    y: 12
                    width: parent.width - 18 - 56
                    height: parent.height - 24
                    wrapMode: TextEdit.Wrap
                    color: "white"
                    selectionColor: Qt.rgba(1, 1, 1, 0.3)
                    selectedTextColor: "white"
                    font.pixelSize: 15
                    clip: true

                    Text {
                        visible: input.text.length === 0 && input.preeditText.length === 0
                        text: i18n("Ask Siri AI…")
                        font: input.font
                        color: Qt.rgba(1, 1, 1, 0.45)
                    }

                    Keys.onPressed: function (event) {
                        if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                                && (event.modifiers & Qt.ShiftModifier) === 0) {
                            win.send();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Escape) {
                            if (menu.opened) {
                                menu.close();
                            } else {
                                win.closeSiri();
                            }
                            event.accepted = true;
                        }
                    }
                }

                Rectangle {
                    id: sendButton

                    readonly property bool busy: win.chat ? win.chat.busy : false

                    anchors.right: parent.right
                    anchors.rightMargin: 9
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 9
                    width: 30
                    height: 30
                    radius: 15
                    color: busy || input.text.trim().length > 0 ? win.accent : Qt.rgba(1, 1, 1, 0.18)

                    SpotlightGlyph {
                        visible: !sendButton.busy
                        anchors.centerIn: parent
                        kind: "send"
                        size: 17
                        lineWidth: 2.2
                        color: "white"
                    }

                    Rectangle {
                        visible: sendButton.busy
                        anchors.centerIn: parent
                        width: 11
                        height: 11
                        radius: 3
                        color: "white"
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (sendButton.busy) {
                                win.chat.cancel();
                            } else {
                                win.send();
                            }
                        }
                    }
                }
            }
        }

        GlassMenu {
            id: menu

            theme: win.glassTheme
            onActivated: function (entryId) {
                win.handleMenu(entryId);
            }
        }
    }
}
