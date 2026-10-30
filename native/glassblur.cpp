#include "glassblur.h"

#include <QPainterPath>
#include <QPolygonF>
#include <QRectF>
#include <QRegion>
#include <QVariantMap>
#include <QWindow>

#include <KWindowEffects>

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
        region += QRegion(path.toFillPolygon().toPolygon());
    }

    KWindowEffects::enableBlurBehind(window, !region.isEmpty(), region);
}

void GlassBlur::clear(QWindow *window)
{
    if (window) {
        KWindowEffects::enableBlurBehind(window, false);
    }
}
