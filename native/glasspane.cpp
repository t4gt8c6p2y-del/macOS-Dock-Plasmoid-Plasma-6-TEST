#include "glasspane.h"

#include <QDebug>
#include <QFileInfo>
#include <QImageReader>
#include <QPainter>
#include <QQuickWindow>
#include <QSize>
#include <QUrl>
#include <QtConcurrent/QtConcurrentRun>

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

// Tout ce dont le calcul du verre a besoin : une copie des réglages et des
// images (partagées, jamais modifiées), pour pouvoir tourner dans un autre fil.
struct GlassJob
{
    // Le fond d'écran à l'emplacement de la zone de calcul (Format_RGB32).
    QImage base;
    // Les fenêtres derrière le Dock, même taille que « base »
    // (Format_ARGB32_Premultiplied). Peut être vide.
    QImage snapshot;
    int width = 0;
    int height = 0;
    int margin = 0;
    int blurRadius = 0;
    float radius = 12.0f;
    bool refraction = false;
    float thickness = 18.0f;
    float strength = 0.8f;
    float dispersion = 0.25f;
    float profile = 1.0f;
    float rim = 1.0f;
};

QImage composeGlass(const GlassJob &job)
{
    const int regionWidth = job.base.width();
    const int regionHeight = job.base.height();
    const int w = job.width;
    const int h = job.height;
    const int margin = job.margin;
    if (regionWidth < 1 || regionHeight < 1 || w < 1 || h < 1) {
        return QImage();
    }
    const bool overlay = !job.snapshot.isNull() && job.snapshot.size() == job.base.size();

    // 1. Le fond d'écran, avec les fenêtres posées dessus. Quand le flou est
    //    fort, on travaille à une résolution réduite (2x ou 4x) : le résultat
    //    est le même, le calcul bien plus rapide.
    int downscale = 1;
    if (job.blurRadius >= 16) {
        downscale = 4;
    } else if (job.blurRadius >= 6) {
        downscale = 2;
    }
    const int lowWidth = (regionWidth + downscale - 1) / downscale;
    const int lowHeight = (regionHeight + downscale - 1) / downscale;
    const size_t count = size_t(lowWidth) * size_t(lowHeight);
    std::vector<float> planes[3] = {std::vector<float>(count), std::vector<float>(count), std::vector<float>(count)};

    for (int ly = 0; ly < lowHeight; ++ly) {
        for (int lx = 0; lx < lowWidth; ++lx) {
            float sum[3] = {0.0f, 0.0f, 0.0f};
            int samples = 0;
            for (int dy = 0; dy < downscale; ++dy) {
                const int y = ly * downscale + dy;
                if (y >= regionHeight) {
                    break;
                }
                const QRgb *baseLine = reinterpret_cast<const QRgb *>(job.base.constScanLine(y));
                const QRgb *overLine = overlay ? reinterpret_cast<const QRgb *>(job.snapshot.constScanLine(y)) : nullptr;
                for (int dx = 0; dx < downscale; ++dx) {
                    const int x = lx * downscale + dx;
                    if (x >= regionWidth) {
                        break;
                    }
                    float r = float(qRed(baseLine[x]));
                    float g = float(qGreen(baseLine[x]));
                    float b = float(qBlue(baseLine[x]));
                    if (overLine) {
                        // Les fenêtres sont en alpha prémultiplié :
                        // résultat = fenêtre + fond * (1 - opacité).
                        const QRgb above = overLine[x];
                        const float keep = 1.0f - float(qAlpha(above)) / 255.0f;
                        r = std::min(255.0f, r * keep + float(qRed(above)));
                        g = std::min(255.0f, g * keep + float(qGreen(above)));
                        b = std::min(255.0f, b * keep + float(qBlue(above)));
                    }
                    sum[0] += r;
                    sum[1] += g;
                    sum[2] += b;
                    ++samples;
                }
            }
            const size_t index = size_t(ly) * size_t(lowWidth) + size_t(lx);
            const float scale = 1.0f / (255.0f * float(std::max(samples, 1)));
            planes[0][index] = sum[0] * scale;
            planes[1][index] = sum[1] * scale;
            planes[2][index] = sum[2] * scale;
        }
    }

    // 2. Le flou.
    if (job.blurRadius > 0) {
        const int radius = std::max(1, (job.blurRadius + downscale / 2) / downscale);
        for (int c = 0; c < 3; ++c) {
            for (int pass = 0; pass < 3; ++pass) {
                boxBlur(planes[c], lowWidth, lowHeight, radius);
            }
        }
    }

    // 3. La forme du Dock, la réfraction des bords et le reflet.
    QImage out(w, h, QImage::Format_ARGB32_Premultiplied);
    const float halfWidth = float(w) * 0.5f;
    const float halfHeight = float(h) * 0.5f;
    const float radius = std::min(std::max(job.radius, 0.0f), std::min(halfWidth, halfHeight));
    const float inverseScale = 1.0f / float(downscale);

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
            if (job.refraction && depth < job.thickness) {
                const float e = 1.0f - depth / job.thickness;
                const float smooth = e * e * (3.0f - 2.0f * e);
                displacement = job.strength * job.thickness * std::pow(smooth, job.profile);
            }

            float rgb[3];
            for (int c = 0; c < 3; ++c) {
                // Chaque couleur est déviée un peu différemment : franges.
                const float k = 1.0f + job.dispersion * 0.4f * float(c - 1);
                const float sx = float(margin) + float(x) + 0.5f + nx * displacement * k;
                const float sy = float(margin) + float(y) + 0.5f + ny * displacement * k;
                rgb[c] = bilinear(planes[c], lowWidth, lowHeight, sx * inverseScale, sy * inverseScale);
            }

            if (job.rim > 0.0f) {
                // Reflet : plus vif sur les bords tournés vers le haut gauche.
                const float glow = std::exp(-depth / 2.5f);
                const float facing = std::fabs(nx * -0.5f + ny * -0.85f);
                const float add = clamp01(job.rim * 0.35f * glow * (0.3f + 0.7f * facing));
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
    return out;
}
}

