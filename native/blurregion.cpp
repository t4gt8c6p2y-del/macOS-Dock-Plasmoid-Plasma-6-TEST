#include "blurregion.h"

#include <KWindowEffects>

#include <QEvent>
#include <QPainterPath>
#include <QPlatformSurfaceEvent>
#include <QRegion>
#include <QTimer>
#include <QWindow>

#include <algorithm>
#include <cmath>

namespace {

// Construit un rectangle à coins arrondis ligne par ligne (1 px de haut).
// Contrairement à un polygone aplati puis rasterisé, le profil suit le vrai
// cercle pixel par pixel : les coins restent ronds, même avec un grand rayon.
QRegion roundedRegion(const QRect &rect, qreal radius)
{
    if (radius <= 0.5) {
        return QRegion(rect);
    }

    const int rows = std::min(static_cast<int>(std::ceil(radius)),
                              rect.height() / 2);
    QRegion region;
    for (int row = 0; row < rows; ++row) {
        const qreal dy = radius - (row + 0.5);
        const qreal dx = radius - std::sqrt(std::max<qreal>(
            0.0, radius * radius - dy * dy));
        const int inset = std::min(static_cast<int>(std::lround(dx)),
                                   rect.width() / 2);
        const int width = rect.width() - 2 * inset;
        if (width <= 0) {
            continue;
        }
        region += QRect(rect.left() + inset, rect.top() + row, width, 1);
        region += QRect(rect.left() + inset, rect.bottom() - row, width, 1);
    }
    const int middleHeight = rect.height() - 2 * rows;
    if (middleHeight > 0) {
        region += QRect(rect.left(), rect.top() + rows,
                        rect.width(), middleHeight);
    }
    return region;
}

} // namespace

BlurRegion::BlurRegion(QObject *parent)
    : QObject(parent)
{
}

BlurRegion::~BlurRegion()
{
    if (m_window) {
        disableFor(m_window);
        m_window->removeEventFilter(this);
    }
}

QWindow *BlurRegion::window() const
{
    return m_window;
}

void BlurRegion::setWindow(QWindow *window)
{
    if (m_window == window) {
        return;
    }

    if (m_window) {
        disableFor(m_window);
        m_window->removeEventFilter(this);
        disconnect(m_window, nullptr, this, nullptr);
    }

    m_window = window;

    if (m_window) {
        m_window->installEventFilter(this);
        connect(m_window, &QWindow::visibleChanged, this,
                [this](bool visible) {
                    if (visible) {
                        scheduleApply();
                    }
                });
        connect(m_window, &QWindow::widthChanged,
                this, &BlurRegion::scheduleApply);
        connect(m_window, &QWindow::heightChanged,
                this, &BlurRegion::scheduleApply);
    }

    Q_EMIT windowChanged();
    scheduleApply();
}

QRectF BlurRegion::region() const
{
    return m_region;
}

void BlurRegion::setRegion(const QRectF &region)
{
    if (m_region == region) {
        return;
    }

    m_region = region;
    Q_EMIT regionChanged();
    scheduleApply();
}

qreal BlurRegion::radius() const
{
    return m_radius;
}

void BlurRegion::setRadius(qreal radius)
{
    radius = std::max<qreal>(0.0, radius);
    if (qFuzzyCompare(m_radius, radius)) {
        return;
    }

    m_radius = radius;
    Q_EMIT radiusChanged();
    scheduleApply();
}

bool BlurRegion::enabled() const
{
    return m_enabled;
}

void BlurRegion::setEnabled(bool enabled)
{
    if (m_enabled == enabled) {
        return;
    }

    m_enabled = enabled;
    Q_EMIT enabledChanged();
    scheduleApply();
}

void BlurRegion::apply()
{
    m_applyScheduled = false;

    if (!m_window) {
        return;
    }

    // Applying an effect before a layer-shell surface becomes visible can
    // race its native surface creation. visibleChanged schedules a fresh pass.
    if (!m_window->isVisible()) {
        return;
    }

    if (!m_enabled || m_region.isEmpty()) {
        disableFor(m_window);
        return;
    }

    // Une zone de flou qui touche le bord de la fenêtre fait apparaître des
    // barres claires rectilignes le long de ce bord (artefact du compositeur),
    // qui ignorent l'arrondi des coins. On garde donc la zone légèrement à
    // l'intérieur de la fenêtre : le fond du dock reste dessiné jusqu'au bord,
    // seul un liseré de quelques pixels n'est pas flouté.
    constexpr int kWindowEdgeInset = 2;
    const QRect windowBounds(0, 0, m_window->width(), m_window->height());
    const QRect safeBounds = windowBounds.adjusted(
        kWindowEdgeInset, kWindowEdgeInset,
        -kWindowEdgeInset, -kWindowEdgeInset);
    QRect blurRect = m_region.toAlignedRect().intersected(safeBounds);

    if (blurRect.isEmpty()) {
        disableFor(m_window);
        return;
    }

    const qreal effectiveRadius = std::min<qreal>(
        m_radius, std::min(blurRect.width(), blurRect.height()) / 2.0);

    KWindowEffects::enableBlurBehind(m_window, true,
                                     roundedRegion(blurRect, effectiveRadius));
}

bool BlurRegion::eventFilter(QObject *watched, QEvent *event)
{
    if (watched == m_window
            && event->type() == QEvent::PlatformSurface) {
        const auto *surfaceEvent = static_cast<QPlatformSurfaceEvent *>(event);
        if (surfaceEvent->surfaceEventType()
                == QPlatformSurfaceEvent::SurfaceCreated) {
            scheduleApply();
        }
    }

    return QObject::eventFilter(watched, event);
}

void BlurRegion::scheduleApply()
{
    if (m_applyScheduled) {
        return;
    }

    m_applyScheduled = true;
    QTimer::singleShot(0, this, &BlurRegion::apply);
}

void BlurRegion::disableFor(QWindow *window)
{
    KWindowEffects::enableBlurBehind(window, false);
}
