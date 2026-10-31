#include "dockmenu.h"

#include <QAction>
#include <QApplication>
#include <QIcon>
#include <QLinearGradient>
#include <QMenu>
#include <QPaintEvent>
#include <QPainterPath>
#include <QPainterPathStroker>
#include <QPoint>
#include <QPointF>
#include <QPolygonF>
#include <QRegion>
#include <QResizeEvent>
#include <QShowEvent>
#include <QSize>
#include <QStyleOptionMenuItem>
#include <QStylePainter>
#include <QTimer>
#include <QVariantMap>
#include <QWindow>

#include <KWindowEffects>

#include "glasstheme.h"

namespace
{
constexpr int bubbleTailHeight = 10;
constexpr int bubbleTailWidth = 24;
constexpr int bubbleGap = 4;

QPointF mix(const QPointF &a, const QPointF &b, qreal t)
{
    return a + (b - a) * t;
}

// QMenu::popup() recale le menu dans l'écran en prenant les coordonnées du
// parent pour des coordonnées d'écran : or la fenêtre du Dock (layer-shell) est
// petite et son origine est (0, 0). Un menu qui doit remonter au-dessus de
// cette fenêtre était donc repoussé vers le bas. On remet la position voulue
// juste avant l'affichage (le compositeur place ensuite le popup par rapport
// à la fenêtre du Dock, sans rien recaler de plus).
class PositionedMenu : public QMenu
{
public:
    void setDesiredPosition(const QPoint &position)
    {
        m_desired = position;
        m_hasDesired = true;
    }

    void setVisible(bool visible) override
    {
        if (visible && m_hasDesired) {
            setGeometry(QRect(m_desired, size()));
        }
        QMenu::setVisible(visible);
    }

private:
    QPoint m_desired;
    bool m_hasDesired = false;
};

// Menu en bulle : le fond est dessiné ici (rectangle arrondi + pointe en « V »
// arrondi), les entrées le sont par le style Qt de l'utilisateur (Kvantum),
// comme dans un menu ordinaire. Le fond est quasi transparent : c'est le flou
// de KWin (effet Glass), demandé sur la forme exacte de la bulle, qui le
// rend visible. Couleurs, liseré et rayon viennent du thème Liquid Glass.
class BubbleMenu : public PositionedMenu
{
public:
    enum class TailSide { Bottom, Top, Left, Right };

    explicit BubbleMenu(TailSide side)
        : m_side(side)
        , m_theme(GlassTheme::load())
    {
        switch (side) {
        case TailSide::Bottom:
            setContentsMargins(0, 0, 0, bubbleTailHeight);
            break;
        case TailSide::Top:
            setContentsMargins(0, bubbleTailHeight, 0, 0);
            break;
        case TailSide::Left:
            setContentsMargins(bubbleTailHeight, 0, 0, 0);
            break;
        case TailSide::Right:
            setContentsMargins(0, 0, bubbleTailHeight, 0);
            break;
        }
    }

    TailSide side() const
    {
        return m_side;
    }

    // Position de la pointe le long du bord (depuis le coin de la fenêtre).
    void setTailOffset(int offset)
    {
        m_tailOffset = offset;
    }

    QPainterPath bubblePath() const
    {
        const QRectF body = QRectF(rect()).marginsRemoved(contentsMargins());
        const QRectF edge = body.adjusted(0.5, 0.5, -0.5, -0.5);
        const qreal radius = qBound<qreal>(
            6, m_theme.popupRadius, qMin(edge.width(), edge.height()) / 2 - 1);
        QPainterPath path;
        path.addRoundedRect(edge, radius, radius);

        const qreal half = bubbleTailWidth / 2.0;
        const bool horizontalEdge = m_side == TailSide::Bottom
            || m_side == TailSide::Top;
        const qreal span = horizontalEdge ? edge.width() : edge.height();
        const qreal origin = horizontalEdge ? edge.left() : edge.top();
        const qreal lowest = origin + radius + half;
        const qreal highest = origin + span - radius - half;
        const qreal along = qBound(lowest, static_cast<qreal>(m_tailOffset),
                                   qMax(lowest, highest));

        QPointF a;
        QPointF tip;
        QPointF b;
        // La base de la pointe rentre d'un pixel dans la bulle : pas de
        // couture entre les deux formes.
        switch (m_side) {
        case TailSide::Bottom:
            a = {along - half, edge.bottom() - 1};
            tip = {along, edge.bottom() + bubbleTailHeight - 1};
            b = {along + half, edge.bottom() - 1};
            break;
        case TailSide::Top:
            a = {along - half, edge.top() + 1};
            tip = {along, edge.top() - bubbleTailHeight + 1};
            b = {along + half, edge.top() + 1};
            break;
        case TailSide::Left:
            a = {edge.left() + 1, along - half};
            tip = {edge.left() - bubbleTailHeight + 1, along};
            b = {edge.left() + 1, along + half};
            break;
        case TailSide::Right:
            a = {edge.right() - 1, along - half};
            tip = {edge.right() + bubbleTailHeight - 1, along};
            b = {edge.right() - 1, along + half};
            break;
        }

        QPainterPath tail;
        tail.moveTo(a);
        tail.lineTo(mix(a, tip, 0.74));
        tail.quadTo(tip, mix(b, tip, 0.74));
        tail.lineTo(b);
        tail.closeSubpath();
        return path.united(tail);
    }

