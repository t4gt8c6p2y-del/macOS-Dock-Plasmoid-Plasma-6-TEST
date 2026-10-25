import QtQuick

// Le verre du Dock (voir DockBackground). Chargé à part par un Loader : si les
// modules manquaient, seul le verre disparaîtrait.
//
// Deux façons de le dessiner :
//  - GlassGpu : par la carte graphique, à chaque image affichée (temps réel).
//    C'est le chemin normal.
//  - GlassCpu : calcul par le processeur (module natif GlassPane), plus lent.
//    Il ne sert que si le chemin GPU est inutilisable (par exemple le shader du
//    Liquid Glass n'a pas été compilé par install.sh : qsb absent).
Item {
    id: layer

    // Fenêtres derrière le Dock : [{ id, x, y, w, h }], en coordonnées écran.
    property var windows: []
    // Position du Dock à l'écran (coin supérieur gauche).
    property real originX: 0
    property real originY: 0
    // Réglages reçus de DockBackground (voir configure).
    property var cfg: ({})
    // Vrai quand le chemin GPU est inutilisable : on passe au processeur.
    property bool gpuBroken: false

    readonly property bool ready: gpuBroken
        ? (cpuLoader.item ? Boolean(cpuLoader.item.ready) : false)
        : (gpuLoader.item ? Boolean(gpuLoader.item.ready) : false)

    function configure(settings) {
        cfg = settings;
        if (cpuLoader.item) {
            cpuLoader.item.configure(settings);
        }
    }

    Loader {
        id: gpuLoader

        anchors.fill: parent
        active: !layer.gpuBroken
        source: "GlassGpu.qml"
        onLoaded: {
            item.cfg = Qt.binding(function() {
                return layer.cfg;
            });
            item.windows = Qt.binding(function() {
                return layer.windows;
            });
            item.originX = Qt.binding(function() {
                return layer.originX;
            });
            item.originY = Qt.binding(function() {
                return layer.originY;
            });
        }
        onStatusChanged: {
            if (status === Loader.Error) {
                console.warn("macOS Dock: GPU glass unavailable, using the CPU path");
                layer.gpuBroken = true;
            }
        }
    }

    Connections {
        target: gpuLoader.item

        function onShaderFailedChanged() {
            if (gpuLoader.item && gpuLoader.item.shaderFailed) {
                layer.gpuBroken = true;
            }
        }
    }

    Loader {
        id: cpuLoader

        anchors.fill: parent
        active: layer.gpuBroken
        source: "GlassCpu.qml"
        onLoaded: {
            item.configure(layer.cfg);
            item.windows = Qt.binding(function() {
                return layer.windows;
            });
            item.originX = Qt.binding(function() {
                return layer.originX;
            });
            item.originY = Qt.binding(function() {
                return layer.originY;
            });
        }
    }
}
