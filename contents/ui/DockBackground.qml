pragma ComponentBehavior: Bound

import QtQuick
import org.kde.kirigami as Kirigami

Kirigami.ShadowedRectangle {
    id: background

    property real surfaceOpacity: 0.55
    property bool useThemeColor: true
    property color customColor: "#20242b"
    property real requestedRadius: Kirigami.Units.cornerRadius * 2
    // Ancien réglage de bordure (opacité). Il ne sert plus qu'à déduire la
    // part éclairée tant que borderStrength n'a pas été réglé.
    property real borderOpacity: 0.22
    // Intensité de la bordure : 0 = aucune bordure, 1 = bordure pleine.
    // (Le nom borderStrength est conservé pour la compatibilité.)
    property real borderStrength: Math.min(1, Math.max(0, borderOpacity / 0.5))
    property real shadowOpacity: 0.42
    // L'ombre portée de ShadowedRectangle est dessinée sous le fond : comme
    // celui-ci est translucide, elle transparaît à l'intérieur et forme un
    // liseré sombre le long des bords. Les fenêtres du dock ont exactement la
    // taille du fond, l'ombre n'y a de toute façon pas la place de s'afficher.
    property bool showShadow: true
    property bool showHighlight: true
    // Intensité du reflet vitré : 1 = rendu d'origine, 0 = aucun reflet.
    property real highlightStrength: 1.0

    // Éclairage de la bordure. La lumière suit le pointeur quand il survole
    // le fond (lightActive) ; au repos elle est posée en haut à gauche. Une
    // seconde lumière, plus faible, se trouve au point opposé.
    property bool lightActive: false
    property real lightX: width / 2
    property real lightY: height / 2

    // Image du fond d'écran (voir main.qml) : { source, fillMode, width, height }.
    // Elle sert au fond en verre (flou, réfraction) et à teinter la bordure.
    property var wallpaperInfo: ({ "source": "", "fillMode": 2,
        "width": 0, "height": 0 })
    // WallpaperLocator (module natif) : sert à lire la couleur du fond d'écran
    // derrière le Dock pour teinter la bordure. null = bordure blanche.
    property var colorSampler: null
    // Position (en pixels écran) du coin supérieur gauche de ce fond.
    property point backdropOrigin: Qt.point(0, 0)

    // --- Fond en verre -------------------------------------------------------
    // Le Dock dessine lui-même son fond : ce qui se trouve derrière lui (le
    // fond d'écran et, en direct, les fenêtres qui passent derrière), flouté
    // (glassBlur) et, pour le Liquid Glass, déformé sur les bords comme par une
    // lentille. Rien ne passe par KWin : aucun effet du bureau n'est touché.
    property bool glassEnabled: false
    // Les fenêtres placées derrière le Dock, du dessous au dessus, en
    // coordonnées écran : [{ id, x, y, w, h }] (voir main.qml). Vide = seul le
    // fond d'écran est visible à travers le verre.
    property var backdropWindows: []
    // Faux : le verre n'affiche que le fond d'écran (réglage « temps réel »).
    property bool liveBackdrop: true
    // Rayon du flou en pixels (0 = net).
    property real glassBlur: 0
    // Liquid Glass : déformation des bords, franges de couleur, reflet.
    property bool glassRefraction: false
    property real glassThickness: 16
    property real glassStrength: 1.0
    property real glassDispersion: 0.25
    property real glassProfile: 1.0
    property real glassRim: 1.0

    // Vrai quand le verre est prêt à être affiché (fond d'écran trouvé et lu) ;
    // sinon le fond reste la simple teinte translucide.
    readonly property bool glassVisible: Boolean(glassEnabled
        && glassLoader.item && glassLoader.item.ready)

    readonly property var glassConfig: ({
        "source": wallpaperInfo ? String(wallpaperInfo.source || "") : "",
        "fillMode": wallpaperInfo ? Number(wallpaperInfo.fillMode) : 2,
        "screenWidth": wallpaperInfo ? Number(wallpaperInfo.width) : 0,
        "screenHeight": wallpaperInfo ? Number(wallpaperInfo.height) : 0,
        "originX": backdropOrigin.x,
        "originY": backdropOrigin.y,
        "radius": radius,
        "blur": glassBlur,
        "refraction": glassRefraction,
        "thickness": glassThickness,
        "strength": glassStrength,
        "dispersion": glassDispersion,
        "profile": glassProfile,
        "rim": glassRim
    })
    onGlassConfigChanged: applyGlass()

    function applyGlass() {
        if (glassLoader.item) {
            glassLoader.item.configure(glassEnabled ? glassConfig : ({}));
        }
    }
    onGlassEnabledChanged: applyGlass()

    // Les fenêtres transmises au verre : aucune si le temps réel est coupé.
    readonly property var liveWindows:
        glassEnabled && liveBackdrop ? backdropWindows : []

    readonly property color themeBackground: qtPalette.window
    readonly property color themeText: qtPalette.windowText
    readonly property color effectiveColor: useThemeColor
        ? themeBackground : customColor
    readonly property real effectiveLuminance: 0.2126 * effectiveColor.r
        + 0.7152 * effectiveColor.g + 0.0722 * effectiveColor.b

    function highlightAlpha(base) {
        return Math.min(1, Math.max(0, base * highlightStrength));
    }

    SystemPalette {
        id: qtPalette

        colorGroup: SystemPalette.Active
    }

    radius: Math.min(Math.max(0, requestedRadius),
        Math.min(width, height) / 2)
    readonly property color tintColor: Qt.rgba(effectiveColor.r,
        effectiveColor.g, effectiveColor.b, Math.min(1, Math.max(0,
            surfaceOpacity * effectiveColor.a)))
    // Avec le verre, la teinte passe au-dessus de l'image du fond d'écran.
    color: glassVisible ? "transparent" : tintColor

    // La bordure est dessinée par le contour éclairé plus bas, pas par la
    // bordure unie de ShadowedRectangle.
    border.width: 0

    shadow.xOffset: 0
    shadow.yOffset: showShadow ? 2 : 0
    shadow.size: showShadow ? 10 : 0
    shadow.color: showShadow
        ? Qt.rgba(0, 0, 0, Math.min(1, Math.max(0, shadowOpacity)))
        : "transparent"

    // Le verre : le fond d'écran flouté et déformé (voir glassEnabled).
    // Chargé à part : si le module natif manquait, le Dock garderait sa teinte.
    Loader {
        id: glassLoader

        anchors.fill: parent
        active: background.glassEnabled
        visible: background.glassVisible
        source: "GlassLayer.qml"
        onLoaded: {
            background.applyGlass();
            // Le verre suit les fenêtres qui passent derrière le Dock.
            item.windows = Qt.binding(function() {
                return background.liveWindows;
            });
            item.originX = Qt.binding(function() {
                return background.backdropOrigin.x;
            });
            item.originY = Qt.binding(function() {
                return background.backdropOrigin.y;
            });
        }
    }

    // La teinte du Dock (réglage « Opacité du fond ») sur le verre.
    Rectangle {
        anchors.fill: parent
        radius: background.radius
        color: background.tintColor
        visible: background.glassVisible
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: Math.max(0, background.radius - 1)
        color: "transparent"
        visible: background.showHighlight
            && background.highlightStrength > 0.001

        gradient: Gradient {
            orientation: Gradient.Vertical

            GradientStop {
                position: 0
                color: Qt.rgba(1, 1, 1, background.highlightAlpha(0.14))
            }

            GradientStop {
                position: 0.55
                color: Qt.rgba(1, 1, 1, background.highlightAlpha(0.025))
            }

            GradientStop {
                position: 1
                color: Qt.rgba(0, 0, 0, background.highlightAlpha(0.08))
            }
        }
    }

    // --- Bordure ---------------------------------------------------------
    // La bordure est faite de pièces simples (Rectangle, dégradés) : aucun
    // effet, aucun masque, aucun Canvas. Le rendu est donc le même sur toutes
    // les configurations graphiques.
    //  - Intensité : opacité de la bordure.
    //  - Largeur : épaisseur du trait.
    //  - Couleur : chaque partie prend la couleur du fond d'écran qui se
    //    trouve derrière elle (désactivable : bordure blanche).
    //  - Lumière : deux halos blancs qui glissent le long de la bordure et
    //    suivent le pointeur.
    //
    // Intensité de la lumière qui suit le pointeur : 0 = aucune lumière,
    // 1 = rendu d'origine, 2 = le double.
    property real lightIntensity: 1.0
    // Largeur de la bordure en pixels.
    property real borderWidth: 1.0
    // Couleur de la bordure : celle du fond d'écran derrière chaque partie.
    property bool colorFromWallpaper: true

    readonly property real borderIntensity:
        Math.min(1, Math.max(0, borderStrength))
    readonly property real ringWidth: Math.min(6, Math.max(0.25, borderWidth))
    // Un trait de moins d'un pixel est dessiné à un pixel, moins opaque.
    readonly property real drawnWidth: Math.max(1, ringWidth)
    // Le trait de base reste discret : la lumière doit s'en détacher.
    readonly property real ringAlpha:
        0.5 * borderIntensity * Math.min(1, ringWidth)
    // Largeur des extrémités arrondies ; les côtés droits sont entre elles.
    readonly property real capWidth:
        Math.ceil(Math.max(radius, drawnWidth))
    readonly property real edgeWidth: Math.max(0, width - 2 * capWidth)

    // La lumière : une tache blanche qui glisse le long de la bordure.
    // L'intensité règle à la fois sa force, son étendue et la profondeur de la
    // lueur qui s'étend vers l'intérieur du Dock.
    readonly property real lightRadius:
        Math.max(70, Math.min(0.2 * width, 170))
        * (0.6 + 0.4 * Math.min(2, lightIntensity))
    readonly property bool lightEnabled: lightIntensity > 0.001
    // La lumière appartient à la bordure : à 0 % d'intensité, plus rien
    // n'est dessiné (ni côtés, ni angles).
    readonly property real lightPeak: lightEnabled && borderIntensity > 0.001
        ? Math.min(1, 0.85 * lightIntensity)
            * (0.75 + 0.25 * borderIntensity)
        : 0
    // Profondeur de la lueur intérieure (pixels), bornée pour ne jamais
    // dépasser la moitié de la hauteur du Dock.
    readonly property int glowDepth: lightPeak > 0.001
        ? Math.max(0, Math.min(10,
            Math.round(3 + 3 * Math.min(2, lightIntensity)),
            Math.floor((height - 2 * drawnWidth) / 2) - 1))
        : 0
    readonly property real restX: -0.1 * width
    readonly property real restY: -0.3 * height

    readonly property bool lightFollows: lightEnabled && lightActive
    property real fadeValue: lightFollows ? 1.0 : 0.0
    // Force réellement utilisée : la lumière n'existe que lorsque le pointeur
    // est sur le Dock. Dès qu'il en sort, elle s'éteint et toute la bordure
    // retrouve la même intensité (aucun côté ni angle plus clair qu'un autre).
    readonly property real activePeak: lightPeak * fadeValue

    Behavior on fadeValue {
        NumberAnimation {
            duration: 220
            easing.type: Easing.OutCubic
        }
    }

    readonly property real primaryX: restX + (lightX - restX) * fadeValue
    readonly property real primaryY: restY + (lightY - restY) * fadeValue
    // La seconde lumière, plus faible, est au point opposé.
    readonly property real secondaryX: width - primaryX
    readonly property real secondaryY: height - primaryY
    readonly property real secondaryScale: 0.6

    // --- Couleurs de la bordure ----------------------------------------------
    // Le fond d'écran derrière le Dock est découpé en colorColumns zones, de
    // gauche à droite ; chaque zone donne la couleur de la bordure à cet
    // endroit (ramenée à pleine luminosité puis éclaircie). Tant que les
    // couleurs sont inconnues, ou si l'option est désactivée, la bordure est
    // blanche.
    readonly property int colorColumns: 16
    property var edgeColors: []
    property bool samplingWarned: false

    function refreshTint() {
        var colors = [];
        if (colorFromWallpaper && colorSampler && wallpaperInfo
                && wallpaperInfo.source && width >= 8 && height >= 8) {
            try {
                colors = colorSampler.sampleColors(
                    String(wallpaperInfo.source), wallpaperInfo.fillMode,
                    wallpaperInfo.width, wallpaperInfo.height,
                    backdropOrigin.x, backdropOrigin.y, width, height,
                    colorColumns, 1);
            } catch (error) {
                colors = [];
            }
        }
        if (!colors || colors.length < colorColumns) {
            if (colorFromWallpaper && wallpaperInfo && wallpaperInfo.source
                    && !samplingWarned) {
                samplingWarned = true;
                console.warn("macOS Dock: could not read the colours of "
                    + wallpaperInfo.source);
            }
            edgeColors = [];
            return;
        }
        var result = [];
        for (var i = 0; i < colorColumns; ++i) {
            var c = colors[i];
            var saturation = c.hsvSaturation;
            if (saturation < 0.08 || c.hsvHue < 0) {
                // Gris, noir ou blanc : pas de teinte à reprendre.
                result.push(Qt.rgba(1, 1, 1, 1));
            } else {
                // Même teinte que le fond d'écran, en plus vif et plus clair
                // pour qu'elle se voie sur un trait fin.
                result.push(Qt.hsva(c.hsvHue, Math.min(1, saturation * 1.4),
                    0.95, 1));
            }
        }
        edgeColors = result;
    }

    // Les mesures sont regroupées : le Dock bouge et se redimensionne souvent.
    Timer {
        id: tintTimer

        interval: 500
        repeat: false
        onTriggered: background.refreshTint()
    }

    onWallpaperInfoChanged: tintTimer.restart()
    onColorSamplerChanged: tintTimer.restart()
    onBackdropOriginChanged: tintTimer.restart()
    // Le Dock grandit quand on ajoute des icônes : les zones de couleur
    // doivent suivre sa largeur actuelle, pas celle du démarrage.
    onWidthChanged: tintTimer.restart()
    onHeightChanged: tintTimer.restart()
    onColorFromWallpaperChanged: refreshTint()
    Component.onCompleted: tintTimer.restart()

    // Côté haut.
    BorderEdge {
        x: background.capWidth
        y: 0
        width: background.edgeWidth
        height: background.drawnWidth
        colors: background.edgeColors
        baseOpacity: background.ringAlpha
    }

    // Côté bas.
    BorderEdge {
        x: background.capWidth
        y: background.height - background.drawnWidth
        width: background.edgeWidth
        height: background.drawnWidth
        colors: background.edgeColors
        baseOpacity: background.ringAlpha
    }

    // Extrémité gauche.
    BorderCap {
        x: 0
        y: 0
        width: background.capWidth
        height: background.height
        leftSide: true
        fullWidth: background.width
        ringRadius: background.radius
        ringWidth: background.drawnWidth
        ringColor: background.edgeColors.length > 0
            ? background.edgeColors[0] : "white"
        baseOpacity: background.ringAlpha
    }

    // Extrémité droite.
    BorderCap {
        x: background.width - background.capWidth
        y: 0
        width: background.capWidth
        height: background.height
        leftSide: false
        fullWidth: background.width
        ringRadius: background.radius
        ringWidth: background.drawnWidth
        ringColor: background.edgeColors.length > 0
            ? background.edgeColors[background.edgeColors.length - 1]
            : "white"
        baseOpacity: background.ringAlpha
    }

    // La lumière qui suit le pointeur : un seul composant natif pour tout le
    // contour (côtés, angles, extrémités), avec la même formule partout. Chargé
    // à part : si le module natif manquait, seule la lumière disparaîtrait.
    Loader {
        anchors.fill: parent
        active: background.lightEnabled
        visible: background.activePeak > 0.003
        source: "BorderLightLayer.qml"
        onLoaded: {
            item.peak = Qt.binding(function() { return background.activePeak; });
            item.lightRadius = Qt.binding(function() { return background.lightRadius; });
            item.lightX1 = Qt.binding(function() { return background.primaryX; });
            item.lightY1 = Qt.binding(function() { return background.primaryY; });
            item.lightX2 = Qt.binding(function() { return background.secondaryX; });
            item.lightY2 = Qt.binding(function() { return background.secondaryY; });
            item.secondaryScale = Qt.binding(function() { return background.secondaryScale; });
            item.cornerRadius = Qt.binding(function() { return background.radius; });
            item.lineWidth = Qt.binding(function() { return background.drawnWidth; });
            item.depth = Qt.binding(function() { return background.glowDepth; });
        }
    }
}