    // Demande à KWin de flouter exactement la forme de la bulle.
    void applyShape()
    {
        if (!isVisible() || !windowHandle()) {
            return;
        }
        KWindowEffects::enableBlurBehind(
            windowHandle(), true, glassRegionFromPath(bubblePath()));
        // La demande ne prend effet qu'au prochain dessin de la fenêtre : sans
        // cela, le verre n'apparaît que quand la souris la survole.
        update();
        windowHandle()->requestUpdate();
    }

protected:
    void showEvent(QShowEvent *event) override
    {
        QMenu::showEvent(event);
        applyShape();
        // Kvantum demande lui aussi un flou (sur tout le rectangle), un peu
        // après l'affichage : on redonne la forme exacte de la bulle ensuite.
        QTimer::singleShot(0, this, [this]() { applyShape(); });
        QTimer::singleShot(80, this, [this]() { applyShape(); });
        QTimer::singleShot(250, this, [this]() { applyShape(); });
    }

    void resizeEvent(QResizeEvent *event) override
    {
        QMenu::resizeEvent(event);
        applyShape();
    }

    void paintEvent(QPaintEvent *) override
    {
        QStylePainter painter(this);
        painter.setRenderHint(QPainter::Antialiasing);

        const QPainterPath path = bubblePath();
        QColor fill = m_theme.fill;
        fill.setAlphaF(qBound<qreal>(0, m_theme.fillOpacity, 1));
        painter.fillPath(path, fill);

        // Liseré fermé, tout autour de la bulle (coins du haut compris) : plus
        // marqué en haut qu'en bas et sur les côtés, avec les valeurs du thème.
        const auto rimColor = [](qreal alpha) {
            QColor color(255, 255, 255);
            color.setAlphaF(qBound<qreal>(0, alpha * 2.7, 1));
            return color;
        };
        QLinearGradient rim(0, 0, 0, height());
        rim.setColorAt(0.0, rimColor(m_theme.rimTop));
        rim.setColorAt(0.5, rimColor(qMax(m_theme.rimSide, m_theme.rimTop * 0.6)));
        rim.setColorAt(1.0, rimColor(m_theme.rimBottom));
        painter.setPen(QPen(QBrush(rim), qMax<qreal>(1.0, m_theme.rimWidth)));
        painter.setBrush(Qt::NoBrush);
        painter.drawPath(path);

        const QList<QAction *> entries = actions();
        for (QAction *action : entries) {
            if (!action->isVisible()) {
                continue;
            }
            const QRect itemRect = actionGeometry(action);
            if (itemRect.isNull()) {
                continue;
            }
            QStyleOptionMenuItem option;
            initStyleOption(&option, action);
            option.rect = itemRect;
            painter.drawControl(QStyle::CE_MenuItem, option);
        }
    }

private:
    TailSide m_side;
    GlassTheme m_theme;
    int m_tailOffset = 0;
};
}

DockMenu::DockMenu(QObject *parent)
    : QObject(parent)
{
}

DockMenu::~DockMenu()
{
    if (m_menu) {
        m_menu->disconnect(this);
        m_menu->hide();
        delete m_menu;
    }
}

bool DockMenu::available() const
{
    return qobject_cast<QApplication *>(QCoreApplication::instance()) != nullptr;
}

bool DockMenu::isVisible() const
{
    return m_visible;
}

void DockMenu::setVisible(bool visible)
{
    if (m_visible == visible) {
        return;
    }
    m_visible = visible;
    Q_EMIT visibleChanged();
}

