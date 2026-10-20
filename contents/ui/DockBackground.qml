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
    // Part de la bordure qui est éclairée : 0 = aucune bordure, 1 = bordure
    // éclairée sur tout le tour.
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

    // Flou réel du fond d'écran (0 = désactivé). backdropOrigin est la
    // position (en pixels écran) du coin supérieur gauche de ce fond.
    property real wallpaperBlur: 0
    // Image du fond d'écran (voir main.qml) : { source, fillMode, width, height }
    property var wallpaperInfo: ({ "source": "", "fillMode": 2,
        "width": 0, "height": 0 })
    // WallpaperLocator (module natif) : sert à lire les couleurs du fond
    // d'écran derrière le Dock pour teinter la bordure. null = bordure blanche.
    property var colorSampler: null
    property point backdropOrigin: Qt.point(0, 0)

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
    color: Qt.rgba(effectiveColor.r, effectiveColor.g,
        effectiveColor.b, Math.min(1, Math.max(0,
            surfaceOpacity * effectiveColor.a)))

    // La bordure est dessinée par le contour éclairé plus bas, pas par la
    // bordure unie de ShadowedRectangle.
    border.width: 0

    shadow.xOffset: 0
    shadow.yOffset: showShadow ? 2 : 0
    shadow.size: showShadow ? 10 : 0
    shadow.color: showShadow
        ? Qt.rgba(0, 0, 0, Math.min(1, Math.max(0, shadowOpacity)))
        : "transparent"

    // Flou du fond d'écran : chargé seulement quand il est demandé, pour
    // qu'une erreur éventuelle dans ce composant ne touche pas le reste du
    // Dock.
    Loader {
        id: backdropLoader

        // z négatif : dessiné sous la couleur de fond translucide.
        z: -1
        anchors.fill: parent
        active: background.wallpaperBlur > 0.001
        source: "WallpaperBackdrop.qml"

        Binding {
            target: backdropLoader.item
            property: "strength"
            value: background.wallpaperBlur
            when: backdropLoader.item !== null
        }

        Binding {
            target: backdropLoader.item
            property: "info"
            value: background.wallpaperInfo
            when: backdropLoader.item !== null
        }

        Binding {
            target: backdropLoader.item
            property: "origin"
            value: background.backdropOrigin
            when: backdropLoader.item !== null
        }

        Binding {
            target: backdropLoader.item
            property: "cornerRadius"
            value: background.radius
            when: backdropLoader.item !== null
        }
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

    // --- Contour éclairé ---------------------------------------------------
    // Un filet d'un pixel, continu sur tout le tour, comme le bord d'une vitre.
    // Il est découpé en petits segments dont l'opacité dépend de la distance à
    // deux lumières (l'une suit le pointeur, l'autre est au point opposé) et
    // dont la couleur est celle du fond d'écran à cet endroit : la bordure
    // brille donc de la couleur de l'arrière-plan. Les côtés restent sombres.
    //
    // borderStrength règle la PART du tour qui est éclairée : à 0 il n'y a plus
    // de bordure, à 1 tout le tour est éclairé uniformément.
    //
    // Faux : la lumière reste à sa position de repos au lieu de suivre le
    // pointeur.
    property bool followMouse: true

    readonly property real ringThickness: 1.0
    readonly property int ringSegmentCount: 288
    readonly property int rimColumns: 48
    readonly property int rimRows: 3
    readonly property real litShare: Math.min(1, Math.max(0, borderStrength))
    readonly property real perimeter: 2 * (width + height)
    // Étalement de la lumière : plus la part éclairée est grande, plus elle
    // couvre de bordure.
    readonly property real taper: Math.max(1, litShare * perimeter / 5.5)
    readonly property real lightRadius: Math.max(8, 3 * taper)
    // Niveau de base de la bordure : très discret, puis il monte jusqu'à 1
    // (bordure uniforme) quand la part éclairée approche 100 %.
    readonly property real litFloor: 0.15 * litShare
        + 0.85 * Math.pow(litShare, 8)
    // Les reflets dépassent le niveau de base d'une part fixe du reste.
    readonly property real lightGain: 0.7
    readonly property real restX: -0.1 * width
    readonly property real restY: -0.3 * height

    readonly property bool lightFollows: followMouse && lightActive
    property real fadeValue: lightFollows ? 1.0 : 0.0

    Behavior on fadeValue {
        NumberAnimation {
            duration: 220
            easing.type: Easing.OutCubic
        }
    }

    readonly property real primaryX: restX + (lightX - restX) * fadeValue
    readonly property real primaryY: restY + (lightY - restY) * fadeValue
    readonly property real secondaryX: width - primaryX
    readonly property real secondaryY: height - primaryY

    // Couleurs du fond d'écran derrière le Dock (rimColumns x rimRows).
    property var rimColors: []

    function refreshRimColors() {
        if (!colorSampler || !wallpaperInfo || !wallpaperInfo.source
                || width < 8 || height < 8) {
            rimColors = [];
            return;
        }
        var colors = [];
        try {
            colors = colorSampler.sampleColors(String(wallpaperInfo.source),
                wallpaperInfo.fillMode, wallpaperInfo.width,
                wallpaperInfo.height, backdropOrigin.x, backdropOrigin.y,
                width, height, rimColumns, rimRows);
        } catch (error) {
            colors = [];
        }
        rimColors = colors || [];
    }

    // Les mesures sont regroupées : le Dock bouge et se redimensionne souvent.
    Timer {
        id: rimColorTimer

        interval: 250
        repeat: false
        onTriggered: background.refreshRimColors()
    }

    onWallpaperInfoChanged: rimColorTimer.restart()
    onBackdropOriginChanged: rimColorTimer.restart()
    onColorSamplerChanged: rimColorTimer.restart()
    onWidthChanged: rimColorTimer.restart()
    onHeightChanged: rimColorTimer.restart()
    Component.onCompleted: rimColorTimer.restart()

    // Couleur du filet à la position (px, py) : la teinte du fond d'écran,
    // ramenée à pleine luminosité puis éclaircie (blanc si le fond est gris).
    function rimColorAt(px, py) {
        var list = rimColors;
        if (!list || list.length < rimColumns * rimRows) {
            return Qt.rgba(1, 1, 1, 1);
        }
        var column = Math.max(0, Math.min(rimColumns - 1,
            Math.floor(px / Math.max(1, width) * rimColumns)));
        var row = Math.max(0, Math.min(rimRows - 1,
            Math.floor(py / Math.max(1, height) * rimRows)));
        var c = list[row * rimColumns + column];
        var peak = Math.max(c.r, c.g, c.b);
        if (peak < 0.02) {
            return Qt.rgba(1, 1, 1, 1);
        }
        var k = 1 / peak;
        return Qt.rgba(c.r * k * 0.72 + 0.28, c.g * k * 0.72 + 0.28,
            c.b * k * 0.72 + 0.28, 1);
    }

    // Opacité du filet à la position (px, py).
    function ringAlpha(px, py) {
        var radius = Math.max(1, lightRadius);
        var d1 = Math.sqrt((px - primaryX) * (px - primaryX)
            + (py - primaryY) * (py - primaryY)) / radius;
        var d2 = Math.sqrt((px - secondaryX) * (px - secondaryX)
            + (py - secondaryY) * (py - secondaryY)) / radius;
        var light = lightGain * (Math.exp(-3 * d1) + 0.9 * Math.exp(-3 * d2));
        return Math.min(1, litFloor + (1 - litFloor) * Math.min(1, light));
    }

    // Point, angle et longueur du segment « index » le long du filet (tour
    // dans le sens horaire à partir du coin supérieur gauche).
    function ringPoint(index) {
        var t = ringThickness;
        var w = Math.max(1, width - t);
        var h = Math.max(1, height - t);
        var r = Math.max(0, Math.min(radius - t / 2, Math.min(w, h) / 2));
        var ox = t / 2;
        var oy = t / 2;
        var top = w - 2 * r;
        var side = h - 2 * r;
        var arc = Math.PI * r / 2;
        var total = 2 * top + 2 * side + 4 * arc;
        var s = (index + 0.5) / ringSegmentCount * total;
        var theta;
        var cx;
        var cy;

        if (s < top) {
            return { "x": ox + r + s, "y": oy, "a": 0,
                "len": total / ringSegmentCount };
        }
        s -= top;
        if (s < arc) {
            theta = r > 0 ? s / r : 0;
            cx = ox + w - r;
            cy = oy + r;
            return { "x": cx + r * Math.sin(theta),
                "y": cy - r * Math.cos(theta),
                "a": theta * 180 / Math.PI, "len": total / ringSegmentCount };
        }
        s -= arc;
        if (s < side) {
            return { "x": ox + w, "y": oy + r + s, "a": 90,
                "len": total / ringSegmentCount };
        }
        s -= side;
        if (s < arc) {
            theta = r > 0 ? s / r : 0;
            cx = ox + w - r;
            cy = oy + h - r;
            return { "x": cx + r * Math.cos(theta),
                "y": cy + r * Math.sin(theta),
                "a": 90 + theta * 180 / Math.PI,
                "len": total / ringSegmentCount };
        }
        s -= arc;
        if (s < top) {
            return { "x": ox + w - r - s, "y": oy + h, "a": 180,
                "len": total / ringSegmentCount };
        }
        s -= top;
        if (s < arc) {
            theta = r > 0 ? s / r : 0;
            cx = ox + r;
            cy = oy + h - r;
            return { "x": cx - r * Math.sin(theta),
                "y": cy + r * Math.cos(theta),
                "a": 180 + theta * 180 / Math.PI,
                "len": total / ringSegmentCount };
        }
        s -= arc;
        if (s < side) {
            return { "x": ox, "y": oy + h - r - s, "a": 270,
                "len": total / ringSegmentCount };
        }
        s -= side;
        theta = r > 0 ? s / r : 0;
        cx = ox + r;
        cy = oy + r;
        return { "x": cx - r * Math.cos(theta), "y": cy - r * Math.sin(theta),
            "a": 270 + theta * 180 / Math.PI,
            "len": total / ringSegmentCount };
    }

    Item {
        id: glow

        anchors.fill: parent
        visible: background.litShare > 0.001

        Repeater {
            model: background.ringSegmentCount

            delegate: Rectangle {
                id: segment

                required property int index

                readonly property var point: background.ringPoint(index)
                readonly property color tint:
                    background.rimColorAt(point.x, point.y)

                width: point.len + 0.6
                height: background.ringThickness
                x: point.x - width / 2
                y: point.y - height / 2
                rotation: point.a
                antialiasing: true
                color: Qt.rgba(tint.r, tint.g, tint.b,
                    background.ringAlpha(point.x, point.y))
            }
        }
    }
}
