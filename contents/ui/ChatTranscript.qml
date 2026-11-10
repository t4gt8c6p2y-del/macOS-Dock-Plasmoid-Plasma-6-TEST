import QtQuick

// Fil d'une conversation avec l'assistant : questions à droite (bulle bleue),
// réponses à gauche (texte libre, sélectionnable, en Markdown), erreurs en
// rouge, points animés pendant que l'assistant répond.
ListView {
    id: view

    property var messages: []
    property bool busy: false
    property bool compact: false
    property color accent: "#0A84FF"
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

    onCountChanged: scrollTimer.restart()
    onBusyChanged: scrollTimer.restart()

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

        width: view.width - view.leftMargin - view.rightMargin
        height: isUser ? userColumn.height : assistantColumn.height

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

            Rectangle {
                id: userBubble

                width: parent.width
                height: userText.contentHeight + 20
                radius: 18
                color: view.accent

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
                width: parent.width
                readOnly: true
                selectByMouse: true
                wrapMode: TextEdit.Wrap
                textFormat: row.isError ? TextEdit.PlainText : TextEdit.MarkdownText
                text: row.isUser ? "" : row.modelData.text
                font.pixelSize: view.textSize
                color: row.isError ? "#FF6B6B" : Qt.rgba(1, 1, 1, 0.95)
                selectionColor: Qt.rgba(1, 1, 1, 0.3)
                selectedTextColor: "white"
            }

            // Pages citées par la recherche web de Gemini : un clic ouvre la page.
            Flow {
                visible: !row.isError && row.sourceList.length > 0
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
                width: parent.width
                wrapMode: Text.WordWrap
                text: i18n("Web search: %1", row.queryList.join(" · "))
                font.pixelSize: 12
                color: Qt.rgba(1, 1, 1, 0.42)
            }

            // Recherche forcée, mais Gemini a répondu sans chercher.
            Text {
                visible: !row.isError && row.modelData.noSearch === true
                width: parent.width
                wrapMode: Text.WordWrap
                text: i18n("Gemini did not run a web search for this answer: it may come from memory and be out of date.")
                font.pixelSize: 12
                color: "#FFB454"
            }

            Row {
                spacing: 10
                visible: !row.isError

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

        Row {
            x: view.leftMargin
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            Repeater {
                model: 3

                delegate: Rectangle {
                    id: dot

                    required property int index

                    width: 8
                    height: 8
                    radius: 4
                    color: Qt.rgba(1, 1, 1, 0.6)

                    SequentialAnimation on opacity {
                        running: view.busy
                        loops: Animation.Infinite

                        PauseAnimation { duration: dot.index * 160 }
                        NumberAnimation { to: 0.25; duration: 360 }
                        NumberAnimation { to: 1.0; duration: 360 }
                        PauseAnimation { duration: (2 - dot.index) * 160 }
                    }
                }
            }
        }
    }
}
