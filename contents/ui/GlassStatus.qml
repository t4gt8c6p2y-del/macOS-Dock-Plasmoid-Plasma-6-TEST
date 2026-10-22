import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import "effects" as DockEffects

// Indique si l'effet KWin « Glass » est chargé. Chargé à part (Loader) par la
// page de configuration : si le module natif manquait, seule cette ligne
// disparaîtrait.
RowLayout {
    id: status

    property bool glassLoaded: false

    function refresh() {
        glassLoaded = kwin.glassLoaded();
    }

    DockEffects.GlassEffectSettings {
        id: kwin
    }

    QQC2.Label {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        text: status.glassLoaded
            ? i18n("The Glass effect is loaded in KWin.")
            : i18n("The Glass effect is not loaded in KWin. Install the liquid-glass-kde effect, or tick “Liquid Glass” and apply: the Dock then tries to load it.")
    }

    QQC2.Button {
        icon.name: "view-refresh"
        onClicked: status.refresh()

        QQC2.ToolTip.visible: hovered
        QQC2.ToolTip.text: i18n("Check again")
    }

    Component.onCompleted: refresh()
}
