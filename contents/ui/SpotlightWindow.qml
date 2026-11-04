import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.layershell as LayerShell
import "effects" as DockEffects
import "SpotlightMath.js" as SpotlightMath

// Spotlight de macOS 27 : une barre « Search or Ask » en verre, et dessous un
// panneau de résultats. Ouvert par la touche Windows, par l'icône du Dock, par
// Alt+Espace ou en tapant sur le bureau (voir SpotlightBackend).
//
// Le bouton à gauche de la barre change de mode à chaque clic :
//   rien (par défaut : applications, puis l'assistant IA si rien ne correspond)
//   -> Applications -> Fichiers -> Presse-papiers -> rien ;
// un double clic revient toujours au mode par défaut.
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

    signal favoritesChangeRequested(var ids)
    signal assistantRequested(bool freshConversation)
    signal settingsRequested()

    // --- État --------------------------------------------------------------------
    // 0 = par défaut, 1 = applications, 2 = fichiers, 3 = presse-papiers
    property int mode: 0
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
    readonly property int columns: 7
    readonly property real cellWidth: 98
    readonly property real cellHeight: 90
    readonly property real barWidth: 444
    readonly property real barHeight: 72
    readonly property real panelWidth: 720
    readonly property real panelMaxHeight: 443
    readonly property real stageGap: 12
    readonly property real stageTop: Math.round(height * 0.17)
    readonly property color accent: "#007AFF"

    readonly property bool gridMode: mode === 1 && query.trim().length === 0 && !aiView
    readonly property bool panelWanted: aiView || mode !== 0 || query.trim().length > 0
    readonly property real panelTargetHeight: {
        if (!panelWanted) {
            return 0;
        }
        if (aiView || gridMode) {
            return panelMaxHeight;
        }
        var total = 16;
        for (var i = 0; i < results.length; ++i) {
            total += results[i].kind === "header" ? 28
                : (results[i].kind === "info" ? 46 : 50);
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
        : (mode === 1 ? i18n("Applications")
            : (mode === 2 ? i18n("Files")
                : (mode === 3 ? i18n("Clipboard") : i18n("Search or Ask"))))

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
        moreMenu.opened = false;
        contextMenu.opened = false;
        refreshApps();
        mode = 0;
        aiView = false;
        query = initialText !== undefined ? String(initialText) : "";
        if (chat) {
            chat.startNew();
        }
        rebuildResults();
        visible = true;
        requestActivate();
        Qt.callLater(focusField);
    }

    function closeSpotlight() {
        moreMenu.opened = false;
        contextMenu.opened = false;
        visible = false;
    }

    function toggleSpotlight() {
        if (visible) {
            closeSpotlight();
        } else {
            openSpotlight("");
        }
    }

    function focusField() {
        field.forceActiveFocus();
        field.cursorPosition = field.text.length;
    }

    onVisibleChanged: {
        if (visible) {
            stage.opacity = 0;
            fadeIn.restart();
        } else {
            glassKey = "";
            glassBlur.clear(win);
            if (backend) {
                backend.cancelFileSearch();
            }
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
        if (mode === 0) {
            if (text.length > 0) {
                var calculation = SpotlightMath.evaluate(text);
                if (calculation) {
                    list.push({ "kind": "calc", "text": text, "value": calculation.text });
                }
                var apps = matchApps(text, 6);
                if (apps.length > 0) {
                    list.push({ "kind": "header", "text": i18n("Applications") });
                    for (i = 0; i < apps.length; ++i) {
                        list.push({ "kind": "app", "app": apps[i] });
                    }
                }
                if (chat) {
                    list.push({ "kind": "ai", "text": text });
                }
            }
        } else if (mode === 1) {
            if (text.length > 0) {
                var found = matchApps(text, 40);
                if (found.length === 0) {
                    list.push({ "kind": "info", "text": i18n("No results") });
                } else {
                    list.push({ "kind": "header", "text": i18n("Applications") });
                    for (i = 0; i < found.length; ++i) {
                        list.push({ "kind": "app", "app": found[i] });
                    }
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

    function askAi(text) {
        var question = String(text).trim();
        if (!chat || question.length === 0) {
            return;
        }
        aiView = true;
        query = "";
        chat.ask(question, chat.activeProvider);
        focusField();
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
        } else if (mode === 0 && chat && query.trim().length > 0) {
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

    function openMoreMenu() {
        contextMenu.opened = false;
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
        } else if (id === "newchat") {
            closeSpotlight();
            assistantRequested(true);
        } else if (id === "openchat") {
            closeSpotlight();
            assistantRequested(false);
        } else if (id === "settings") {
            closeSpotlight();
            settingsRequested();
        }
    }

    function openContextMenu(target, sceneX, sceneY) {
        moreMenu.opened = false;
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

    // --- Flou demandé à KWin ---------------------------------------------------------------
    property string glassKey: ""
    property int glassTicks: 0

    function itemRect(item, radius) {
        if (!item || !item.visible || item.width < 1 || item.height < 1) {
            return null;
        }
        var origin = item.mapToItem(null, 0, 0);
        return {
            "x": Math.round(origin.x),
            "y": Math.round(origin.y),
            "width": Math.round(item.width),
            "height": Math.round(item.height),
            "radius": radius
        };
    }

    function updateGlass() {
        if (!visible) {
            return;
        }
        var rects = [];
        var bar = itemRect(barSurface, barSurface.radius);
        if (bar) {
            rects.push(bar);
        }
        if (panelSurface.height > 8) {
            var panel = itemRect(panelSurface, panelSurface.radius);
            if (panel) {
                rects.push(panel);
            }
        }
        if (moreMenu.opened) {
            rects.push({ "x": Math.round(moreMenu.boxRect.x), "y": Math.round(moreMenu.boxRect.y),
                "width": Math.round(moreMenu.boxRect.width),
                "height": Math.round(moreMenu.boxRect.height), "radius": 14 });
        }
        if (contextMenu.opened) {
            rects.push({ "x": Math.round(contextMenu.boxRect.x), "y": Math.round(contextMenu.boxRect.y),
                "width": Math.round(contextMenu.boxRect.width),
                "height": Math.round(contextMenu.boxRect.height), "radius": 14 });
        }
        // On ne renvoie la liste à KWin que si elle a changé (et, de temps en
        // temps, par sécurité : la surface peut être créée après le premier envoi).
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
        GlassSurface {
            id: barSurface

            theme: win.glassTheme
            radius: win.barHeight / 2
            width: win.barWidth
            height: win.barHeight
            x: Math.round((win.width - width) / 2)
            y: win.stageTop

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
            }

            // Bouton de mode : rien, Applications, Fichiers, Presse-papiers.
            Item {
                id: modeButton

                x: 12
                anchors.verticalCenter: parent.verticalCenter
                width: 44
                height: 44

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
                    visible: win.mode !== 0
                    kind: win.mode === 1 ? "apps" : (win.mode === 2 ? "files" : "clipboard")
                    size: 26
                    lineWidth: 1.6
                    color: Qt.rgba(1, 1, 1, 0.82)
                }

                HoverHandler {
                    id: modeHover

                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    // Un double clic (deux taps rapprochés) revient au mode par défaut.
                    onTapped: {
                        if (tapCount >= 2) {
                            win.setMode(0);
                        } else {
                            win.setMode((win.mode + 1) % 4);
                        }
                    }
                }
            }

            TextInput {
                id: field

                x: 64
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 64 - 56
                color: "white"
                selectionColor: Qt.rgba(1, 1, 1, 0.3)
                selectedTextColor: "white"
                font.pixelSize: 22
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
                    color: Qt.rgba(1, 1, 1, 0.5)
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
                    } else if (control && event.key >= Qt.Key_0 && event.key <= Qt.Key_3) {
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

            // Bouton « … » : les mêmes réglages que le Spotlight de macOS.
            Item {
                id: moreButton

                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                width: 40
                height: 40

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
                            width: 4.5
                            height: 4.5
                            radius: 2.25
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
        GlassSurface {
            id: panelSurface

            theme: win.glassTheme
            radius: 30
            width: win.panelWidth
            height: win.panelTargetHeight
            visible: height > 1
            x: Math.round((win.width - width) / 2)
            y: barSurface.y + barSurface.height + win.stageGap

            Behavior on height {
                NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
            }

            // Pastilles de catégories (étoile des favoris en premier).
            Item {
                id: pillsArea

                visible: win.gridMode
                x: 14
                y: 14
                width: parent.width - 28
                height: 30
                clip: true

                Row {
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
                                font.pixelSize: 13.5
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

            // Grille des applications, par catégorie.
            ListView {
                id: appsList

                visible: win.gridMode
                x: 12
                y: 54
                width: parent.width - 24
                height: parent.height - 54 - 14
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: win.sections

                NumberAnimation {
                    id: scrollAnimation

                    target: appsList
                    property: "contentY"
                    duration: 240
                    easing.type: Easing.OutCubic
                }

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
                                    radius: 14
                                    color: cell.current ? Qt.rgba(1, 1, 1, 0.18)
                                        : (cellMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent")
                                }

                                Kirigami.Icon {
                                    x: Math.round((parent.width - width) / 2)
                                    y: 8
                                    width: 52
                                    height: 52
                                    source: cell.modelData.icon
                                }

                                Text {
                                    x: 4
                                    y: 64
                                    width: parent.width - 8
                                    height: 20
                                    horizontalAlignment: Text.AlignHCenter
                                    elide: Text.ElideRight
                                    text: cell.modelData.name
                                    font.pixelSize: 12
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

                // Barre de défilement fine, comme sur la capture.
                Rectangle {
                    visible: appsList.contentHeight > appsList.height
                    x: parent.width - 6
                    y: appsList.height * (appsList.contentY / Math.max(1, appsList.contentHeight))
                    width: 4
                    height: Math.max(28, appsList.height * appsList.height
                        / Math.max(1, appsList.contentHeight))
                    radius: 2
                    color: Qt.rgba(1, 1, 1, 0.35)
                }
            }

            // Liste de résultats (recherche, fichiers, presse-papiers).
            ListView {
                id: resultsList

                visible: !win.gridMode && !win.aiView
                x: 10
                y: 8
                width: parent.width - 20
                height: parent.height - 16
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
                    height: kind === "header" ? 28 : (kind === "info" ? 46 : 50)

                    Rectangle {
                        visible: resultRow.kind !== "header" && resultRow.kind !== "info"
                        anchors.fill: parent
                        anchors.topMargin: 1
                        anchors.bottomMargin: 1
                        radius: 12
                        color: resultRow.selected ? Qt.rgba(1, 1, 1, 0.18)
                            : (resultRow.hovered ? Qt.rgba(1, 1, 1, 0.09) : "transparent")
                    }

                    Text {
                        visible: resultRow.kind === "header"
                        x: 14
                        anchors.verticalCenter: parent.verticalCenter
                        text: resultRow.modelData.text || ""
                        font.pixelSize: 12.5
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
                        x: 12
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 12

                        Kirigami.Icon {
                            width: 34
                            height: 34
                            source: resultRow.kind === "app" ? resultRow.modelData.app.icon : ""
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            Text {
                                text: resultRow.kind === "app" ? resultRow.modelData.app.name : ""
                                font.pixelSize: 15
                                color: "white"
                            }
                            Text {
                                visible: text.length > 0
                                text: resultRow.kind === "app" ? resultRow.modelData.app.genericName : ""
                                font.pixelSize: 12
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
                            font.pixelSize: 14.5
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

                    // Demander à l'assistant
                    Row {
                        visible: resultRow.kind === "ai"
                        x: 12
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 12

                        Rectangle {
                            width: 34
                            height: 34
                            radius: 17
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0.0; color: "#7B61FF" }
                                GradientStop { position: 0.5; color: "#35A7FF" }
                                GradientStop { position: 1.0; color: "#FF5FA2" }
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
                            anchors.verticalCenter: parent.verticalCenter
                            width: resultRow.width - 80

                            Text {
                                text: win.chat ? i18n("Ask %1", win.chat.providerName(win.chat.activeProvider)) : ""
                                font.pixelSize: 15
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

            // Conversation avec l'assistant, dans le panneau.
            Item {
                id: aiPanel

                visible: win.aiView
                anchors.fill: parent

                Row {
                    x: 22
                    y: 14
                    height: 28
                    spacing: 8

                    SpotlightGlyph {
                        anchors.verticalCenter: parent.verticalCenter
                        kind: "sparkle"
                        size: 18
                        color: Qt.rgba(1, 1, 1, 0.85)
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: win.chat ? win.chat.providerName(win.chat.activeProvider) : ""
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                        color: Qt.rgba(1, 1, 1, 0.85)
                    }
                }

                // Ouvrir la conversation dans l'application Siri IA.
                Rectangle {
                    visible: win.assistantEnabled
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.topMargin: 12
                    anchors.rightMargin: 16
                    width: 32
                    height: 32
                    radius: 16
                    color: Qt.rgba(1, 1, 1, expandMouse.containsMouse ? 0.18 : 0.08)

                    SpotlightGlyph {
                        anchors.centerIn: parent
                        kind: "expand"
                        size: 16
                        color: Qt.rgba(1, 1, 1, 0.85)
                    }

                    MouseArea {
                        id: expandMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            win.closeSpotlight();
                            win.assistantRequested(false);
                        }
                    }
                }

                ChatTranscript {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.topMargin: 52
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    anchors.bottomMargin: 12
                    compact: true
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
            }
        }

        GlassMenu {
            id: moreMenu

            theme: win.glassTheme
            onActivated: function (entryId) {
                win.handleMoreMenu(entryId);
            }
            onDismissed: win.focusField()
        }

        GlassMenu {
            id: contextMenu

            theme: win.glassTheme
            onActivated: function (entryId) {
                win.handleContextMenu(entryId);
            }
            onDismissed: win.focusField()
        }
    }
}