GlassPane::GlassPane(QQuickItem *parent)
    : QQuickPaintedItem(parent)
{
    setAntialiasing(true);
    m_timer.setSingleShot(true);
    m_timer.setInterval(60);
    connect(&m_timer, &QTimer::timeout, this, &GlassPane::render);

    m_liveTimer.setInterval(33);
    connect(&m_liveTimer, &QTimer::timeout, this, &GlassPane::pollScene);

    connect(&m_watcher, &QFutureWatcher<QImage>::finished, this, &GlassPane::jobFinished);
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

QQuickItem *GlassPane::scene() const
{
    return m_scene;
}

void GlassPane::setScene(QQuickItem *scene)
{
    if (m_scene == scene) {
        return;
    }
    m_scene = scene;
    m_grab.reset();
    Q_EMIT sceneChanged();
}

bool GlassPane::live() const
{
    return m_live;
}

void GlassPane::setLive(bool live)
{
    if (m_live == live) {
        return;
    }
    m_live = live;
    m_unchangedFrames = 0;
    if (m_live) {
        m_liveTimer.setInterval(33);
        m_liveTimer.start();
    } else {
        m_liveTimer.stop();
        m_grab.reset();
        if (!m_snapshot.isNull()) {
            // Plus de fenêtre derrière le Dock : le fond d'écran seul.
            m_snapshot = QImage();
            scheduleRender();
        }
    }
    Q_EMIT liveChanged();
}

int GlassPane::margin() const
{
    return m_margin;
}

int GlassPane::regionWidth() const
{
    return m_regionWidth;
}

int GlassPane::regionHeight() const
{
    return m_regionHeight;
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

    updateRegion();
    scheduleRender();
}

void GlassPane::geometryChange(const QRectF &newGeometry, const QRectF &oldGeometry)
{
    QQuickPaintedItem::geometryChange(newGeometry, oldGeometry);
    if (newGeometry.size() != oldGeometry.size()) {
        updateRegion();
        scheduleRender();
    }
}

// Calcule la marge (le flou et la réfraction lisent au-delà des bords du Dock)
// et la taille de la zone de calcul. QML dessine les fenêtres dans une scène de
// cette taille.
void GlassPane::updateRegion()
{
    const int w = int(std::lround(width()));
    const int h = int(std::lround(height()));
    const int blurRadius = int(std::lround(std::min(std::max(m_blur, 0.0), 80.0) * 0.5));
    const double thickness = std::min(std::max(m_thickness, 2.0), double(std::max(1, std::min(w, h))) / 2.0);
    const double strength = std::min(std::max(m_strength, 0.0), 3.0);
    const bool refraction = m_refraction && strength > 0.001;

    int margin = 3 * blurRadius + 6;
    if (refraction) {
        margin += int(std::ceil(thickness * strength * 1.6));
    }
    margin = std::min(std::max(margin, 6), 220);
    const int regionWidth = (w >= 4 && h >= 4) ? w + 2 * margin : 0;
    const int regionHeight = (w >= 4 && h >= 4) ? h + 2 * margin : 0;

    if (margin == m_margin && regionWidth == m_regionWidth && regionHeight == m_regionHeight) {
        return;
    }
    m_margin = margin;
    m_regionWidth = regionWidth;
    m_regionHeight = regionHeight;
    Q_EMIT regionChanged();
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

// Découpe le fond d'écran à l'emplacement de la zone de calcul (le Dock et sa
// marge). Le résultat est gardé tant que rien ne change : les images en direct
// n'ont pas à le recalculer.
bool GlassPane::ensureBase()
{
    if (m_path.isEmpty() || m_screenWidth < 1 || m_screenHeight < 1 || m_regionWidth < 1 || m_regionHeight < 1
        || !loadWallpaper()) {
        return false;
    }

    const QString key = QStringLiteral("%1|%2|%3|%4|%5|%6|%7|%8|%9|%10")
                            .arg(m_wallPath)
                            .arg(m_wallStamp.toMSecsSinceEpoch())
                            .arg(m_fillMode)
                            .arg(m_screenWidth, 0, 'f', 2)
                            .arg(m_screenHeight, 0, 'f', 2)
                            .arg(m_originX, 0, 'f', 2)
                            .arg(m_originY, 0, 'f', 2)
                            .arg(m_regionWidth)
                            .arg(m_regionHeight)
                            .arg(m_margin);
    if (!m_base.isNull() && key == m_baseKey) {
        return true;
    }

    const int regionWidth = m_regionWidth;
    const int regionHeight = m_regionHeight;
    const int margin = m_margin;

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

    QImage base(regionWidth, regionHeight, QImage::Format_RGB32);
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
        QRgb *line = reinterpret_cast<QRgb *>(base.scanLine(y));
        for (int x = 0; x < regionWidth; ++x) {
            const qreal screenX = m_originX - margin + x + 0.5;
            const qreal fx = std::min(std::max((screenX - offsetX) / scaleX - 0.5, 0.0), double(maxX));
            const int x0 = int(fx);
            const int x1 = std::min(x0 + 1, maxX);
            const float tx = float(fx - x0);
            const QRgb p00 = row0[x0];
            const QRgb p10 = row0[x1];
            const QRgb p01 = row1[x0];
            const QRgb p11 = row1[x1];
            const auto mix = [&](int (*channel)(QRgb)) {
                const float top = float(channel(p00)) * (1.0f - tx) + float(channel(p10)) * tx;
                const float bottom = float(channel(p01)) * (1.0f - tx) + float(channel(p11)) * tx;
                return top * (1.0f - ty) + bottom * ty;
            };
            line[x] = qRgb(int(std::lround(mix(qRed))), int(std::lround(mix(qGreen))), int(std::lround(mix(qBlue))));
        }
    }

    m_base = base;
    m_baseKey = key;
    return true;
}

void GlassPane::render()
{
    const int w = int(std::lround(width()));
    const int h = int(std::lround(height()));
    if (w < 4 || h < 4 || !ensureBase()) {
        m_base = QImage();
        m_baseKey.clear();
        m_image = QImage();
        setReady(false);
        update();
        return;
    }
    startJob();
}

// Lance le calcul du verre dans un fil à part. Si un calcul est déjà en cours,
// un seul nouveau calcul est mis en attente (avec les données les plus
// récentes) : on ne s'empile jamais.
void GlassPane::startJob()
{
    const int w = int(std::lround(width()));
    const int h = int(std::lround(height()));
    if (m_base.isNull() || w < 4 || h < 4) {
        return;
    }
    if (m_watcher.isRunning()) {
        m_jobQueued = true;
        return;
    }
    m_jobQueued = false;

    GlassJob job;
    job.base = m_base;
    job.snapshot = m_live ? m_snapshot : QImage();
    job.width = w;
    job.height = h;
    job.margin = m_margin;
    job.blurRadius = int(std::lround(std::min(std::max(m_blur, 0.0), 80.0) * 0.5));
    job.radius = float(std::min(std::max(m_radius, 0.0), double(std::min(w, h)) / 2.0));
    job.strength = float(std::min(std::max(m_strength, 0.0), 3.0));
    job.thickness = float(std::min(std::max(m_thickness, 2.0), double(std::min(w, h)) / 2.0));
    job.dispersion = float(std::min(std::max(m_dispersion, 0.0), 1.0));
    job.profile = float(std::min(std::max(m_profile, 0.3), 5.0));
    job.rim = float(std::min(std::max(m_rim, 0.0), 3.0));
    job.refraction = m_refraction && job.strength > 0.001f;

    m_watcher.setFuture(QtConcurrent::run([job]() {
        return composeGlass(job);
    }));
}

void GlassPane::jobFinished()
{
    if (m_base.isNull()) {
        // Les réglages ont changé pendant le calcul : le résultat ne vaut plus.
        m_image = QImage();
        setReady(false);
        update();
        return;
    }
    m_image = m_watcher.future().result();
    setReady(!m_image.isNull());
    update();
    if (m_jobQueued) {
        startJob();
    }
}

// Relit la scène des fenêtres (voir « scene »). La relecture est asynchrone ;
// sceneGrabbed() reçoit l'image.
void GlassPane::pollScene()
{
    if (!m_live || !m_scene || m_regionWidth < 1 || m_regionHeight < 1) {
        return;
    }
    if (m_grab) {
        // La relecture précédente n'est jamais arrivée (fenêtre masquée, par
        // exemple) : on repart de zéro.
        if (QDateTime::currentMSecsSinceEpoch() - m_grabStarted > 1500) {
            m_grab.reset();
        }
        return;
    }
    if (!isVisible() || m_scene->width() < 1 || m_scene->height() < 1) {
        return;
    }
    QQuickWindow *window = m_scene->window();
    if (!window || !window->isVisible()) {
        return;
    }
    m_grab = m_scene->grabToImage(QSize(m_regionWidth, m_regionHeight));
    if (!m_grab) {
        return;
    }
    m_grabStarted = QDateTime::currentMSecsSinceEpoch();
    connect(m_grab.data(), &QQuickItemGrabResult::ready, this, &GlassPane::sceneGrabbed);
}

void GlassPane::sceneGrabbed()
{
    const QSharedPointer<QQuickItemGrabResult> grab = m_grab;
    m_grab.reset();
    if (!grab || !m_live) {
        return;
    }
    QImage image = grab->image();
    if (image.isNull()) {
        return;
    }
    if (image.format() != QImage::Format_ARGB32_Premultiplied) {
        image = image.convertToFormat(QImage::Format_ARGB32_Premultiplied);
    }

    // Rien n'a bougé derrière le Dock : on ne recalcule pas, et on relit moins
    // souvent (30 fois par seconde tant que ça bouge, 8 fois sinon).
    if (!m_snapshot.isNull() && image == m_snapshot) {
        if (++m_unchangedFrames == 20) {
            m_liveTimer.setInterval(120);
        }
        return;
    }
    m_unchangedFrames = 0;
    if (m_liveTimer.interval() != 33) {
        m_liveTimer.setInterval(33);
    }
    m_snapshot = image;
    startJob();
}
