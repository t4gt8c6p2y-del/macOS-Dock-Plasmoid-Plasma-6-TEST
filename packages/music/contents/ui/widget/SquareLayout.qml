import QtQuick
import QtQuick.Layouts
import QtQuick.Effects

Item {
    id: layout

    required property QtObject colors
    property real cornerRadius: 24
    property real roundness: 7.5
    property string fontFamily: ""
    property string fontFamilyThin: ""
    property string track: ""
    property string artist: ""
    property string albumArt: ""
    property bool isPlaying: false
    property bool canGoPrevious: false
    property bool canGoNext: false
    property bool canPlay: false
    property bool canPause: false
    property real position: 0
    property real length: 0
    property var formatTime: function(us) { return "" }

    signal togglePlaying()
    signal nextTrack()
    signal previousTrack()
    signal seek(real positionUs)

    readonly property real _m: Math.round(Math.min(width, height) * 0.08)
    readonly property real _s: Math.min(width, height)
    readonly property real _bgArtRadius: Math.min(layout.cornerRadius, Math.min(width, height) * 0.22)

    clip: true

    // Album art as full background with gradient fade-out toward bottom.
    // roundedimage.frag clips it to the same squircle as the glass shader
    // (analytic anti-aliased edge) and applies the black gradient.
    Image {
        id: bgArtImage
        anchors.fill: parent
        source: layout.albumArt
        fillMode: Image.PreserveAspectCrop
        smooth: true
        mipmap: true
        visible: false
        layer.enabled: true
        layer.smooth: true
    }

    ShaderEffect {
        anchors.fill: parent
        visible: layout.albumArt !== ""
        fragmentShader: Qt.resolvedUrl("roundedimage.frag.qsb")
        property variant source: bgArtImage
        property size size: Qt.size(width, height)
        property real radius: layout.cornerRadius
        property real roundness: layout.roundness
        property real gradientOn: 1.0
    }

    // Fallback icon when no album art
    Item {
        anchors.fill: parent
        visible: layout.albumArt === ""

        Rectangle {
            anchors.centerIn: parent
            width: layout._s * 0.3
            height: width
            radius: width * 0.15
            color: layout.colors.foreground
            opacity: 0.08
        }
    }

    // Content overlay
    Item {
        id: content
        anchors.fill: parent
        anchors.margins: layout._m

        Column {
            id: infoCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: controls.top
            anchors.bottomMargin: Math.round(layout._s * 0.04)
            spacing: 2

            MarqueeText {
                width: parent.width
                height: Math.round(layout._s * 0.0735) + 4
                text: layout.track || "Not Playing"
                fontSize: Math.max(13, Math.round(layout._s * 0.0683))
                fontWeight: Font.DemiBold
                fontFamily: layout.fontFamily
                textColor: layout.colors.foreground
                horizontalAlignment: Text.AlignHCenter
            }

            MarqueeText {
                width: parent.width
                height: Math.max(13, Math.round(layout._s * 0.0504)) + 4
                text: layout.artist || "—"
                fontSize: Math.max(9, Math.round(layout._s * 0.0494))
                fontWeight: Font.Medium
                fontFamily: layout.fontFamily
                textColor: layout.colors.foreground
                textOpacity: 0.55
                horizontalAlignment: Text.AlignHCenter
            }
        }

        Row {
            id: controls
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Math.round(layout._s * 0.08)

            readonly property real _iconSize: Math.max(20, Math.round(layout._s * 0.11))
            readonly property real _rowH: _iconSize * 1.6

            ControlButton {
                iconSource: Qt.resolvedUrl("../icons/previous.svg")
                iconColor: layout.colors.foreground
                iconSize: controls._iconSize
                height: controls._rowH
                opacity: layout.canGoPrevious ? 1.0 : 0.3
                onClicked: layout.previousTrack()
            }

            ControlButton {
                iconSource: layout.isPlaying ? Qt.resolvedUrl("../icons/pause.svg") : Qt.resolvedUrl("../icons/play.svg")
                iconColor: layout.colors.foreground
                iconSize: controls._iconSize
                height: controls._rowH
                opacity: (layout.canPlay || layout.canPause) ? 1.0 : 0.3
                onClicked: layout.togglePlaying()
            }

            ControlButton {
                iconSource: Qt.resolvedUrl("../icons/next.svg")
                iconColor: layout.colors.foreground
                iconSize: controls._iconSize
                height: controls._rowH
                opacity: layout.canGoNext ? 1.0 : 0.3
                onClicked: layout.nextTrack()
            }
        }
    }
}
