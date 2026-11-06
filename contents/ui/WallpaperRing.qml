import QtQuick

// Liseré fin dont chaque partie prend la couleur du fond d'écran qui se trouve
// derrière elle : même principe que la bordure du Dock (voir DockBackground),
// mais sans lumière qui se déplace ni dégradé : le trait est uniforme, seule sa
// teinte change d'un endroit à l'autre.
//
// Chaque côté est découpé en 16 zones lues sur l'image du fond d'écran
// (WallpaperLocator.sampleColors) ; les quatre angles prennent la couleur du
// bout du côté voisin. Sans fond d'écran lisible, le liseré est blanc.
Item {
    id: ring

    // Rayon des angles de l'élément décoré.
    property real radius: 30
    // Épaisseur du trait (1 px minimum : un trait plus fin ne s'affiche pas).
    property real ringWidth: 1
    // Opacité du trait (0 = rien). Le Dock utilise 0,5 x l'intensité.
    property real ringOpacity: 0.5
    property bool colorFromWallpaper: true
    // { source, fillMode, width, height } fourni par main.qml.
    property var wallpaperInfo: ({ "source": "", "fillMode": 2, "width": 0, "height": 0 })
    // Le WallpaperLocator natif.
    property var colorSampler: null
    // Vrai quand l'élément est affiché : les couleurs ne sont lues qu'alors.
    property bool active: visible

    property var topColors: []
    property var bottomColors: []
    property var leftColors: []
    property var rightColors: []

    readonly property real bw: Math.max(1, ringWidth)
    readonly property real cap: Math.max(1, Math.min(radius, width / 2, height / 2))

    function colorAt(list, index) {
        return list && list.length > index ? list[index] : "white";
    }

    // Même traitement que la bordure du Dock : la teinte du fond, en plus vive
    // et plus claire ; un fond gris, noir ou blanc donne un liseré blanc.
    function tint(c) {
        var saturation = c.hsvSaturation;
        if (saturation < 0.08 || c.hsvHue < 0) {
            return Qt.rgba(1, 1, 1, 1);
        }
        return Qt.hsva(c.hsvHue, Math.min(1, saturation * 1.4), 0.95, 1);
    }

    function strip(x, y, w, h, columns, rows) {
        var info = wallpaperInfo;
        var list = [];
        try {
            list = colorSampler.sampleColors(String(info.source), info.fillMode,
                info.width, info.height, x, y, w, h, columns, rows);
        } catch (error) {
            list = [];
        }
        if (!list || list.length < columns * rows) {
            return [];
        }
        var result = [];
        for (var i = 0; i < list.length; ++i) {
            result.push(tint(list[i]));
        }
        return result;
    }

    function refresh() {
        var usable = colorFromWallpaper && colorSampler && wallpaperInfo
            && wallpaperInfo.source && width >= 8 && height >= 8
            && wallpaperInfo.width > 0 && wallpaperInfo.height > 0;
        if (!usable) {
            topColors = [];
            bottomColors = [];
            leftColors = [];
            rightColors = [];
            return;
        }
        var origin = ring.mapToItem(null, 0, 0);
        var x = origin.x;
        var y = origin.y;
        // On lit le fond juste à l'intérieur du bord (4 px d'épaisseur).
        topColors = strip(x, y, width, 4, 16, 1);
        bottomColors = strip(x, y + height - 4, width, 4, 16, 1);
        leftColors = strip(x, y, 4, height, 1, 16);
        rightColors = strip(x + width - 4, y, 4, height, 1, 16);
    }

    Timer {
        id: refreshTimer

        interval: 150
        repeat: false
        onTriggered: ring.refresh()
    }

    onActiveChanged: if (active) refreshTimer.restart()
    onWidthChanged: if (active) refreshTimer.restart()
    onHeightChanged: if (active) refreshTimer.restart()
    onWallpaperInfoChanged: if (active) refreshTimer.restart()
    onColorSamplerChanged: if (active) refreshTimer.restart()
    onColorFromWallpaperChanged: if (active) refreshTimer.restart()

    opacity: ringOpacity

    // Côté haut et côté bas (entre les angles).

    Rectangle {
        x: ring.cap
        y: 0
        width: Math.max(0, ring.width - 2 * ring.cap)
        height: ring.bw
        visible: ring.width > 0 && ring.ringOpacity > 0.003
        gradient: Gradient {
            orientation: Gradient.Horizontal
                GradientStop { position: 0.00000; color: ring.colorAt(ring.topColors, 0) }
                GradientStop { position: 0.06667; color: ring.colorAt(ring.topColors, 1) }
                GradientStop { position: 0.13333; color: ring.colorAt(ring.topColors, 2) }
                GradientStop { position: 0.20000; color: ring.colorAt(ring.topColors, 3) }
                GradientStop { position: 0.26667; color: ring.colorAt(ring.topColors, 4) }
                GradientStop { position: 0.33333; color: ring.colorAt(ring.topColors, 5) }
                GradientStop { position: 0.40000; color: ring.colorAt(ring.topColors, 6) }
                GradientStop { position: 0.46667; color: ring.colorAt(ring.topColors, 7) }
                GradientStop { position: 0.53333; color: ring.colorAt(ring.topColors, 8) }
                GradientStop { position: 0.60000; color: ring.colorAt(ring.topColors, 9) }
                GradientStop { position: 0.66667; color: ring.colorAt(ring.topColors, 10) }
                GradientStop { position: 0.73333; color: ring.colorAt(ring.topColors, 11) }
                GradientStop { position: 0.80000; color: ring.colorAt(ring.topColors, 12) }
                GradientStop { position: 0.86667; color: ring.colorAt(ring.topColors, 13) }
                GradientStop { position: 0.93333; color: ring.colorAt(ring.topColors, 14) }
                GradientStop { position: 1.00000; color: ring.colorAt(ring.topColors, 15) }
        }
    }

    Rectangle {
        x: ring.cap
        y: ring.height - ring.bw
        width: Math.max(0, ring.width - 2 * ring.cap)
        height: ring.bw
        visible: ring.width > 0 && ring.ringOpacity > 0.003
        gradient: Gradient {
            orientation: Gradient.Horizontal
                GradientStop { position: 0.00000; color: ring.colorAt(ring.bottomColors, 0) }
                GradientStop { position: 0.06667; color: ring.colorAt(ring.bottomColors, 1) }
                GradientStop { position: 0.13333; color: ring.colorAt(ring.bottomColors, 2) }
                GradientStop { position: 0.20000; color: ring.colorAt(ring.bottomColors, 3) }
                GradientStop { position: 0.26667; color: ring.colorAt(ring.bottomColors, 4) }
                GradientStop { position: 0.33333; color: ring.colorAt(ring.bottomColors, 5) }
                GradientStop { position: 0.40000; color: ring.colorAt(ring.bottomColors, 6) }
                GradientStop { position: 0.46667; color: ring.colorAt(ring.bottomColors, 7) }
                GradientStop { position: 0.53333; color: ring.colorAt(ring.bottomColors, 8) }
                GradientStop { position: 0.60000; color: ring.colorAt(ring.bottomColors, 9) }
                GradientStop { position: 0.66667; color: ring.colorAt(ring.bottomColors, 10) }
                GradientStop { position: 0.73333; color: ring.colorAt(ring.bottomColors, 11) }
                GradientStop { position: 0.80000; color: ring.colorAt(ring.bottomColors, 12) }
                GradientStop { position: 0.86667; color: ring.colorAt(ring.bottomColors, 13) }
                GradientStop { position: 0.93333; color: ring.colorAt(ring.bottomColors, 14) }
                GradientStop { position: 1.00000; color: ring.colorAt(ring.bottomColors, 15) }
        }
    }

    // Côté gauche et côté droit.

    Rectangle {
        x: 0
        y: ring.cap
        width: ring.bw
        height: Math.max(0, ring.height - 2 * ring.cap)
        visible: ring.width > 0 && ring.ringOpacity > 0.003
        gradient: Gradient {
            orientation: Gradient.Vertical
                GradientStop { position: 0.00000; color: ring.colorAt(ring.leftColors, 0) }
                GradientStop { position: 0.06667; color: ring.colorAt(ring.leftColors, 1) }
                GradientStop { position: 0.13333; color: ring.colorAt(ring.leftColors, 2) }
                GradientStop { position: 0.20000; color: ring.colorAt(ring.leftColors, 3) }
                GradientStop { position: 0.26667; color: ring.colorAt(ring.leftColors, 4) }
                GradientStop { position: 0.33333; color: ring.colorAt(ring.leftColors, 5) }
                GradientStop { position: 0.40000; color: ring.colorAt(ring.leftColors, 6) }
                GradientStop { position: 0.46667; color: ring.colorAt(ring.leftColors, 7) }
                GradientStop { position: 0.53333; color: ring.colorAt(ring.leftColors, 8) }
                GradientStop { position: 0.60000; color: ring.colorAt(ring.leftColors, 9) }
                GradientStop { position: 0.66667; color: ring.colorAt(ring.leftColors, 10) }
                GradientStop { position: 0.73333; color: ring.colorAt(ring.leftColors, 11) }
                GradientStop { position: 0.80000; color: ring.colorAt(ring.leftColors, 12) }
                GradientStop { position: 0.86667; color: ring.colorAt(ring.leftColors, 13) }
                GradientStop { position: 0.93333; color: ring.colorAt(ring.leftColors, 14) }
                GradientStop { position: 1.00000; color: ring.colorAt(ring.leftColors, 15) }
        }
    }

    Rectangle {
        x: ring.width - ring.bw
        y: ring.cap
        width: ring.bw
        height: Math.max(0, ring.height - 2 * ring.cap)
        visible: ring.width > 0 && ring.ringOpacity > 0.003
        gradient: Gradient {
            orientation: Gradient.Vertical
                GradientStop { position: 0.00000; color: ring.colorAt(ring.rightColors, 0) }
                GradientStop { position: 0.06667; color: ring.colorAt(ring.rightColors, 1) }
                GradientStop { position: 0.13333; color: ring.colorAt(ring.rightColors, 2) }
                GradientStop { position: 0.20000; color: ring.colorAt(ring.rightColors, 3) }
                GradientStop { position: 0.26667; color: ring.colorAt(ring.rightColors, 4) }
                GradientStop { position: 0.33333; color: ring.colorAt(ring.rightColors, 5) }
                GradientStop { position: 0.40000; color: ring.colorAt(ring.rightColors, 6) }
                GradientStop { position: 0.46667; color: ring.colorAt(ring.rightColors, 7) }
                GradientStop { position: 0.53333; color: ring.colorAt(ring.rightColors, 8) }
                GradientStop { position: 0.60000; color: ring.colorAt(ring.rightColors, 9) }
                GradientStop { position: 0.66667; color: ring.colorAt(ring.rightColors, 10) }
                GradientStop { position: 0.73333; color: ring.colorAt(ring.rightColors, 11) }
                GradientStop { position: 0.80000; color: ring.colorAt(ring.rightColors, 12) }
                GradientStop { position: 0.86667; color: ring.colorAt(ring.rightColors, 13) }
                GradientStop { position: 0.93333; color: ring.colorAt(ring.rightColors, 14) }
                GradientStop { position: 1.00000; color: ring.colorAt(ring.rightColors, 15) }
        }
    }

    // Angle haut gauche : un coin du contour arrondi, découpé.
    Item {
        x: 0
        y: 0
        width: ring.cap
        height: ring.cap
        clip: true

        Rectangle {
            x: 0
            y: 0
            width: ring.width
            height: ring.height
            radius: ring.radius
            color: "transparent"
            border.width: ring.bw
            border.color: ring.colorAt(ring.topColors, 0)
        }
    }

    // Angle haut droit : un coin du contour arrondi, découpé.
    Item {
        x: ring.width - ring.cap
        y: 0
        width: ring.cap
        height: ring.cap
        clip: true

        Rectangle {
            x: ring.cap - ring.width
            y: 0
            width: ring.width
            height: ring.height
            radius: ring.radius
            color: "transparent"
            border.width: ring.bw
            border.color: ring.colorAt(ring.topColors, 15)
        }
    }

    // Angle bas gauche : un coin du contour arrondi, découpé.
    Item {
        x: 0
        y: ring.height - ring.cap
        width: ring.cap
        height: ring.cap
        clip: true

        Rectangle {
            x: 0
            y: ring.cap - ring.height
            width: ring.width
            height: ring.height
            radius: ring.radius
            color: "transparent"
            border.width: ring.bw
            border.color: ring.colorAt(ring.bottomColors, 0)
        }
    }

    // Angle bas droit : un coin du contour arrondi, découpé.
    Item {
        x: ring.width - ring.cap
        y: ring.height - ring.cap
        width: ring.cap
        height: ring.cap
        clip: true

        Rectangle {
            x: ring.cap - ring.width
            y: ring.cap - ring.height
            width: ring.width
            height: ring.height
            radius: ring.radius
            color: "transparent"
            border.width: ring.bw
            border.color: ring.colorAt(ring.bottomColors, 15)
        }
    }
}