void DockMenu::addItems(QMenu *menu, const QVariantList &items)
{
    for (const QVariant &entry : items) {
        const QVariantMap map = entry.toMap();
        if (map.value(QStringLiteral("separator")).toBool()) {
            menu->addSeparator();
            continue;
        }

        const QString id = map.value(QStringLiteral("id")).toString();
        // « & » introduit un raccourci clavier dans un QAction : on le double.
        QString text = map.value(QStringLiteral("text")).toString();
        text.replace(QLatin1Char('&'), QStringLiteral("&&"));
        const QString iconName = map.value(QStringLiteral("icon")).toString();
        const QIcon icon = iconName.isEmpty() ? QIcon()
                                              : QIcon::fromTheme(iconName);
        const bool enabled = map.value(QStringLiteral("enabled"), true).toBool();
        const QVariantList children = map.value(QStringLiteral("children")).toList();

        if (!children.isEmpty()) {
            QMenu *subMenu = menu->addMenu(icon, text);
            subMenu->setEnabled(enabled);
            subMenu->setAttribute(Qt::WA_TranslucentBackground);
            // Comme pour le menu du bureau : le sous-menu est rattaché à la
            // fenêtre de son menu, sinon Wayland ne sait pas où le poser.
            connect(subMenu, &QMenu::aboutToShow, subMenu, [subMenu, menu]() {
                subMenu->winId();
                if (subMenu->windowHandle() && menu->windowHandle()) {
                    subMenu->windowHandle()->setTransientParent(menu->windowHandle());
                }
            });
            addItems(subMenu, children);
            continue;
        }

        QAction *action = menu->addAction(icon, text);
        action->setEnabled(enabled);
        connect(action, &QAction::triggered, this, [this, id]() {
            Q_EMIT triggered(id);
        });
    }
}

bool DockMenu::popup(QWindow *parentWindow, qreal x, qreal y,
                     const QString &direction, const QVariantList &items,
                     bool bubble)
{
    if (!parentWindow || items.isEmpty() || !available()) {
        return false;
    }

    close();

    BubbleMenu *bubbleMenu = nullptr;
    PositionedMenu *positionedMenu = nullptr;
    QMenu *menu = nullptr;
    if (bubble) {
        const BubbleMenu::TailSide side = direction == QLatin1String("down")
            ? BubbleMenu::TailSide::Top
            : direction == QLatin1String("right") ? BubbleMenu::TailSide::Left
            : direction == QLatin1String("left") ? BubbleMenu::TailSide::Right
            : BubbleMenu::TailSide::Bottom;
        bubbleMenu = new BubbleMenu(side);
        positionedMenu = bubbleMenu;
        menu = bubbleMenu;
    } else {
        positionedMenu = new PositionedMenu;
        menu = positionedMenu;
    }
    menu->setAttribute(Qt::WA_TranslucentBackground);
    addItems(menu, items);
    m_menu = menu;

    connect(menu, &QMenu::aboutToShow, this, [this]() {
        setVisible(true);
        Q_EMIT opened();
    });
    connect(menu, &QMenu::aboutToHide, this, [this, menu]() {
        setVisible(false);
        Q_EMIT closed();
        menu->deleteLater();
    });

    // Même recette que le menu du bureau de Plasma : la fenêtre du menu est
    // créée d'abord, puis rattachée à la fenêtre du Dock (sinon Wayland refuse
    // de poser un popup sans parent).
    menu->winId();
    if (menu->windowHandle()) {
        menu->windowHandle()->setTransientParent(parentWindow);
    }

    menu->ensurePolished();
    const QSize size = menu->sizeHint();
    const QPoint anchor = parentWindow->mapToGlobal(
        QPoint(qRound(x), qRound(y)));
    QPoint position = anchor;

    if (bubbleMenu) {
        // La bulle est centrée sur l'icône, la pointe tournée vers elle.
        switch (bubbleMenu->side()) {
        case BubbleMenu::TailSide::Bottom:
            position = {anchor.x() - size.width() / 2,
                        anchor.y() - bubbleGap - size.height()};
            bubbleMenu->setTailOffset(anchor.x() - position.x());
            break;
        case BubbleMenu::TailSide::Top:
            position = {anchor.x() - size.width() / 2, anchor.y() + bubbleGap};
            bubbleMenu->setTailOffset(anchor.x() - position.x());
            break;
        case BubbleMenu::TailSide::Left:
            position = {anchor.x() + bubbleGap, anchor.y() - size.height() / 2};
            bubbleMenu->setTailOffset(anchor.y() - position.y());
            break;
        case BubbleMenu::TailSide::Right:
            position = {anchor.x() - bubbleGap - size.width(),
                        anchor.y() - size.height() / 2};
            bubbleMenu->setTailOffset(anchor.y() - position.y());
            break;
        }
    } else if (direction == QLatin1String("up")) {
        position.ry() -= size.height();
    } else if (direction == QLatin1String("left")) {
        position.rx() -= size.width();
    }
    positionedMenu->setDesiredPosition(position);
    menu->popup(position);
    return true;
}

void DockMenu::close()
{
    if (m_menu) {
        m_menu->hide();
    }
}
