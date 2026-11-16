import QtQuick
import QtQuick.Effects
import org.kde.kirigami as Kirigami
import org.kde.layershell as LayerShell
import "effects" as DockEffects
import "SpotlightMath.js" as SpotlightMath

// Spotlight de macOS 27 : une barre « Search or Ask » en verre, et dessous un
// panneau de résultats. Ouvert par la touche Windows, par l'icône du Dock, par
// Alt+Espace ou en tapant sur le bureau (voir SpotlightBackend).
//
// Le bouton à gauche de la barre change de mode à chaque clic :
//   Applications (par défaut : la grille s'ouvre tout de suite ; si rien ne
//   correspond à la saisie, la question part vers l'assistant IA)
//   -> Fichiers -> Presse-papiers -> Applications ;
// un double clic revient toujours aux applications.
//
// Le fond de la barre et du panneau est celui des menus du clic droit : presque
// transparent, avec un liseré, le flou / Liquid Glass étant demandé à KWin
// (GlassBlur). Modifier l'application Liquid Glass change donc aussi le
// Spotlight.
Window {
    id: win

    // --- Fournis par main.qml ------------------------------------------------
    property var backend: null
    property var chat: null
    // Identifiants (desktopId) des applications favorites.
    property var favorites: []
    property bool assistantEnabled: true
    // Le Spotlight dessine lui-même son verre (moteur du verre du Dock, mais
    // avec ses propres réglages : onglet « Spotlight »). Il n'utilise ni KWin ni
    // l'effet Liquid Glass de l'application externe, et ne touche pas au verre
    // du Dock. Fond d'écran (venant de main.qml) ; fenêtres derrière, en direct.
    property var wallpaperInfo: ({ "source": "", "fillMode": 2, "width": 0, "height": 0 })
    // WallpaperLocator (module natif) : lit les couleurs du fond d'écran derrière
    // la barre. null = le bas de la barre garde son gris-bleu d'origine.
    property var colorSampler: null
    property var backdropWindows: []
    property bool liveBackdrop: true
    // Rayon du flou en px (nommé ainsi : « glassBlur » est l'identifiant de
    // l'objet GlassBlur plus bas ; un même nom donnait un flou nul).
    property real glassBlurPx: 14
    property real glassTint: 0.3
    // Voile noir supplémentaire (0..1) : assombrit l'arrière-plan du Spotlight.
    property real glassDarken: 0
    property real glassThickness: 34
    property real glassStrength: 1.0
    property real glassProfile: 1.0
    property real glassDispersion: 0.25
    property real glassRim: 1.0
    // Liseré : chaque point prend la couleur de ce qui est derrière lui.
    property real borderStrength: 0.8
    property real borderWidth: 1.5
    // Liquid Glass du menu d'applications (réglages repris du dépôt
    // liquidglass-kde-widgets : onglet Spotlight de la configuration). Ils ne
    // concernent que le menu d'applications ; la barre et la fenêtre de
    // conversation gardent leur verre.
    property real menuBlurPx: 10
    property real menuRadius: 34
    // Exposant de la superellipse des coins : 2 = cercle, 5 = squircle.
    property real menuRoundness: 5
    property real menuThickness: 35
    property real menuRefraction: 65
    property real menuIor: 1.7
    property real menuChroma: 0.3
    property real menuSpec: 0.7

    signal favoritesChangeRequested(var ids)
    signal assistantRequested(bool freshConversation)
    signal settingsRequested()

    // --- État --------------------------------------------------------------------
    // 0 = par défaut, 1 = applications, 2 = fichiers, 3 = presse-papiers
    property int mode: 1
    property string query: ""
    // Vrai : le panneau montre la conversation avec l'assistant.
    property bool aiView: false
    property var glassTheme: ({})
    property var allApps: []
    property var sections: []
    property int gridSection: 0
    property int gridIndex: 0
    property var results: []
    property int selectedIndex: -1
    property var fileResults: []
    property bool fileSearching: false
    property var recentFileList: []
    property var clipboardItems: []
    property bool clipboardAvailable: true
    property var contextTarget: null

    // --- Dimensions (celles de la capture de macOS 27) -------------------------
    // Toujours 7 applications par ligne : la grille (7 x 111 px) est centrée
    // dans le panneau, avec de part et d'autre de la place pour les bords.
    // Taille intermédiaire entre la version d'origine (barre 444, panneau 720)
    // et la capture de macOS 27 (barre 563, panneau 910).
    readonly property int columns: 7
    readonly property real cellWidth: 111
    readonly property real cellHeight: 108
    readonly property real iconSize: 66
    readonly property real barWidth: 504
    readonly property real barHeight: 86
    readonly property real panelWidth: Math.min(815, width - 40)
    // Fenêtre de conversation avec l'assistant (comme Siri sur macOS 27) :
    // la barre et le panneau se transforment en cette fenêtre verticale.
    readonly property real compactWidth: 400
    readonly property real compactRadius: 34
    readonly property real compactHeight:
        Math.max(380, Math.min(640, height - stageTop - 28))
    // Position et taille choisies par l'utilisateur (la fenêtre se déplace par
    // son en-tête et se redimensionne par ses bords). -1 / 0 : valeurs d'origine.
    property real compactUserX: -1
    property real compactUserY: -1
    property real compactUserWidth: 0
    property real compactUserHeight: 0

    // Transformation de la barre en fenêtre de conversation (animation
    // « goutte ») : 0 = forme de la barre, 1 = fenêtre ; légèrement au-delà de 1
    // pendant le rebond. Opacités de la barre qui s'efface et du contenu de la
    // fenêtre qui apparaît.
    property real compactMorph: 1
    property real compactContentOpacity: 1
    property real barFadeOpacity: 1

    function resetCompactGeometry() {
        compactUserX = -1;
        compactUserY = -1;
        compactUserWidth = 0;
        compactUserHeight = 0;
    }
    // Plus haut que la capture, mais jamais plus que l'écran ne le permet.
    readonly property real panelMaxHeight:
        Math.max(300, Math.min(550, height - stageTop - barHeight - stageGap - 28))
    readonly property real stageGap: 12
    readonly property real stageTop: Math.round(height * 0.17)
    readonly property color accent: "#007AFF"

    readonly property bool gridMode: mode === 1 && query.trim().length === 0 && !aiView
    // Recherche d'une application (mode Applications, texte saisi) : la barre
    // et le panneau ont la même largeur, comme sur macOS 27.
    readonly property bool appSearch: mode === 1 && query.trim().length > 0 && !aiView
    readonly property var selectedEntry:
        selectedIndex >= 0 && selectedIndex < results.length ? results[selectedIndex] : null
    // Application sélectionnée dans les résultats (son icône remplace le bouton « … »).
    readonly property var selectedApp:
        appSearch && selectedEntry && selectedEntry.kind === "app" ? selectedEntry.app : null
    // Rayon des coins du panneau ; la sélection d'une ligne est une gélule de
    // (rowHeight - 4) px, dont le rayon est celui du panneau moins la marge
    // de 8 px : les deux contours sont concentriques.
    readonly property real panelRadius: menuRadius
    readonly property real rowHeight: 56
    readonly property bool panelWanted: true
    readonly property real panelTargetHeight: {
        if (!panelWanted) {
            return 0;
        }
        if (aiView || gridMode) {
            return panelMaxHeight;
        }
        // 8 px de marge en haut et en bas ; la dernière ligne n'a pas d'espace dessous.
        var total = 12;
        for (var i = 0; i < results.length; ++i) {
            total += results[i].kind === "header" ? 28
                : (results[i].kind === "info" ? 46 : rowHeight);
        }
        return Math.max(66, Math.min(panelMaxHeight, total));
    }

    readonly property var categoryList: [
        { "id": "utilities", "title": i18n("Utilities") },
        { "id": "productivity", "title": i18n("Productivity & Finance") },
        { "id": "photovideo", "title": i18n("Photo & Video") },
        { "id": "entertainment", "title": i18n("Entertainment") },
        { "id": "social", "title": i18n("Social") },
        { "id": "creativity", "title": i18n("Creativity") },
        { "id": "information", "title": i18n("Information & Reading") },
        { "id": "other", "title": i18n("Other") }
    ]

    readonly property string placeholder: aiView ? i18n("Ask a follow-up…")
        : (mode === 2 ? i18n("Files")
            : (mode === 3 ? i18n("Clipboard") : i18n("Applications")))

    // --- Fenêtre : un calque plein écran, au-dessus de tout -------------------
    flags: Qt.FramelessWindowHint
    color: "transparent"
    visible: false
    title: "Spotlight"
    width: screen ? screen.width : 1920
    height: screen ? screen.height : 1080

    LayerShell.Window.scope: "macosdock-spotlight"
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

    DockEffects.GlassBlur {
        id: glassBlur
    }

    // --- Ouverture / fermeture ---------------------------------------------------
    function openSpotlight(initialText) {
        glassTheme = glassBlur.theme();
        moreMenu.close();
        contextMenu.close();
        // Une animation d'agrandissement interrompue ne doit rien laisser derrière elle.
        expandAnimation.stop();
        compactIntro.stop();
        compactSurface.scale = 1;
        compactSurface.opacity = 1;
        compactMorph = 1;
        compactContentOpacity = 1;
        barFadeOpacity = 1;
        // La fenêtre de conversation ne reprend pas la position ni la taille
        // de la fois d'avant.
        resetCompactGeometry();
        refreshApps();
        aiView = false;
        query = initialText !== undefined ? String(initialText) : "";
        if (chat) {
            chat.startNew();
        }
        if (mode !== 1) {
            mode = 1;
        } else {
            resetGridSelection();
            appsList.contentY = 0;
            pillsArea.contentX = 0;
        }
        rebuildResults();
        visible = true;
        requestActivate();
        Qt.callLater(focusField);
        Qt.callLater(refreshBarColors);
    }

    function closeSpotlight() {
        moreMenu.close();
        contextMenu.close();
        expandAnimation.stop();
        visible = false;
    }

    // Agrandit la conversation du panneau vers l'application Siri IA : le
    // panneau grossit en s'estompant, puis le Spotlight se ferme et la fenêtre
    // de Siri IA apparaît en grossissant à son tour (voir SiriWindow).
    function expandToAssistant() {
        if (!assistantEnabled || expandAnimation.running) {
            return;
        }
        moreMenu.close();
        contextMenu.close();
        expandAnimation.restart();
    }

    function toggleSpotlight() {
        if (visible) {
            closeSpotlight();
        } else {
            openSpotlight("");
        }
    }

    function focusField() {
        var input = aiView ? aiField : field;
        input.forceActiveFocus();
        input.cursorPosition = input.text.length;
    }

    onVisibleChanged: {
        if (visible) {
            stage.opacity = 0;
            fadeIn.restart();
        } else {
            glassBlur.clear(win);
            if (backend) {
                backend.cancelFileSearch();
            }
        }
    }

    ParallelAnimation {
        id: expandAnimation

        NumberAnimation {
            target: compactSurface
            property: "scale"
            to: 1.08
            duration: 190
            easing.type: Easing.InOutCubic
        }

        NumberAnimation {
            target: compactSurface
            property: "opacity"
            to: 0
            duration: 190
            easing.type: Easing.InCubic
        }

        onFinished: {
            win.closeSpotlight();
            win.assistantRequested(false);
        }
    }

    // La barre devient la fenêtre de conversation comme une goutte qui
    // s'agrandit : la fenêtre part de la forme exacte de la barre (même
    // position, même taille, coins en pilule), puis grandit vers sa taille avec
    // un petit rebond ; la barre s'efface en fondu, le contenu apparaît ensuite.
    ParallelAnimation {
        id: compactIntro

        NumberAnimation {
            target: compactSurface
            property: "opacity"
            from: 0
            to: 1
            duration: 150
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            target: win
            property: "barFadeOpacity"
            from: 1
            to: 0
            duration: 150
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            target: win
            property: "compactMorph"
            from: 0
            to: 1
            duration: 440
            easing.type: Easing.OutBack
            easing.overshoot: 1.15
        }

        SequentialAnimation {
            PauseAnimation { duration: 130 }

            NumberAnimation {
                target: win
                property: "compactContentOpacity"
                from: 0
                to: 1
                duration: 220
                easing.type: Easing.OutCubic
            }
        }
    }

    onAiViewChanged: {
        if (aiView) {
            // Départ immédiat à la forme de la barre : pas d'image à taille
            // finale avant le début de l'animation.
            compactMorph = 0;
            compactContentOpacity = 0;
            compactSurface.opacity = 0;
            compactIntro.restart();
        } else {
            compactIntro.stop();
            compactMorph = 1;
            compactContentOpacity = 1;
            barFadeOpacity = 1;
            compactSurface.opacity = 1;
        }
    }

    NumberAnimation {
        id: fadeIn

        target: stage
        property: "opacity"
        from: 0
        to: 1
        duration: 130
        easing.type: Easing.OutCubic
    }

    Connections {
        target: win.backend

        function onToggleRequested() {
            win.toggleSpotlight();
        }

        function onShowRequested() {
            if (!win.visible) {
                win.openSpotlight("");
            }
        }

        function onHideRequested() {
            win.closeSpotlight();
        }

        function onQueryRequested(text) {
            win.openSpotlight(text);
        }

        function onFilesFound(searched, found) {
            if (win.mode === 2 && searched === win.query.trim()) {
                win.fileResults = found;
                win.fileSearching = false;
                win.rebuildResults();
            }
        }

        function onClipboardHistoryReady(items, available) {
            win.clipboardItems = items;
            win.clipboardAvailable = available;
            if (win.mode === 3) {
                win.rebuildResults();
            }
        }
    }

    // --- Applications ----------------------------------------------------------------
    function refreshApps() {
        allApps = backend ? backend.applications() : [];
        buildSections();
    }

    onFavoritesChanged: buildSections()

    function buildSections() {
        var byCategory = ({});
        var byId = ({});
        var i;
        for (i = 0; i < allApps.length; ++i) {
            var app = allApps[i];
            byId[app.desktopId] = app;
            if (byCategory[app.category] === undefined) {
                byCategory[app.category] = [];
            }
            byCategory[app.category].push(app);
        }
        var favoriteApps = [];
        for (i = 0; i < favorites.length; ++i) {
            if (byId[favorites[i]] !== undefined) {
                favoriteApps.push(byId[favorites[i]]);
            }
        }
        var list = [{ "id": "favorites", "title": i18n("Favorites"), "apps": favoriteApps }];
        for (i = 0; i < categoryList.length; ++i) {
            var apps = byCategory[categoryList[i].id];
            if (apps !== undefined && apps.length > 0) {
                list.push({ "id": categoryList[i].id, "title": categoryList[i].title, "apps": apps });
            }
        }
        sections = list;
        resetGridSelection();
    }

    function resetGridSelection() {
        gridSection = firstNonEmptySection(0);
        gridIndex = 0;
    }

    function firstNonEmptySection(from) {
        for (var i = Math.max(0, from); i < sections.length; ++i) {
            if (sections[i].apps.length > 0) {
                return i;
            }
        }
        return 0;
    }

    function sectionHeight(section) {
        if (section.apps.length === 0) {
            return 64;
        }
        return Math.ceil(section.apps.length / columns) * cellHeight + 16;
    }

    function sectionOffset(index) {
        var offset = 0;
        for (var i = 0; i < index && i < sections.length; ++i) {
            offset += sectionHeight(sections[i]);
        }
        return offset;
    }

    // Section qui occupe le haut de la liste (pastille de catégorie active).
    function sectionAtOffset(contentY) {
        var offset = 0;
        for (var i = 0; i < sections.length; ++i) {
            offset += sectionHeight(sections[i]);
            if (contentY + 24 < offset) {
                return i;
            }
        }
        return Math.max(0, sections.length - 1);
    }

    function scrollToSection(index) {
        if (index < 0 || index >= sections.length) {
            return;
        }
        var target = Math.max(0, Math.min(sectionOffset(index),
            appsList.contentHeight - appsList.height));
        scrollAnimation.stop();
        scrollAnimation.from = appsList.contentY;
        scrollAnimation.to = target;
        scrollAnimation.start();
    }

    function nonEmptySectionAfter(index, step) {
        for (var i = index + step; i >= 0 && i < sections.length; i += step) {
            if (sections[i].apps.length > 0) {
                return i;
            }
        }
        return -1;
    }

    function gridMove(rowStep, columnStep) {
        if (sections.length === 0) {
            return;
        }
        var s = gridSection;
        var j = gridIndex;
        if (!sections[s] || sections[s].apps.length === 0) {
            s = firstNonEmptySection(0);
            j = 0;
            if (sections[s].apps.length === 0) {
                return;
            }
        }
        var length = sections[s].apps.length;
        var other;
        if (columnStep !== 0) {
            j += columnStep;
            if (j < 0) {
                other = nonEmptySectionAfter(s, -1);
                if (other < 0) {
                    return;
                }
                s = other;
                j = sections[s].apps.length - 1;
            } else if (j >= length) {
                other = nonEmptySectionAfter(s, 1);
                if (other < 0) {
                    return;
                }
                s = other;
                j = 0;
            }
        } else {
            var row = Math.floor(j / columns);
            var column = j % columns;
            if (rowStep > 0) {
                if ((row + 1) * columns + column < length) {
                    j = (row + 1) * columns + column;
                } else if (row + 1 < Math.ceil(length / columns)) {
                    j = length - 1;
                } else {
                    other = nonEmptySectionAfter(s, 1);
                    if (other < 0) {
                        return;
                    }
                    s = other;
                    j = Math.min(column, sections[s].apps.length - 1);
                }
            } else if (row > 0) {
                j = (row - 1) * columns + column;
            } else {
                other = nonEmptySectionAfter(s, -1);
                if (other < 0) {
                    return;
                }
                s = other;
                var previousLength = sections[s].apps.length;
                var lastRow = Math.floor((previousLength - 1) / columns);
                j = Math.min(lastRow * columns + column, previousLength - 1);
            }
        }
        gridSection = s;
        gridIndex = j;
        ensureGridVisible();
    }

    function ensureGridVisible() {
        var top = sectionOffset(gridSection) + 8 + Math.floor(gridIndex / columns) * cellHeight;
        scrollAnimation.stop();
        if (top < appsList.contentY) {
            appsList.contentY = Math.max(0, top - 8);
        } else if (top + cellHeight > appsList.contentY + appsList.height) {
            appsList.contentY = top + cellHeight - appsList.height + 8;
        }
    }

    function selectedGridApp() {
        var section = sections[gridSection];
        return section && gridIndex < section.apps.length ? section.apps[gridIndex] : null;
    }

    // --- Recherche -------------------------------------------------------------------
    function normalize(text) {
        return String(text || "").toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, "");
    }

    function scoreApp(app, needle) {
        var name = normalize(app.name);
        if (name === needle) {
            return 0;
        }
        if (name.indexOf(needle) === 0) {
            return 1;
        }
        if (name.indexOf(" " + needle) >= 0) {
            return 2;
        }
        if (name.indexOf(needle) >= 0) {
            return 3;
        }
        if (normalize(app.genericName).indexOf(needle) >= 0
                || normalize(app.keywords).indexOf(needle) >= 0) {
            return 4;
        }
        if (normalize(app.desktopId).indexOf(needle) >= 0) {
            return 5;
        }
        if (normalize(app.comment).indexOf(needle) >= 0) {
            return 6;
        }
        return -1;
    }

    function matchApps(text, limit) {
        var needle = normalize(text).trim();
        if (needle.length === 0) {
            return [];
        }
        var scored = [];
        for (var i = 0; i < allApps.length; ++i) {
            var score = scoreApp(allApps[i], needle);
            if (score >= 0) {
                scored.push({ "score": score, "app": allApps[i] });
            }
        }
        scored.sort(function (a, b) {
            return a.score !== b.score ? a.score - b.score : a.app.name.localeCompare(b.app.name);
        });
        return scored.slice(0, limit).map(function (entry) {
            return entry.app;
        });
    }

    function isSelectable(entry) {
        return entry.kind !== "header" && entry.kind !== "info";
    }

    function rebuildResults() {
        var text = query.trim();
        var list = [];
        var i;
        if (aiView) {
            results = [];
            selectedIndex = -1;
            return;
        }
        if (mode === 1) {
            if (text.length > 0) {
                var calculation = SpotlightMath.evaluate(text);
                if (calculation) {
                    list.push({ "kind": "calc", "text": text, "value": calculation.text });
                }
                var apps = matchApps(text, 40);
                if (apps.length > 0) {
                    for (i = 0; i < apps.length; ++i) {
                        list.push({ "kind": "app", "app": apps[i] });
                    }
                }
                // Rien ne correspond : la question part vers l'assistant IA.
                if (chat) {
                    list.push({ "kind": "ai", "text": text });
                }
            }
        } else if (mode === 2) {
            var files = text.length > 0 ? fileResults : recentFileList;
            if (text.length > 0 && files.length === 0) {
                list.push({ "kind": "info",
                    "text": fileSearching ? i18n("Searching…") : i18n("No results") });
            } else if (files.length === 0) {
                list.push({ "kind": "info", "text": i18n("No recent files") });
            } else {
                list.push({ "kind": "header",
                    "text": text.length > 0 ? i18n("Files") : i18n("Recent") });
                for (i = 0; i < files.length; ++i) {
                    list.push({ "kind": "file", "file": files[i] });
                }
            }
        } else {
            if (!clipboardAvailable) {
                list.push({ "kind": "info",
                    "text": i18n("Clipboard history is unavailable (Klipper is not running).") });
            } else {
                var needle = normalize(text);
                var shown = 0;
                for (i = 0; i < clipboardItems.length && shown < 60; ++i) {
                    if (needle.length === 0 || normalize(clipboardItems[i]).indexOf(needle) >= 0) {
                        if (shown === 0) {
                            list.push({ "kind": "header", "text": i18n("Clipboard history") });
                        }
                        list.push({ "kind": "clip", "text": clipboardItems[i] });
                        ++shown;
                    }
                }
                if (shown === 0) {
                    list.push({ "kind": "info",
                        "text": text.length > 0 ? i18n("No results") : i18n("The clipboard history is empty") });
                }
            }
        }
        results = list;
        selectedIndex = -1;
        for (i = 0; i < list.length; ++i) {
            if (isSelectable(list[i])) {
                selectedIndex = i;
                break;
            }
        }
    }

    function moveSelection(step) {
        var i = selectedIndex + step;
        while (i >= 0 && i < results.length && !isSelectable(results[i])) {
            i += step;
        }
        if (i >= 0 && i < results.length) {
            selectedIndex = i;
            resultsList.positionViewAtIndex(i, ListView.Contain);
        }
    }

    onQueryChanged: {
        if (field.text !== query) {
            field.text = query;
        }
        if (aiField.text !== query) {
            aiField.text = query;
        }
        if (mode === 2) {
            var text = query.trim();
            if (text.length >= 2) {
                fileSearching = true;
                fileResults = [];
                fileTimer.restart();
            } else {
                fileTimer.stop();
                fileSearching = false;
                fileResults = [];
                if (backend) {
                    backend.cancelFileSearch();
                }
            }
        }
        rebuildResults();
    }

    Timer {
        id: fileTimer

        interval: 200
        repeat: false
        onTriggered: {
            if (win.backend) {
                win.backend.searchFiles(win.query.trim());
            }
        }
    }

    onModeChanged: {
        aiView = false;
        fileResults = [];
        fileSearching = false;
        if (backend) {
            backend.cancelFileSearch();
        }
        if (mode === 1) {
            resetGridSelection();
            appsList.contentY = 0;
            pillsArea.contentX = 0;
        } else if (mode === 2) {
            recentFileList = backend ? backend.recentFiles(20) : [];
            if (query.trim().length >= 2) {
                fileSearching = true;
                fileTimer.restart();
            }
        } else if (mode === 3 && backend) {
            backend.requestClipboardHistory();
        }
        rebuildResults();
    }

    // --- Actions -----------------------------------------------------------------------
    function launchApp(app) {
        if (app && backend) {
            backend.launchApplication(app.desktopId);
        }
        closeSpotlight();
    }

    function openFile(file, reveal) {
        if (file && backend) {
            if (reveal) {
                backend.revealPath(file.path);
            } else {
                backend.openPath(file.path);
            }
        }
        closeSpotlight();
    }

    function copyText(text) {
        if (backend) {
            backend.setClipboardText(String(text));
        }
        closeSpotlight();
    }

    // --- Fichiers donnés à l'IA (bouton « + » de la conversation) -------------------------
    // La fenêtre du Spotlight est au-dessus de tout : elle se cache pendant que
    // le sélecteur de fichiers est ouvert, puis revient dans le même état.
    property int pickProcess: -1
    property bool picking: false
    property string attachNotice: ""

    function pickFiles() {
        if (!chat || !backend || picking) {
            return;
        }
        moreMenu.close();
        picking = true;
        pickProcess = backend.runProcess("kdialog",
            ["--getopenfilename", "--multiple", "--separate-output"], 600000);
        visible = false;
    }

    function endPick() {
        if (!picking) {
            return;
        }
        picking = false;
        visible = true;
        requestActivate();
        Qt.callLater(focusField);
    }

    function attachFile(location) {
        if (chat && !chat.addAttachment(location, false)
                && chat.attachments.length >= chat.maxAttachments) {
            attachNotice = i18n("You can attach up to %1 items.", chat.maxAttachments);
            attachNoticeTimer.restart();
        }
    }

    Timer {
        id: attachNoticeTimer

        interval: 6000
        onTriggered: win.attachNotice = ""
    }

    // Repli quand kdialog est absent : la boîte de dialogue de Qt.
    Loader {
        id: pickerLoader

        active: false
        source: "AttachPicker.qml"
        onLoaded: item.openFiles()
        onStatusChanged: {
            if (status === Loader.Error) {
                win.endPick();
            }
        }
    }

    Connections {
        target: pickerLoader.item
        ignoreUnknownSignals: true

        function onPicked(location, isDir) {
            win.attachFile(location);
            win.endPick();
        }

        function onCancelled() {
            win.endPick();
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
                // 1 = dialogue annulé ; autre : kdialog absent -> boîte de Qt.
                if (exitCode !== 1 && pickerLoader.status !== Loader.Error) {
                    if (pickerLoader.status === Loader.Ready) {
                        pickerLoader.item.openFiles();
                    } else {
                        pickerLoader.active = true;
                    }
                    return;
                }
                win.endPick();
                return;
            }
            var lines = String(standardOutput).split("\n");
            for (var i = 0; i < lines.length; ++i) {
                var path = lines[i].trim();
                if (path.length > 0) {
                    win.attachFile(path);
                }
            }
            win.endPick();
        }
    }

    function askAi(text) {
        var question = String(text).trim();
        if (!chat || question.length === 0) {
            return;
        }
        // Une réponse est déjà en cours : le texte tapé est conservé.
        if (aiView && chat.currentBusy) {
            return;
        }
        aiView = true;
        query = "";
        chat.ask(question, chat.activeProvider);
        Qt.callLater(focusField);
    }

    function activateEntry(entry, reveal) {
        if (!entry) {
            return;
        }
        if (entry.kind === "app") {
            launchApp(entry.app);
        } else if (entry.kind === "file") {
            openFile(entry.file, reveal === true);
        } else if (entry.kind === "clip") {
            copyText(entry.text);
        } else if (entry.kind === "calc") {
            copyText(entry.value);
        } else if (entry.kind === "ai") {
            askAi(entry.text);
        }
    }

    function activateSelected(reveal) {
        if (aiView) {
            askAi(query);
        } else if (gridMode) {
            var app = selectedGridApp();
            if (app) {
                launchApp(app);
            }
        } else if (selectedIndex >= 0 && selectedIndex < results.length) {
            activateEntry(results[selectedIndex], reveal);
        } else if (mode === 1 && chat && query.trim().length > 0) {
            askAi(query);
        }
    }

    function isFavorite(desktopId) {
        return favorites.indexOf(desktopId) >= 0;
    }

    function toggleFavorite(desktopId) {
        var next = favorites.slice();
        var index = next.indexOf(desktopId);
        if (index >= 0) {
            next.splice(index, 1);
        } else {
            next.push(desktopId);
        }
        favoritesChangeRequested(next);
    }

    function setMode(newMode) {
        mode = newMode;
        focusField();
    }

    // --- Menus ---------------------------------------------------------------------------
    function moreEntries() {
        var entries = [
            { "id": "mode1", "text": i18n("Applications"), "glyph": "apps",
              "checked": mode === 1, "shortcut": "Ctrl+1" },
            { "id": "mode2", "text": i18n("Files"), "glyph": "files",
              "checked": mode === 2, "shortcut": "Ctrl+2" },
            { "id": "mode3", "text": i18n("Clipboard"), "glyph": "clipboard",
              "checked": mode === 3, "shortcut": "Ctrl+3" },
            { "id": "favorites", "text": i18n("Favorites"), "glyph": "star" },
            { "separator": true }
        ];
        if (chat) {
            for (var i = 0; i < chat.providerCount; ++i) {
                entries.push({
                    "id": "provider" + i,
                    "text": i18n("Ask %1", chat.providerName(i)),
                    "glyph": "sparkle",
                    "checked": chat.activeProvider === i
                });
            }
            entries.push({ "separator": true });
        }
        if (assistantEnabled) {
            entries.push({ "id": "newchat", "text": i18n("New Siri AI conversation"), "glyph": "compose" });
            entries.push({ "id": "openchat", "text": i18n("Open Siri AI"), "glyph": "expand" });
            entries.push({ "separator": true });
        }
        entries.push({ "id": "settings", "text": i18n("Spotlight Settings…"), "glyph": "" });
        return entries;
    }

    // Menu du bouton « + » de la fenêtre de conversation.
    function aiEntries() {
        var entries = [];
        if (chat) {
            for (var i = 0; i < chat.providerCount; ++i) {
                entries.push({
                    "id": "provider" + i,
                    "text": i18n("Ask %1", chat.providerName(i)),
                    "glyph": "sparkle",
                    "checked": chat.activeProvider === i
                });
            }
            entries.push({ "separator": true });
        }
        entries.push({ "id": "newinline", "text": i18n("New Siri AI conversation"), "glyph": "compose" });
        if (assistantEnabled) {
            entries.push({ "id": "openchat", "text": i18n("Open Siri AI"), "glyph": "expand" });
        }
        entries.push({ "separator": true });
        entries.push({ "id": "settings", "text": i18n("Spotlight Settings…"), "glyph": "" });
        return entries;
    }

    function openAiMenu() {
        contextMenu.close();
        moreMenu.entries = aiEntries();
        var anchor = plusButton.mapToItem(null, 0, -6);
        moreMenu.openAt(anchor.x, anchor.y, false, "up");
    }

    function openMoreMenu() {
        contextMenu.close();
        moreMenu.entries = moreEntries();
        var anchor = moreButton.mapToItem(null, moreButton.width, moreButton.height + 6);
        moreMenu.openAt(anchor.x, anchor.y, true);
    }

    function handleMoreMenu(id) {
        if (id === "mode1" || id === "mode2" || id === "mode3") {
            setMode(Number(id.substring(4)));
        } else if (id === "favorites") {
            setMode(1);
            Qt.callLater(function () {
                win.scrollToSection(0);
            });
        } else if (id.indexOf("provider") === 0 && chat) {
            chat.setActiveProvider(Number(id.substring(8)));
            focusField();
        } else if (id === "newinline") {
            if (chat) {
                chat.startNew();
            }
            focusField();
        } else if (id === "newchat") {
            closeSpotlight();
            assistantRequested(true);
        } else if (id === "openchat") {
            if (aiView) {
                expandToAssistant();
            } else {
                closeSpotlight();
                assistantRequested(false);
            }
        } else if (id === "settings") {
            closeSpotlight();
            settingsRequested();
        }
    }

    function openContextMenu(target, sceneX, sceneY) {
        moreMenu.close();
        contextTarget = target;
        var entries = [];
        if (target.kind === "app") {
            entries.push({ "id": "open", "text": i18n("Open"), "glyph": "" });
            entries.push({ "id": "favorite",
                "text": isFavorite(target.app.desktopId) ? i18n("Remove from Favorites")
                    : i18n("Add to Favorites"),
                "glyph": "star" });
            entries.push({ "separator": true });
            entries.push({ "id": "reveal", "text": i18n("Show in File Manager"), "glyph": "files" });
        } else if (target.kind === "file") {
            entries.push({ "id": "open", "text": i18n("Open"), "glyph": "" });
            entries.push({ "id": "reveal", "text": i18n("Show in Folder"), "glyph": "files" });
            entries.push({ "id": "copy", "text": i18n("Copy Path"), "glyph": "copy" });
        } else {
            entries.push({ "id": "open", "text": i18n("Copy"), "glyph": "copy" });
        }
        contextMenu.entries = entries;
        contextMenu.openAt(sceneX, sceneY, false);
    }

    function handleContextMenu(id) {
        var target = contextTarget;
        if (!target) {
            return;
        }
        if (id === "open") {
            if (target.kind === "app") {
                launchApp(target.app);
            } else if (target.kind === "file") {
                openFile(target.file, false);
            } else {
                copyText(target.text);
            }
        } else if (id === "favorite") {
            toggleFavorite(target.app.desktopId);
            focusField();
        } else if (id === "reveal") {
            if (target.kind === "app" && backend) {
                backend.showApplicationLocation(target.app.desktopId);
                closeSpotlight();
            } else if (target.kind === "file") {
                openFile(target.file, true);
            }
        } else if (id === "copy" && target.kind === "file") {
            copyText(target.file.path);
        }
    }

    // --- Couleur du bas de la barre ----------------------------------------------------------
    // Le haut de la barre est toujours noir ; le bas prend la couleur du fond
    // d'écran qui se trouve derrière (assombrie), avec un dégradé entre les deux.
    readonly property int barColorColumns: 24
    // Part de la luminosité du fond d'écran conservée dans la barre.
    readonly property real barColorDepth: 0.6
    readonly property color barFallbackColor: Qt.rgba(0.165, 0.165, 0.222, 1)
    property var barColors: []

    function refreshBarColors() {
        var result = [];
        var info = wallpaperInfo;
        if (colorSampler && info && info.source && Number(info.width) > 0
                && barSurface.width > 0) {
            try {
                var all = colorSampler.sampleColors(String(info.source),
                    Number(info.fillMode), Number(info.width), Number(info.height),
                    barSurface.x, barSurface.y, barSurface.width, barSurface.height,
                    barColorColumns, 2);
                // Deux lignes de cellules : on garde la ligne du bas.
                if (all && all.length >= 2 * barColorColumns) {
                    for (var i = barColorColumns; i < 2 * barColorColumns; ++i) {
                        var c = all[i];
                        result.push(Qt.rgba(c.r * barColorDepth, c.g * barColorDepth,
                            c.b * barColorDepth, 1));
                    }
                }
            } catch (error) {
                result = [];
            }
        }
        barColors = result;
    }

    onWallpaperInfoChanged: Qt.callLater(refreshBarColors)
    onColorSamplerChanged: Qt.callLater(refreshBarColors)

    // --- Flou demandé à KWin ---------------------------------------------------------------
    // Configuration du verre du panneau (voir GlassGpu) : flou, Liquid Glass,
    // teinte et liseré calculés dans le shader.
    // Verre d'origine du Spotlight (réglages « Glass » de l'onglet Spotlight) :
    // il sert à la fenêtre de conversation, et de secours au menu d'applications
    // si le shader du Liquid Glass n'a pas pu être compilé.
    readonly property var legacyGlassCfg: ({
        "fadeMs": 140,
        "source": String(wallpaperInfo.source || ""),
        "fillMode": wallpaperInfo.fillMode === undefined ? 2 : Number(wallpaperInfo.fillMode),
        "screenWidth": Number(wallpaperInfo.width || 0),
        "screenHeight": Number(wallpaperInfo.height || 0),
        "radius": panelRadius,
        "blur": glassBlurPx,
        "refraction": true,
        "thickness": glassThickness,
        "strength": glassStrength,
        "dispersion": glassDispersion,
        "profile": glassProfile,
        "rim": glassRim,
        "ringWidth": borderWidth,
        "ringStrength": borderStrength,
        "tint": panelTint
    })

    // Liquid Glass du menu d'applications (shader glassliquid, porté du dépôt
    // liquidglass-kde-widgets) : flou, réfraction « Snell sur un dôme » sur les
    // bords, indice du verre, franges de couleur, reflet des bords, coins en
    // squircle. Teinte et liseré restent ceux du Spotlight.
    readonly property var panelGlassCfg: Object.assign({}, legacyGlassCfg, {
        "radius": panelRadius,
        "blur": menuBlurPx,
        "liquid": true,
        "roundness": menuRoundness,
        "liquidThickness": menuThickness,
        "liquidScale": menuRefraction,
        "ior": menuIor,
        "chroma": menuChroma,
        "spec": menuSpec
    })

    // Teinte bleu nuit, puis voile noir (glassDarken) : composés en une seule
    // couleur pour le shader.
    readonly property vector4d panelTint: {
        var a = Math.min(1, Math.max(0, glassTint));
        var d = Math.min(1, Math.max(0, glassDarken));
        var outA = 1 - (1 - a) * (1 - d);
        var k = outA > 0.0001 ? a * (1 - d) / outA : 0;
        return Qt.vector4d(0.03 * k, 0.05 * k, 0.11 * k, outA);
    }

    // Fenêtre de conversation : même verre que le panneau, mais plus sombre
    // (presque noir, comme la fenêtre de Siri sur macOS 27).
    readonly property var compactGlassCfg: Object.assign({}, legacyGlassCfg, {
        "radius": compactSurface.radius,
        "tint": Qt.vector4d(0.012, 0.014, 0.026, Math.max(0.78, panelTint.w))
    })

    // La barre de recherche reste opaque : le verre ne dessine que son liseré.
    readonly property var barGlassCfg: ({
        "fadeMs": 140,
        "source": String(wallpaperInfo.source || ""),
        "fillMode": wallpaperInfo.fillMode === undefined ? 2 : Number(wallpaperInfo.fillMode),
        "screenWidth": Number(wallpaperInfo.width || 0),
        "screenHeight": Number(wallpaperInfo.height || 0),
        "radius": barHeight / 2,
        "blur": 6,
        "refraction": true,
        "thickness": 8,
        "strength": 0,
        "dispersion": 0,
        "profile": 1,
        "rim": 0,
        "ringWidth": borderWidth,
        "ringStrength": borderStrength * 0.8,
        "ringOnly": true
    })
    // Fond de la barre : ce qui est derrière (fond d'écran ET fenêtres, en
    // direct) est flouté et assombri ; le noir du haut est posé par-dessus.
    readonly property var barBackdropCfg: Object.assign({}, barGlassCfg, {
        // Flou au maximum, appliqué deux fois : on ne doit plus deviner ce qu'il
        // y a derrière, seulement ses couleurs et ses grandes formes.
        "blur": 64,
        "doubleBlur": true,
        "strength": 0,
        "ringWidth": 0,
        "ringStrength": 0,
        "ringOnly": false,
        "tint": Qt.vector4d(0, 0, 0.004, 0.45)
    })
    readonly property var liveWindows: liveBackdrop ? backdropWindows : []

    // --- Interface ---------------------------------------------------------------------------
    Item {
        id: stage

        anchors.fill: parent

        // Un clic dans la partie transparente referme le Spotlight.
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onPressed: win.closeSpotlight()
        }

        // ---- La barre de recherche ----
        // Fond sombre quasi opaque, sans verre liquide ni flou (comme sur la
        // capture de macOS) : presque noir en haut, un peu plus clair en bas,
        // avec un liseré très fin.
        Rectangle {
            id: barSurface

            radius: win.barHeight / 2
            width: win.barWidth
            height: win.barHeight
            visible: !win.aiView || win.barFadeOpacity > 0.01
            opacity: win.barFadeOpacity
            x: Math.round((win.width - width) / 2)
            y: win.stageTop
            color: "transparent"

            // Fond de la barre : noir en haut, couleur du fond d'écran en bas,
            // dégradé au milieu (comme sur macOS 27). Le tout est découpé aux
            // coins arrondis de la barre.
            Item {
                id: barFill

                anchors.fill: parent
                layer.enabled: true
                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskSource: barFillMask
                    maskThresholdMin: 0.5
                    maskSpreadAtMin: 1.0
                }

                Rectangle {
                    anchors.fill: parent
                    color: Qt.rgba(0, 0, 0.004, 1)
                }

                // Les couleurs du fond d'écran, de gauche à droite (dégradé
                // horizontal entre deux colonnes voisines), sur toute la hauteur.
                Item {
                    id: barTint

                    anchors.fill: parent

                    // Sans couleurs lues : le gris-bleu d'origine.
                    Rectangle {
                        anchors.fill: parent
                        visible: win.barColors.length < 2
                        color: win.barFallbackColor
                    }

                    Repeater {
                        model: win.barColors.length > 1 ? win.barColors.length - 1 : 0

                        delegate: Rectangle {
                            id: tintSlice

                            required property int index

                            readonly property real sliceWidth: barTint.width / (win.barColors.length - 1)

                            x: index * sliceWidth
                            width: sliceWidth + 1
                            height: barTint.height
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0.0; color: win.barColors[tintSlice.index] }
                                GradientStop { position: 1.0; color: win.barColors[tintSlice.index + 1] }
                            }
                        }
                    }
                }

                // Le noir du haut, posé PAR-DESSUS les couleurs : noir plein dans
                // le quart du haut, puis il s'efface jusqu'au bas de la barre,
                // où la couleur du fond d'écran est entière.
                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        GradientStop { position: 0.00; color: Qt.rgba(0, 0, 0.004, 1) }
                        GradientStop { position: 0.25; color: Qt.rgba(0, 0, 0.004, 1) }
                        GradientStop { position: 0.95; color: Qt.rgba(0, 0, 0.004, 0) }
                    }
                }
            }

            // Masque des coins arrondis.
            Item {
                id: barFillMask

                visible: false
                layer.enabled: true
                width: parent.width
                height: parent.height

                Rectangle {
                    anchors.fill: parent
                    radius: win.barHeight / 2
                    color: "black"
                }
            }

            // Fond en verre : le flou de ce qui se trouve derrière la barre, fond
            // d'écran et fenêtres (capturées en direct : une fenêtre qui passe
            // derrière change la couleur du bas de la barre).
            GlassLayer {
                id: barBackdrop

                anchors.fill: parent
                windows: win.liveWindows
                originX: barSurface.x
                originY: barSurface.y
                Component.onCompleted: configure(win.barBackdropCfg)

                Connections {
                    target: win
                    function onBarBackdropCfgChanged() {
                        barBackdrop.configure(win.barBackdropCfg);
                    }
                }
            }

            // Le noir du haut, par-dessus le verre : noir plein sur le quart du
            // haut, puis il s'efface vers le bas, où le fond reste assombri.
            Rectangle {
                anchors.fill: parent
                radius: win.barHeight / 2
                gradient: Gradient {
                    GradientStop { position: 0.00; color: Qt.rgba(0, 0, 0.004, 1) }
                    GradientStop { position: 0.25; color: Qt.rgba(0, 0, 0.004, 1) }
                    GradientStop { position: 0.95; color: Qt.rgba(0, 0, 0.004, 0.15) }
                }
            }

            // Liseré fin : chaque point prend la couleur de ce qui est derrière
            // la barre (fond d'écran ou fenêtre), en direct.
            GlassLayer {
                id: barGlass

                anchors.fill: parent
                windows: win.liveWindows
                originX: barSurface.x
                originY: barSurface.y
                Component.onCompleted: configure(win.barGlassCfg)

                Connections {
                    target: win
                    function onBarGlassCfgChanged() {
                        barGlass.configure(win.barGlassCfg);
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
            }

            // Bouton de mode : Applications, Fichiers, Presse-papiers.
            Item {
                id: modeButton

                x: 13
                anchors.verticalCenter: parent.verticalCenter
                width: 47
                height: 47
                // Pendant la recherche d'une application, le bouton de mode
                // s'efface (comme sur macOS 27) : le texte passe à gauche.
                opacity: win.appSearch ? 0 : 1
                visible: opacity > 0.01
                enabled: !win.appSearch

                Behavior on opacity {
                    NumberAnimation { duration: 110 }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: Qt.rgba(1, 1, 1, 0.12)
                    opacity: modeHover.hovered ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation { duration: 100 }
                    }
                }

                SpotlightGlyph {
                    anchors.centerIn: parent
                    kind: win.mode === 1 ? "apps" : (win.mode === 2 ? "files" : "clipboard")
                    size: 28
                    lineWidth: 1.9
                    color: Qt.rgba(1, 1, 1, 0.66)
                }

                HoverHandler {
                    id: modeHover

                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    // Un double clic (deux taps rapprochés) revient aux applications.
                    onTapped: {
                        if (tapCount >= 2) {
                            win.setMode(1);
                        } else {
                            win.setMode(win.mode >= 3 ? 1 : win.mode + 1);
                        }
                    }
                }
            }

            // Clignotement du curseur (le clignotement de Qt est coupé sur
            // Wayland/Plasma) : allumé en continu pendant la frappe.
            property bool caretLit: true

            Timer {
                id: blinkTimer

                interval: 530
                repeat: true
                running: field.activeFocus && win.visible
                onRunningChanged: barSurface.caretLit = true
                onTriggered: barSurface.caretLit = !barSurface.caretLit
            }

            Connections {
                target: field
                function onTextChanged() {
                    barSurface.caretLit = true;
                    blinkTimer.restart();
                }
                function onCursorPositionChanged() {
                    barSurface.caretLit = true;
                    blinkTimer.restart();
                }
            }

            // Lueur du curseur : floutée, sans bords, des deux côtés du trait
            // (cyan en haut, orange en bas). Hors du champ pour ne pas être
            // coupée à gauche.
            Item {
                id: caretGlow

                readonly property real caretX: field.x + field.cursorRectangle.x + 1
                x: caretX - 14
                y: field.y + field.cursorRectangle.y - 8
                width: 28
                height: field.cursorRectangle.height + 16
                visible: field.activeFocus && field.cursorRectangle.x >= -1
                    && field.cursorRectangle.x <= field.width
                opacity: barSurface.caretLit ? 1 : 0
                layer.enabled: true
                layer.effect: MultiEffect {
                    blurEnabled: true
                    blur: 0.3
                    blurMax: 16
                }

                Behavior on opacity {
                    NumberAnimation { duration: 120 }
                }

                // Trait fin (comme le curseur) : c'est son flou qui fait la
                // petite lueur autour du trait blanc.
                Rectangle {
                    x: 13
                    y: 7
                    width: 3
                    height: parent.height - 14
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Qt.rgba(0.45, 0.88, 1.0, 1.0) }
                        GradientStop { position: 0.5; color: Qt.rgba(1.0, 1.0, 1.0, 0.8) }
                        GradientStop { position: 1.0; color: Qt.rgba(1.0, 0.62, 0.25, 1.0) }
                    }
                }
            }

            TextInput {
                id: field

                x: win.appSearch ? 33 : 70
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - x - 63
                color: "white"

                Behavior on x {
                    NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                }
                cursorDelegate: Item {
                    id: caret

                    // Le trait seul : la lueur est dessinée à part (caretGlow),
                    // car le champ coupe tout ce qui dépasse de son cadre, donc
                    // la lueur de gauche disparaissait au début du texte.
                    width: 2
                    opacity: barSurface.caretLit ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation { duration: 120 }
                    }

                    // Blanc, très légèrement chaud vers le bas.
                    Rectangle {
                        anchors.fill: parent
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "#FFFFFF" }
                            GradientStop { position: 0.7; color: "#FFFFFF" }
                            GradientStop { position: 1.0; color: "#FFE9CC" }
                        }
                    }
                }
                selectionColor: Qt.rgba(1, 1, 1, 0.3)
                selectedTextColor: "white"
                font.pixelSize: 24
                clip: true
                inputMethodHints: Qt.ImhNoPredictiveText
                onTextChanged: {
                    if (text !== win.query) {
                        win.query = text;
                    }
                }

                Text {
                    visible: field.text.length === 0 && field.preeditText.length === 0
                    text: win.placeholder
                    font: field.font
                    color: Qt.rgba(1, 1, 1, 0.58)
                }

                Keys.onPressed: function (event) {
                    var control = (event.modifiers & Qt.ControlModifier) !== 0;
                    if (moreMenu.opened || contextMenu.opened) {
                        if (event.key === Qt.Key_Escape) {
                            moreMenu.close();
                            contextMenu.close();
                        }
                        event.accepted = true;
                        return;
                    }
                    if (event.key === Qt.Key_Escape) {
                        if (win.query.length > 0) {
                            win.query = "";
                        } else {
                            win.closeSpotlight();
                        }
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        win.activateSelected(control);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Down || event.key === Qt.Key_Up) {
                        var step = event.key === Qt.Key_Down ? 1 : -1;
                        if (win.gridMode) {
                            win.gridMove(step, 0);
                        } else {
                            win.moveSelection(step);
                        }
                        event.accepted = true;
                    } else if ((event.key === Qt.Key_Left || event.key === Qt.Key_Right)
                            && win.gridMode) {
                        win.gridMove(0, event.key === Qt.Key_Right ? 1 : -1);
                        event.accepted = true;
                    } else if (control && event.key >= Qt.Key_1 && event.key <= Qt.Key_3) {
                        win.setMode(event.key - Qt.Key_0);
                        event.accepted = true;
                    } else if (control && event.key === Qt.Key_R) {
                        if (win.selectedIndex >= 0 && win.results[win.selectedIndex]
                                && win.results[win.selectedIndex].kind === "file") {
                            win.openFile(win.results[win.selectedIndex].file, true);
                        }
                        event.accepted = true;
                    }
                }
            }

            // « — Ouvrir » après le texte saisi quand le premier résultat est
            // une application (comme sur macOS 27).
            Text {
                visible: win.selectedApp !== null && field.preeditText.length === 0
                    && field.contentWidth + 120 < field.width
                x: field.x + field.contentWidth + 6
                anchors.verticalCenter: parent.verticalCenter
                text: "— " + i18n("Open")
                font.pixelSize: 24
                color: Qt.rgba(1, 1, 1, 0.5)
            }

            // Icône de l'application sélectionnée, à la place du bouton « … ».
            Item {
                id: appBadge

                visible: win.selectedApp !== null
                anchors.right: parent.right
                anchors.rightMargin: 17
                anchors.verticalCenter: parent.verticalCenter
                width: 49
                height: 49

                Kirigami.Icon {
                    anchors.fill: parent
                    source: win.selectedApp ? win.selectedApp.icon : ""
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: win.launchApp(win.selectedApp)
                }
            }

            // Bouton « … » : les mêmes réglages que le Spotlight de macOS.
            Item {
                id: moreButton

                visible: win.selectedApp === null
                anchors.right: parent.right
                anchors.rightMargin: 15
                anchors.verticalCenter: parent.verticalCenter
                width: 43
                height: 43

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: Qt.rgba(1, 1, 1, 0.12)
                    opacity: moreHover.hovered || moreMenu.opened ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation { duration: 100 }
                    }
                }

                Row {
                    anchors.centerIn: parent
                    spacing: 4

                    Repeater {
                        model: 3

                        delegate: Rectangle {
                            width: 5
                            height: 5
                            radius: 2.5
                            color: Qt.rgba(1, 1, 1, 0.7)
                        }
                    }
                }

                HoverHandler {
                    id: moreHover

                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    onTapped: {
                        if (moreMenu.opened) {
                            moreMenu.close();
                        } else {
                            win.openMoreMenu();
                        }
                    }
                }
            }
        }

        // ---- Le panneau de résultats ----
        Item {
            id: panelSurface

            // Rayon des coins (le verre et le masque de la grille l'utilisent).
            readonly property real radius: win.panelRadius
            width: win.appSearch ? win.barWidth : win.panelWidth
            height: win.panelTargetHeight
            visible: height > 1 && !win.aiView
            x: Math.round((win.width - width) / 2)
            y: barSurface.y + barSurface.height + win.stageGap

            Behavior on height {
                NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
            }

            Behavior on width {
                NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
            }

            // Teinte de secours : avant que le verre soit prêt, ou si le chemin
            // GPU est indisponible (shader non compilé).
            Rectangle {
                anchors.fill: parent
                radius: panelSurface.radius
                color: Qt.rgba(0.03, 0.05, 0.11, Math.min(1, win.glassTint + 0.25))
                visible: panelGlass.gpuBroken || !panelGlass.ready
            }

            // Le verre du Spotlight : fond d'écran et fenêtres derrière, floutés
            // et déformés sur les bords, teinte et liseré compris.
            GlassLayer {
                id: panelGlass

                anchors.fill: parent
                windows: win.liveWindows
                originX: panelSurface.x
                originY: panelSurface.y
                // Le reflet de coin suit le curseur (comme dans les widgets
                // Liquid Glass).
                mouseU: panelHover.hovered
                    ? Math.max(0, Math.min(1, panelHover.point.position.x
                        / Math.max(1, panelSurface.width))) : -1
                mouseV: panelHover.hovered
                    ? Math.max(0, Math.min(1, panelHover.point.position.y
                        / Math.max(1, panelSurface.height))) : -1
                Component.onCompleted: configure(win.panelGlassCfg)

                Connections {
                    target: win
                    function onPanelGlassCfgChanged() {
                        panelGlass.configure(win.panelGlassCfg);
                    }
                }
            }

            HoverHandler {
                id: panelHover
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
            }

            // Pastilles de catégories (étoile des favoris en premier).
            Flickable {
                id: pillsArea

                visible: win.gridMode
                x: 14
                y: 14
                width: parent.width - 28
                height: 30
                clip: true
                contentWidth: pillsRow.width
                contentHeight: 30
                flickableDirection: Flickable.HorizontalFlick
                boundsBehavior: Flickable.StopAtBounds

                // Fait apparaître une pastille entière.
                function reveal(item) {
                    var maxX = Math.max(0, contentWidth - width);
                    if (item.x < contentX) {
                        contentX = Math.max(0, item.x - 6);
                    } else if (item.x + item.width > contentX + width) {
                        contentX = Math.min(maxX, item.x + item.width - width + 6);
                    }
                }

                // Molette de la souris (verticale) ou du pavé tactile : défile
                // les catégories sur le côté.
                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: (event) => {
                        var delta = event.angleDelta.x !== 0
                            ? event.angleDelta.x : event.angleDelta.y;
                        var maxX = Math.max(0, pillsArea.contentWidth - pillsArea.width);
                        pillsArea.contentX = Math.min(maxX,
                            Math.max(0, pillsArea.contentX - delta));
                    }
                }

                Row {
                    id: pillsRow

                    spacing: 6

                    Repeater {
                        model: win.sections

                        delegate: Rectangle {
                            id: pill

                            required property var modelData
                            required property int index

                            readonly property bool isFavorites: modelData.id === "favorites"
                            readonly property bool active:
                                win.sectionAtOffset(appsList.contentY) === index

                            height: 30
                            width: isFavorites ? 38 : pillLabel.implicitWidth + 24
                            radius: 15
                            color: active ? Qt.rgba(1, 1, 1, 0.22)
                                : (pillMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.14)
                                    : Qt.rgba(1, 1, 1, 0.07))

                            Behavior on color {
                                ColorAnimation { duration: 100 }
                            }

                            onActiveChanged: {
                                if (active) {
                                    pillsArea.reveal(pill);
                                }
                            }

                            SpotlightGlyph {
                                visible: pill.isFavorites
                                anchors.centerIn: parent
                                kind: "star"
                                size: 16
                                filled: pill.active
                                lineWidth: 1.7
                                color: Qt.rgba(1, 1, 1, pill.active ? 0.95 : 0.7)
                            }

                            Text {
                                id: pillLabel

                                visible: !pill.isFavorites
                                anchors.centerIn: parent
                                text: pill.modelData.title
                                font.pixelSize: 14
                                color: Qt.rgba(1, 1, 1, pill.active ? 0.95 : 0.7)
                            }

                            MouseArea {
                                id: pillMouse

                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    win.scrollToSection(pill.index);
                                    win.focusField();
                                }
                            }
                        }
                    }
                }
            }

            // Grille des applications, par catégorie. Aucune marge en bas : les
            // applications sont coupées net par la bordure arrondie du panneau
            // (masque aux mêmes coins que le panneau).
            Item {
                id: appsClip

                visible: win.gridMode
                x: 0
                y: 54
                width: parent.width
                height: parent.height - 54
                layer.enabled: true
                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskSource: appsMask
                    maskThresholdMin: 0.5
                    maskSpreadAtMin: 1.0
                }

            // Flickable (et non ListView) : la hauteur totale est connue d'avance
            // (voir sectionHeight). Un ListView l'estimait au fil du défilement :
            // la poignée grossissait et, en revenant, un grand vide apparaissait
            // en haut de la liste.
            Flickable {
                id: appsList

                x: 12
                y: 0
                width: parent.width - 24
                height: parent.height
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                flickableDirection: Flickable.VerticalFlick
                contentWidth: width
                contentHeight: win.sectionOffset(win.sections.length)
                onContentHeightChanged: returnToBounds()

                NumberAnimation {
                    id: scrollAnimation

                    target: appsList
                    property: "contentY"
                    duration: 240
                    easing.type: Easing.OutCubic
                }

                Column {
                    width: appsList.width

                Repeater {
                    model: win.sections

                delegate: Item {
                    id: sectionItem

                    required property var modelData
                    required property int index

                    width: appsList.width
                    height: win.sectionHeight(modelData)

                    Rectangle {
                        visible: sectionItem.index > 0
                        x: 8
                        width: parent.width - 16
                        height: 1
                        color: Qt.rgba(1, 1, 1, 0.12)
                    }

                    Text {
                        visible: sectionItem.modelData.apps.length === 0
                        anchors.centerIn: parent
                        width: parent.width - 60
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        text: i18n("No favorites yet. Right-click an app, then “Add to Favorites”.")
                        font.pixelSize: 13
                        color: Qt.rgba(1, 1, 1, 0.5)
                    }

                    Grid {
                        x: Math.round((parent.width - win.columns * win.cellWidth) / 2)
                        y: 8
                        columns: win.columns

                        Repeater {
                            model: sectionItem.modelData.apps

                            delegate: Item {
                                id: cell

                                required property var modelData
                                required property int index

                                readonly property bool current:
                                    win.gridSection === sectionItem.index && win.gridIndex === index

                                width: win.cellWidth
                                height: win.cellHeight

                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: 3
                                    radius: 16
                                    color: cell.current ? Qt.rgba(1, 1, 1, 0.18)
                                        : (cellMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent")
                                }

                                Kirigami.Icon {
                                    x: Math.round((parent.width - width) / 2)
                                    y: 8
                                    width: win.iconSize
                                    height: win.iconSize
                                    source: cell.modelData.icon
                                }

                                Text {
                                    x: 4
                                    y: 8 + win.iconSize + 7
                                    width: parent.width - 8
                                    height: 20
                                    horizontalAlignment: Text.AlignHCenter
                                    elide: Text.ElideRight
                                    text: cell.modelData.name
                                    font.pixelSize: 13
                                    color: Qt.rgba(1, 1, 1, 0.92)
                                }

                                MouseArea {
                                    id: cellMouse

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    onClicked: function (mouse) {
                                        if (mouse.button === Qt.RightButton) {
                                            win.gridSection = sectionItem.index;
                                            win.gridIndex = cell.index;
                                            var point = cell.mapToItem(null, mouse.x, mouse.y);
                                            win.openContextMenu({ "kind": "app", "app": cell.modelData },
                                                point.x, point.y);
                                        } else {
                                            win.launchApp(cell.modelData);
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                }
                }
            }

            }

            // Trait de séparation sous les catégories (comme sur macOS) : les
            // applications défilent dessous et sont coupées net à cet endroit.
            Rectangle {
                visible: win.gridMode
                x: 18
                y: appsClip.y
                width: panelSurface.width - 36
                height: 1
                color: Qt.rgba(1, 1, 1, 0.17)
            }

            // Masque de la grille : mêmes coins arrondis que le panneau.
            Item {
                id: appsMask

                visible: false
                layer.enabled: true
                x: 0
                y: appsClip.y
                width: appsClip.width
                height: appsClip.height

                Rectangle {
                    x: 0
                    y: -appsClip.y
                    width: parent.width
                    height: panelSurface.height
                    radius: panelSurface.radius
                    color: "black"
                }
            }

            // Barre de défilement : un rail sombre collé au bord droit du panneau
            // et une poignée grise, comme sur la capture.
            Item {
                id: scrollRail

                visible: win.gridMode && appsList.visibleArea.heightRatio < 0.995
                anchors.right: parent.right
                anchors.rightMargin: 5
                y: appsClip.y + 4
                width: 12
                height: appsClip.height - 4 - 24

                Rectangle {
                    anchors.fill: parent
                    radius: 6
                    color: Qt.rgba(0, 0, 0, 0.28)
                }

                Rectangle {
                    x: 2
                    width: 8
                    radius: 4
                    // visibleArea tient compte des hauteurs estimées de la liste
                    // (la poignée ne grossit plus en défilant) ; tout est borné
                    // pour que la poignée reste dans le rail.
                    height: Math.min(parent.height, Math.max(36,
                        parent.height * appsList.visibleArea.heightRatio))
                    y: (parent.height - height) * Math.min(1, Math.max(0,
                        appsList.visibleArea.yPosition
                        / Math.max(0.0001, 1 - appsList.visibleArea.heightRatio)))
                    color: Qt.rgba(1, 1, 1, 0.42)
                }
            }

            // Liste de résultats (recherche, fichiers, presse-papiers).
            ListView {
                id: resultsList

                visible: !win.gridMode && !win.aiView
                x: 8
                y: 8
                width: parent.width - 16
                // Contenu = n x rowHeight (4 px sous chaque gélule) : 8 px en
                // haut, 8 px en bas sous la dernière gélule.
                height: parent.height - 12
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: win.results

                delegate: Item {
                    id: resultRow

                    required property var modelData
                    required property int index

                    readonly property string kind: modelData.kind
                    readonly property bool selected: win.selectedIndex === index
                    readonly property bool hovered: rowMouse.containsMouse

                    width: resultsList.width
                    height: kind === "header" ? 28 : (kind === "info" ? 46 : win.rowHeight)

                    // Sélection : une gélule de 48 px, à 8 px du bord du panneau.
                    // Son rayon (24) est celui du panneau (32) moins cette
                    // marge : les deux contours sont concentriques.
                    Rectangle {
                        visible: resultRow.kind !== "header" && resultRow.kind !== "info"
                        anchors.fill: parent
                        anchors.bottomMargin: 4
                        radius: height / 2
                        color: resultRow.selected ? Qt.rgba(1, 1, 1, 0.18)
                            : (resultRow.hovered ? Qt.rgba(1, 1, 1, 0.09) : "transparent")
                    }

                    Text {
                        visible: resultRow.kind === "header"
                        x: 14
                        anchors.verticalCenter: parent.verticalCenter
                        text: resultRow.modelData.text || ""
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        color: Qt.rgba(1, 1, 1, 0.5)
                    }

                    Text {
                        visible: resultRow.kind === "info"
                        anchors.centerIn: parent
                        width: parent.width - 40
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: resultRow.modelData.text || ""
                        font.pixelSize: 14
                        color: Qt.rgba(1, 1, 1, 0.5)
                    }

                    // Application
                    Row {
                        visible: resultRow.kind === "app"
                        x: 14
                        y: Math.round((win.rowHeight - 4 - height) / 2)
                        spacing: 13

                        Kirigami.Icon {
                            width: 37
                            height: 37
                            source: resultRow.kind === "app" ? resultRow.modelData.app.icon : ""
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            Text {
                                text: resultRow.kind === "app" ? resultRow.modelData.app.name : ""
                                font.pixelSize: 16
                                color: "white"
                            }
                            Text {
                                visible: text.length > 0
                                text: resultRow.kind === "app" ? resultRow.modelData.app.genericName : ""
                                font.pixelSize: 13
                                color: Qt.rgba(1, 1, 1, 0.5)
                            }
                        }
                    }

                    // Fichier
                    Row {
                        visible: resultRow.kind === "file"
                        x: 12
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 12

                        Kirigami.Icon {
                            width: 34
                            height: 34
                            source: resultRow.kind === "file" ? resultRow.modelData.file.icon : ""
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: resultRow.width - 80

                            Text {
                                width: parent.width
                                elide: Text.ElideMiddle
                                text: resultRow.kind === "file" ? resultRow.modelData.file.name : ""
                                font.pixelSize: 15
                                color: "white"
                            }
                            Text {
                                width: parent.width
                                elide: Text.ElideMiddle
                                text: resultRow.kind === "file" ? resultRow.modelData.file.directory : ""
                                font.pixelSize: 12
                                color: Qt.rgba(1, 1, 1, 0.5)
                            }
                        }
                    }

                    // Presse-papiers
                    Row {
                        visible: resultRow.kind === "clip"
                        x: 14
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 12

                        SpotlightGlyph {
                            anchors.verticalCenter: parent.verticalCenter
                            kind: "clipboard"
                            size: 22
                            color: Qt.rgba(1, 1, 1, 0.6)
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: resultRow.width - 70
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            text: resultRow.kind === "clip"
                                ? resultRow.modelData.text.replace(/\s+/g, " ").trim() : ""
                            font.pixelSize: 15
                            color: "white"
                        }
                    }

                    // Calculatrice
                    Row {
                        visible: resultRow.kind === "calc"
                        x: 16
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 10

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: resultRow.kind === "calc" ? resultRow.modelData.text + " =" : ""
                            font.pixelSize: 15
                            color: Qt.rgba(1, 1, 1, 0.6)
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: resultRow.kind === "calc" ? resultRow.modelData.value : ""
                            font.pixelSize: 22
                            font.weight: Font.DemiBold
                            color: "white"
                        }
                    }

                    // Demander à l'assistant (sans logo)
                    Column {
                        visible: resultRow.kind === "ai"
                        x: 22
                        y: Math.round((win.rowHeight - 4 - height) / 2)
                        width: resultRow.width - 44

                        Text {
                            text: win.chat ? i18n("Ask %1", win.chat.providerName(win.chat.activeProvider)) : ""
                            font.pixelSize: 16
                            color: "white"
                        }
                        Text {
                            width: parent.width
                            elide: Text.ElideRight
                            text: resultRow.kind === "ai" ? resultRow.modelData.text : ""
                            font.pixelSize: 12
                            color: Qt.rgba(1, 1, 1, 0.5)
                        }
                    }

                    MouseArea {
                        id: rowMouse

                        anchors.fill: parent
                        enabled: resultRow.kind !== "header" && resultRow.kind !== "info"
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: function (mouse) {
                            if (mouse.button === Qt.RightButton) {
                                var point = resultRow.mapToItem(null, mouse.x, mouse.y);
                                var entry = resultRow.modelData;
                                if (entry.kind === "app") {
                                    win.openContextMenu({ "kind": "app", "app": entry.app }, point.x, point.y);
                                } else if (entry.kind === "file") {
                                    win.openContextMenu({ "kind": "file", "file": entry.file }, point.x, point.y);
                                } else if (entry.kind === "clip") {
                                    win.openContextMenu({ "kind": "clip", "text": entry.text }, point.x, point.y);
                                }
                            } else {
                                win.activateEntry(resultRow.modelData, false);
                            }
                        }
                    }
                }
            }
        }

        // ---- La conversation avec l'assistant ----
        // Quand une question part vers l'IA, la barre et le panneau se
        // transforment en cette fenêtre verticale (comme Siri sur macOS 27) :
        // bouton de fermeture en haut à gauche, bouton d'agrandissement en
        // haut à droite, la conversation, puis la zone de saisie en bas.
        // On la déplace en la glissant par son en-tête (double clic : retour à
        // la place d'origine) et on la redimensionne par ses bords et ses coins.
        Item {
            id: compactSurface

            readonly property real minWidth: 320
            readonly property real minHeight: 300
            // Taille et place de la fenêtre une fois la transformation finie.
            readonly property real finalWidth: win.compactUserWidth > 0
                ? win.compactUserWidth : win.compactWidth
            readonly property real finalHeight: win.compactUserHeight > 0
                ? win.compactUserHeight : win.compactHeight
            readonly property real finalX: win.compactUserX >= 0
                ? Math.max(0, Math.min(win.compactUserX, win.width - finalWidth))
                : Math.round((win.width - finalWidth) / 2)
            readonly property real finalY: win.compactUserY >= 0
                ? Math.max(0, Math.min(win.compactUserY, win.height - finalHeight))
                : win.stageTop
            // Pendant la transformation, la fenêtre part de la barre (même
            // taille, centrée au même endroit) et rejoint sa taille finale.
            readonly property real morph: win.compactMorph
            readonly property real radius: win.barHeight / 2
                + (win.compactRadius - win.barHeight / 2)
                * Math.max(0, Math.min(1, morph))
            width: win.barWidth + (finalWidth - win.barWidth) * morph
            height: win.barHeight + (finalHeight - win.barHeight) * morph
            visible: win.aiView
            x: finalX + (finalWidth - width) / 2
            y: finalY

            // Teinte de secours : avant que le verre soit prêt.
            Rectangle {
                anchors.fill: parent
                radius: compactSurface.radius
                color: Qt.rgba(0.02, 0.022, 0.035, 0.92)
                visible: compactGlass.gpuBroken || !compactGlass.ready
            }

            GlassLayer {
                id: compactGlass

                anchors.fill: parent
                windows: win.liveWindows
                originX: compactSurface.x
                originY: compactSurface.y
                Component.onCompleted: configure(win.compactGlassCfg)

                Connections {
                    target: win
                    function onCompactGlassCfgChanged() {
                        compactGlass.configure(win.compactGlassCfg);
                    }
                }
            }

            // Zone sombre de la fenêtre : un noir en diagonale, le plus profond
            // dans le coin haut gauche (noir plein sur le haut), qui s'éclaircit
            // vers le bas et vers la droite ; le reste est le verre. Le dégradé
            // est incliné de 24 degrés : à gauche le noir descend environ deux
            // fois plus bas qu'à droite. Découpé aux coins arrondis.
            Item {
                id: darkLayer

                readonly property real angle: 24
                // Longueur du dégradé : de l'angle haut gauche à l'angle bas droit.
                readonly property real axisLength:
                    Math.sin(angle * Math.PI / 180) * width
                    + Math.cos(angle * Math.PI / 180) * height

                anchors.fill: parent
                clip: true
                layer.enabled: true
                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskSource: compactShapeMask
                    maskThresholdMin: 0.5
                    maskSpreadAtMin: 1.0
                }

                Rectangle {
                    width: darkLayer.width + darkLayer.height
                    height: darkLayer.axisLength
                    x: (darkLayer.width - width) / 2
                    y: (darkLayer.height - height) / 2
                    rotation: -darkLayer.angle
                    gradient: Gradient {
                        GradientStop { position: 0.00; color: Qt.rgba(0, 0, 0, 1) }
                        GradientStop { position: 0.16; color: Qt.rgba(0, 0, 0, 1) }
                        GradientStop { position: 0.60; color: Qt.rgba(0, 0, 0, 0) }
                    }
                }
            }

            // Masque des coins arrondis de la fenêtre.
            Item {
                id: compactShapeMask

                visible: false
                layer.enabled: true
                width: parent.width
                height: parent.height

                Rectangle {
                    anchors.fill: parent
                    radius: compactSurface.radius
                    color: "black"
                }
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
            }

            // En-tête : on glisse la fenêtre par là.
            MouseArea {
                id: dragArea

                property real startX: 0
                property real startY: 0
                property real originX: 0
                property real originY: 0

                x: 0
                y: 0
                width: parent.width
                height: 66
                acceptedButtons: Qt.LeftButton
                cursorShape: pressed ? Qt.ClosedHandCursor : Qt.ArrowCursor
                onPressed: function (mouse) {
                    var point = mapToItem(stage, mouse.x, mouse.y);
                    startX = point.x;
                    startY = point.y;
                    originX = compactSurface.x;
                    originY = compactSurface.y;
                }
                onPositionChanged: function (mouse) {
                    if (!pressed) {
                        return;
                    }
                    var point = mapToItem(stage, mouse.x, mouse.y);
                    win.compactUserX = Math.max(0, Math.min(originX + point.x - startX,
                        win.width - compactSurface.width));
                    win.compactUserY = Math.max(0, Math.min(originY + point.y - startY,
                        win.height - compactSurface.height));
                }
                onDoubleClicked: win.resetCompactGeometry()
            }

            // Fermer.
            Rectangle {
                id: closeButton

                opacity: win.compactContentOpacity
                x: 16
                y: 16
                width: 38
                height: 38
                radius: 19
                color: Qt.rgba(1, 1, 1, closeMouse.containsMouse ? 0.26 : 0.16)

                SpotlightGlyph {
                    anchors.centerIn: parent
                    kind: "close"
                    size: 15
                    lineWidth: 2.2
                    color: "white"
                }

                MouseArea {
                    id: closeMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: win.closeSpotlight()
                }
            }

            // Ouvrir la conversation dans l'application Siri IA.
            Rectangle {
                visible: win.assistantEnabled
                opacity: win.compactContentOpacity
                x: parent.width - width - 16
                y: 16
                width: 38
                height: 38
                radius: 19
                color: Qt.rgba(1, 1, 1, expandMouse.containsMouse ? 0.26 : 0.16)

                SpotlightGlyph {
                    anchors.centerIn: parent
                    kind: "expand"
                    size: 16
                    lineWidth: 2
                    color: "white"
                }

                MouseArea {
                    id: expandMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: win.expandToAssistant()
                }
            }

            ChatTranscript {
                opacity: win.compactContentOpacity
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: attachStrip.top
                anchors.topMargin: 66
                anchors.leftMargin: 18
                anchors.rightMargin: 18
                anchors.bottomMargin: 8
                compact: true
                userColor: Qt.rgba(1, 1, 1, 0.16)
                emptyText: i18n("How can I help?")
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

            // Fichiers joints (pastilles) et message éventuel.
            Flow {
                id: attachStrip

                opacity: win.compactContentOpacity
                readonly property bool shown: (!!win.chat && win.chat.attachments.length > 0)
                    || win.attachNotice.length > 0

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: inputRow.top
                anchors.leftMargin: 20
                anchors.rightMargin: 20
                anchors.bottomMargin: shown ? 8 : 0
                height: shown ? implicitHeight : 0
                visible: shown
                spacing: 6

                Repeater {
                    model: win.chat ? win.chat.attachments : []

                    delegate: Rectangle {
                        id: chip

                        required property var modelData
                        required property int index

                        height: 26
                        width: chipContent.implicitWidth + 22
                        radius: 13
                        color: Qt.rgba(1, 1, 1, 0.16)

                        Row {
                            id: chipContent

                            anchors.centerIn: parent
                            spacing: 6

                            SpotlightGlyph {
                                anchors.verticalCenter: parent.verticalCenter
                                kind: chip.modelData.isDir ? "folder" : "files"
                                size: 14
                                lineWidth: 1.8
                                color: Qt.rgba(1, 1, 1, 0.78)
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: Math.min(implicitWidth, 150)
                                elide: Text.ElideMiddle
                                text: chip.modelData.name
                                font.pixelSize: 12
                                color: Qt.rgba(1, 1, 1, 0.9)
                            }

                            SpotlightGlyph {
                                anchors.verticalCenter: parent.verticalCenter
                                kind: "close"
                                size: 11
                                lineWidth: 2.2
                                color: removeMouse.containsMouse ? "white" : Qt.rgba(1, 1, 1, 0.5)

                                MouseArea {
                                    id: removeMouse

                                    anchors.fill: parent
                                    anchors.margins: -5
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (win.chat) {
                                            win.chat.removeAttachment(chip.index);
                                        }
                                    }
                                }
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
                    color: "#FFB454"
                }
            }

            // Zone de saisie : « + » (joindre des fichiers), champ « Ask Siri »,
            // envoi / arrêt.
            Item {
                id: inputRow

                opacity: win.compactContentOpacity
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                anchors.bottomMargin: 14
                height: 48

                // Clic : ajouter des fichiers. Clic droit : fournisseur d'IA,
                // nouvelle conversation, Siri IA, réglages.
                Rectangle {
                    id: plusButton

                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: 44
                    height: 44
                    radius: 22
                    color: Qt.rgba(1, 1, 1, plusMouse.containsMouse || moreMenu.opened ? 0.24 : 0.14)

                    SpotlightGlyph {
                        anchors.centerIn: parent
                        kind: "plus"
                        size: 20
                        lineWidth: 2
                        color: "white"
                    }

                    MouseArea {
                        id: plusMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: function (mouse) {
                            if (mouse.button === Qt.RightButton) {
                                if (moreMenu.opened) {
                                    moreMenu.close();
                                } else {
                                    win.openAiMenu();
                                }
                            } else {
                                win.pickFiles();
                            }
                        }
                    }
                }

                Rectangle {
                    id: aiInputPill

                    anchors.left: plusButton.right
                    anchors.right: parent.right
                    anchors.leftMargin: 8
                    anchors.rightMargin: sendButton.visible ? sendButton.width + 8 : 0
                    anchors.verticalCenter: parent.verticalCenter
                    height: 44
                    radius: 22
                    color: Qt.rgba(1, 1, 1, 0.12)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, aiField.activeFocus ? 0.22 : 0.1)

                    TextInput {
                        id: aiField

                        x: 18
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 36
                        color: "white"
                        selectionColor: Qt.rgba(1, 1, 1, 0.3)
                        selectedTextColor: "white"
                        font.pixelSize: 16
                        clip: true
                        inputMethodHints: Qt.ImhNoPredictiveText
                        onTextChanged: {
                            if (text !== win.query) {
                                win.query = text;
                            }
                        }

                        Text {
                            visible: aiField.text.length === 0 && aiField.preeditText.length === 0
                            text: i18n("Ask Siri AI…")
                            font: aiField.font
                            color: Qt.rgba(1, 1, 1, 0.5)
                        }

                        Keys.onPressed: function (event) {
                            if (moreMenu.opened || contextMenu.opened) {
                                if (event.key === Qt.Key_Escape) {
                                    moreMenu.close();
                                    contextMenu.close();
                                }
                                event.accepted = true;
                                return;
                            }
                            if (event.key === Qt.Key_Escape) {
                                if (win.query.length > 0) {
                                    win.query = "";
                                } else {
                                    win.closeSpotlight();
                                }
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                win.askAi(win.query);
                                event.accepted = true;
                            }
                        }
                    }
                }

                // Flèche d'envoi pendant la saisie ; carré d'arrêt pendant que
                // l'assistant répond ; absent le reste du temps (pas de micro).
                Rectangle {
                    id: sendButton

                    readonly property bool busy: win.chat ? win.chat.currentBusy : false
                    readonly property bool typing: win.query.trim().length > 0

                    visible: busy || typing
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 44
                    height: 44
                    radius: 22
                    color: win.accent

                    SpotlightGlyph {
                        visible: !sendButton.busy
                        anchors.centerIn: parent
                        kind: "send"
                        size: 20
                        lineWidth: 2.2
                        color: "white"
                    }

                    Rectangle {
                        visible: sendButton.busy
                        anchors.centerIn: parent
                        width: 13
                        height: 13
                        radius: 3.5
                        color: "white"
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (sendButton.busy) {
                                if (win.chat) {
                                    win.chat.cancel();
                                }
                            } else {
                                win.askAi(win.query);
                            }
                        }
                    }
                }
            }

            // Poignées de redimensionnement : bords et coins.
            // edges : 1 = gauche, 2 = droite, 4 = haut, 8 = bas.
            Repeater {
                model: [
                    { "edges": 1, "cursor": Qt.SizeHorCursor },
                    { "edges": 2, "cursor": Qt.SizeHorCursor },
                    { "edges": 4, "cursor": Qt.SizeVerCursor },
                    { "edges": 8, "cursor": Qt.SizeVerCursor },
                    { "edges": 5, "cursor": Qt.SizeFDiagCursor },
                    { "edges": 10, "cursor": Qt.SizeFDiagCursor },
                    { "edges": 6, "cursor": Qt.SizeBDiagCursor },
                    { "edges": 9, "cursor": Qt.SizeBDiagCursor }
                ]

                delegate: MouseArea {
                    id: grip

                    required property var modelData

                    readonly property bool atLeft: (modelData.edges & 1) !== 0
                    readonly property bool atRight: (modelData.edges & 2) !== 0
                    readonly property bool atTop: (modelData.edges & 4) !== 0
                    readonly property bool atBottom: (modelData.edges & 8) !== 0
                    readonly property bool corner: (atLeft || atRight) && (atTop || atBottom)
                    property real startX: 0
                    property real startY: 0
                    property real originX: 0
                    property real originY: 0
                    property real originWidth: 0
                    property real originHeight: 0

                    z: 30
                    width: corner ? 20 : ((atLeft || atRight) ? 8 : parent.width - 40)
                    height: corner ? 20 : ((atTop || atBottom) ? 8 : parent.height - 40)
                    x: atLeft ? 0 : (atRight ? parent.width - width : 20)
                    y: atTop ? 0 : (atBottom ? parent.height - height : 20)
                    acceptedButtons: Qt.LeftButton
                    cursorShape: modelData.cursor
                    onPressed: function (mouse) {
                        var point = mapToItem(stage, mouse.x, mouse.y);
                        startX = point.x;
                        startY = point.y;
                        originX = compactSurface.x;
                        originY = compactSurface.y;
                        originWidth = compactSurface.width;
                        originHeight = compactSurface.height;
                    }
                    onPositionChanged: function (mouse) {
                        if (!pressed) {
                            return;
                        }
                        var point = mapToItem(stage, mouse.x, mouse.y);
                        var dx = point.x - startX;
                        var dy = point.y - startY;
                        var maxWidth = win.width - 20;
                        var maxHeight = win.height - 20;
                        var newX = originX;
                        var newY = originY;
                        var newWidth = originWidth;
                        var newHeight = originHeight;
                        if (atRight) {
                            newWidth = originWidth + dx;
                        } else if (atLeft) {
                            newWidth = originWidth - dx;
                        }
                        if (atBottom) {
                            newHeight = originHeight + dy;
                        } else if (atTop) {
                            newHeight = originHeight - dy;
                        }
                        newWidth = Math.max(compactSurface.minWidth, Math.min(maxWidth, newWidth));
                        newHeight = Math.max(compactSurface.minHeight, Math.min(maxHeight, newHeight));
                        if (atLeft) {
                            newX = originX + originWidth - newWidth;
                        }
                        if (atTop) {
                            newY = originY + originHeight - newHeight;
                        }
                        // Reste dans l'écran.
                        newX = Math.max(0, Math.min(newX, win.width - newWidth));
                        newY = Math.max(0, Math.min(newY, win.height - newHeight));
                        win.compactUserX = newX;
                        win.compactUserY = newY;
                        win.compactUserWidth = newWidth;
                        win.compactUserHeight = newHeight;
                    }
                }
            }
        }

    }

    // Menus natifs : ce sont des fenêtres à part, donc avec leur propre
    // flou et leur propre effet Liquid Glass (comme le clic droit du Dock).
    NativeGlassMenu {
        id: moreMenu

        window: win
        onActivated: function (entryId) {
            win.handleMoreMenu(entryId);
        }
        onDismissed: win.focusField()
    }

    NativeGlassMenu {
        id: contextMenu

        window: win
        onActivated: function (entryId) {
            win.handleContextMenu(entryId);
        }
        onDismissed: win.focusField()
    }
}
