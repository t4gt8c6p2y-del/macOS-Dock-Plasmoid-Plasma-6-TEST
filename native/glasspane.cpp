#include "glasspane.h"

#include <QDebug>
#include <QFileInfo>
#include <QImageReader>
#include <QPainter>
#include <QSize>
#include <QUrl>

#include <algorithm>
#include <cmath>
#include <vector>

namespace
{
inline float clamp01(float value)
{
    return std::min(1.0f, std::max(0.0f, value));
}

// Flou « boîte » (horizontal puis vertical), bords répliqués. Trois passages
// donnent un flou proche d'un flou gaussien.
void boxBlur(std::vector<float> &data, int width, int height, int radius)
{
    if (radius < 1 || width < 2 || height < 2) {
        return;
    }
    std::vector<float> temp(data.size());
    const float norm = 1.0f / float(2 * radius + 1);

    for (int y = 0; y < height; ++y) {
        const float *in = &data[size_t(y) * size_t(width)];
        float *out = &temp[size_t(y) * size_t(width)];
        float sum = 0;
        for (int i = -radius; i <= radius; ++i) {
            sum += in[std::min(std::max(i, 0), width - 1)];
        }
        for (int x = 0; x < width; ++x) {
            out[x] = sum * norm;
            sum += in[std::min(x + radius + 1, width - 1)] - in[std::max(x - radius, 0)];
        }
    }

    for (int x = 0; x < width; ++x) {
        float sum = 0;
        for (int i = -radius; i <= radius; ++i) {
            sum += temp[size_t(std::min(std::max(i, 0), height - 1)) * size_t(width) + size_t(x)];
        }
        for (int y = 0; y < height; ++y) {
            data[size_t(y) * size_t(width) + size_t(x)] = sum * norm;
            sum += temp[size_t(std::min(y + radius + 1, height - 1)) * size_t(width) + size_t(x)]
                - temp[size_t(std::max(y - radius, 0)) * size_t(width) + size_t(x)];
        }
    }
}

// Lecture bilinéaire ; (x, y) est exprimé en pixels, le centre du pixel i
// étant en i + 0.5. Les coordonnées hors de l'image sont ramenées au bord.
float bilinear(const std::vector<float> &plane, int width, int height, float x, float y)
{
    x = std::min(std::max(x - 0.5f, 0.0f), float(width - 1));
    y = std::min(std::max(y - 0.5f, 0.0f), float(height - 1));
    const int x0 = int(x);
    const int y0 = int(y);
    const int x1 = std::min(x0 + 1, width - 1);
    const int y1 = std::min(y0 + 1, height - 1);
    const float fx = x - float(x0);
    const float fy = y - float(y0);
    const float top = plane[size_t(y0) * size_t(width) + size_t(x0)] * (1.0f - fx)
        + plane[size_t(y0) * size_t(width) + size_t(x1)] * fx;
    const float bottom = plane[size_t(y1) * size_t(width) + size_t(x0)] * (1.0f - fx)
        + plane[size_t(y1) * size_t(width) + size_t(x1)] * fx;
    return top * (1.0f - fy) + bottom * fy;
}
}

GlassPane::GlassPane(QQuickItem *parent)
    : QQuickPaintedItem(parent)
{
    setAntialiasing(true);
    m_timer.setSingleShot(true);
    m_timer.setInterval(60);
    connect(&m_timer, &QTimer::timeout, this, &GlassPane::render);
}

bool GlassPane::ready() const
{
    return m_ready;
}

void GlassPane::setReady(bool ready)
{
    if (m_ready == ready) {
        return;
    }
    m_ready = ready;
    Q_EMIT readyChanged();
}

void GlassPane::paint(QPainter *painter)
{
    if (m_image.isNull()) {
        return;
    }
    painter->setRenderHint(QPainter::SmoothPixmapTransform, true);
    painter->drawImage(QRectF(0, 0, width(), height()), m_image);
}

void GlassPane::configure(const QVariantMap &settings)
{
    if (settings == m_rawSettings) {
        return;
    }
    m_rawSettings = settings;

    const auto number = [&settings](const char *key, qreal fallback) {
        const QVariant value = settings.value(QLatin1String(key));
        return value.isValid() ? value.toDouble() : fallback;
    };

    QString source = settings.value(QStringLiteral("source")).toString();
    if (source.startsWith(QLatin1String("file://"))) {
        source = QUrl(source).toLocalFile();
    }
    m_path = source;
    m_fillMode = int(number("fillMode", 2));
    m_screenWidth = number("screenWidth", 0);
    m_screenHeight = number("screenHeight", 0);
    m_originX = number("originX", 0);
    m_originY = number("originY", 0);
    m_radius = number("radius", 12);
    m_blur = number("blur", 0);
    m_refraction = settings.value(QStringLiteral("refraction")).toBool();
    m_thickness = number("thickness", 18);
    m_strength = number("strength", 0.8);
    m_dispersion = number("dispersion", 0.25);
    m_profile = number("profile", 1.0);
    m_rim = number("rim", 1.0);

    scheduleRender();
}

