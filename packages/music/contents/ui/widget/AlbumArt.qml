import QtQuick
import org.kde.kirigami as Kirigami

Item {
    id: art

    property string artUrl: ""
    property real radius: 12
    property color fallbackColor: "#2c2c2e"
    property color fallbackIconColor: "#ffffff"

    // The cover is drawn by roundedimage.frag, which clips it to a rounded
    // rectangle with an analytically anti-aliased edge (no mask texture).
    Image {
        id: coverImage
        anchors.fill: parent
        source: art.artUrl
        fillMode: Image.PreserveAspectCrop
        smooth: true
        mipmap: true
        visible: false
        layer.enabled: true
        layer.smooth: true
        cache: false
    }

    Rectangle {
        anchors.fill: parent
        color: art.fallbackColor
        radius: art.radius
        antialiasing: true
        opacity: 0.3
    }

    ShaderEffect {
        anchors.fill: parent
        visible: art.artUrl !== ""
        fragmentShader: Qt.resolvedUrl("roundedimage.frag.qsb")
        property variant source: coverImage
        property size size: Qt.size(width, height)
        property real radius: art.radius
        property real roundness: 2.0
        property real gradientOn: 0.0
    }

    Kirigami.Icon {
        anchors.centerIn: parent
        width: parent.width * 0.35
        height: parent.height * 0.35
        source: "media-optical-audio"
        color: art.fallbackIconColor
        opacity: 0.4
        visible: art.artUrl === ""
    }
}
