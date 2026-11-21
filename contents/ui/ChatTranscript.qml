import QtQuick
import "MathText.js" as MathText

// Fil d'une conversation avec l'assistant : questions à droite (bulle bleue),
// réponses à gauche (texte libre, sélectionnable, en Markdown), erreurs en
// rouge. Comme dans ChatGPT : un point qui pulse pendant que l'assistant
// réfléchit, puis la réponse s'écrit progressivement (mot par mot) avec un point
// pulsant au bout du texte.
ListView {
    id: view

    property var messages: []
    property bool busy: false
    property bool compact: false
    property color accent: "#0A84FF"
    // Couleur de la bulle des questions (bleue par défaut ; grise dans le
    // Spotlight, comme la fenêtre de Siri).
    property color userColor: accent
    property string providerLabel: ""
    // Texte affiché quand la conversation est vide.
    property string emptyText: ""

    signal copyRequested(string text)

    readonly property real textSize: compact ? 14 : 15

    model: messages
    spacing: compact ? 10 : 14
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    leftMargin: compact ? 4 : 8
    rightMargin: compact ? 4 : 8
    topMargin: 8
    bottomMargin: 8

    // Réponses qui s'écrivent progressivement (mot par mot).
    property bool animateAnswers: true
    // Réponses déjà animées (clé : heure du message) : une réponse ne s'anime
    // qu'une fois, même si sa ligne est recréée.
    property var revealedKeys: ({})
    // Nombre de réponses en cours d'écriture ; pendant ce temps le fil suit le
    // bas du texte, sauf si l'utilisateur fait défiler lui-même.
    property int revealingRows: 0
    property bool stickToEnd: true

    onCountChanged: scrollTimer.restart()
    onBusyChanged: scrollTimer.restart()
    onContentHeightChanged: {
        if (revealingRows > 0 && stickToEnd) {
            positionViewAtEnd();
        }
    }
    onMovementStarted: stickToEnd = false

    Timer {
        id: scrollTimer

        interval: 30
        repeat: false
        onTriggered: view.positionViewAtEnd()
    }

    Text {
        anchors.centerIn: parent
        visible: view.count === 0 && !view.busy
        width: parent.width - 48
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        text: view.emptyText
        font.pixelSize: view.textSize
        color: Qt.rgba(1, 1, 1, 0.5)
    }

    delegate: Item {
        id: row

        required property var modelData

        readonly property bool isUser: modelData.role === "user"
        readonly property bool isError: modelData.error === true
        readonly property var sourceList: Array.isArray(modelData.sources) ? modelData.sources : []
        readonly property var queryList: Array.isArray(modelData.queries) ? modelData.queries : []
        readonly property var attachedList: Array.isArray(modelData.attached) ? modelData.attached : []
        // Images envoyées avec cette question : [{ path, name }].
        readonly property var imageList: Array.isArray(modelData.images) ? modelData.images : []
        readonly property bool hasText: String(modelData.text).trim().length > 0

        width: view.width - view.leftMargin - view.rightMargin
        height: isUser ? userColumn.height : assistantColumn.height

        // Écriture progressive d'une réponse qui vient d'arriver : nombre de
        // caractères déjà affichés (-1 : texte complet, pas d'animation).
        readonly property string rawText: isUser ? "" : String(modelData.text)
        property int revealCount: -1
        readonly property bool revealing: revealCount >= 0
        property int revealStep: 1

        function startReveal() {
            var n = rawText.length;
            if (n < 2) {
                return;
            }
            // Environ 320 caractères par seconde, entre 0,45 s et 4,5 s au total ;
            // une étape toutes les 40 ms (la mise en page du texte est refaite à
            // chaque étape : plus espacée, elle ménage le processeur).
            var duration = Math.min(4500, Math.max(450, n * 3.1));
            revealStep = Math.max(1, Math.ceil(n * 40 / duration));
            revealCount = 0;
            view.stickToEnd = true;
            view.revealingRows += 1;
            fadeIn.start();
            revealTimer.start();
        }

        function advanceReveal() {
            var n = rawText.length;
            var next = revealCount + revealStep;
            // On ne coupe pas un mot en deux.
            while (next < n && next < revealCount + revealStep + 14
                    && !/\s/.test(rawText.charAt(next))) {
                ++next;
            }
            if (next >= n) {
                finishReveal();
            } else {
                revealCount = next;
            }
        }

        function finishReveal() {
            revealTimer.stop();
            if (revealCount >= 0) {
                revealCount = -1;
                view.revealingRows = Math.max(0, view.revealingRows - 1);
            }
        }

        Component.onCompleted: {
            if (isUser || isError || !view.animateAnswers) {
                return;
            }
            var key = String(modelData.time);
            if (view.revealedKeys[key] === true) {
                return;
            }
            view.revealedKeys[key] = true;
            // Seule une réponse qui vient d'arriver s'écrit : pas celles d'une
            // conversation que l'on rouvre.
            var age = Date.now() - Number(modelData.time);
            if (age >= 0 && age < 2500) {
                startReveal();
            }
        }

        Component.onDestruction: {
            if (revealCount >= 0) {
                view.revealingRows = Math.max(0, view.revealingRows - 1);
            }
        }

        Timer {
            id: revealTimer

            interval: 40
            repeat: true
            onTriggered: row.advanceReveal()
        }

        NumberAnimation {
            id: fadeIn

            target: assistantColumn
            property: "opacity"
            from: 0
            to: 1
            duration: 220
            easing.type: Easing.OutCubic
        }

        // Largeur naturelle (sur une ligne) du texte de la question.
        Text {
            id: userMeasure

            visible: false
            text: row.isUser ? row.modelData.text : ""
            font.pixelSize: view.textSize
        }

        Column {
            id: userColumn

            visible: row.isUser
            anchors.right: parent.right
            width: Math.min(row.width * 0.82, userMeasure.implicitWidth + 28)
            spacing: 4

            // Images envoyées avec la question (au-dessus du texte, à droite).
            Flow {
                visible: row.imageList.length > 0
                anchors.right: parent.right
                width: row.width * 0.82
                layoutDirection: Qt.RightToLeft
                spacing: 6

                Repeater {
                    model: row.imageList

                    delegate: RoundedImage {
                        id: sentImage

                        required property var modelData

                        width: row.imageList.length === 1 ? (view.compact ? 190 : 240) : 108
                        height: row.imageList.length === 1 ? (view.compact ? 136 : 170) : 108
                        radius: 16
                        decodeSize: 480
                        source: sentImage.modelData.path
                            ? "file://" + String(sentImage.modelData.path).split("/")
                                .map(encodeURIComponent).join("/") : ""
                    }
                }
            }

            Rectangle {
                id: userBubble

                visible: row.hasText
                width: parent.width
                height: row.hasText ? userText.contentHeight + 20 : 0
                radius: 18
                color: view.userColor

                TextEdit {
                    id: userText

                    x: 14
                    y: 10
                    width: userBubble.width - 28
                    readOnly: true
                    selectByMouse: true
                    wrapMode: TextEdit.Wrap
                    text: row.isUser ? row.modelData.text : ""
                    font.pixelSize: view.textSize
                    color: "white"
                    selectionColor: Qt.rgba(1, 1, 1, 0.35)
                    selectedTextColor: "white"
                }
            }

            // Dossiers et fichiers joints à cette question.
            Text {
                visible: row.attachedList.length > 0
                anchors.right: parent.right
                width: Math.min(implicitWidth, row.width * 0.82)
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideLeft
                text: i18n("Attached: %1", row.attachedList.join(", "))
                font.pixelSize: 12
                color: Qt.rgba(1, 1, 1, 0.42)
            }
        }

        Column {
            id: assistantColumn

            visible: !row.isUser
            width: row.width
            spacing: 4

            TextEdit {
                id: answerText

                width: parent.width
                readOnly: true
                selectByMouse: true
                wrapMode: TextEdit.Wrap
                textFormat: row.isError ? TextEdit.PlainText : TextEdit.MarkdownText
                // Formules LaTeX → vrais symboles (½, x², √, ×, π…). Pendant
                // l'écriture progressive, seul le début de la réponse est affiché.
                text: row.isUser ? "" : (row.isError ? row.modelData.text
                    : MathText.prettify(row.revealing
                        ? row.rawText.substring(0, row.revealCount) : row.rawText))
                font.pixelSize: view.textSize
                color: row.isError ? "#FF6B6B" : Qt.rgba(1, 1, 1, 0.95)
                selectionColor: Qt.rgba(1, 1, 1, 0.3)
                selectedTextColor: "white"

                // Place de la fin du texte déjà écrit.
                readonly property rect endRect: positionToRectangle(length)

                // Point pulsant au bout du texte pendant qu'il s'écrit.
                Rectangle {
                    id: writingDot

                    visible: row.revealing
                    x: answerText.endRect.x + 5
                    y: answerText.endRect.y + answerText.endRect.height / 2 - height / 2
                    width: 10
                    height: 10
                    radius: 5
                    color: Qt.rgba(1, 1, 1, 0.92)
                    scale: 0.7

                    SequentialAnimation on scale {
                        running: row.revealing
                        loops: Animation.Infinite

                        NumberAnimation { to: 1.1; duration: 420; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 0.7; duration: 420; easing.type: Easing.InOutSine }
                    }
                }
            }

            // Pages citées par la recherche web de Gemini : un clic ouvre la page.
            Flow {
                visible: !row.isError && row.sourceList.length > 0
                opacity: row.revealing ? 0 : 1
                Behavior on opacity { NumberAnimation { duration: 220 } }
                width: parent.width
                spacing: 8

                Text {
                    text: i18n("Sources:")
                    font.pixelSize: 12
                    color: Qt.rgba(1, 1, 1, 0.42)
                }

                Repeater {
                    model: row.sourceList

                    delegate: Text {
                        id: sourceLink

                        required property var modelData

                        text: sourceLink.modelData.title
                        font.pixelSize: 12
                        elide: Text.ElideRight
                        width: Math.min(implicitWidth, row.width - 60)
                        color: sourceArea.containsMouse ? "white" : "#6CB6FF"

                        MouseArea {
                            id: sourceArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Qt.openUrlExternally(sourceLink.modelData.uri)
                        }
                    }
                }
            }

            // Recherches réellement faites par Gemini sur le web.
            Text {
                visible: !row.isError && row.queryList.length > 0
                opacity: row.revealing ? 0 : 1
                Behavior on opacity { NumberAnimation { duration: 220 } }
                width: parent.width
                wrapMode: Text.WordWrap
                text: i18n("Web search: %1", row.queryList.join(" · "))
                font.pixelSize: 12
                color: Qt.rgba(1, 1, 1, 0.42)
            }

            // Recherche forcée, mais Gemini a répondu sans chercher.
            Text {
                visible: !row.isError && row.modelData.noSearch === true
                opacity: row.revealing ? 0 : 1
                Behavior on opacity { NumberAnimation { duration: 220 } }
                width: parent.width
                wrapMode: Text.WordWrap
                text: i18n("Gemini did not run a web search for this answer: it may come from memory and be out of date.")
                font.pixelSize: 12
                color: "#FFB454"
            }

            Row {
                spacing: 10
                visible: !row.isError
                opacity: row.revealing ? 0 : 1
                Behavior on opacity { NumberAnimation { duration: 220 } }

                Text {
                    text: row.modelData.label ? String(row.modelData.label)
                        : (row.modelData.provider !== undefined ? view.providerNameFor(row.modelData.provider) : "")
                    font.pixelSize: 12
                    color: Qt.rgba(1, 1, 1, 0.42)
                }

                Text {
                    text: i18n("Copy")
                    font.pixelSize: 12
                    color: copyArea.containsMouse ? "white" : Qt.rgba(1, 1, 1, 0.42)

                    MouseArea {
                        id: copyArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: view.copyRequested(row.modelData.text)
                    }
                }
            }
        }
    }

    // Nom du fournisseur d'un message (rempli par le parent si besoin).
    property var providerNames: ["Gemini", "GLM", i18n("Custom AI")]
    function providerNameFor(index) {
        return index >= 0 && index < providerNames.length ? providerNames[index] : "";
    }

    footer: Item {
        width: view.width
        height: view.busy ? 36 : 0
        visible: view.busy

        // Comme dans ChatGPT : un seul point qui pulse pendant que l'assistant
        // réfléchit.
        Rectangle {
            id: thinkingDot

            x: view.leftMargin + 3
            anchors.verticalCenter: parent.verticalCenter
            width: 12
            height: 12
            radius: 6
            color: Qt.rgba(1, 1, 1, 0.92)
            scale: 0.6
            opacity: 0.5

            SequentialAnimation {
                running: view.busy
                loops: Animation.Infinite

                ParallelAnimation {
                    NumberAnimation {
                        target: thinkingDot; property: "scale"; to: 1.0
                        duration: 640; easing.type: Easing.InOutSine
                    }
                    NumberAnimation {
                        target: thinkingDot; property: "opacity"; to: 1.0
                        duration: 640; easing.type: Easing.InOutSine
                    }
                }

                ParallelAnimation {
                    NumberAnimation {
                        target: thinkingDot; property: "scale"; to: 0.6
                        duration: 640; easing.type: Easing.InOutSine
                    }
                    NumberAnimation {
                        target: thinkingDot; property: "opacity"; to: 0.5
                        duration: 640; easing.type: Easing.InOutSine
                    }
                }
            }
        }
    }
}