void GlassPane::geometryChange(const QRectF &newGeometry, const QRectF &oldGeometry)
{
    QQuickPaintedItem::geometryChange(newGeometry, oldGeometry);
    if (newGeometry.size() != oldGeometry.size()) {
        scheduleRender();
    }
}

void GlassPane::scheduleRender()
{
    // Les réglages arrivent en rafale (curseur, Dock qui s'agrandit) : on
    // calcule une seule fois, quand ils se sont stabilisés.
    m_timer.start();
}

bool GlassPane::loadWallpaper()
{
    const QFileInfo info(m_path);
    if (!info.exists() || !info.isFile()) {
        return false;
    }
    if (m_path == m_wallPath && info.lastModified() == m_wallStamp && !m_wall.isNull()) {
        return true;
    }

    QImageReader reader(m_path);
    reader.setAutoTransform(true);
    const QSize size = reader.size();
    if (size.isValid() && size.width() > 1920) {
        const int height = std::max(1, int(std::lround(1920.0 * size.height() / size.width())));
        reader.setScaledSize(QSize(1920, height));
    }
    const QImage image = reader.read();
    if (image.isNull()) {
        if (m_failedPath != m_path) {
            m_failedPath = m_path;
            qWarning() << "GlassPane : image du fond d'écran illisible" << m_path << reader.errorString();
        }
        return false;
    }
    m_wall = image.convertToFormat(QImage::Format_RGB32);
    m_wallPath = m_path;
    m_wallStamp = info.lastModified();
    return true;
}

