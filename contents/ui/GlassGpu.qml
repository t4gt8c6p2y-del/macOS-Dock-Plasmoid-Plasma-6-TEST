pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects

// Le verre du Dock calculé par la carte graphique, à chaque image affichée.
//
// Ce qui se trouve derrière le Dock est reconstitué dans une « scène » : le
// fond d'écran à sa place sur l'écran, puis les fenêtres qui passent derrière,
// capturées en direct (flux PipeWire, comme les aperçus des icônes). Cette
// scène est floutée par MultiEffect ; pour le Liquid Glass, l'image floutée est
// ensuite déformée sur les bords par un petit shader (glassrefract.frag.qsb,
// compilé par install.sh). Il n'y a aucun aller-retour vers le processeur : une
// fenêtre qui bouge derrière le Dock bouge dans le verre à l'image suivante.
// Rien ne passe par KWin.
Item {
    id: gpu

    // Fenêtres derrière le Dock : [{ id, x, y, w, h }], du dessous au dessus,
    // en coordonnées écran (fournies par DockBackground via GlassLayer).
    property var windows: []
    // Position du Dock à l'écran (coin supérieur gauche).
    property real originX: 0
    property real originY: 0
    // Réglages du verre (voir DockBackground.glassConfig).
    property var cfg: ({})

    // Vrai quand le fond d'écran est chargé : le verre peut être affiché.
    readonly property bool ready: wallpaper.status === Image.Ready
    // Vrai si le shader du Liquid Glass n'a pas pu être chargé : GlassLayer
    // bascule alors sur le calcul par le processeur.
    property bool shaderFailed: false
    // Vrai quand la fenêtre du Dock est affichée : sinon les flux de capture
    // restent éteints.
    readonly property bool windowShown: Window.window !== null
        && Window.window !== undefined && Window.window.visible

    // Le verre n'apparaît qu'une fois les fenêtres derrière le Dock capturées
    // (sinon on verrait un instant le fond d'écran seul, par exemple quand le
    // Dock réapparaît au-dessus d'une fenêtre agrandie). Au bout de 1,5 s, il
    // s'affiche de toute façon.
    readonly property bool windowsReady: liveLoader.item
        ? (liveLoader.item.evaluated && liveLoader.item.pendingCount === 0)
        : true
    property bool settleTimedOut: false
    property bool settled: false
    readonly property bool glassReady: ready && windowShown
        && (windowsReady || settleTimedOut)
    onGlassReadyChanged: {
        if (glassReady) {
            settled = true;
        }
    }
    onWindowShownChanged: {
        if (!windowShown) {
            settled = false;
            settleTimedOut = false;
        }
    }
    // Jamais tout à fait 0 : un élément transparent n'est plus dessiné, et la
    // scène des fenêtres ne se mettrait plus à jour.
    opacity: settled || glassReady ? 1.0 : 0.01
    Behavior on opacity {
        NumberAnimation { duration: 160 }
    }

    Timer {
        interval: 1500
        running: gpu.windowShown && !gpu.settled && !gpu.settleTimedOut
        onTriggered: gpu.settleTimedOut = true
    }

    readonly property bool refraction: Boolean(cfg.refraction)
    // Flou : 0..1 pour MultiEffect (1 = 64 pixels).
    readonly property real blurAmount:
        Math.min(1, Math.max(0, Number(cfg.blur || 0) / 64))
    readonly property real cornerRadius: Number(cfg.radius || 0)
    readonly property real thickness: Math.max(2, Number(cfg.thickness || 16))
    readonly property real lensStrength: Number(cfg.strength === undefined
        ? 1 : cfg.strength)
    readonly property var wallpaperInfo: ({
        "source": String(cfg.source || ""),
        "fillMode": cfg.fillMode === undefined ? 2 : Number(cfg.fillMode),
        "width": Number(cfg.screenWidth || 0),
        "height": Number(cfg.screenHeight || 0)
    })

    // Marge autour du Dock : le flou et la réfraction lisent au-delà des bords.
    readonly property real pad: Math.min(220, Math.max(8,
        Math.ceil(blurAmount * 64 * 1.5) + 8
        + (refraction ? Math.ceil(thickness * lensStrength * 1.6) : 0)))

    function fileUrl(path) {
        var text = String(path || "");
        if (text.length > 0 && text.indexOf("://") < 0
                && text.charAt(0) === "/") {
            return "file://" + text;
        }
        return text;
    }

    // --- La scène : le fond d'écran et les fenêtres ---------------------------
    // La scène doit rester « visible » pour Qt : un flux de capture PipeWire
    // s'éteint dès que son élément est invisible, et les fenêtres ne seraient
    // alors jamais mises à jour. On la range donc très loin hors de la fenêtre
    // du Dock (on ne voit jamais cette copie, seulement son image floutée).
    Item {
        id: sceneContent

        x: -gpu.pad - 100000
        y: -gpu.pad
        width: gpu.width + 2 * gpu.pad
        height: gpu.height + 2 * gpu.pad
        // MultiEffect exige une source « en couche » (layer).
        layer.enabled: true
        layer.smooth: true

        Image {
            id: wallpaper

            x: gpu.pad - gpu.originX
            y: gpu.pad - gpu.originY
            width: gpu.wallpaperInfo.width
            height: gpu.wallpaperInfo.height
            source: gpu.fileUrl(gpu.wallpaperInfo.source)
            fillMode: gpu.wallpaperInfo.fillMode
            asynchronous: true
            cache: true
            smooth: true
            sourceSize.width: gpu.wallpaperInfo.width
            sourceSize.height: gpu.wallpaperInfo.height
        }

        // Les fenêtres, capturées en direct et posées à leur place réelle. Chargé
        // à part : si le module PipeWire manquait, le verre garderait le fond
        // d'écran seul.
        Loader {
            id: liveLoader

            anchors.fill: parent
            source: "LiveWindows.qml"
            onLoaded: {
                item.windows = Qt.binding(function() {
                    return gpu.windows;
                });
                item.regionX = Qt.binding(function() {
                    return gpu.originX - gpu.pad;
                });
                item.regionY = Qt.binding(function() {
                    return gpu.originY - gpu.pad;
                });
                item.running = Qt.binding(function() {
                    return gpu.windowShown;
                });
            }
        }
    }

    // Masque aux coins arrondis du Dock (même taille que la scène).
    Item {
        id: maskItem

        x: -gpu.pad
        y: -gpu.pad
        width: sceneContent.width
        height: sceneContent.height
        layer.enabled: true
        visible: false

        Rectangle {
            anchors.fill: parent
            anchors.margins: gpu.pad
            radius: gpu.cornerRadius
            color: "black"
        }
    }

    // --- Le flou ----------------------------------------------------------------
    // Sans Liquid Glass, c'est aussi la forme finale (masque arrondi). Avec le
    // Liquid Glass, il alimente le shader et n'est pas affiché lui-même.
    MultiEffect {
        id: blurred

        x: -gpu.pad
        y: -gpu.pad
        width: sceneContent.width
        height: sceneContent.height
        source: sceneContent
        autoPaddingEnabled: false
        blurEnabled: gpu.blurAmount > 0.001
        blur: gpu.blurAmount
        blurMax: 64
        maskEnabled: !gpu.refraction
        maskSource: maskItem
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1.0
        layer.enabled: gpu.refraction
        visible: !gpu.refraction
    }

    // --- Le Liquid Glass ----------------------------------------------------------
    Loader {
        active: gpu.refraction

        sourceComponent: ShaderEffect {
            x: -gpu.pad
            y: -gpu.pad
            width: sceneContent.width
            height: sceneContent.height

            property var source: blurred
            property vector2d regionSize: Qt.vector2d(width, height)
            property vector2d dockSize: Qt.vector2d(gpu.width, gpu.height)
            property real cornerRadius: gpu.cornerRadius
            property real thickness: gpu.thickness
            property real strength: gpu.lensStrength
            property real dispersion: Number(gpu.cfg.dispersion === undefined
                ? 0.25 : gpu.cfg.dispersion)
            property real profile: Number(gpu.cfg.profile === undefined
                ? 1 : gpu.cfg.profile)
            property real rim: Number(gpu.cfg.rim === undefined
                ? 1 : gpu.cfg.rim)

            fragmentShader: Qt.resolvedUrl("effects/glassrefract.frag.qsb")

            onStatusChanged: {
                if (status === ShaderEffect.Error) {
                    console.warn("macOS Dock: Liquid Glass shader unavailable:",
                        log);
                    gpu.shaderFailed = true;
                }
            }
        }
    }
}
