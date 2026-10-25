import QtQuick
import "effects" as DockEffects

// Le verre du Dock (voir DockBackground). Chargé à part par un Loader : si le
// module natif était absent, seul le verre disparaîtrait.
//
// Les fenêtres qui passent derrière le Dock sont dessinées dans une scène
// (LiveWindows.qml) rangée hors de la fenêtre du Dock, à la taille exacte de la
// zone que le verre lit (le Dock plus sa marge). GlassPane relit cette scène
// quand des fenêtres s'y trouvent, et la mélange au fond d'écran avant de
// flouter et de réfracter. La scène est chargée à part : si le module PipeWire
// manquait, le verre garderait le fond d'écran seul.
DockEffects.GlassPane {
    id: pane

    // Fenêtres derrière le Dock : [{ id, x, y, w, h }], du dessous au dessus,
    // en coordonnées écran. Fournies par DockBackground.
    property var windows: []
    // Position du Dock à l'écran (coin supérieur gauche).
    property real originX: 0
    property real originY: 0
    // Vrai quand la fenêtre du Dock est affichée : sinon les flux de capture
    // restent éteints.
    readonly property bool windowShown: Window.window !== null
        && Window.window !== undefined && Window.window.visible

    scene: sceneLoader
    live: sceneLoader.item !== null && sceneLoader.item.activeCount > 0
        && pane.windowShown

    Loader {
        id: sceneLoader

        // Hors de la fenêtre : la scène n'est jamais vue, seulement relue.
        x: -50000
        y: 0
        width: pane.regionWidth
        height: pane.regionHeight
        source: "LiveWindows.qml"
        onLoaded: {
            item.windows = Qt.binding(function() {
                return pane.windows;
            });
            item.regionX = Qt.binding(function() {
                return pane.originX - pane.margin;
            });
            item.regionY = Qt.binding(function() {
                return pane.originY - pane.margin;
            });
            item.running = Qt.binding(function() {
                return pane.windowShown;
            });
        }
    }
}
