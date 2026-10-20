#pragma once

#include <QDateTime>
#include <QImage>
#include <QObject>
#include <QString>
#include <QVariantList>
#include <QVariantMap>

/**
 * Retrouve le fond d'écran du bureau et en échantillonne les couleurs.
 *
 * Le fond d'écran est lu dans la configuration de Plasma
 * (plasma-org.kde.plasma.desktop-appletsrc), ce qui ne dépend d'aucun détail
 * interne de l'interface de Plasma. Les couleurs servent à teinter le contour
 * du Dock ; le chemin de l'image sert au flou de l'arrière-plan.
 */
class WallpaperLocator : public QObject
{
    Q_OBJECT

public:
    explicit WallpaperLocator(QObject *parent = nullptr);

    /**
     * { source: "file:///…", fillMode: 2 } pour l'écran donné, ou une table
     * vide si aucun fond d'écran n'a été trouvé.
     */
    Q_INVOKABLE QVariantMap currentWallpaper(int screenIndex) const;

    /**
     * Couleurs moyennes d'une zone de l'écran, découpée en columns x rows
     * cellules (ligne par ligne). La zone (x, y, w, h) est exprimée en pixels
     * d'écran, screenWidth x screenHeight étant la taille de l'écran.
     * Renvoie une liste vide si l'image est introuvable.
     */
    Q_INVOKABLE QVariantList sampleColors(const QString &source,
                                          int fillMode,
                                          qreal screenWidth,
                                          qreal screenHeight,
                                          qreal x,
                                          qreal y,
                                          qreal w,
                                          qreal h,
                                          int columns,
                                          int rows);

private:
    QImage loadImage(const QString &path);

    QString m_cachePath;
    QDateTime m_cacheStamp;
    QImage m_cache;
};
