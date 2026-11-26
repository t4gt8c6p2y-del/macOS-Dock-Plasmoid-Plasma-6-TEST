import QtQuick
import QtQuick.Effects
import "effects" as DockEffects

// « Siri IA » : l'application de conversation du Dock, à la manière de
// l'app Siri de macOS 27 (thème clair). À gauche, l'historique des discussions
// en cartes sur deux colonnes (recherche par le bouton filtre, épinglage) ;
// à droite, sur fond blanc, la conversation en cours
// avec Gemini, GLM ou le fournisseur personnalisé. L'historique est partagé
// avec les réponses données depuis le Spotlight.
//
// C'est une vraie fenêtre d'application (et non plus un calque de Plasma) :
// KWin la réduit, la maximise, la redimensionne et la déplace comme n'importe
// quelle autre. Les boutons rouge / orange / vert de la barre du haut
// appellent ces fonctions du compositeur. La fenêtre est créée une fois au
// chargement du Dock et seulement masquée à la fermeture : elle se rouvre
// donc instantanément.
Window {
    id: win

    property var backend: null
    property var chat: null
    // Prompts enregistrés (onglet « Siri IA » des réglages) : { icon, image,
    // title, text }. Leurs pastilles s'affichent au-dessus de la zone de saisie.
    property var prompts: []

    signal settingsRequested()
    // Le bouton liste / icônes de la barre latérale a été cliqué : la fenêtre
    // demande l'état voulu, le Dock l'enregistre dans ses réglages.
    signal listModeRequested(bool listMode)

    // Réglage « Mode » de l'onglet Siri IA : clair (vrai) ou sombre.
    property bool lightMode: true
    // Barre latérale : discussions en liste (vrai) ou en cartes (faux).
    property bool listMode: false

    readonly property color accent: "#0A84FF"
    // --- Palette (sombre ou claire) ---
    readonly property color sidebarColor: lightMode ? "#D7D3D0" : "#161618"
    readonly property color paneColor: lightMode ? "#FFFFFF" : "#000000"
    readonly property color ink: lightMode ? "#1D1D1F" : "#F5F5F7"
    readonly property color inkSoft: lightMode ? Qt.rgba(0, 0, 0, 0.5) : Qt.rgba(1, 1, 1, 0.55)
    readonly property color inkFaint: lightMode ? Qt.rgba(0, 0, 0, 0.4) : Qt.rgba(1, 1, 1, 0.45)
    readonly property color glyphColor: lightMode ? Qt.rgba(0, 0, 0, 0.66) : Qt.rgba(1, 1, 1, 0.88)
    readonly property color fillSoft: lightMode ? Qt.rgba(0, 0, 0, 0.07) : Qt.rgba(1, 1, 1, 0.10)
    readonly property color fillHover: lightMode ? Qt.rgba(0, 0, 0, 0.13) : Qt.rgba(1, 1, 1, 0.20)
    readonly property color cardFill: lightMode ? Qt.rgba(1, 1, 1, 0.66) : "#050506"
    readonly property color cardHoverFill: lightMode ? Qt.rgba(1, 1, 1, 0.85) : "#0F0F11"
    readonly property color cardSelectedFill: lightMode ? "#FFFFFF" : "#1B1B1E"
    readonly property color rowSelectedFill: lightMode ? Qt.rgba(1, 1, 1, 0.85) : Qt.rgba(1, 1, 1, 0.16)
    readonly property color rowHoverFill: lightMode ? Qt.rgba(1, 1, 1, 0.5) : Qt.rgba(1, 1, 1, 0.08)
    readonly property color inputFill: lightMode ? Qt.rgba(0, 0, 0, 0.045) : Qt.rgba(1, 1, 1, 0.08)
    readonly property color inputBorder: lightMode ? Qt.rgba(0, 0, 0, 0.10) : Qt.rgba(1, 1, 1, 0.12)
    readonly property color inputBorderFocus: lightMode ? Qt.rgba(0, 0, 0, 0.26) : Qt.rgba(1, 1, 1, 0.32)
    readonly property color selectionFill: lightMode ? Qt.rgba(0.04, 0.52, 1, 0.3) : Qt.rgba(1, 1, 1, 0.3)
    readonly property color separatorColor: lightMode ? Qt.rgba(0, 0, 0, 0.10) : Qt.rgba(1, 1, 1, 0.10)
    readonly property color sendIdle: lightMode ? Qt.rgba(0, 0, 0, 0.16) : Qt.rgba(1, 1, 1, 0.22)
    readonly property real screenWidth: screen ? screen.width : 1920
    readonly property real screenHeight: screen ? screen.height : 1080
    // Vrai quand KWin a maximisé la fenêtre (plus de coins arrondis ni de liseré).
    readonly property bool maximized: visibility === Window.Maximized
        || visibility === Window.FullScreen
    // Dernier état « agrandi » connu : une fenêtre maximisée puis réduite doit
    // revenir maximisée.
    property bool wasMaximized: false
    property bool sized: false
    property string contextConversation: ""

    readonly property real normalWidth: Math.min(940, screenWidth - 40)
    readonly property real normalHeight: Math.min(620, screenHeight - 60)
    // Deux colonnes de cartes dans la barre latérale (comme l'app Siri de macOS 27).
    readonly property real sidebarWidth: Math.max(250, Math.min(340, width * 0.35))
    readonly property real titleBarHeight: 52
    // Thème « Liquid Glass for KDE » (rayon des coins vu par KWin).
    property var glassTheme: ({})
    // Rayon des coins : celui de la forme que KWin donne à la fenêtre, pour que
    // le fond noir la remplisse exactement (rien ne dépasse du liseré de KWin).
    // Bords dessinés par la fenêtre elle-même : coins arrondis (30 px) et
    // liseré fin et clair (plus lumineux en haut). KWin n'ajoute plus son
    // propre contour. Mettre false pour revenir au liseré de l'effet Liquid
    // Glass de KWin (rayon pris dans son thème).
    readonly property bool ownEdges: true
    readonly property real cornerRadius: maximized
        ? 0 : (ownEdges ? 30 : Math.min(Number(glassTheme.popupRadius || 22), 40))

    flags: Qt.Window | Qt.FramelessWindowHint
    color: "transparent"
    visible: false
    title: "Siri IA"
    minimumWidth: 640
    minimumHeight: 420
    // Taille de départ ; elle est ensuite adaptée à l'écran (openSiri) puis
    // laissée à l'utilisateur et au compositeur.
    width: 940
    height: 620

    DockEffects.GlassBlur {
        id: glassBlur
    }

    // --- Forme de la fenêtre pour KWin -------------------------------------------------
    // L'effet Liquid Glass de KWin arrondit la fenêtre et trace son liseré le
    // long de la forme qu'on lui indique. On lui donne exactement celle du fond
    // noir (toute la fenêtre, mêmes coins) : le liseré tombe alors sur le bord.
    property string glassKey: ""

    function updateGlass(force) {
        if (!visible) {
            return;
        }
        if (ownEdges) {
            // Les bords sont dessinés ici : KWin ne trace rien.
            if (glassKey !== "own") {
                glassKey = "own";
                glassBlur.clear(win);
            }
            return;
        }
        var rects = [{ "x": 0, "y": 0, "width": Math.round(width),
            "height": Math.round(height), "radius": Math.round(cornerRadius) }];
        var key = JSON.stringify(rects);
        if (!force && key === glassKey) {
            return;
        }
        glassKey = key;
        glassBlur.apply(win, rects);
    }

    // On attend que la taille se stabilise ; la demande est refaite un peu
    // après l'affichage (KWin ne la prend en compte qu'une fois la fenêtre posée).
    Timer {
        id: glassTimer

        interval: 40
        onTriggered: win.updateGlass(false)
    }

    Timer {
        id: glassRetry

        interval: 350
        onTriggered: win.updateGlass(true)
    }

    onCornerRadiusChanged: glassTimer.restart()

    function openSiri(freshConversation) {
        glassTheme = glassBlur.theme();
        if (chat) {
            if (freshConversation) {
                chat.startNew();
            }
            chat.selectAvailableProvider();
            chat.refreshGeminiModels(false);
        }
        if (!sized) {
            width = normalWidth;
            height = normalHeight;
            sized = true;
        }
        if (!visible) {
            visible = true;
            if (wasMaximized) {
                showMaximized();
            }
        } else if (visibility === Window.Minimized) {
            // Fenêtre réduite : on la restaure dans l'état où elle était.
            if (wasMaximized) {
                showMaximized();
            } else {
                showNormal();
            }
        }
        raise();
        requestActivate();
        Qt.callLater(focusInput);
    }

    function closeSiri() {
        menu.close();
        visible = false;
    }

    function toggleSiri() {
        if (visible) {
            closeSiri();
        } else {
            openSiri(false);
        }
    }

    function minimizeSiri() {
        menu.close();
        showMinimized();
    }

    // Agrandir / restaurer avec animation. Le compositeur change la taille de
    // la fenêtre d'un coup : on garde donc une photo de l'ancienne fenêtre
    // (« snapshot »), posée par-dessus, qui grandit (ou rétrécit) depuis le
    // centre jusqu'à la nouvelle taille en s'estompant, pendant que le vrai
    // contenu, déjà à la bonne taille, apparaît dessous.
    property bool zooming: false
    property bool zoomStarted: false
    property bool zoomPlaying: false
    property bool zoomGrowing: true
    property real zoomFromWidth: 0
    property real zoomFromHeight: 0

    function toggleMaximize() {
        menu.close();
        var growing = !maximized;
        if (zooming || !visible || visibility === Window.Minimized) {
            // Déjà en cours (ou fenêtre cachée) : changement direct.
            if (growing) {
                showMaximized();
            } else {
                showNormal();
            }
            return;
        }
        appear.stop();
        frame.scale = 1;
        frame.opacity = 1;
        zoomGrowing = growing;
        zoomFromWidth = frame.width;
        zoomFromHeight = frame.height;
        zoomPlaying = false;
        zoomStarted = false;
        zooming = true;
        snapshot.textureSize = Qt.size(Math.max(1, zoomFromWidth), Math.max(1, zoomFromHeight));
        snapshot.sourceRect = Qt.rect(0, 0, zoomFromWidth, zoomFromHeight);
        snapshot.width = zoomFromWidth;
        snapshot.height = zoomFromHeight;
        snapshot.opacity = 1;
        snapshot.visible = true;
        snapshot.scheduleUpdate();
        // Laisse un rendu photographier la fenêtre avant que KWin la change.
        zoomStart.restart();
    }

    function playZoom() {
        if (!zooming || zoomPlaying) {
            return;
        }
        zoomPlaying = true;
        zoomGuard.stop();
        zoomAnimation.restart();
    }

    function endZoom() {
        zooming = false;
        zoomStarted = false;
        zoomPlaying = false;
        snapshot.visible = false;
        snapshot.opacity = 1;
    }

    Timer {
        id: zoomStart

        interval: 45
        onTriggered: {
            win.zoomStarted = true;
            if (win.zoomGrowing) {
                win.showMaximized();
            } else {
                win.showNormal();
            }
            // Si la taille ne change finalement pas : on ne reste pas bloqué.
            zoomGuard.restart();
        }
    }

    Timer {
        id: zoomGuard

        interval: 500
        onTriggered: win.playZoom()
    }

    // Les changements de taille arrivent en deux temps (largeur, hauteur) :
    // on attend qu'ils se stabilisent avant de lancer l'animation.
    Timer {
        id: zoomSettle

        interval: 30
        onTriggered: win.playZoom()
    }

    onWidthChanged: {
        glassTimer.restart();
        if (zooming && zoomStarted && !zoomPlaying) {
            zoomSettle.restart();
        }
    }

    onHeightChanged: {
        glassTimer.restart();
        if (zooming && zoomStarted && !zoomPlaying) {
            zoomSettle.restart();
        }
    }

    ParallelAnimation {
        id: zoomAnimation

        onFinished: win.endZoom()

        NumberAnimation {
            target: snapshot
            property: "width"
            from: win.zoomFromWidth
            to: win.width
            duration: 380
            easing.type: Easing.OutQuart
        }

        NumberAnimation {
            target: snapshot
            property: "height"
            from: win.zoomFromHeight
            to: win.height
            duration: 380
            easing.type: Easing.OutQuart
        }

        SequentialAnimation {
            PauseAnimation { duration: 90 }

            NumberAnimation {
                target: snapshot
                property: "opacity"
                from: 1
                to: 0
                duration: 290
                easing.type: Easing.InOutQuad
            }
        }
    }

    function focusInput() {
        input.forceActiveFocus();
    }


    // Première image envoyée dans la conversation (la plus récente), en URL :
    // elle illustre la carte. Chaîne vide s'il n'y en a pas.
    function conversationImage(conversation) {
        if (!conversation || !conversation.messages) {
            return "";
        }
        for (var i = conversation.messages.length - 1; i >= 0; --i) {
            var list = conversation.messages[i].images;
            if (list && typeof list.length === "number") {
                for (var j = 0; j < list.length; ++j) {
                    if (list[j] && list[j].path) {
                        return "file://" + String(list[j].path).split("/")
                            .map(encodeURIComponent).join("/");
                    }
                }
            }
        }
        return "";
    }

    // Hauteur approximative d'une carte : sert seulement à choisir la colonne.
    function estimateCardHeight(conversation) {
        var titleLength = String(conversation.title || "").length;
        var previewLength = lastText(conversation).length;
        var height = 28 + 16 + 6 + Math.min(3, Math.max(1, Math.ceil(titleLength / 13))) * 19;
        if (previewLength > 0) {
            height += 4 + Math.min(4, Math.ceil(previewLength / 17)) * 16;
        }
        if (conversationImage(conversation).length > 0) {
            height += 92;
        }
        return height;
    }

    // Ajoute le texte d'un prompt à la zone de saisie (après ce qui s'y trouve).
    function insertPrompt(text) {
        var addition = String(text);
        if (addition.length === 0) {
            return;
        }
        var current = input.text;
        if (current.length > 0 && !/\s$/.test(current)) {
            current += " ";
        }
        input.text = current + addition;
        input.forceActiveFocus();
        input.cursorPosition = input.text.length;
    }

    onVisibilityChanged: {
        if (visibility === Window.Maximized) {
            wasMaximized = true;
        } else if (visibility === Window.Windowed) {
            wasMaximized = false;
        }
    }

    onVisibleChanged: {
        if (visible) {
            appear.restart();
            glassTimer.restart();
            glassRetry.restart();
        } else {
            appear.stop();
            frame.scale = 1;
            frame.opacity = 1;
            glassKey = "";
            glassBlur.clear(win);
        }
    }

    // Ouverture : la fenêtre apparaît en fondu (c'est aussi l'arrivée de la
    // conversation agrandie depuis le Spotlight). Pas de changement d'échelle :
    // la forme donnée à KWin ne bougerait pas avec elle.
    ParallelAnimation {
        id: appear

        NumberAnimation {
            target: frame
            property: "opacity"
            from: 0
            to: 1
            duration: 200
            easing.type: Easing.OutCubic
        }
    }

    // Raccourcis habituels d'une application.
    Shortcut {
        sequence: "Ctrl+W"
        onActivated: win.closeSiri()
    }

    Shortcut {
        sequence: "Ctrl+M"
        onActivated: win.minimizeSiri()
    }

    function send() {
        var text = input.text.trim();
        // Une image (ou un fichier) ajoutée depuis le dernier envoi suffit :
        // le message peut n'avoir aucun texte.
        if (!chat || chat.busy || !chat.canSend(text)) {
            return;
        }
        input.text = "";
        chat.ask(text, chat.activeProvider, {
            "forceSearch": chat.forceSearch && chat.activeProvider === 0
        });
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
        if (!conversation || !conversation.messages) {
            return "";
        }
        for (var i = conversation.messages.length - 1; i >= 0; --i) {
            if (!conversation.messages[i].error) {
                var preview = String(conversation.messages[i].text).replace(/\s+/g, " ").trim();
                // Message sans texte : une image seule.
                var pictures = conversation.messages[i].images;
                if (preview.length === 0 && Array.isArray(pictures) && pictures.length > 0) {
                    return i18n("Image");
                }
                return preview;
            }
        }
        return "";
    }

    // --- Menus ------------------------------------------------------------------
    // 0 = fournisseurs, 1 = conversation (clic droit), 2 = pièces jointes
    property int menuKind: 0

    // Menu de l'IA : seules les IA utilisables y figurent (clé API renseignée,
    // CLI OpenCode trouvé, fournisseur personnalisé configuré). Pour Gemini,
    // chaque modèle que la clé peut utiliser est une entrée.
    function openProviderMenu() {
        if (!chat) {
            return;
        }
        menuKind = 0;
        chat.refreshGeminiModels(false);
        chat.refreshGroqModels(false);
        var entries = [];
        if (chat.providerReady(0)) {
            var models = chat.geminiModelChoices();
            var currentModel = chat.currentGeminiModel();
            for (var i = 0; i < models.length; ++i) {
                entries.push({ "id": "gemini:" + models[i], "text": chat.geminiLabel(models[i]),
                    "glyph": "sparkle",
                    "checked": chat.activeProvider === 0 && models[i] === currentModel });
            }
        }
        if (chat.providerReady(3)) {
            if (entries.length > 0) {
                entries.push({ "separator": true });
            }
            var groqModels = chat.groqModelChoices();
            var currentGroq = chat.currentGroqModel();
            for (var g = 0; g < groqModels.length; ++g) {
                entries.push({ "id": "groq:" + groqModels[g],
                    "text": "Groq · " + chat.groqLabel(groqModels[g]), "glyph": "sparkle",
                    "checked": chat.activeProvider === 3 && groqModels[g] === currentGroq });
            }
        }
        var others = [];
        for (var index = 1; index < 3; ++index) {
            if (chat.providerReady(index)) {
                others.push({ "id": "provider" + index, "text": chat.providerName(index),
                    "glyph": "sparkle", "checked": chat.activeProvider === index });
            }
        }
        if (entries.length > 0 && others.length > 0) {
            entries.push({ "separator": true });
        }
        entries = entries.concat(others);
        if (entries.length === 0) {
            entries.push({ "id": "none", "text": i18n("No AI available"), "glyph": "",
                "enabled": false });
        }
        entries.push({ "separator": true });
        entries.push({ "id": "settings", "text": i18n("Credentials…"), "glyph": "" });
        menu.entries = entries;
        var anchor = providerChip.mapToItem(null, providerChip.width, providerChip.height + 6);
        menu.openAt(anchor.x, anchor.y, true);
    }

    // --- Dossiers et fichiers donnés à l'IA ---------------------------------------
    property string pendingPick: ""
    property int pickProcess: -1
    property string pickKind: ""
    property string attachNotice: ""

    function openAttachMenu() {
        if (!chat) {
            return;
        }
        menuKind = 2;
        var entries = [
            { "id": "attach-folder", "text": i18n("Add a folder…"), "glyph": "folder" },
            { "id": "attach-files", "text": i18n("Add files…"), "glyph": "attach" }
        ];
        if (chat.attachments.length > 0) {
            entries.push({ "separator": true });
            entries.push({ "id": "attach-clear", "text": i18n("Remove all attachments"),
                "glyph": "trash" });
        }
        menu.entries = entries;
        var anchor = attachButton.mapToItem(null, 0, -6);
        menu.openAt(anchor.x, anchor.y, false, "up");
    }

    function pickAttachment(kind) {
        pendingPick = kind;
        if (pickerLoader.status === Loader.Ready) {
            if (kind === "folder") {
                pickerLoader.item.openFolder();
            } else {
                pickerLoader.item.openFiles();
            }
        } else if (pickerLoader.status === Loader.Error) {
            pickExternally(kind);
        } else {
            pickerLoader.active = true;
        }
    }

    // Repli quand QtQuick.Dialogs n'est pas installé : kdialog (KDE).
    function pickExternally(kind) {
        if (!backend) {
            return;
        }
        pickKind = kind;
        pickProcess = backend.runProcess("kdialog", kind === "folder"
            ? ["--getexistingdirectory"]
            : ["--getopenfilename", "--multiple", "--separate-output"], 600000);
    }

    function showAttachNotice(text) {
        attachNotice = text;
        attachNoticeTimer.restart();
    }

    // Ctrl+V : joint l'image ou les fichiers du presse-papiers. Renvoie false
    // s'il n'y en a pas : le champ colle alors son texte comme d'habitude.
    function pasteAttachments() {
        if (!chat) {
            return false;
        }
        var state = chat.pasteFromClipboard();
        if (state === "full") {
            showAttachNotice(i18n("You can attach up to %1 items.", chat.maxAttachments));
        }
        return state !== "none";
    }

    Timer {
        id: attachNoticeTimer

        interval: 6000
        onTriggered: win.attachNotice = ""
    }

    Loader {
        id: pickerLoader

        active: false
        source: "AttachPicker.qml"
        onLoaded: win.pickAttachment(win.pendingPick)
        onStatusChanged: {
            if (status === Loader.Error) {
                win.pickExternally(win.pendingPick);
            }
        }
    }

    Connections {
        target: pickerLoader.item
        ignoreUnknownSignals: true

        function onPicked(location, isDir) {
            if (win.chat && !win.chat.addAttachment(location, isDir)
                    && win.chat.attachments.length >= win.chat.maxAttachments) {
                win.showAttachNotice(i18n("You can attach up to %1 items.", win.chat.maxAttachments));
            }
        }
    }

    Connections {
        target: win.backend
        ignoreUnknownSignals: true

        function onProcessFinished(id, exitCode, standardOutput, standardError, timedOut) {
            if (id !== win.pickProcess) {
                return;
            }
            win.pickProcess = -1;
            if (exitCode !== 0 && String(standardOutput).trim().length === 0) {
                // 1 = dialogue annulé par l'utilisateur ; autre : kdialog absent.
                if (exitCode !== 1) {
                    win.showAttachNotice(i18n("Could not open a file picker."));
                }
                return;
            }
            var lines = String(standardOutput).split("\n");
            for (var i = 0; i < lines.length; ++i) {
                var path = lines[i].trim();
                if (path.length > 0 && win.chat) {
                    win.chat.addAttachment(path, win.pickKind === "folder");
                }
            }
        }
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
            if (id.indexOf("gemini:") === 0) {
                chat.setGeminiModel(id.substring(7));
            } else if (id.indexOf("groq:") === 0) {
                chat.setGroqModel(id.substring(5));
            } else if (id.indexOf("provider") === 0) {
                chat.setActiveProvider(Number(id.substring(8)));
            } else if (id === "settings") {
                settingsRequested();
            }
        } else if (menuKind === 2) {
            if (id === "attach-folder") {
                pickAttachment("folder");
                return;
            } else if (id === "attach-files") {
                pickAttachment("files");
                return;
            } else if (id === "attach-clear") {
                while (chat.attachments.length > 0) {
                    chat.removeAttachment(chat.attachments.length - 1);
                }
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

    // --- Interface ----------------------------------------------------------------------
    // Fond noir (plus de verre ni de flou). Coins arrondis tant que la fenêtre
    // n'est pas maximisée. Aucun contour n'est dessiné ici : le liseré est celui
    // de l'effet Liquid Glass de KWin, tracé le long de la forme indiquée par
    // updateGlass() (donc exactement sur le bord de la fenêtre).
    // Liseré : un anneau de 1 px (sombre en mode clair, clair en mode sombre).
    Rectangle {
        id: edgeRing

        visible: win.ownEdges && !win.maximized
        // Apparaît en fondu avec la fenêtre (voir « appear »).
        opacity: frame.opacity
        anchors.fill: parent
        radius: win.cornerRadius
        gradient: Gradient {
            GradientStop { position: 0.0; color: win.lightMode ? Qt.rgba(0, 0, 0, 0.10) : Qt.rgba(1, 1, 1, 0.42) }
            GradientStop { position: 0.3; color: win.lightMode ? Qt.rgba(0, 0, 0, 0.14) : Qt.rgba(1, 1, 1, 0.16) }
            GradientStop { position: 1.0; color: win.lightMode ? Qt.rgba(0, 0, 0, 0.20) : Qt.rgba(1, 1, 1, 0.22) }
        }
    }

    Rectangle {
        id: frame

        anchors.fill: parent
        anchors.margins: win.ownEdges && !win.maximized ? 1 : 0
        radius: Math.max(0, win.cornerRadius - anchors.margins)
        // Fond de la barre latérale ; le volet de droite est blanc (clair) ou noir (sombre).
        color: win.sidebarColor

        Keys.onEscapePressed: win.closeSiri()

        // ---- Volet de droite : fond blanc (coins gauches droits) ----
        Rectangle {
            x: win.sidebarWidth
            width: parent.width - win.sidebarWidth
            height: parent.height
            radius: frame.radius
            color: win.paneColor

            Rectangle {
                width: Math.max(1, frame.radius)
                height: parent.height
                color: parent.color
            }
        }

        // Trait de séparation (mode sombre : les deux fonds sont proches).
        Rectangle {
            visible: !win.lightMode
            x: win.sidebarWidth
            y: win.titleBarHeight
            width: 1
            height: parent.height - win.titleBarHeight
            color: Qt.rgba(1, 1, 1, 0.12)
        }

        // ---- Barre du haut : boutons de fenêtre et déplacement ----
        Item {
            id: titleBar

            x: 0
            y: 0
            width: parent.width
            height: win.titleBarHeight

            // Zone de déplacement : c'est KWin qui déplace la fenêtre (on la
            // glisse comme n'importe quelle fenêtre, y compris pour la sortir de
            // l'état maximisé) ; un double clic la maximise ou la restaure.
            Item {
                anchors.fill: parent

                DragHandler {
                    target: null
                    grabPermissions: PointerHandler.CanTakeOverFromAnything
                    onActiveChanged: {
                        if (active) {
                            win.startSystemMove();
                        }
                    }
                }

                TapHandler {
                    acceptedButtons: Qt.LeftButton
                    onDoubleTapped: win.toggleMaximize()
                }
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
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (light.modelData.action === "zoom") {
                                    win.toggleMaximize();
                                } else if (light.modelData.action === "hide") {
                                    win.minimizeSiri();
                                } else {
                                    win.closeSiri();
                                }
                            }
                        }
                    }
                }
            }

            // Bascule de l'affichage des discussions : cartes (icônes) ou liste.
            // Le bouton montre le logo de l'affichage qu'il va activer.
            Rectangle {
                id: viewToggle

                x: win.sidebarWidth - 14 - width
                anchors.verticalCenter: parent.verticalCenter
                width: 32
                height: 32
                radius: 16
                color: toggleMouse.containsMouse ? win.fillHover : win.fillSoft

                // Logo « liste » (affiché quand les discussions sont en cartes).
                Column {
                    visible: !win.listMode
                    anchors.centerIn: parent
                    spacing: 3

                    Repeater {
                        model: 3

                        delegate: Row {
                            spacing: 2.5

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 3
                                height: 3
                                radius: 1.5
                                color: win.glyphColor
                            }

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 9
                                height: 2
                                radius: 1
                                color: win.glyphColor
                            }
                        }
                    }
                }

                // Logo « icônes » (affiché quand les discussions sont en liste).
                Grid {
                    visible: win.listMode
                    anchors.centerIn: parent
                    columns: 2
                    spacing: 3

                    Repeater {
                        model: 4

                        delegate: Rectangle {
                            width: 6
                            height: 6
                            radius: 1.8
                            color: win.glyphColor
                        }
                    }
                }

                MouseArea {
                    id: toggleMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: win.listModeRequested(!win.listMode)
                }
            }

            // Nouvelle conversation, en haut à gauche du volet de droite.
            Rectangle {
                id: composeButton

                x: win.sidebarWidth + 16
                anchors.verticalCenter: parent.verticalCenter
                width: 32
                height: 32
                radius: 10
                color: composeMouse.containsMouse ? win.fillHover : win.fillSoft

                SpotlightGlyph {
                    anchors.centerIn: parent
                    kind: "compose"
                    size: 17
                    color: win.glyphColor
                }

                MouseArea {
                    id: composeMouse

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

            // Titre de la conversation, à côté du bouton de nouvelle conversation.
            Text {
                x: composeButton.x + composeButton.width + 12
                width: Math.max(40, providerChip.x - x - 12)
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideRight
                text: win.chat && win.chat.current ? win.chat.current.title : "Siri IA"
                font.pixelSize: 14
                font.weight: Font.DemiBold
                color: win.inkSoft
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
                color: chipMouse.containsMouse || menu.opened ? win.fillHover : win.fillSoft

                Row {
                    id: chipRow

                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        // Pour Gemini : avec le modèle (« Gemini 3.8 Flash »).
                        text: win.chat ? win.chat.providerLabel(win.chat.activeProvider) : ""
                        font.pixelSize: 13
                        color: win.ink
                    }

                    SpotlightGlyph {
                        anchors.verticalCenter: parent.verticalCenter
                        kind: "chevronDown"
                        size: 12
                        lineWidth: 2
                        color: win.inkSoft
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

        // ---- Barre latérale : recherche et discussions (cartes ou liste) ----
        Item {
            id: sidebar

            x: 0
            y: win.titleBarHeight
            width: win.sidebarWidth
            height: parent.height - win.titleBarHeight

            // Discussions filtrées par la recherche, les plus récentes d'abord
            // (épinglées en tête).
            readonly property var sortedList: {
                if (!win.chat) {
                    return [];
                }
                void win.chat.conversations;
                return win.chat.sortedConversations(searchField.text);
            }

            // Mode cartes : deux colonnes (comme les notes de l'app Siri de
            // macOS 27) ; chaque carte va dans la colonne la moins haute
            // (hauteur estimée).
            readonly property var cardColumns: {
                var columns = [[], []];
                if (win.listMode) {
                    return columns;
                }
                var list = sidebar.sortedList;
                var heights = [0, 0];
                for (var i = 0; i < list.length; ++i) {
                    var target = heights[0] <= heights[1] ? 0 : 1;
                    columns[target].push(list[i]);
                    heights[target] += win.estimateCardHeight(list[i]) + 8;
                }
                return columns;
            }

            // Contenu qui défile (liste ou cartes) : il passe derrière la
            // recherche, qui le floute (verre).
            Item {
                id: scrollArea

                anchors.fill: parent

            // Mode liste : une ligne par discussion.
            ListView {
                id: conversationList

                visible: win.listMode
                x: 8
                y: 0
                width: parent.width - 16
                height: parent.height - 8
                topMargin: 44
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                spacing: 0
                Component.onCompleted: contentY = -topMargin
                model: win.listMode ? sidebar.sortedList : []

                delegate: Item {
                    id: conversationRow

                    required property var modelData
                    required property int index

                    readonly property bool selected: !!win.chat && win.chat.currentId === modelData.id

                    width: conversationList.width
                    height: 70

                    // Séparateur entre deux discussions.
                    Rectangle {
                        visible: conversationRow.index < conversationList.count - 1
                            && !conversationRow.selected
                        x: 14
                        y: parent.height - 1
                        width: parent.width - 28
                        height: 1
                        color: win.separatorColor
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: 14
                        color: conversationRow.selected ? win.rowSelectedFill
                            : (rowMouse.containsMouse ? win.rowHoverFill : "transparent")
                    }

                    Column {
                        x: 14
                        y: 10
                        width: parent.width - 14 - 12
                        spacing: 2

                        Row {
                            width: parent.width
                            spacing: 6

                            SpotlightGlyph {
                                visible: Boolean(conversationRow.modelData.pinned)
                                anchors.verticalCenter: parent.verticalCenter
                                kind: "pin"
                                size: 12
                                color: win.inkSoft
                            }

                            Text {
                                width: parent.width - (conversationRow.modelData.pinned ? 18 : 0) - dateText.implicitWidth - 6
                                elide: Text.ElideRight
                                text: conversationRow.modelData.title
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                                color: win.ink
                            }

                            Text {
                                id: dateText

                                text: win.dateLabel(conversationRow.modelData.updated)
                                font.pixelSize: 12
                                color: win.inkSoft
                            }
                        }

                        Text {
                            width: parent.width
                            height: 30
                            wrapMode: Text.WordWrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                            text: win.lastText(conversationRow.modelData)
                            font.pixelSize: 13
                            color: win.inkSoft
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
            }

            // Mode cartes : deux colonnes.
            Flickable {
                id: cardScroll

                readonly property real gap: 8
                readonly property real sideMargin: 12
                readonly property real columnWidth: (width - 2 * sideMargin - gap) / 2

                visible: !win.listMode
                x: 0
                y: 0
                width: parent.width
                height: parent.height - 4
                topMargin: 44
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                contentWidth: width
                Component.onCompleted: contentY = -topMargin
                contentHeight: Math.max(leftColumn.height, rightColumn.height) + 12

                Column {
                    id: leftColumn

                    x: cardScroll.sideMargin
                    y: 4
                    width: cardScroll.columnWidth
                    spacing: cardScroll.gap

                    Repeater {
                        model: sidebar.cardColumns[0]

                        delegate: ConversationCard {
                            required property var modelData

                            conversation: modelData
                            width: leftColumn.width
                        }
                    }
                }

                Column {
                    id: rightColumn

                    x: cardScroll.sideMargin + cardScroll.columnWidth + cardScroll.gap
                    y: 4
                    width: cardScroll.columnWidth
                    spacing: cardScroll.gap

                    Repeater {
                        model: sidebar.cardColumns[1]

                        delegate: ConversationCard {
                            required property var modelData

                            conversation: modelData
                            width: rightColumn.width
                        }
                    }
                }
            }

            }

            // Recherche en verre liquide : le flou de ce qui défile derrière,
            // une teinte, un liseré lumineux et un reflet sur le bord haut.
            Item {
                id: searchBox

                x: 14
                y: 0
                width: parent.width - 28
                height: 34

                ShaderEffectSource {
                    id: searchBackdrop

                    anchors.fill: parent
                    visible: false
                    sourceItem: scrollArea
                    sourceRect: Qt.rect(searchBox.x, searchBox.y, searchBox.width, searchBox.height)
                    live: true
                }

                Item {
                    id: searchMask

                    anchors.fill: parent
                    visible: false
                    layer.enabled: true

                    Rectangle {
                        anchors.fill: parent
                        radius: height / 2
                        color: "black"
                    }
                }

                MultiEffect {
                    anchors.fill: parent
                    source: searchBackdrop
                    blurEnabled: true
                    blur: 1.0
                    blurMax: 40
                    saturation: win.lightMode ? 0.25 : 0.1
                    brightness: win.lightMode ? 0.04 : -0.05
                    maskEnabled: true
                    maskSource: searchMask
                    maskThresholdMin: 0.5
                    maskSpreadAtMin: 1.0
                }

                // Teinte du verre.
                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: win.lightMode ? Qt.rgba(1, 1, 1, 0.34) : Qt.rgba(0.1, 0.1, 0.12, 0.45)
                }

                // Reflet : lumière qui vient du haut, perdue vers le bas.
                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, win.lightMode ? 0.50 : 0.16) }
                        GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.0) }
                        GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, win.lightMode ? 0.12 : 0.05) }
                    }
                }

                // Liseré clair (bord du verre) et ombre fine à l'intérieur.
                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: "transparent"
                    border.width: 1
                    border.color: win.lightMode ? Qt.rgba(1, 1, 1, 0.85) : Qt.rgba(1, 1, 1, 0.28)
                }

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 1
                    radius: height / 2
                    color: "transparent"
                    border.width: 1
                    border.color: win.lightMode ? Qt.rgba(0, 0, 0, 0.06) : Qt.rgba(0, 0, 0, 0.35)
                }

                SpotlightGlyph {
                    x: 11
                    anchors.verticalCenter: parent.verticalCenter
                    kind: "search"
                    size: 15
                    color: win.inkSoft
                }

                TextInput {
                    id: searchField

                    x: 34
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 34 - 12
                    color: win.ink
                    selectionColor: win.selectionFill
                    font.pixelSize: 14
                    clip: true

                    Text {
                        visible: searchField.text.length === 0
                        text: i18n("Search")
                        font: searchField.font
                        color: win.inkFaint
                    }
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 90
                visible: sidebar.sortedList.length === 0
                width: parent.width - 40
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: searchField.text.length > 0 ? i18n("No conversations found")
                    : i18n("Your conversations will appear here")
                font.pixelSize: 13
                color: win.inkFaint
            }
        }

        // ---- Volet de droite : la conversation ----
        Item {
            id: conversationPane

            x: win.sidebarWidth
            y: win.titleBarHeight
            width: parent.width - win.sidebarWidth
            height: parent.height - win.titleBarHeight

            // Nouvelle conversation : seulement une phrase d'accueil (pas de logo).
            Text {
                visible: !!win.chat && win.chat.currentMessages.length === 0 && !win.chat.currentBusy
                anchors.horizontalCenter: parent.horizontalCenter
                y: (parent.height - 110 - 28) / 2
                text: i18n("How can I help?")
                font.pixelSize: 20
                font.weight: Font.DemiBold
                color: win.ink
            }

            ChatTranscript {
                id: transcript

                light: win.lightMode
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: attachStrip.top
                anchors.leftMargin: 20
                anchors.rightMargin: 20
                anchors.bottomMargin: 8
                accent: win.accent
                messages: win.chat ? win.chat.currentMessages : []
                busy: win.chat ? win.chat.currentBusy : false
                providerNames: win.chat
                    ? [win.chat.providerName(0), win.chat.providerName(1), win.chat.providerName(2),
                        win.chat.providerName(3)]
                    : ["Gemini", "GLM", "", "Groq"]
                onCopyRequested: function (text) {
                    if (win.backend) {
                        win.backend.setClipboardText(text);
                    }
                }
                onImageClicked: function (path) {
                    imageViewer.show(path);
                }
            }

            // Dossiers et fichiers donnés à l'IA (pastilles), et message éventuel.
            Flow {
                id: attachStrip

                readonly property bool shown: (!!win.chat && win.chat.attachments.length > 0)
                    || win.attachNotice.length > 0

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: promptBar.top
                anchors.leftMargin: 22
                anchors.rightMargin: 22
                anchors.bottomMargin: shown ? 8 : 0
                height: shown ? implicitHeight : 0
                visible: shown
                spacing: 6

                Repeater {
                    model: win.chat ? win.chat.attachments : []

                    delegate: AttachmentCard {
                        id: chip

                        required property var modelData
                        required property int index

                        light: win.lightMode
                        fill: win.fillSoft
                        path: modelData.path
                        name: modelData.name
                        isDir: modelData.isDir === true
                        maxNameWidth: 180
                        onOpenRequested: imageViewer.show(chip.path)
                        onRemoveRequested: {
                            if (win.chat) {
                                win.chat.removeAttachment(chip.index);
                            }
                        }
                    }
                }

                Text {
                    visible: win.attachNotice.length > 0
                    height: 26
                    verticalAlignment: Text.AlignVCenter
                    text: win.attachNotice
                    font.pixelSize: 12
                    color: "#D9822B"
                }
            }

            // Raccourcis de prompts : petits, alignés à gauche, au-dessus de la
            // zone de saisie et sous les fichiers joints. Aucune place n'est
            // prise s'il n'y en a pas.
            PromptBar {
                id: promptBar

                light: win.lightMode
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: inputBar.top
                anchors.leftMargin: 20
                anchors.rightMargin: 20
                anchors.bottomMargin: shown ? 8 : 0
                prompts: win.prompts
                onPromptChosen: function (text) {
                    win.insertPrompt(text);
                }
            }

            // Bouton « + » : joindre un dossier ou des fichiers.
            InputTool {
                id: attachButton

                diameter: 40
                glyph: "plus"
                active: !!win.chat && win.chat.attachments.length > 0
                anchors.left: parent.left
                anchors.leftMargin: 20
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 22
                onClicked: win.openAttachMenu()
            }

            // Zone de saisie.
            Rectangle {
                id: inputBar

                anchors.left: attachButton.right
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.leftMargin: 10
                anchors.rightMargin: 20
                anchors.bottomMargin: 18
                height: Math.max(48, Math.min(150, input.contentHeight + 24))
                radius: Math.min(24, height / 2)
                color: win.inputFill
                border.width: 1
                border.color: input.activeFocus ? win.inputBorderFocus : win.inputBorder

                // Bouton à gauche : forcer la recherche web (Gemini seulement).
                Row {
                    id: toolRow

                    x: 9
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 9
                    spacing: 6

                    // La recherche web intégrée n'existe que pour Gemini.
                    InputTool {
                        glyph: "globe"
                        visible: !!win.chat && win.chat.activeProvider === 0
                        active: !!win.chat && win.chat.forceSearch
                        onClicked: {
                            if (win.chat) {
                                win.chat.forceSearch = !win.chat.forceSearch;
                            }
                        }
                    }
                }

                TextEdit {
                    id: input

                    x: toolRow.x + toolRow.width + 12
                    y: 12
                    width: parent.width - x - 56
                    height: parent.height - 24
                    wrapMode: TextEdit.Wrap
                    color: win.ink
                    selectionColor: win.selectionFill
                    selectedTextColor: win.lightMode ? "#000000" : "#FFFFFF"
                    font.pixelSize: 15
                    clip: true

                    Text {
                        visible: input.text.length === 0 && input.preeditText.length === 0
                        text: i18n("Ask Siri AI…")
                        font: input.font
                        color: win.inkFaint
                    }

                    Keys.onPressed: function (event) {
                        if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                                && (event.modifiers & Qt.ShiftModifier) === 0) {
                            win.send();
                            event.accepted = true;
                        } else if (event.matches(StandardKey.Paste)) {
                            // Image ou fichiers : joints (sinon le texte est collé).
                            if (win.pasteAttachments()) {
                                event.accepted = true;
                            }
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
                    color: busy || input.text.trim().length > 0 || (!!win.chat && win.chat.hasFresh)
                        ? win.accent : win.sendIdle

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
    }

    // Photo de l'ancienne fenêtre pendant l'animation d'agrandissement.
    ShaderEffectSource {
        id: snapshot

        anchors.centerIn: parent
        sourceItem: frame
        live: false
        visible: false
        smooth: true
        z: 50
    }

    // Bouton rond de la zone de saisie (fond clair).
    component InputTool: Rectangle {
        id: tool

        property string glyph: ""
        property bool active: false
        property real diameter: 30

        signal clicked()

        width: diameter
        height: diameter
        radius: diameter / 2
        color: active ? win.accent : (toolMouse.containsMouse ? win.fillHover : win.fillSoft)

        SpotlightGlyph {
            anchors.centerIn: parent
            kind: tool.glyph
            size: Math.round(tool.diameter * 0.57)
            lineWidth: 1.9
            color: tool.active ? "white" : win.glyphColor
        }

        MouseArea {
            id: toolMouse

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: tool.clicked()
        }
    }

    // Carte d'une discussion dans la barre latérale : date, titre, début du
    // dernier message et, s'il y en a une, la dernière image envoyée.
    component ConversationCard: Item {
        id: card

        property var conversation: ({})

        readonly property bool selected: !!win.chat && win.chat.currentId === conversation.id
        readonly property string picture: win.conversationImage(conversation)
        readonly property string preview: win.lastText(conversation)

        height: body.implicitHeight + 28

        Rectangle {
            anchors.fill: parent
            radius: 24
            color: card.selected ? win.cardSelectedFill
                : (cardMouse.containsMouse ? win.cardHoverFill : win.cardFill)
            border.width: card.selected ? 2 : 0
            border.color: win.accent
        }

        Column {
            id: body

            x: 14
            y: 14
            width: parent.width - 28
            spacing: 4

            Row {
                spacing: 4

                SpotlightGlyph {
                    visible: Boolean(card.conversation.pinned)
                    anchors.verticalCenter: parent.verticalCenter
                    kind: "pin"
                    size: 11
                    color: win.inkSoft
                }

                Text {
                    text: win.dateLabel(card.conversation.updated)
                    font.pixelSize: 11
                    color: win.inkSoft
                }
            }

            Text {
                width: parent.width
                wrapMode: Text.WordWrap
                maximumLineCount: 3
                elide: Text.ElideRight
                text: card.conversation.title
                font.pixelSize: 15
                font.weight: Font.Bold
                color: win.ink
            }

            Text {
                visible: card.preview.length > 0
                width: parent.width
                wrapMode: Text.WordWrap
                maximumLineCount: 4
                elide: Text.ElideRight
                text: card.preview
                font.pixelSize: 13
                color: win.inkSoft
            }

            RoundedImage {
                visible: card.picture.length > 0
                width: parent.width
                height: 84
                radius: 16
                source: card.picture
                decodeSize: 320
            }
        }

        MouseArea {
            id: cardMouse

            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: function (mouse) {
                if (mouse.button === Qt.RightButton) {
                    var point = card.mapToItem(null, mouse.x, mouse.y);
                    win.openConversationMenu(card.conversation.id, point.x, point.y);
                } else if (win.chat) {
                    win.chat.select(card.conversation.id);
                    win.focusInput();
                }
            }
        }
    }

    // --- Redimensionnement ---------------------------------------------------------
    // La fenêtre n'a pas de bordure du système : de fines poignées sur les
    // bords et les coins laissent KWin la redimensionner (inactives quand la
    // fenêtre est maximisée).
    component ResizeHandle: MouseArea {
        required property int edges

        enabled: !win.maximized
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        z: 100
        onPressed: win.startSystemResize(edges)
    }

    ResizeHandle {
        edges: Qt.LeftEdge
        x: 0
        y: 12
        width: 6
        height: win.height - 24
        cursorShape: Qt.SizeHorCursor
    }

    ResizeHandle {
        edges: Qt.RightEdge
        x: win.width - 6
        y: 12
        width: 6
        height: win.height - 24
        cursorShape: Qt.SizeHorCursor
    }

    ResizeHandle {
        edges: Qt.TopEdge
        x: 12
        y: 0
        width: win.width - 24
        height: 6
        cursorShape: Qt.SizeVerCursor
    }

    ResizeHandle {
        edges: Qt.BottomEdge
        x: 12
        y: win.height - 6
        width: win.width - 24
        height: 6
        cursorShape: Qt.SizeVerCursor
    }

    ResizeHandle {
        edges: Qt.TopEdge | Qt.LeftEdge
        x: 0
        y: 0
        width: 12
        height: 12
        cursorShape: Qt.SizeFDiagCursor
    }

    ResizeHandle {
        edges: Qt.TopEdge | Qt.RightEdge
        x: win.width - 12
        y: 0
        width: 12
        height: 12
        cursorShape: Qt.SizeBDiagCursor
    }

    ResizeHandle {
        edges: Qt.BottomEdge | Qt.LeftEdge
        x: 0
        y: win.height - 12
        width: 12
        height: 12
        cursorShape: Qt.SizeBDiagCursor
    }

    ResizeHandle {
        edges: Qt.BottomEdge | Qt.RightEdge
        x: win.width - 12
        y: win.height - 12
        width: 12
        height: 12
        cursorShape: Qt.SizeFDiagCursor
    }

    // Image de la conversation agrandie (clic sur une image envoyée).
    ImageViewer {
        id: imageViewer

        anchors.fill: parent
        z: 100
        onClosed: input.forceActiveFocus()
    }

    NativeGlassMenu {
        id: menu

        window: win
        onActivated: function (entryId) {
            win.handleMenu(entryId);
        }
    }
}
