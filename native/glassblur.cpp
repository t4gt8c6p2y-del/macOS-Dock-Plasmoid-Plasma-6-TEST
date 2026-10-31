#include "glassblur.h"
#include "glasstheme.h"

#include <QPainterPath>
#include <QPolygonF>
#include <QRectF>
#include <QRegion>
#include <QVariantMap>
#include <QQuickWindow>
#include <QWindow>

#include <KWindowEffects>

namespace
{
// La demande de flou ne prend effet qu'au prochain « commit » de la surface :
// une fenêtre immobile (infobulle) n'en ferait aucun et resterait sans flou
// jusqu'à ce qu'elle se redessine. On force donc une image.
void requestRepaint(QWindow *window)
{
    if (auto *quickWindow = qobject_cast<QQuickWindow *>(window)) {
        quickWindow->update();
    } else {
        window->requestUpdate();
    }
}
}

GlassBlur::GlassBlur(QObject *parent)
    : QObject(parent)
{
}

void GlassBlur::apply(QWindow *window, const QVariantList &rects)
{
    if (!window) {
        return;
    }

    QRegion region;
    for (const QVariant &entry : rects) {
        const QVariantMap map = entry.toMap();
        const QRectF rect(map.value(QStringLiteral("x")).toReal(),
                          map.value(QStringLiteral("y")).toReal(),
                          map.value(QStringLiteral("width")).toReal(),
                          map.value(QStringLiteral("height")).toReal());
        if (rect.width() < 1 || rect.height() < 1) {
            continue;
        }
        const qreal radius = qMin(map.value(QStringLiteral("radius")).toReal(),
                                  qMin(rect.width(), rect.height()) / 2);
        QPainterPath path;
        path.addRoundedRect(rect, radius, radius);
        region += glassRegionFromPath(path);
    }

    KWindowEffects::enableBlurBehind(window, !region.isEmpty(), region);
    requestRepaint(window);
}

void GlassBlur::clear(QWindow *window)
{
    if (window) {
        KWindowEffects::enableBlurBehind(window, false);
        requestRepaint(window);
    }
}

QVariantMap GlassBlur::theme() const
{
    const GlassTheme theme = GlassTheme::load();
    return {
        {QStringLiteral("fillColor"), theme.fill},
        {QStringLiteral("fillOpacity"), theme.fillOpacity},
        {QStringLiteral("rimWidth"), theme.rimWidth},
        {QStringLiteral("rimTop"), theme.rimTop},
        {QStringLiteral("rimSide"), theme.rimSide},
        {QStringLiteral("rimBottom"), theme.rimBottom},
        {QStringLiteral("popupRadius"), theme.popupRadius},
        {QStringLiteral("menuRadius"), theme.menuRadius},
        {QStringLiteral("tooltipRadius"), theme.tooltipRadius},
    };
}