void GlassPane::render()
{
    const int w = int(std::lround(width()));
    const int h = int(std::lround(height()));
    if (w < 4 || h < 4 || m_path.isEmpty() || m_screenWidth < 1 || m_screenHeight < 1 || !loadWallpaper()) {
        m_image = QImage();
        setReady(false);
        update();
        return;
    }

    const int blurRadius = int(std::lround(std::min(std::max(m_blur, 0.0), 80.0) * 0.5));
    const float thickness = float(std::min(std::max(m_thickness, 2.0), double(std::min(w, h)) / 2.0));
    const float strength = float(std::min(std::max(m_strength, 0.0), 3.0));
    const float dispersion = float(std::min(std::max(m_dispersion, 0.0), 1.0));
    const float profile = float(std::min(std::max(m_profile, 0.3), 5.0));
    const float rim = float(std::min(std::max(m_rim, 0.0), 3.0));
    const bool refraction = m_refraction && strength > 0.001f;

    // Marge autour du Dock : le flou et la réfraction lisent au-delà des bords.
    int margin = 3 * blurRadius + 6;
    if (refraction) {
        margin += int(std::ceil(thickness * strength * 1.6f));
    }
    margin = std::min(std::max(margin, 6), 220);
    const int regionWidth = w + 2 * margin;
    const int regionHeight = h + 2 * margin;

    // 1. La zone du fond d'écran qui entoure le Dock.
    const qreal imageWidth = m_wall.width();
    const qreal imageHeight = m_wall.height();
    qreal scaleX = m_screenWidth / imageWidth;
    qreal scaleY = m_screenHeight / imageHeight;
    if (m_fillMode == 1) {
        scaleX = scaleY = std::min(scaleX, scaleY);
    } else if (m_fillMode != 0) {
        scaleX = scaleY = std::max(scaleX, scaleY);
    }
    const qreal offsetX = (m_screenWidth - imageWidth * scaleX) / 2;
    const qreal offsetY = (m_screenHeight - imageHeight * scaleY) / 2;

    const size_t count = size_t(regionWidth) * size_t(regionHeight);
    std::vector<float> planes[3] = {std::vector<float>(count), std::vector<float>(count), std::vector<float>(count)};
    const int maxX = m_wall.width() - 1;
    const int maxY = m_wall.height() - 1;
    for (int y = 0; y < regionHeight; ++y) {
        const qreal screenY = m_originY - margin + y + 0.5;
        const qreal fy = std::min(std::max((screenY - offsetY) / scaleY - 0.5, 0.0), double(maxY));
        const int y0 = int(fy);
        const int y1 = std::min(y0 + 1, maxY);
        const float ty = float(fy - y0);
        const QRgb *row0 = reinterpret_cast<const QRgb *>(m_wall.constScanLine(y0));
        const QRgb *row1 = reinterpret_cast<const QRgb *>(m_wall.constScanLine(y1));
        for (int x = 0; x < regionWidth; ++x) {
            const qreal screenX = m_originX - margin + x + 0.5;
            const qreal fx = std::min(std::max((screenX - offsetX) / scaleX - 0.5, 0.0), double(maxX));
            const int x0 = int(fx);
            const int x1 = std::min(x0 + 1, maxX);
            const float tx = float(fx - x0);
            const size_t index = size_t(y) * size_t(regionWidth) + size_t(x);
            const QRgb p00 = row0[x0];
            const QRgb p10 = row0[x1];
            const QRgb p01 = row1[x0];
            const QRgb p11 = row1[x1];
            const auto mix = [&](int (*channel)(QRgb)) {
                const float top = float(channel(p00)) * (1.0f - tx) + float(channel(p10)) * tx;
                const float bottom = float(channel(p01)) * (1.0f - tx) + float(channel(p11)) * tx;
                return (top * (1.0f - ty) + bottom * ty) / 255.0f;
            };
            planes[0][index] = mix(qRed);
            planes[1][index] = mix(qGreen);
            planes[2][index] = mix(qBlue);
        }
    }

    // 2. Le flou.
    if (blurRadius > 0) {
        for (int c = 0; c < 3; ++c) {
            for (int pass = 0; pass < 3; ++pass) {
                boxBlur(planes[c], regionWidth, regionHeight, blurRadius);
            }
        }
    }

    // 3. La forme du Dock, la réfraction des bords et le reflet.
    QImage out(w, h, QImage::Format_ARGB32_Premultiplied);
    const float halfWidth = float(w) * 0.5f;
    const float halfHeight = float(h) * 0.5f;
    const float radius = float(std::min(std::max(m_radius, 0.0), double(std::min(halfWidth, halfHeight))));

    for (int y = 0; y < h; ++y) {
        QRgb *line = reinterpret_cast<QRgb *>(out.scanLine(y));
        for (int x = 0; x < w; ++x) {
            const float px = float(x) + 0.5f - halfWidth;
            const float py = float(y) + 0.5f - halfHeight;
            const float qx = std::fabs(px) - (halfWidth - radius);
            const float qy = std::fabs(py) - (halfHeight - radius);
            const float ox = std::max(qx, 0.0f);
            const float oy = std::max(qy, 0.0f);
            const float outside = std::sqrt(ox * ox + oy * oy);
            // Distance signée au rectangle arrondi (négative à l'intérieur).
            const float distance = outside + std::min(std::max(qx, qy), 0.0f) - radius;
            const float coverage = clamp01(0.5f - distance);
            if (coverage <= 0.0f) {
                line[x] = 0;
                continue;
            }

            // Normale sortante du bord le plus proche.
            float nx = 0.0f;
            float ny = 0.0f;
            if (outside > 1e-4f) {
                nx = (px < 0.0f ? -1.0f : 1.0f) * ox / outside;
                ny = (py < 0.0f ? -1.0f : 1.0f) * oy / outside;
            } else if (qx > qy) {
                nx = px < 0.0f ? -1.0f : 1.0f;
            } else {
                ny = py < 0.0f ? -1.0f : 1.0f;
            }

            const float depth = -distance;
            float displacement = 0.0f;
            if (refraction && depth < thickness) {
                const float e = 1.0f - depth / thickness;
                const float smooth = e * e * (3.0f - 2.0f * e);
                displacement = strength * thickness * std::pow(smooth, profile);
            }

            float rgb[3];
            for (int c = 0; c < 3; ++c) {
                // Chaque couleur est déviée un peu différemment : franges.
                const float k = 1.0f + dispersion * 0.4f * float(c - 1);
                const float sx = float(margin) + float(x) + 0.5f + nx * displacement * k;
                const float sy = float(margin) + float(y) + 0.5f + ny * displacement * k;
                rgb[c] = bilinear(planes[c], regionWidth, regionHeight, sx, sy);
            }

            if (rim > 0.0f) {
                // Reflet : plus vif sur les bords tournés vers le haut gauche.
                const float glow = std::exp(-depth / 2.5f);
                const float facing = std::fabs(nx * -0.5f + ny * -0.85f);
                const float add = clamp01(rim * 0.35f * glow * (0.3f + 0.7f * facing));
                for (int c = 0; c < 3; ++c) {
                    rgb[c] += (1.0f - rgb[c]) * add;
                }
            }

            const int alpha = int(std::lround(coverage * 255.0f));
            line[x] = qRgba(int(std::lround(clamp01(rgb[0]) * coverage * 255.0f)),
                            int(std::lround(clamp01(rgb[1]) * coverage * 255.0f)),
                            int(std::lround(clamp01(rgb[2]) * coverage * 255.0f)),
                            alpha);
        }
    }

    m_image = out;
    setReady(true);
    update();
}
