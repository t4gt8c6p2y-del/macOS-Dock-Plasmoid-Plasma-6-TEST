#pragma once

#include <QDateTime>
#include <QImage>
#include <QQuickPaintedItem>
#include <QString>
#include <QTimer>
#include <QVariantMap>

/**
 * Fond en verre du Dock, dessiné par le Dock lui-même (sans KWin).
 *
 * À partir de l'image du fond d'écran, la zone qui se trouve derrière le Dock
 * est découpée, floutée, puis déformée sur les bords comme par une lentille
 * (réfraction, franges colorées) et éclairée (reflet des bords). Le résultat
 * est une simple image : rien n'est recalculé à chaque image affichée.
 *
 * Seul le fond d'écran est visible dans ce verre : un composant graphique ne
 * peut pas lire le contenu des autres fenêtres.
 */
class GlassPane : public QQuickPaintedItem
{
    Q_OBJECT
    Q_PROPERTY(bool ready READ ready NOTIFY readyChanged)

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

Q_SIGNALS:
    void readyChanged();

protected:
    void geometryChange(const QRectF &newGeometry, const QRectF &oldGeometry) override;

private:
    void scheduleRender();
    void render();
    bool loadWallpaper();
    void setReady(bool ready);

    QTimer m_timer;
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

    QImage m_wall;
    QString m_wallPath;
    QDateTime m_wallStamp;
    QString m_failedPath;
};
