pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Dialogs
import QtQuick.Layouts
import QtCore
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.kquickcontrols as KQuickControls

KCM.SimpleKCM {
    id: configPage

    property alias cfg_dockPosition: dockPositionCombo.currentIndex
    property alias cfg_maxScale: maxScaleSlider.value
    property alias cfg_zoomRadius: zoomRadiusSlider.value
    property alias cfg_iconSize: iconSizeSlider.value
    property alias cfg_iconSpacing: iconSpacingSlider.value
    property alias cfg_dockMargin: dockMarginSlider.value
    property alias cfg_dockCrossMargin: dockCrossMarginSlider.value
    property alias cfg_screenEdgeMargin: screenEdgeMarginSlider.value
    property alias cfg_backgroundOpacity: backgroundOpacitySlider.value
    property alias cfg_useThemeBackground: useThemeBackgroundCheckBox.checked
    property alias cfg_customBackgroundColor: backgroundColorButton.color
    property alias cfg_cornerRadius: cornerRadiusSlider.value
    // L'ancienne opacité de bordure n'a plus de contrôle : la bordure est
    // désormais réglée par cfg_borderStrength (part éclairée du contour).
    property real cfg_borderOpacity: 0.22
    property real cfg_borderStrength: -1
    property alias cfg_borderWidth: borderWidthSlider.value
    // Onglet Glass (effet KWin Glass).
    property alias cfg_glassManage: glassManageCheckBox.checked
    property alias cfg_glassBlurStrength: glassBlurStrengthSlider.value
    property alias cfg_glassBlurFinetune: glassBlurFinetuneSlider.value
    property alias cfg_glassNoise: glassNoiseSlider.value
    property alias cfg_glassSaturation: glassSaturationSlider.value
    property alias cfg_glassRefraction: glassRefractionCheckBox.checked
    property alias cfg_glassThickness: glassThicknessSlider.value
    property alias cfg_glassIor: glassIorSlider.value
    property alias cfg_glassBevel: glassBevelSlider.value
    property alias cfg_glassDispersion: glassDispersionSlider.value
    property alias cfg_glassNormalPower: glassNormalPowerSlider.value
    property alias cfg_glassEdgeBlur: glassEdgeBlurSlider.value
    property alias cfg_glassRimStrength: glassRimStrengthSlider.value
    // Flou de l'arrière-plan : 0 = désactivé, au-dessus = activé (KWin ne
    // permet pas de régler l'intensité fenêtre par fenêtre).
    property real cfg_wallpaperBlur: 0
    property alias cfg_useThemeIndicatorColor: useThemeIndicatorCheckBox.checked
    property alias cfg_indicatorColor: indicatorColorButton.color
    property alias cfg_wallpaperBlurImage: wallpaperBlurImageField.text
    // Le curseur d'ombre a été retiré de l'interface : la clé reste connue de
    // Plasma (popups) mais n'a plus de contrôle associé.
    property real cfg_shadowOpacity: 0.42
    property bool cfg_showHighlight: true
    property real cfg_highlightStrength: -1
    property bool cfg_perDesktopDock: true
    // Intensité de la lumière de la bordure (0..2). -1 = jamais réglé : on
    // reprend l'ancienne case cfg_borderFollowMouse, qui n'a plus de contrôle.
    property real cfg_borderLightIntensity: -1
    property bool cfg_borderFollowMouse: true
    property alias cfg_hideOnMaximized: hideOnMaximizedCheckBox.checked
    property alias cfg_launchAnimation: launchAnimationCombo.currentIndex
    property alias cfg_magnificationSpring: magnificationSpringSlider.value
    property alias cfg_magnificationDamping: magnificationDampingSlider.value
    property alias cfg_clickBounceHeight: clickBounceHeightSlider.value
    property alias cfg_launchBounceHeight: launchBounceHeightSlider.value
    property alias cfg_dockRevealDuration: dockRevealDurationSlider.value
    property alias cfg_dockHideDuration: dockHideDurationSlider.value
    property alias cfg_appGroupPopupDuration:
        appGroupPopupDurationSlider.value
    property alias cfg_appGroupPopupOvershoot:
        appGroupPopupOvershootSlider.value
    property alias cfg_folderHoverScale: folderHoverScaleSlider.value
    property alias cfg_showFolderView: showFolderViewCheckBox.checked
    property alias cfg_autoOpenFolderWithOpenDocument:
        autoOpenFolderWithOpenDocumentCheckBox.checked
    property alias cfg_autoOpenAppGroupWithRunningApp:
        autoOpenAppGroupWithRunningAppCheckBox.checked
    property alias cfg_appGroupViewMode: appGroupViewModeCombo.currentIndex
    property alias cfg_folderUrl: folderUrlField.text
    property var cfg_folderUrls: []
    property alias cfg_showTrash: showTrashCheckBox.checked
    property alias cfg_showRemovableVolumes: showRemovableVolumesCheckBox.checked
    property alias cfg_openRemovableVolumesInNewTab:
        openRemovableVolumesInNewTabCheckBox.checked
    property alias cfg_showDesktopSwitcher:
        showDesktopSwitcherCheckBox.checked
    property alias cfg_desktopSwitcherPosition:
        desktopSwitcherPositionCombo.currentIndex
    property alias cfg_desktopSwitcherLabelMode:
        desktopSwitcherLabelModeCombo.currentIndex
    property alias cfg_showPowerButton:
        showPowerButtonCheckBox.checked
    property alias cfg_powerButtonPosition:
        powerButtonPositionCombo.currentIndex
    property alias cfg_showProgressIndicators:
        showProgressIndicatorsCheckBox.checked
    property alias cfg_showKdeConnectRecentShares:
        showKdeConnectRecentSharesCheckBox.checked
    property var cfg_launchers: []
    property var cfg_appGroups: []

    // Plasma setzt zu jedem Konfigurationsschluessel nicht nur cfg_<key>,
    // sondern auch cfg_<key>Default auf dieser Seite. Fehlen die Deklarationen,
    // meldet plasmashell beim Oeffnen der Seite fuer jeden Schluessel
    // "Setting initial properties failed" und der Knopf "Voreinstellungen"
    // kann nicht erkennen, welcher Wert der Standard ist. Die hier gesetzten
    // Werte spiegeln contents/config/main.xml; Plasma ueberschreibt sie beim
    // Laden ohnehin mit den echten Vorgaben.
    property int cfg_dockPositionDefault: 0
    property real cfg_maxScaleDefault: 1.45
    property int cfg_zoomRadiusDefault: 70
    property int cfg_iconSizeDefault: 44
    property int cfg_iconSpacingDefault: 4
    property int cfg_dockMarginDefault: 16
    property int cfg_dockCrossMarginDefault: 5
    property int cfg_screenEdgeMarginDefault: 8
    property real cfg_backgroundOpacityDefault: 0.55
    property bool cfg_useThemeBackgroundDefault: true
    property color cfg_customBackgroundColorDefault: "#20242b"
    property bool cfg_useThemeIndicatorColorDefault: true
    property color cfg_indicatorColorDefault: "#3daee9"
    property int cfg_cornerRadiusDefault: 12
    property real cfg_borderOpacityDefault: 0.22
    property real cfg_borderStrengthDefault: -1
    property real cfg_borderWidthDefault: 1.0
    property bool cfg_glassManageDefault: false
    property int cfg_glassBlurStrengthDefault: 1
    property int cfg_glassBlurFinetuneDefault: 5
    property int cfg_glassNoiseDefault: 0
    property real cfg_glassSaturationDefault: 1.0
    property bool cfg_glassRefractionDefault: true
    property int cfg_glassThicknessDefault: 14
    property real cfg_glassIorDefault: 2.0
    property real cfg_glassBevelDefault: 3.4
    property real cfg_glassDispersionDefault: 0.25
    property real cfg_glassNormalPowerDefault: 1.0
    property int cfg_glassEdgeBlurDefault: 10
    property real cfg_glassRimStrengthDefault: 1.0
    property real cfg_wallpaperBlurDefault: 0
    property string cfg_wallpaperBlurImageDefault: ""
    property real cfg_shadowOpacityDefault: 0.42
    property bool cfg_showHighlightDefault: true
    property real cfg_highlightStrengthDefault: -1
    property bool cfg_perDesktopDockDefault: true
    property real cfg_borderLightIntensityDefault: -1
    property bool cfg_borderFollowMouseDefault: true
    property bool cfg_hideOnMaximizedDefault: true
    property int cfg_launchAnimationDefault: 1
    property real cfg_magnificationSpringDefault: 50.0
    property real cfg_magnificationDampingDefault: 1.0
    property int cfg_clickBounceHeightDefault: 4
    property int cfg_launchBounceHeightDefault: 8
    property int cfg_dockRevealDurationDefault: 140
    property int cfg_dockHideDurationDefault: 160
    property int cfg_appGroupPopupDurationDefault: 180
    property real cfg_appGroupPopupOvershootDefault: 1.35
    property real cfg_folderHoverScaleDefault: 1.06
    property bool cfg_showFolderViewDefault: true
    property string cfg_folderUrlDefault: ""
    property bool cfg_autoOpenFolderWithOpenDocumentDefault: true
    property bool cfg_autoOpenAppGroupWithRunningAppDefault: true
    property int cfg_appGroupViewModeDefault: 1
    property var cfg_folderUrlsDefault: []
    property bool cfg_showTrashDefault: true
    property bool cfg_showRemovableVolumesDefault: true
    property bool cfg_openRemovableVolumesInNewTabDefault: false
    property bool cfg_showDesktopSwitcherDefault: true
    property int cfg_desktopSwitcherPositionDefault: 0
    property int cfg_desktopSwitcherLabelModeDefault: 0
    property bool cfg_showPowerButtonDefault: true
    property int cfg_powerButtonPositionDefault: 1
    property bool cfg_showProgressIndicatorsDefault: true
    property bool cfg_showKdeConnectRecentSharesDefault: true
    property var cfg_appGroupsDefault: []
    property var cfg_launchersDefault: []

    // Accepted for compatibility with the configuration page instance that
    // existed before 1.3 and with Plasma's standard applet page properties.
    property bool cfg_showDockBackground: false
    property bool cfg_expanding: false
    property int cfg_length: 0

    // ------------------------------------------------------------------
    // Copier / coller le style, réinitialiser
    // ------------------------------------------------------------------
    // Réglages numériques : clé -> [minimum, maximum]. Sert aussi à valider
    // un style collé (une valeur hors plage est ramenée dans la plage).
    readonly property var styleNumberRanges: ({
        "dockPosition": [0, 2], "maxScale": [1, 2], "zoomRadius": [30, 200],
        "iconSize": [24, 96], "iconSpacing": [0, 32], "dockMargin": [4, 40],
        "dockCrossMargin": [0, 20], "screenEdgeMargin": [0, 32],
        "backgroundOpacity": [0.15, 1], "cornerRadius": [0, 48],
        "borderStrength": [0, 1], "borderLightIntensity": [0, 2],
        "borderWidth": [0.5, 4],
        "glassBlurStrength": [1, 10], "glassBlurFinetune": [0, 10],
        "glassNoise": [0, 20], "glassSaturation": [0.5, 2],
        "glassThickness": [4, 120], "glassIor": [1, 2.5],
        "glassBevel": [0.5, 10], "glassDispersion": [0, 1],
        "glassNormalPower": [0.5, 4], "glassEdgeBlur": [0, 60],
        "glassRimStrength": [0, 2],
        "wallpaperBlur": [0, 1],
        "shadowOpacity": [0, 0.7],
        "highlightStrength": [0, 2],
        "launchAnimation": [0, 1], "magnificationSpring": [20, 60],
        "magnificationDamping": [0.2, 1], "clickBounceHeight": [0, 16],
        "launchBounceHeight": [0, 24], "dockRevealDuration": [60, 400],
        "dockHideDuration": [60, 400], "appGroupPopupDuration": [60, 400],
        "appGroupPopupOvershoot": [0, 3], "folderHoverScale": [1, 1.2],
        "appGroupViewMode": [0, 1],
        "powerButtonPosition": [0, 1], "desktopSwitcherPosition": [0, 1],
        "desktopSwitcherLabelMode": [0, 1]
    })
    readonly property var styleBooleanKeys: [
        "useThemeBackground", "hideOnMaximized", "showFolderView",
        "autoOpenFolderWithOpenDocument", "autoOpenAppGroupWithRunningApp",
        "showTrash", "showRemovableVolumes", "openRemovableVolumesInNewTab",
        "showDesktopSwitcher", "showPowerButton", "showProgressIndicators",
        "showKdeConnectRecentShares", "perDesktopDock",
        "useThemeIndicatorColor", "glassRefraction"
    ]
    // Contenu du Dock (icônes épinglées, groupes, dossiers) : copié et collé
    // avec le style, mais jamais touché par la réinitialisation.
    readonly property var contentListKeys: ["launchers", "appGroups", "folderUrls"]

    function effectiveStyleValue(key) {
        if (key === "borderStrength") {
            return cfg_borderStrength >= 0
                ? cfg_borderStrength : Math.min(1, cfg_borderOpacity / 0.5);
        }
        if (key === "borderLightIntensity") {
            return cfg_borderLightIntensity >= 0
                ? cfg_borderLightIntensity : (cfg_borderFollowMouse ? 1 : 0);
        }
        if (key === "highlightStrength") {
            return cfg_highlightStrength >= 0
                ? cfg_highlightStrength : (cfg_showHighlight ? 1 : 0);
        }
        return configPage["cfg_" + key];
    }

    function collectStyle() {
        var settings = {};
        for (var key in styleNumberRanges) {
            settings[key] = Number(effectiveStyleValue(key));
        }
        for (var b = 0; b < styleBooleanKeys.length; ++b) {
            settings[styleBooleanKeys[b]] =
                Boolean(configPage["cfg_" + styleBooleanKeys[b]]);
        }
        settings["customBackgroundColor"] = String(cfg_customBackgroundColor);
        settings["indicatorColor"] = String(cfg_indicatorColor);
        settings["wallpaperBlurImage"] = String(cfg_wallpaperBlurImage);
        var contents = {
            "folderUrl": String(cfg_folderUrl)
        };
        for (var l = 0; l < contentListKeys.length; ++l) {
            var list = configPage["cfg_" + contentListKeys[l]];
            contents[contentListKeys[l]] = list ? Array.from(list) : [];
        }
        return {
            "format": "macos-dock-style",
            "version": 1,
            "settings": settings,
            "contents": contents
        };
    }

    function showStyleMessage(kind, text) {
        styleMessage.type = kind;
        styleMessage.text = text;
        styleMessage.visible = true;
    }

    function copyStyle() {
        clipboardHelper.text = JSON.stringify(collectStyle());
        clipboardHelper.selectAll();
        clipboardHelper.copy();
        clipboardHelper.deselect();
        showStyleMessage(Kirigami.MessageType.Positive,
            i18n("Style copied: all settings and the Dock icons are in the clipboard."));
    }

    function applyStyle(style) {
        var settings = style.settings || {};
        var contents = style.contents || {};

        for (var key in styleNumberRanges) {
            if (settings[key] === undefined) {
                continue;
            }
            var number = Number(settings[key]);
            if (!Number.isFinite(number)) {
                continue;
            }
            var range = styleNumberRanges[key];
            number = Math.min(range[1], Math.max(range[0], number));
            configPage["cfg_" + key] = number;
        }
        for (var b = 0; b < styleBooleanKeys.length; ++b) {
            var boolKey = styleBooleanKeys[b];
            if (settings[boolKey] !== undefined) {
                configPage["cfg_" + boolKey] = Boolean(settings[boolKey]);
            }
        }
        if (typeof settings["customBackgroundColor"] === "string"
                && /^#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/.test(
                    settings["customBackgroundColor"])) {
            cfg_customBackgroundColor = settings["customBackgroundColor"];
        }
        if (typeof settings["indicatorColor"] === "string"
                && /^#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/.test(
                    settings["indicatorColor"])) {
            cfg_indicatorColor = settings["indicatorColor"];
        }
        if (typeof settings["wallpaperBlurImage"] === "string") {
            cfg_wallpaperBlurImage = settings["wallpaperBlurImage"];
        }
        // Les anciennes cases restent cohérentes avec les curseurs.
        cfg_showHighlight = effectiveStyleValue("highlightStrength") > 0.001;
        cfg_borderFollowMouse =
            effectiveStyleValue("borderLightIntensity") > 0.001;

        if (typeof contents["folderUrl"] === "string") {
            cfg_folderUrl = contents["folderUrl"];
        }
        for (var l = 0; l < contentListKeys.length; ++l) {
            var listKey = contentListKeys[l];
            if (Array.isArray(contents[listKey])) {
                configPage["cfg_" + listKey] = contents[listKey].map(String);
            }
        }
    }

    function pasteStyle() {
        clipboardHelper.text = "";
        clipboardHelper.paste();
        var style = null;
        try {
            style = JSON.parse(clipboardHelper.text);
        } catch (error) {
            style = null;
        }
        clipboardHelper.text = "";
        if (!style || style.format !== "macos-dock-style"
                || typeof style.settings !== "object") {
            showStyleMessage(Kirigami.MessageType.Error,
                i18n("The clipboard does not contain a Dock style. Use “Copy style” first."));
            return;
        }
        applyStyle(style);
        showStyleMessage(Kirigami.MessageType.Positive,
            i18n("Style pasted. Click “Apply” to save it."));
    }

    function resetSettings() {
        var keys = Object.keys(styleNumberRanges).concat(
            styleBooleanKeys, ["customBackgroundColor", "indicatorColor",
                "wallpaperBlurImage"]);
        for (var i = 0; i < keys.length; ++i) {
            var key = keys[i];
            var fallback = configPage["cfg_" + key + "Default"];
            if (fallback !== undefined) {
                configPage["cfg_" + key] = fallback;
            }
        }
        // Les curseurs ont -1 (« jamais réglé ») comme valeur par défaut
        // technique : on les remet explicitement à leur valeur d'origine.
        cfg_highlightStrength = 1.0;
        cfg_borderStrength = 0.5;
        cfg_borderLightIntensity = 1.0;
        cfg_borderFollowMouse = true;
        cfg_showHighlight = true;
        cfg_glassManage = false;
        showStyleMessage(Kirigami.MessageType.Information,
            i18n("Settings reset. Dock icons were kept. Click “Apply” to save."));
    }

    // Presse-papiers : un TextEdit invisible est le moyen le plus simple
    // d'accéder au presse-papiers du système depuis QML.
    TextEdit {
        id: clipboardHelper

        visible: false
        width: 0
        height: 0
    }

    Kirigami.PromptDialog {
        id: resetDialog

        title: i18n("Reset settings")
        subtitle: i18n("All settings of every tab will return to their default values. The icons kept in the Dock are not affected.")
        standardButtons: Kirigami.Dialog.Ok | Kirigami.Dialog.Cancel
        onAccepted: configPage.resetSettings()
    }


    ColumnLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Kirigami.Units.largeSpacing

        QQC2.TabBar {
            id: tabBar

            Layout.fillWidth: true

            QQC2.TabButton {
                text: i18n("Appearance")
            }

            QQC2.TabButton {
                text: i18n("Glass")
            }

            QQC2.TabButton {
                text: i18n("Animation")
            }

            QQC2.TabButton {
                text: i18n("Dock items")
            }

            QQC2.TabButton {
                text: i18n("Miscellaneous")
            }
        }

        StackLayout {
            id: tabStack

            Layout.fillWidth: true
            // Chaque onglet a sa propre hauteur : on ne réserve pas celle du
            // plus haut.
            Layout.preferredHeight: tabStack.children[tabStack.currentIndex]
                ? tabStack.children[tabStack.currentIndex].implicitHeight : 0
            currentIndex: tabBar.currentIndex

            Kirigami.FormLayout {
                QQC2.ComboBox {
                    id: dockPositionCombo

                    Kirigami.FormData.label: i18n("Dock position:")
                    model: [i18n("Bottom"), i18n("Left"), i18n("Right")]
                }

                RowLayout {
                    Kirigami.FormData.label: i18n("Icon size:")

                    QQC2.Slider {
                        id: iconSizeSlider
                        Layout.fillWidth: true
                        from: 24
                        to: 96
                        stepSize: 2
                        live: true
                    }

                    QQC2.Label {
                        text: Math.round(iconSizeSlider.value) + i18n(" px")
                    }
                }

                RowLayout {
                    Kirigami.FormData.label: i18n("Icon spacing:")

                    QQC2.Slider {
                        id: iconSpacingSlider
                        Layout.fillWidth: true
                        from: 0
                        to: 32
                        stepSize: 1
                        live: true
                    }

                    QQC2.Label {
                        text: Math.round(iconSpacingSlider.value) + i18n(" px")
                    }
                }

                QQC2.Label {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    text: i18n("The Dock grows with the spacing. If it would no longer fit on the screen, the spacing is reduced automatically so the icons never leave the Dock.")
                    opacity: 0.78
                }

                RowLayout {
                    Kirigami.FormData.label: i18n("Left/right margin:")

                    QQC2.Slider {
                        id: dockMarginSlider
                        Layout.fillWidth: true
                        from: 4
                        to: 40
                        stepSize: 1
                        live: true
                    }

                    QQC2.Label {
                        text: Math.round(dockMarginSlider.value) + i18n(" px")
                    }
                }

                RowLayout {
                    Kirigami.FormData.label: i18n("Top/bottom margin:")

                    QQC2.Slider {
                        id: dockCrossMarginSlider
                        Layout.fillWidth: true
                        from: 0
                        to: 20
                        stepSize: 1
                        live: true
                    }

                    QQC2.Label {
                        text: Math.round(dockCrossMarginSlider.value) + i18n(" px")
                    }
                }

                RowLayout {
                    Kirigami.FormData.label: i18n("Distance from screen edge:")

                    QQC2.Slider {
                        id: screenEdgeMarginSlider
                        Layout.fillWidth: true
                        from: 0
                        to: 32
                        stepSize: 1
                        live: true
                    }

                    QQC2.Label {
                        text: Math.round(screenEdgeMarginSlider.value) + i18n(" px")
                    }
                }

                RowLayout {
                    Kirigami.FormData.label: i18n("Background opacity:")

                    QQC2.Slider {
                        id: backgroundOpacitySlider
                        Layout.fillWidth: true
                        from: 0.15
                        to: 1.0
                        stepSize: 0.05
                        live: true
                    }

                    QQC2.Label {
                        text: Math.round(backgroundOpacitySlider.value * 100) + "%"
                    }
                }

                QQC2.CheckBox {
                    id: useThemeBackgroundCheckBox

                    Kirigami.FormData.label: i18n("Background:")
                    text: i18n("Use color from the Plasma theme")
                }

                KQuickControls.ColorButton {
                    id: backgroundColorButton

                    Kirigami.FormData.label: i18n("Custom background color:")
                    enabled: !useThemeBackgroundCheckBox.checked
                    showAlphaChannel: false
                    dialogTitle: i18n("Choose Dock Background Color")
                }

                RowLayout {
                    Kirigami.FormData.label: i18n("Corner radius:")

                    QQC2.Slider {
                        id: cornerRadiusSlider
                        Layout.fillWidth: true
                        from: 0
                        to: 48
                        stepSize: 1
                        live: true
                    }

                    QQC2.Label {
                        text: Math.round(cornerRadiusSlider.value) + i18n(" px")
                    }
                }

                RowLayout {
                    Kirigami.FormData.label: i18n("Border intensity:")

                    QQC2.Slider {
                        id: borderStrengthSlider
                        Layout.fillWidth: true
                        from: 0
                        to: 1
                        stepSize: 0.02
                        live: true
                        value: configPage.cfg_borderStrength >= 0
                            ? configPage.cfg_borderStrength
                            : Math.min(1, configPage.cfg_borderOpacity / 0.5)
                        onMoved: configPage.cfg_borderStrength = value
                    }

                    QQC2.Label {
                        text: Math.round(borderStrengthSlider.value * 100) + "%"
                    }
                }

                QQC2.Label {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    text: i18n("Brightness of the border: 100 % is a solid outline, 0 % removes it.")
                    opacity: 0.78
                }

                RowLayout {
                    Kirigami.FormData.label: i18n("Border width:")

                    QQC2.Slider {
                        id: borderWidthSlider
                        Layout.fillWidth: true
                        from: 0.5
                        to: 4
                        stepSize: 0.5
                        live: true
                    }

                    QQC2.Label {
                        text: borderWidthSlider.value.toFixed(1) + i18n(" px")
                    }
                }

                RowLayout {
                    Kirigami.FormData.label: i18n("Border light:")

                    QQC2.Slider {
                        id: borderLightSlider
                        Layout.fillWidth: true
                        from: 0
                        to: 2
                        stepSize: 0.05
                        live: true
                        value: configPage.cfg_borderLightIntensity >= 0
                            ? configPage.cfg_borderLightIntensity
                            : (configPage.cfg_borderFollowMouse ? 1 : 0)
                        onMoved: {
                            configPage.cfg_borderLightIntensity = value;
                            configPage.cfg_borderFollowMouse = value > 0.001;
                        }
                    }

                    QQC2.Label {
                        text: Math.round(borderLightSlider.value * 100) + "%"
                    }
                }

                QQC2.Label {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    text: i18n("Intensity of the light that follows the mouse along the border: 100 % is the original look, 0 % turns the light off.")
                    opacity: 0.78
                }

                QQC2.CheckBox {
                    id: wallpaperBlurCheckBox

                    Kirigami.FormData.label: i18n("Background blur:")
                    text: i18n("Blur what is behind the Dock")
                    onToggled: configPage.cfg_wallpaperBlur = checked ? 1 : 0
                }

                // Garde la case synchronisée (réinitialisation, style collé).
                Binding {
                    target: wallpaperBlurCheckBox
                    property: "checked"
                    value: configPage.cfg_wallpaperBlur > 0.001
                }

                QQC2.Label {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    text: i18n("Blurs everything behind the Dock, windows included, using KWin's blur effect. KWin sets the strength for all windows (System Settings, Window Management, Desktop Effects, Blur), and that effect must be enabled.")
                    opacity: 0.78
                }

                QQC2.Label {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    text: i18n("The border takes the colors of the wallpaper. If it stays white, choose the wallpaper image yourself below.")
                    opacity: 0.78
                }

                RowLayout {
                    Kirigami.FormData.label: i18n("Wallpaper image:")

                    QQC2.TextField {
                        id: wallpaperBlurImageField
                        Layout.fillWidth: true
                        placeholderText: i18n("Automatic")
                    }

                    QQC2.Button {
                        text: i18n("Choose…")
                        icon.name: "document-open"
                        onClicked: wallpaperImageDialog.open()
                    }

                    QQC2.Button {
                        icon.name: "edit-clear"
                        enabled: wallpaperBlurImageField.text.length > 0
                        onClicked: wallpaperBlurImageField.text = ""

                        QQC2.ToolTip.visible: hovered
                        QQC2.ToolTip.text: i18n("Detect the wallpaper automatically")
                    }
                }

                FileDialog {
                    id: wallpaperImageDialog

                    title: i18n("Choose the wallpaper image")
                    nameFilters: [i18n("Images (*.png *.jpg *.jpeg *.webp *.bmp *.avif)")]
                    onAccepted: wallpaperBlurImageField.text =
                        String(selectedFile)
                }

                RowLayout {
                    Kirigami.FormData.label: i18n("Glass highlight:")

                    QQC2.Slider {
                        id: highlightStrengthSlider
                        Layout.fillWidth: true
                        from: 0
                        to: 2
                        stepSize: 0.05
                        live: true
                        value: configPage.cfg_highlightStrength >= 0
                            ? configPage.cfg_highlightStrength
                            : (configPage.cfg_showHighlight ? 1 : 0)
                        onMoved: {
                            configPage.cfg_highlightStrength = value;
                            configPage.cfg_showHighlight = value > 0.001;
                        }
                    }

                    QQC2.Label {
                        text: Math.round(highlightStrengthSlider.value * 100) + "%"
                    }
                }

                Item {
                    Kirigami.FormData.label: i18n("Preview:")
                    Layout.fillWidth: true
                    implicitHeight: 64

                    DockBackground {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(parent.width, 280)
                        height: 52
                        surfaceOpacity: backgroundOpacitySlider.value
                        useThemeColor: useThemeBackgroundCheckBox.checked
                        customColor: backgroundColorButton.color
                        requestedRadius: cornerRadiusSlider.value
                        id: previewBackground
                        borderStrength: borderStrengthSlider.value
                        borderWidth: borderWidthSlider.value
                        showShadow: false
                        highlightStrength: highlightStrengthSlider.value
                        lightActive: previewHover.hovered
                        lightIntensity: borderLightSlider.value
                        lightX: previewHover.point.position.x
                            - previewBackground.x
                        lightY: previewHover.point.position.y
                            - previewBackground.y
                    }

                    HoverHandler {
                        id: previewHover
                    }
                }
            }

            // ---------------------------------------------------------------
            // Onglet Glass : flou et verre liquide (effet KWin « Glass »)
            // ---------------------------------------------------------------
            Kirigami.FormLayout {
                QQC2.CheckBox {
                    id: glassBlurCheckBox

                    Kirigami.FormData.label: i18n("Behind the Dock:")
                    text: i18n("Blur what is behind the Dock")
                    onToggled: configPage.cfg_wallpaperBlur = checked ? 1 : 0
                }

                // Même réglage que la case de l'onglet Apparence.
                Binding {
                    target: glassBlurCheckBox
                    property: "checked"
                    value: configPage.cfg_wallpaperBlur > 0.001
                }

                QQC2.CheckBox {
                    id: glassManageCheckBox

                    Kirigami.FormData.label: i18n("Glass effect:")
                    text: i18n("Control the KWin Glass effect from the Dock")
                }

                QQC2.Label {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    text: i18n("These settings drive the KWin “Glass” effect (the liquid-glass-kde project), which must be installed. The effect is global to KWin: panels and menus are affected too. Nothing is written to KWin unless this box is checked, and only when a value changes. The starting values are the defaults of the liquid-glass-kde project.")
                    opacity: 0.78
                }

                Kirigami.Separator {
                    Kirigami.FormData.isSection: true
                    Kirigami.FormData.label: i18n("Blur")
                }

                RowLayout {
                    Kirigami.FormData.label: i18n("Blur strength:")
                    enabled: glassManageCheckBox.checked

                    QQC2.Slider {
                        id: glassBlurStrengthSlider
                        Layout.fillWidth: true
                        from: 1
                        to: 10
                        stepSize: 1
                        live: true
                    }

                    QQC2.Label {
                        text: Math.round(glassBlurStrengthSlider.value)
                    }
                }

                RowLayout {
                    Kirigami.FormData.label: i18n("Blur fineness:")
                    enabled: glassManageCheckBox.checked

                    QQC2.Slider {
                        id: glassBlurFinetuneSlider
                        Layout.fillWidth: true
                        from: 0
                        to: 10
                        stepSize: 1
                        live: true
                    }

                    QQC2.Label {
                        text: Math.round(glassBlurFinetuneSlider.value)
                    }
                }

                RowLayout {
                    Kirigami.FormData.label: i18n("Grain:")
                    enabled: glassManageCheckBox.checked

                    QQC2.Slider {
                        id: glassNoiseSlider
                        Layout.fillWidth: true
                        from: 0
                        to: 20
                        stepSize: 1
                        live: true
                    }

                    QQC2.Label {
                        text: Math.round(glassNoiseSlider.value)
                    }
                }

                RowLayout {
                    Kirigami.FormData.label: i18n("Saturation:")
                    enabled: glassManageCheckBox.checked

                    QQC2.Slider {
                        id: glassSaturationSlider
                        Layout.fillWidth: true
                        from: 0.5
                        to: 2
                        stepSize: 0.05
                        live: true
                    }

                    QQC2.Label {
                        text: Math.round(glassSaturationSlider.value * 100) + "%"
                    }
                }

                QQC2.Label {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    text: i18n("The blur strength, fineness and grain apply to docks only. The saturation applies to everything the effect blurs.")
                    opacity: 0.78
                }

                Kirigami.Separator {
                    Kirigami.FormData.isSection: true
                    Kirigami.FormData.label: i18n("Glass")
                }

                QQC2.CheckBox {
                    id: glassRefractionCheckBox

                    Kirigami.FormData.label: i18n("Refraction:")
                    text: i18n("Bend what is behind the edges, like a lens")
                    enabled: glassManageCheckBox.checked
                }

                RowLayout {
                    Kirigami.FormData.label: i18n("Edge thickness:")
                    enabled: glassManageCheckBox.checked
                        && glassRefractionCheckBox.checked

                    QQC2.Slider {
                        id: glassThicknessSlider
                        Layout.fillWidth: true
                        from: 4
                        to: 120
                        stepSize: 1
                        live: true
                    }

                    QQC2.Label {
                        text: Math.round(glassThicknessSlider.value) + i18n(" px")
                    }
                }

                RowLayout {
                    Kirigami.FormData.label: i18n("Refraction index:")
                    enabled: glassManageCheckBox.checked
                        && glassRefractionCheckBox.checked

                    QQC2.Slider {
                        id: glassIorSlider
                        Layout.fillWidth: true
                        from: 1
                        to: 2.5
                        stepSize: 0.05
                        live: true
                    }

                    QQC2.Label {
                        text: glassIorSlider.value.toFixed(2)
                    }
                }

                RowLayout {
                    Kirigami.FormData.label: i18n("Lens strength:")
                    enabled: glassManageCheckBox.checked
                        && glassRefractionCheckBox.checked

                    QQC2.Slider {
                        id: glassBevelSlider
                        Layout.fillWidth: true
                        from: 0.5
                        to: 10
                        stepSize: 0.1
                        live: true
                    }

                    QQC2.Label {
                        text: glassBevelSlider.value.toFixed(1)
                    }
                }

                RowLayout {
                    Kirigami.FormData.label: i18n("Edge profile:")
                    enabled: glassManageCheckBox.checked
                        && glassRefractionCheckBox.checked

                    QQC2.Slider {
                        id: glassNormalPowerSlider
                        Layout.fillWidth: true
                        from: 0.5
                        to: 4
                        stepSize: 0.1
                        live: true
                    }

                    QQC2.Label {
                        text: glassNormalPowerSlider.value.toFixed(1)
                    }
                }

                RowLayout {
                    Kirigami.FormData.label: i18n("Colored fringes:")
                    enabled: glassManageCheckBox.checked
                        && glassRefractionCheckBox.checked

                    QQC2.Slider {
                        id: glassDispersionSlider
                        Layout.fillWidth: true
                        from: 0
                        to: 1
                        stepSize: 0.05
                        live: true
                    }

                    QQC2.Label {
                        text: Math.round(glassDispersionSlider.value * 100) + "%"
                    }
                }

                RowLayout {
                    Kirigami.FormData.label: i18n("Edge blur:")
                    enabled: glassManageCheckBox.checked

                    QQC2.Slider {
                        id: glassEdgeBlurSlider
                        Layout.fillWidth: true
                        from: 0
                        to: 60
                        stepSize: 1
                        live: true
                    }

                    QQC2.Label {
                        text: Math.round(glassEdgeBlurSlider.value) + i18n(" px")
                    }
                }

                RowLayout {
                    Kirigami.FormData.label: i18n("Edge highlight:")
                    enabled: glassManageCheckBox.checked

                    QQC2.Slider {
                        id: glassRimStrengthSlider
                        Layout.fillWidth: true
                        from: 0
                        to: 2
                        stepSize: 0.05
                        live: true
                    }

                    QQC2.Label {
                        text: Math.round(glassRimStrengthSlider.value * 100) + "%"
                    }
                }

                QQC2.Label {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    text: i18n("The edge blur needs the patched Glass effect of the liquid-glass-kde project. The light that follows the mouse around the Dock border is the Dock's own (Appearance tab).")
                    opacity: 0.78
                }
            }

            Kirigami.FormLayout {
                RowLayout {
                    Kirigami.FormData.label: i18n("Maximum magnification:")

                    QQC2.Slider {
                        id: maxScaleSlider
                        Layout.fillWidth: true
                        from: 1.0
                        to: 2.0
                        stepSize: 0.05
                        live: true
                    }

                    QQC2.Label {
                        text: maxScaleSlider.value.toFixed(2) + "×"
                    }
                }

                RowLayout {
                    Kirigami.FormData.label: i18n("Magnification radius:")

                    QQC2.Slider {
                        id: zoomRadiusSlider
                        Layout.fillWidth: true
                        from: 30
                        to: 200
                        stepSize: 5
                        live: true
                    }

                    QQC2.Label {
                        text: Math.round(zoomRadiusSlider.value) + i18n(" px")
                    }
                }

                QQC2.ComboBox {
                    id: launchAnimationCombo

                    Kirigami.FormData.label: i18n("Launch animation:")
                    Layout.fillWidth: true
                    model: [i18n("None"), i18n("Bounce")]
                }

                QQC2.Label {
                    Kirigami.FormData.label: i18n("Magnification dynamics:")
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    text: i18n("Response controls speed; damping controls how firmly the magnification settles without oscillating.")
                    opacity: 0.78
                }

                RowLayout {
                    Kirigami.FormData.label: i18n("Magnification response:")

                    QQC2.Slider {
                        id: magnificationSpringSlider
                        Layout.fillWidth: true
                        from: 20.0
                        to: 60.0
                        stepSize: 1.0
                        live: true
                    }

                    QQC2.Label {
                        text: magnificationSpringSlider.value.toFixed(1)
                    }
                }

                RowLayout {
                    Kirigami.FormData.label: i18n("Magnification damping:")

                    QQC2.Slider {
                        id: magnificationDampingSlider
                        Layout.fillWidth: true
                        from: 0.2
                        to: 1.0
                        stepSize: 0.05
                        live: true
                    }

                    QQC2.Label {
                        text: magnificationDampingSlider.value.toFixed(2)
                    }
                }

                RowLayout {
                    Kirigami.FormData.label: i18n("Click bounce height:")

                    QQC2.Slider {
                        id: clickBounceHeightSlider
                        Layout.fillWidth: true
                        from: 0
                        to: 16
                        stepSize: 1
                        live: true
                    }

                    QQC2.Label {
                        text: Math.round(clickBounceHeightSlider.value) + i18n(" px")
                    }
                }

                RowLayout {
                    Kirigami.FormData.label: i18n("Launch bounce height:")

                    QQC2.Slider {
                        id: launchBounceHeightSlider
                        Layout.fillWidth: true
                        from: 0
                        to: 24
                        stepSize: 1
                        live: true
                    }

                    QQC2.Label {
                        text: Math.round(launchBounceHeightSlider.value) + i18n(" px")
                    }
                }

                RowLayout {
                    Kirigami.FormData.label: i18n("Show Dock duration:")

                    QQC2.Slider {
                        id: dockRevealDurationSlider
                        Layout.fillWidth: true
                        from: 60
                        to: 400
                        stepSize: 10
                        live: true
                    }

                    QQC2.Label {
                        text: Math.round(dockRevealDurationSlider.value) + i18n(" ms")
                    }
                }

                RowLayout {
                    Kirigami.FormData.label: i18n("Hide Dock duration:")

                    QQC2.Slider {
                        id: dockHideDurationSlider
                        Layout.fillWidth: true
                        from: 60
                        to: 400
                        stepSize: 10
                        live: true
                    }

                    QQC2.Label {
                        text: Math.round(dockHideDurationSlider.value) + i18n(" ms")
                    }
                }

                RowLayout {
                    Kirigami.FormData.label: i18n("Group popup duration:")

                    QQC2.Slider {
                        id: appGroupPopupDurationSlider
                        Layout.fillWidth: true
                        from: 60
                        to: 400
                        stepSize: 10
                        live: true
                    }

                    QQC2.Label {
                        text: Math.round(appGroupPopupDurationSlider.value)
                            + i18n(" ms")
                    }
                }

                RowLayout {
                    Kirigami.FormData.label: i18n("Group popup bounce:")

                    QQC2.Slider {
                        id: appGroupPopupOvershootSlider
                        Layout.fillWidth: true
                        from: 0.0
                        to: 3.0
                        stepSize: 0.05
                        live: true
                    }

                    QQC2.Label {
                        text: appGroupPopupOvershootSlider.value.toFixed(2)
                    }
                }

                RowLayout {
                    Kirigami.FormData.label: i18n("Folder hover zoom:")

                    QQC2.Slider {
                        id: folderHoverScaleSlider
                        Layout.fillWidth: true
                        from: 1.0
                        to: 1.2
                        stepSize: 0.01
                        live: true
                    }

                    QQC2.Label {
                        text: Math.round((folderHoverScaleSlider.value - 1) * 100)
                            + "%"
                    }
                }
            }

            Kirigami.FormLayout {
                QQC2.CheckBox {
                    id: useThemeIndicatorCheckBox

                    Kirigami.FormData.label: i18n("Active app indicator:")
                    text: i18n("Use the highlight color of the Plasma theme")
                }

                KQuickControls.ColorButton {
                    id: indicatorColorButton

                    Kirigami.FormData.label: i18n("Indicator color:")
                    enabled: !useThemeIndicatorCheckBox.checked
                    showAlphaChannel: false
                    dialogTitle: i18n("Choose the Active App Indicator Color")
                }

                ColumnLayout {
                    Kirigami.FormData.label: i18n("Utilities:")

                    QQC2.CheckBox {
                        id: showFolderViewCheckBox
                        text: i18n("Show folder view")
                    }

                    QQC2.CheckBox {
                        id: autoOpenFolderWithOpenDocumentCheckBox
                        text: i18n("Open folder on hover when a document from it is open")
                        leftPadding: Kirigami.Units.largeSpacing + Kirigami.Units.smallSpacing
                        enabled: showFolderViewCheckBox.checked
                        visible: showFolderViewCheckBox.checked
                    }

                    QQC2.CheckBox {
                        id: autoOpenAppGroupWithRunningAppCheckBox
                        text: i18n("Open app group on hover when one of its apps is running")
                    }

                    QQC2.CheckBox {
                        id: showTrashCheckBox
                        text: i18n("Show Trash")
                    }

                    QQC2.CheckBox {
                        id: showRemovableVolumesCheckBox
                        text: i18n("Show removable drives")
                    }

                    QQC2.CheckBox {
                        id: openRemovableVolumesInNewTabCheckBox
                        text: i18n("Open removable drives in a new tab")
                        leftPadding: Kirigami.Units.largeSpacing + Kirigami.Units.smallSpacing
                        enabled: showRemovableVolumesCheckBox.checked
                        visible: showRemovableVolumesCheckBox.checked
                    }

                    QQC2.CheckBox {
                        id: showDesktopSwitcherCheckBox
                        text: i18n("Show desktop switcher")
                    }

                    QQC2.CheckBox {
                        id: showPowerButtonCheckBox
                        text: i18n("Show power button")
                    }
                }

                Item {
                    Kirigami.FormData.isSection: true
                    Kirigami.FormData.label: i18n("View layouts")
                }

                QQC2.ComboBox {
                    id: appGroupViewModeCombo

                    Kirigami.FormData.label: i18n("App group layout:")
                    Layout.fillWidth: true
                    model: [i18n("List View"), i18n("Grid View")]
                }

                QQC2.ComboBox {
                    id: powerButtonPositionCombo

                    Kirigami.FormData.label: i18n("Power button position:")
                    Layout.fillWidth: true
                    enabled: showPowerButtonCheckBox.checked
                    model: [i18n("Left"), i18n("Right")]
                }

                QQC2.ComboBox {
                    id: desktopSwitcherPositionCombo

                    Kirigami.FormData.label: i18n("Desktop switcher position:")
                    Layout.fillWidth: true
                    enabled: showDesktopSwitcherCheckBox.checked
                    model: [i18n("Left"), i18n("Right")]
                }

                QQC2.ComboBox {
                    id: desktopSwitcherLabelModeCombo

                    Kirigami.FormData.label: i18n("Desktop labels:")
                    Layout.fillWidth: true
                    enabled: showDesktopSwitcherCheckBox.checked
                    model: [i18n("Numbers"), i18n("Desktop names")]
                }

                QQC2.Label {
                    Kirigami.FormData.label: i18n("Desktop names:")
                    Layout.fillWidth: true
                    visible: showDesktopSwitcherCheckBox.checked
                        && desktopSwitcherLabelModeCombo.currentIndex === 1
                    wrapMode: Text.WordWrap
                    text: i18n("The names configured in Plasma, including custom names, are shown.")
                    opacity: 0.78
                }

                RowLayout {
                    Kirigami.FormData.label: i18n("Default folder:")
                    Layout.fillWidth: true
                    enabled: showFolderViewCheckBox.checked

                    QQC2.TextField {
                        id: folderUrlField

                        Layout.fillWidth: true
                        placeholderText: StandardPaths.writableLocation(
                            StandardPaths.DownloadLocation).toString()
                        selectByMouse: true
                    }

                    QQC2.Button {
                        icon.name: "document-open-folder"
                        text: i18n("Choose…")
                        onClicked: folderDialog.open()

                        QQC2.ToolTip.visible: hovered
                        QQC2.ToolTip.text: i18n("Choose folder")
                    }
                }

                QQC2.Label {
                    Kirigami.FormData.label: i18n("Folder view:")
                    Layout.fillWidth: true
                    visible: showFolderViewCheckBox.checked
                    wrapMode: Text.WordWrap
                    text: i18n("If no folder is selected, the Downloads folder is used. Drag folders from the file manager onto the Dock to add more stacks.")
                    opacity: 0.78
                }

                FolderDialog {
                    id: folderDialog

                    title: i18n("Choose Folder for the Dock")
                    currentFolder: folderUrlField.text.length > 0
                        ? folderUrlField.text
                        : StandardPaths.writableLocation(StandardPaths.DownloadLocation)
                    onAccepted: folderUrlField.text = selectedFolder.toString()
                }

                QQC2.CheckBox {
                    id: perDesktopDockCheckBox

                    Kirigami.FormData.label: i18n("Virtual desktops:")
                    text: i18n("Each desktop has its own Dock (only show windows of the current desktop)")
                    checked: configPage.cfg_perDesktopDock
                    onToggled: configPage.cfg_perDesktopDock = checked
                }
            }

            Kirigami.FormLayout {
                QQC2.CheckBox {
                    id: hideOnMaximizedCheckBox

                    Kirigami.FormData.label: i18n("Window behavior:")
                    text: i18n("Automatically hide when a window is maximized")
                }

                QQC2.CheckBox {
                    id: showProgressIndicatorsCheckBox

                    Kirigami.FormData.label: i18n("Integrations:")
                    text: i18n("Show download and job progress indicators")
                }

                QQC2.CheckBox {
                    id: showKdeConnectRecentSharesCheckBox

                    text: i18n("Show KDE Connect recent shares")
                }

                Item {
                    Kirigami.FormData.isSection: true
                    Kirigami.FormData.label: i18n("Applications")
                }

                QQC2.Label {
                    Kirigami.FormData.label: i18n("Dock content:")
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    text: i18n("Running applications appear automatically. Right-click an icon to keep it in the Dock, unpin it, or move it. The widget does not include fixed launchers.")
                    opacity: 0.78
                }

                QQC2.Label {
                    Kirigami.FormData.label: i18n("Standalone placement:")
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    text: i18n("Place this widget directly on the Plasma desktop, not inside a panel. The invisible desktop widget only stores settings; the Dock itself uses a separate transparent window anchored to the selected screen edge and centered along it. BetterBlur can blur that window directly.")
                    opacity: 0.78
                }
                Item {
                    Kirigami.FormData.isSection: true
                    Kirigami.FormData.label: i18n("Style")
                }

                RowLayout {
                    Kirigami.FormData.label: i18n("Style:")
                    Layout.fillWidth: true

                    QQC2.Button {
                        icon.name: "edit-copy"
                        text: i18n("Copy style")
                        onClicked: configPage.copyStyle()

                        QQC2.ToolTip.visible: hovered
                        QQC2.ToolTip.text: i18n("Copy all settings of every tab and the icons kept in the Dock")
                    }

                    QQC2.Button {
                        icon.name: "edit-paste"
                        text: i18n("Paste style")
                        onClicked: configPage.pasteStyle()

                        QQC2.ToolTip.visible: hovered
                        QQC2.ToolTip.text: i18n("Apply a style copied earlier, including the Dock icons")
                    }

                    QQC2.Button {
                        icon.name: "edit-reset"
                        text: i18n("Reset settings")
                        onClicked: resetDialog.open()

                        QQC2.ToolTip.visible: hovered
                        QQC2.ToolTip.text: i18n("Restore the default settings of every tab (Dock icons are kept)")
                    }
                }

                Kirigami.InlineMessage {
                    id: styleMessage

                    Layout.fillWidth: true
                    visible: false
                    showCloseButton: true
                }
            }
        }
    }
}
