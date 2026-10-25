#pragma once

#include <QDateTime>
#include <QFutureWatcher>
#include <QImage>
#include <QPointer>
#include <QQuickItem>
#include <QQuickItemGrabResult>
#include <QQuickPaintedItem>
#include <QSharedPointer>
#include <QString>
#include <QTimer>
#include <QVariantMap>

/**
 * Fond en verre du Dock, dessiné par le Dock lui-même (sans KWin).
 *
 * La zone qui se trouve derrière le Dock est découpée, floutée, puis déformée
 * sur les bords comme par une lentille (réfraction, franges colorées) et
 * éclairée (reflet des bords). Le calcul se fait dans un fil de calcul à part :
 * l'interface ne ralentit jamais.
 *
 * Ce qui est visible à travers le verre :
 *  - le fond d'écran, lu dans son fichier ;
 *  - en direct, les fenêtres qui passent derrière le Dock. Elles sont
 *    dessinées par QML dans « scene » (un élément transparent de la taille de
 *    la zone de calcul, voir regionWidth/regionHeight/margin) ; tant que
 *    « live » est vrai, la scène est relue une trentaine de fois par seconde
 *    et le verre est recalculé dès qu'elle a changé.
 */
class GlassPane : public QQuickPaintedItem
{
    Q_OBJECT
    Q_PROPERTY(bool ready READ ready NOTIFY readyChanged)
    Q_PROPERTY(QQuickItem *scene READ scene WRITE setScene NOTIFY sceneChanged)
    Q_PROPERTY(bool live READ live WRITE setLive NOTIFY liveChanged)
    Q_PROPERTY(int margin READ margin NOTIFY regionChanged)
    Q_PROPERTY(int regionWidth READ regionWidth NOTIFY regionChanged)
    Q_PROPERTY(int regionHeight READ regionHeight NOTIFY regionChanged)

public:
    explicit GlassPane(QQuickItem *parent = nullptr);

    void paint(QPainter *painter) override;

    /**
     * Réglages : source (fichier ou URL file://), fillMode (0 étiré, 1 ajusté,
     * 2 recadré), screenWidth/screenHeight (taille logique de l'écran),
     * originX/originY (position de ce composant à l'écran), radius (coins),
     * blur (rayon du flou en pixels, 0 = net), refraction (booléen),
     * thickness (épaisseur du bord réfracté, px), strength (force de la
     * réfraction), dispersion (franges colorées, 0..1), profile (profil du
     * bord), rim (reflet des bords, 0..2).
     */
    Q_INVOKABLE void configure(const QVariantMap &settings);

    bool ready() const;

    QQuickItem *scene() const;
    void setScene(QQuickItem *scene);

    bool live() const;
    void setLive(bool live);

    int margin() const;
    int regionWidth() const;
    int regionHeight() const;

Q_SIGNALS:
    void readyChanged();
    void sceneChanged();
    void liveChanged();
    void regionChanged();

protected:
    void geometryChange(const QRectF &newGeometry, const QRectF &oldGeometry) override;

private:
    void scheduleRender();
    void render();
    bool loadWallpaper();
    bool ensureBase();
    void updateRegion();
    void startJob();
    void jobFinished();
    void pollScene();
    void sceneGrabbed();
    void setReady(bool ready);

    QTimer m_timer;
    QTimer m_liveTimer;
    QVariantMap m_rawSettings;
    QImage m_image;
    bool m_ready = false;

    QString m_path;
    int m_fillMode = 2;
    qreal m_screenWidth = 0;
    qreal m_screenHeight = 0;
    qreal m_originX = 0;
    qreal m_originY = 0;
    qreal m_radius = 12;
    qreal m_blur = 0;
    bool m_refraction = false;
    qreal m_thickness = 18;
    qreal m_strength = 0.8;
    qreal m_dispersion = 0.25;
    qreal m_profile = 1.0;
    qreal m_rim = 1.0;

    // Zone de calcul : le Dock plus une marge de chaque côté.
    int m_margin = 6;
    int m_regionWidth = 0;
    int m_regionHeight = 0;

    QImage m_wall;
    QString m_wallPath;
    QDateTime m_wallStamp;
    QString m_failedPath;

    // Le fond d'écran découpé à l'emplacement de la zone de calcul.
    QImage m_base;
    QString m_baseKey;

    // Fenêtres en direct.
    QPointer<QQuickItem> m_scene;
    bool m_live = false;
    QImage m_snapshot;
    QSharedPointer<QQuickItemGrabResult> m_grab;
    qint64 m_grabStarted = 0;
    int m_unchangedFrames = 0;

    // Calcul dans un fil à part.
    QFutureWatcher<QImage> m_watcher;
    bool m_jobQueued = false;
};
