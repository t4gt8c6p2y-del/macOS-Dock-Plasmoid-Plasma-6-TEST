#pragma once

#include <QColor>
#include <QDir>
#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QPainterPath>
#include <QPolygonF>
#include <QRegion>
#include <QStandardPaths>

// Réglages du thème « Liquid Glass for KDE » de l'utilisateur
// (~/.config/liquid-glass-kde/settings.json). Les bulles du Dock les relisent à
// chaque ouverture : modifier le thème (liquidglassctl, application de
// réglages) change aussi leur aspect. Valeurs par défaut = celles du thème.
struct GlassTheme
{
    QColor fill = QColor(0x1c, 0x1c, 0x1e);
    qreal fillOpacity = 0.06;
    qreal rimWidth = 1.0;
    qreal rimTop = 0.10;
    qreal rimSide = 0.06;
    qreal rimBottom = 0.08;
    qreal popupRadius = 24;
    qreal menuRadius = 12;
    qreal tooltipRadius = 12;

    static GlassTheme load()
    {
        GlassTheme theme;
        const QString path = QStandardPaths::writableLocation(
                                 QStandardPaths::GenericConfigLocation)
            + QStringLiteral("/liquid-glass-kde/settings.json");
        QFile file(path);
        if (!file.open(QIODevice::ReadOnly)) {
            return theme;
        }
        const QJsonObject root = QJsonDocument::fromJson(file.readAll()).object();
        const QJsonObject themeObject = root.value(QStringLiteral("theme")).toObject();
        const QJsonObject effectObject = root.value(QStringLiteral("effect")).toObject();

        const auto number = [](const QJsonObject &object, const char *key,
                               qreal fallback) {
            const QJsonValue value = object.value(QLatin1String(key));
            return value.isDouble() ? value.toDouble() : fallback;
        };

        theme.rimWidth = number(themeObject, "rim_width", theme.rimWidth);
        theme.rimTop = number(themeObject, "rim_top", theme.rimTop);
        theme.rimSide = number(themeObject, "rim_side", theme.rimSide);
        theme.rimBottom = number(themeObject, "rim_bottom", theme.rimBottom);
        theme.fillOpacity = number(themeObject, "tint_opacity", theme.fillOpacity);
        theme.menuRadius = number(themeObject, "menu_radius", theme.menuRadius);
        theme.tooltipRadius = number(themeObject, "tooltip_radius", theme.tooltipRadius);
        // Le rayon vu par KWin (effet Glass) est celui de « effect » : la bulle
        // l'utilise pour que sa forme coïncide avec celle du verre.
        theme.popupRadius = number(effectObject, "popup_radius",
                                   number(themeObject, "popup_radius", theme.popupRadius));
        const QColor tint(effectObject.value(QStringLiteral("tint_color")).toString());
        if (tint.isValid()) {
            theme.fill = tint;
        }
        return theme;
    }
};

// Région (en pixels) d'un tracé : chaque sous-tracé est rempli séparément
// (toFillPolygon() les relierait en un seul polygone et ferait des trous).
inline QRegion glassRegionFromPath(const QPainterPath &path)
{
    QRegion region;
    const QList<QPolygonF> polygons = path.toFillPolygons();
    for (const QPolygonF &polygon : polygons) {
        region = region.united(QRegion(polygon.toPolygon()));
    }
    return region;
}
