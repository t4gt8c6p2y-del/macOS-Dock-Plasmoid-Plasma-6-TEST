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
    // Position du curseur sur le verre, en 0..1 (-1 : absent). Sert au reflet de
    // coin du Liquid Glass du menu d'applications.
    property real mouseU: -1
    property real mouseV: -1

    // Vrai quand le fond d'écran est chargé : le verre peut être affiché.
    readonly property bool ready: wallpaper.status === Image.Ready
    // Vrai si le shader du Liquid Glass n'a pas pu être chargé : GlassLayer
    // bascule alors sur le calcul par le processeur.
    property bool shaderFailed: false
    // Vrai si le shader du Liquid Glass du menu d'applications (glassliquid)
    // n'a pas pu être chargé : le verre reprend alors le shader d'origine, avec
    // les réglages d'origine (épaisseur, force, profil…), sans passer par le
    // processeur.
    property bool liquidFailed: false
    // Vrai quand la fenêtre du Dock est affichée : sinon les flux de capture
    // restent éteints.
    readonly property bool windowShown: Window.window !== null
        && Window.window !== undefined && Window.window.visible

    // Le verre n'apparaît qu'une fois les fenêtres derrière le Dock capturées
    // (sinon on verrait un instant le fond d'écran seul, par exemple quand le
    // Dock réapparaît au-dessus d'une fenêtre agrandie). Au bout de 1,2 s, il
    // s'affiche de toute façon.
    // Toutes les captures ont livré une image.
    readonly property bool captureIdle: liveLoader.item
        ? (liveLoader.item.evaluated && liveLoader.item.pendingCount === 0)
        : true
    // Aucune fenêtre ne touche le Dock : rien à attendre.
    readonly property bool nothingToCapture: liveLoader.item
        ? (liveLoader.item.evaluated && liveLoader.item.activeCount === 0)
        : true
    // Une capture annonce « prête » un peu avant que son image soit à l'écran :
    // on laisse passer un court instant avant d'afficher le verre.
    property bool captureHeld: false
    readonly property bool windowsReady: windowShown && captureIdle
        && (nothingToCapture || captureHeld)
    onCaptureIdleChanged: {
        if (!captureIdle) {
            captureHeld = false;
        }
    }
    property bool settleTimedOut: false
    property bool settled: false
    // Vrai quand ce verre est affiché pour de bon : le fond de l'autre fenêtre
    // du Dock (Basis / Overlay) peut alors s'effacer sans que l'on voie un trou
    // (voir DockBackground.glassHandoffReady).
    readonly property bool handoffReady: settled
    // Durée du fondu d'apparition (0 : instantané, pour le passage d'une fenêtre
    // du Dock à l'autre).
    readonly property int fadeMs: cfg.fadeMs === undefined
        ? 160 : Number(cfg.fadeMs)
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
            captureHeld = false;
        }
    }
    // Jamais tout à fait 0 : un élément transparent n'est plus dessiné, et la
    // scène des fenêtres ne se mettrait plus à jour.
    opacity: settled || glassReady ? 1.0 : 0.01
    Behavior on opacity {
        NumberAnimation { duration: gpu.fadeMs }
    }

    Timer {
        // Marge de sécurité entre « la capture annonce une image » et « cette
        // image est à l'écran » : sans elle, on verrait un instant le fond
        // d'écran seul. C'est la partie la plus visible du délai avant que le
        // flou et le Liquid Glass n'apparaissent quand le Dock réapparaît au-
        // dessus d'une fenêtre agrandie ; 120 ms suffisent (elle était de 300).
        interval: 120
        running: gpu.windowShown && gpu.captureIdle && !gpu.nothingToCapture
        onTriggered: gpu.captureHeld = true
    }

    Timer {
        interval: 1200
        running: gpu.windowShown && !gpu.settled && !gpu.settleTimedOut
        onTriggered: gpu.settleTimedOut = true
    }

    readonly property bool refraction: Boolean(cfg.refraction)
    // Liquid Glass « Snell sur un dôme » (shader glassliquid) demandé par le
    // menu d'applications du Spotlight.
    readonly property bool liquid: refraction && Boolean(cfg.liquid)
        && !liquidFailed
    // Second flou posé sur le premier (le fond de la barre du Spotlight : il ne
    // doit plus laisser deviner que des couleurs et des formes).
    readonly property bool doubleBlur: refraction && Boolean(cfg.doubleBlur)
        && blurAmount > 0.001
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
        Math.ceil(blurAmount * 64 * (doubleBlur ? 2.4 : 1.5)) + 8
        + (refraction && !liquid
            ? Math.ceil(thickness * lensStrength * 1.6) : 0)))

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

    // Second flou, appliqué à l'image déjà floutée.
    MultiEffect {
        id: blurredTwice

        x: -gpu.pad
        y: -gpu.pad
        width: sceneContent.width
        height: sceneContent.height
        source: blurred
        autoPaddingEnabled: false
        blurEnabled: gpu.doubleBlur
        blur: gpu.blurAmount
        blurMax: 64
        layer.enabled: gpu.doubleBlur
        visible: false
    }

    // --- Le Liquid Glass ----------------------------------------------------------
    // Menu d'applications du Spotlight : Liquid Glass « Snell sur un dôme »
    // (shader glassliquid, porté du dépôt liquidglass-kde-widgets).
    Loader {
        active: gpu.liquid

        sourceComponent: ShaderEffect {
            x: -gpu.pad
            y: -gpu.pad
            width: sceneContent.width
            height: sceneContent.height

            property var source: blurred
            property vector2d regionSize: Qt.vector2d(width, height)
            property vector2d glassSize: Qt.vector2d(gpu.width, gpu.height)
            property real glassRadius: gpu.cornerRadius
            property real glassRoundness: Number(gpu.cfg.roundness === undefined
                ? 5 : gpu.cfg.roundness)
            property real refractThickness: Number(gpu.cfg.liquidThickness === undefined
                ? 35 : gpu.cfg.liquidThickness)
            property real refractIOR: Number(gpu.cfg.ior === undefined
                ? 1.7 : gpu.cfg.ior)
            property real refractScale: Number(gpu.cfg.liquidScale === undefined
                ? 65 : gpu.cfg.liquidScale)
            property real chromaStrength: Number(gpu.cfg.chroma === undefined
                ? 0.3 : gpu.cfg.chroma)
            property vector4d tint: gpu.cfg.tint !== undefined
                ? gpu.cfg.tint : Qt.vector4d(0, 0, 0, 0)
            property vector2d mousePos: Qt.vector2d(gpu.mouseU, gpu.mouseV)
            property real mouseFade: gpu.mouseU >= 0 && gpu.mouseV >= 0 ? 1 : 0
            property real specStrength: Number(gpu.cfg.spec === undefined
                ? 0.7 : gpu.cfg.spec)
            property real ringWidth: Number(gpu.cfg.ringWidth || 0)
            property real ringStrength: Number(gpu.cfg.ringStrength || 0)

            Behavior on mouseFade {
                NumberAnimation { duration: 180; easing.type: Easing.OutQuad }
            }

            fragmentShader: Qt.resolvedUrl("effects/glassliquid.frag.qsb")

            onStatusChanged: {
                if (status === ShaderEffect.Error) {
                    console.warn("macOS Dock: Spotlight Liquid Glass shader unavailable:",
                        log);
                    gpu.liquidFailed = true;
                }
            }
        }
    }

    // Verre d'origine (Dock, barre et fenêtre de conversation du Spotlight).
    Loader {
        active: gpu.refraction && !gpu.liquid

        sourceComponent: ShaderEffect {
            x: -gpu.pad
            y: -gpu.pad
            width: sceneContent.width
            height: sceneContent.height

            property var source: gpu.doubleBlur ? blurredTwice : blurred
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
            // Réservés au Spotlight (le Dock laisse 0 : aucun effet).
            property real ringWidth: Number(gpu.cfg.ringWidth || 0)
            property real ringStrength: Number(gpu.cfg.ringStrength || 0)
            property real ringOnly: gpu.cfg.ringOnly ? 1 : 0
            property vector4d tint: gpu.cfg.tint !== undefined
                ? gpu.cfg.tint : Qt.vector4d(0, 0, 0, 0)

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
