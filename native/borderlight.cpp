#include "borderlight.h"

#include <QImage>
#include <QPainter>
#include <QQuickWindow>

#include <algorithm>
#include <cmath>

BorderLight::BorderLight(QQuickItem *parent)
    : QQuickPaintedItem(parent)
{
    connect(this, &BorderLight::changed, this, [this]() {
        update();
    });
}

void BorderLight::paint(QPainter *painter)
{
    const double w = width();
    const double h = height();
    if (m_peak < 0.003 || w < 4.0 || h < 4.0) {
        return;
    }

    const double dpr = window() ? window()->effectiveDevicePixelRatio() : 1.0;
    const int imageWidth = int(std::ceil(w * dpr));
    const int imageHeight = int(std::ceil(h * dpr));
    if (imageWidth < 2 || imageHeight < 2) {
        return;
    }

    QImage image(imageWidth, imageHeight, QImage::Format_ARGB32_Premultiplied);
    image.fill(Qt::transparent);

    const double halfWidth = w * 0.5;
    const double halfHeight = h * 0.5;
    const double radius = std::min(std::max(m_cornerRadius, 0.0), std::min(halfWidth, halfHeight));
    const double lineWidth = std::max(0.25, m_lineWidth);
    const double depth = std::max(0.0, m_depth);
    // Au-delà de cette distance au bord, rien n'est dessiné.
    const double band = lineWidth + depth + 1.0;
    const double lightRadius = std::max(1.0, m_lightRadius);
    const double falloff = 2.2 / (lightRadius * lightRadius);

    for (int y = 0; y < imageHeight; ++y) {
        QRgb *line = reinterpret_cast<QRgb *>(image.scanLine(y));
        const double ly = (double(y) + 0.5) / dpr;
        const double qy = std::fabs(ly - halfHeight) - (halfHeight - radius);
        const double oy = std::max(qy, 0.0);
        for (int x = 0; x < imageWidth; ++x) {
            const double lx = (double(x) + 0.5) / dpr;
            const double qx = std::fabs(lx - halfWidth) - (halfWidth - radius);
            const double ox = std::max(qx, 0.0);
            // Distance signée au rectangle arrondi (négative à l'intérieur) ;
            // « inside » est la profondeur du pixel sous le bord extérieur.
            const double distance = std::sqrt(ox * ox + oy * oy) + std::min(std::max(qx, qy), 0.0) - radius;
            const double inside = -distance;
            if (inside < -0.5 || inside > band) {
                continue;
            }

            const double coverage = std::min(1.0, std::max(0.0, 0.5 + inside));
            // Le trait lui-même, puis la lueur qui s'estompe vers l'intérieur.
            double weight = std::min(1.0, std::max(0.0, lineWidth - (inside - 0.5)));
            if (depth > 0.0) {
                const double u = (inside - lineWidth) / depth;
                if (u > 0.0 && u < 1.0) {
                    weight = std::max(weight, m_glowScale * (1.0 - u) * (1.0 - u));
                }
            }
            if (weight <= 0.0) {
                continue;
            }

            const double d1x = lx - m_lightX1;
            const double d1y = ly - m_lightY1;
            const double d2x = lx - m_lightX2;
            const double d2y = ly - m_lightY2;
            const double light = std::exp(-falloff * (d1x * d1x + d1y * d1y))
                + m_secondaryScale * std::exp(-falloff * (d2x * d2x + d2y * d2y));
            const double alpha = std::min(1.0, m_peak * light) * coverage * weight;
            const int value = int(std::lround(std::min(1.0, std::max(0.0, alpha)) * 255.0));
            if (value > 0) {
                line[x] = qRgba(value, value, value, value);
            }
        }
    }

    image.setDevicePixelRatio(dpr);
    painter->setRenderHint(QPainter::SmoothPixmapTransform, true);
    painter->drawImage(QRectF(0, 0, w, h), image);
}
