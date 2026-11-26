#include "dockmenu.h"

#include <QAction>
#include <QDebug>
#include <QApplication>
#include <QIcon>
#include <QKeySequence>
#include <QLinearGradient>
#include <QMenu>
#include <QtMath>
#include <QEasingCurve>
#include <QPaintEvent>
#include <QPainter>
#include <QPainterPath>
#include <QPainterPathStroker>
#include <QPixmap>
#include <QPoint>
#include <QRect>
#include <QPointF>
#include <QPolygonF>
#include <QRegion>
#include <QResizeEvent>
#include <QShowEvent>
#include <QSize>
#include <QSizeF>
#include <QStyleOptionMenuItem>
#include <QStylePainter>
#include <QTimer>
#include <QTransform>
#include <QVariantAnimation>
#include <QVariantMap>
#include <QWindow>

#include <KWindowEffects>

#include "glasstheme.h"

namespace
{
constexpr int bubbleTailHeight = 10;
constexpr int bubbleTailWidth = 24;
constexpr int bubbleGap = 4;
// Part de l'intensité du liseré du thème utilisée pour les bulles.
constexpr qreal bubbleRimStrength = 0.42;

QPointF mix(const QPointF &a, const QPointF &b, qreal t)
{
    return a + (b - a) * t;
}

// Ouverture « goutte » : la courbe dépasse un peu 1 avant de se poser (comme
// une goutte qui s'étale puis se rétracte).
qreal dropEase(qreal t)
{
    t = qBound<qreal>(0, t, 1);
    const qreal overshoot = 1.45;
    const qreal u = t - 1;
    return 1 + (overshoot + 1) * u * u * u + overshoot * u * u;
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
    explicit PositionedMenu(QWidget *parent = nullptr)
        : QMenu(parent)
    {
    }

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
    // « None » : même fond et même liseré, sans pointe (menu du Dock, sous-menus).
    enum class TailSide { Bottom, Top, Left, Right, None };

    explicit BubbleMenu(TailSide side, QWidget *parent = nullptr)
        : PositionedMenu(parent)
        , m_side(side)
        , m_theme(GlassTheme::load())
    {
        // KWin arrondit les coins de la fenêtre avec le rayon des popups du
        // thème (grand). Si le contour de la bulle est plus droit que cela, ses
        // angles sortent de la forme arrondie par KWin et sont rognés (plus de
        // liseré dans les angles). On entoure donc la bulle d'une marge
        // transparente assez large pour que ses angles restent à l'intérieur.
        const qreal kwinRadius = m_theme.popupRadius;
        const qreal drawnRadius = bubbleRadius();
        m_pad = qMax(0, qCeil((kwinRadius - drawnRadius) * 0.2929)) + 2;

        const int pad = static_cast<int>(m_pad);
        int tail[4] = {0, 0, 0, 0}; // gauche, haut, droite, bas
        switch (side) {
        case TailSide::None:
            break;
        case TailSide::Bottom:
            tail[3] = bubbleTailHeight;
            break;
        case TailSide::Top:
            tail[1] = bubbleTailHeight;
            break;
        case TailSide::Left:
            tail[0] = bubbleTailHeight;
            break;
        case TailSide::Right:
            tail[2] = bubbleTailHeight;
            break;
        }
        setContentsMargins(pad + tail[0], pad + tail[1], pad + tail[2], pad + tail[3]);
    }

    // Marge transparente autour de la bulle (voir le constructeur).
    int pad() const
    {
        return static_cast<int>(m_pad);
    }

    TailSide side() const
    {
        return m_side;
    }

    // Liseré blanc lumineux (Dock) ou simple trait sombre très fin.
    void setRim(bool rim)
    {
        m_rim = rim;
        update();
    }

    // Point d'où la goutte s'étend, en fraction du corps du menu (0, 0 = coin
    // haut gauche), pour les menus sans pointe. Avec une pointe, c'est son bout.
    void setRevealOrigin(const QPointF &fraction)
    {
        m_originFraction = fraction;
    }

    // L'ouverture part d'un rectangle de la taille du bouton (ou de la ligne du
    // menu parent) collé au coin du menu : à droite si right, en bas si bottom.
    void setRevealFromButton(const QSizeF &size, bool right, bool bottom)
    {
        m_hasButton = size.isValid() && size.width() > 0 && size.height() > 0;
        m_buttonSize = size;
        m_buttonRight = right;
        m_buttonBottom = bottom;
    }

    // Position de la pointe le long du bord (depuis le coin de la fenêtre).
    void setTailOffset(int offset)
    {
        m_tailOffset = offset;
    }

    // Rayon des menus du thème : les angles ressemblent à ceux de la sélection.
    qreal bubbleRadius() const
    {
        return qMax<qreal>(4, m_theme.menuRadius);
    }

    qreal cornerRadius(const QRectF &edge) const
    {
        return qBound<qreal>(
            4, bubbleRadius(), qMin(edge.width(), edge.height()) / 2 - 1);
    }

    QPainterPath bubblePath() const
    {
        const QRectF body = QRectF(rect()).marginsRemoved(contentsMargins());
        const QRectF edge = body.adjusted(0.5, 0.5, -0.5, -0.5);
        const qreal radius = cornerRadius(edge);
        QPainterPath path;
        path.addRoundedRect(edge, radius, radius);
        if (m_side == TailSide::None) {
            return path;
        }

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
        case TailSide::None:
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
        QPainterPath shape = bubblePath();
        if (m_animating) {
            shape = revealTransform().map(shape);
        }
        QRegion region = glassRegionFromPath(shape);
        // KWin arrondit les coins de la zone floutée avec le rayon (grand) des
        // popups, en partant de la boîte englobante de la région : avec notre
        // rayon plus petit, le verre s'arrêtait avant le liseré dans les
        // angles. On étend la boîte jusqu'aux coins de la fenêtre avec quatre
        // pixels isolés : ils tombent dans la partie arrondie par KWin, donc
        // invisibles, et la marge transparente (pad) garde les angles du
        // liseré à l'intérieur de la forme arrondie.
        const QRect box = rect();
        if (!m_animating && box.width() > 2 && box.height() > 2) {
            region += QRect(box.left(), box.top(), 1, 1);
            region += QRect(box.right(), box.top(), 1, 1);
            region += QRect(box.left(), box.bottom(), 1, 1);
            region += QRect(box.right(), box.bottom(), 1, 1);
        }
        KWindowEffects::enableBlurBehind(windowHandle(), true, region);
        // La demande ne prend effet qu'au prochain dessin de la fenêtre : sans
        // cela, le verre n'apparaît que quand la souris la survole.
        update();
        windowHandle()->requestUpdate();
    }

protected:
    void showEvent(QShowEvent *event) override
    {
        QMenu::showEvent(event);
        startReveal();
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
        if (m_animating && !m_capturing) {
            paintReveal();
            return;
        }
        QStylePainter painter(this);
        painter.setRenderHint(QPainter::Antialiasing);

        const QPainterPath path = bubblePath();
        QColor fill = m_theme.fill;
        fill.setAlphaF(qBound<qreal>(0, m_theme.fillOpacity, 1));
        painter.fillPath(path, fill);

        // Liseré fermé, d'une seule couleur : même luminosité partout (côtés,
        // angles, pointe). Il est adouci par rapport au thème (bubbleRimStrength)
        // car KWin ajoute déjà sa propre lumière sur la forme.
        QColor rimColor(255, 255, 255);
        rimColor.setAlphaF(qBound<qreal>(0, m_theme.rimTop * 2.7 * bubbleRimStrength, 1));
        if (!m_rim) {
            rimColor = QColor(0, 0, 0);
            rimColor.setAlphaF(0.22);
        }
        QPen pen(rimColor, m_rim ? qMax<qreal>(1.0, m_theme.rimWidth) : 1.0);
        pen.setJoinStyle(Qt::RoundJoin);
        pen.setCapStyle(Qt::RoundCap);
        painter.setPen(pen);
        painter.setBrush(Qt::NoBrush);
        painter.drawPath(path);

        // Séparateurs : le style (Kvantum) n'en trace aucun sur ce fond
        // transparent, on les dessine nous-mêmes, comme dans les menus macOS.
        QColor lineColor(255, 255, 255);
        lineColor.setAlphaF(qBound<qreal>(0.12, m_theme.rimTop * 2.7 * 0.8, 0.4));

        const QList<QAction *> entries = actions();
        for (QAction *action : entries) {
            if (!action->isVisible()) {
                continue;
            }
            const QRect itemRect = actionGeometry(action);
            if (itemRect.isNull()) {
                continue;
            }
            if (action->isSeparator()) {
                const qreal y = itemRect.center().y() + 0.5;
                painter.setPen(QPen(lineColor, 1.0));
                painter.drawLine(QPointF(itemRect.left() + 12, y),
                                 QPointF(itemRect.right() - 12, y));
                continue;
            }
            QStyleOptionMenuItem option;
            initStyleOption(&option, action);
            option.rect = itemRect;
            painter.drawControl(QStyle::CE_MenuItem, option);
        }
    }

private:
    // --- Ouverture en goutte ------------------------------------------------------
    QPointF revealOrigin() const
    {
        const QRectF body = QRectF(rect()).marginsRemoved(contentsMargins());
        switch (m_side) {
        case TailSide::Top:
            return {static_cast<qreal>(m_tailOffset), body.top() - bubbleTailHeight};
        case TailSide::Bottom:
            return {static_cast<qreal>(m_tailOffset), body.bottom() + bubbleTailHeight};
        case TailSide::Left:
            return {body.left() - bubbleTailHeight, static_cast<qreal>(m_tailOffset)};
        case TailSide::Right:
            return {body.right() + bubbleTailHeight, static_cast<qreal>(m_tailOffset)};
        case TailSide::None:
            break;
        }
        return {body.left() + m_originFraction.x() * body.width(),
                body.top() + m_originFraction.y() * body.height()};
    }

    // Transformation de la goutte à l'instant de l'animation : elle part d'un
    // petit point et s'étire un peu plus vite en hauteur qu'en largeur.
    QTransform revealTransform() const
    {
        if (m_hasButton) {
            const QRectF full = QRectF(rect()).marginsRemoved(contentsMargins());
            const QSizeF start(qMin(m_buttonSize.width(), full.width()),
                               qMin(m_buttonSize.height(), full.height()));
            const QPointF startPos(m_buttonRight ? full.right() - start.width() : full.left(),
                                   m_buttonBottom ? full.bottom() - start.height() : full.top());
            const qreal ex = dropEase(m_progress);
            const qreal ey = dropEase(qMin<qreal>(1, m_progress * 1.18));
            const QRectF now(startPos.x() + (full.x() - startPos.x()) * ex,
                             startPos.y() + (full.y() - startPos.y()) * ey,
                             start.width() + (full.width() - start.width()) * ex,
                             start.height() + (full.height() - start.height()) * ey);
            const qreal bx = qMax<qreal>(0.04, now.width() / qMax<qreal>(1, full.width()));
            const qreal by = qMax<qreal>(0.04, now.height() / qMax<qreal>(1, full.height()));
            QTransform fromButton;
            fromButton.translate(now.x(), now.y());
            fromButton.scale(bx, by);
            fromButton.translate(-full.x(), -full.y());
            return fromButton;
        }
        const qreal sx = qMax<qreal>(0.04, 0.12 + 0.88 * dropEase(m_progress));
        const qreal sy = qMax<qreal>(0.04, 0.12 + 0.88 * dropEase(qMin<qreal>(1, m_progress * 1.18)));
        const QPointF origin = revealOrigin();
        QTransform transform;
        transform.translate(origin.x(), origin.y());
        transform.scale(sx, sy);
        transform.translate(-origin.x(), -origin.y());
        return transform;
    }

    void startReveal()
    {
        m_snapshot = QPixmap();
        m_progress = 0;
        m_animating = true;
        if (!m_animation) {
            m_animation = new QVariantAnimation(this);
            m_animation->setStartValue(0.0);
            m_animation->setEndValue(1.0);
            m_animation->setDuration(340);
            m_animation->setEasingCurve(QEasingCurve::OutSine);
            connect(m_animation, &QVariantAnimation::valueChanged, this,
                    [this](const QVariant &value) {
                        m_progress = value.toReal();
                        applyShape();
                        update();
                    });
            connect(m_animation, &QVariantAnimation::finished, this, [this]() {
                m_animating = false;
                m_snapshot = QPixmap();
                applyShape();
                update();
            });
        }
        m_animation->stop();
        m_animation->start();
    }

    void captureSnapshot()
    {
        m_capturing = true;
        const qreal ratio = devicePixelRatioF();
        QPixmap pixmap((QSizeF(size()) * ratio).toSize());
        pixmap.setDevicePixelRatio(ratio);
        pixmap.fill(Qt::transparent);
        render(&pixmap);
        m_capturing = false;
        m_snapshot = pixmap;
    }

    void paintReveal()
    {
        if (m_snapshot.isNull()) {
            captureSnapshot();
        }
        QPainter painter(this);
        painter.setRenderHint(QPainter::SmoothPixmapTransform);
        painter.setOpacity(qBound<qreal>(0, m_progress * (m_hasButton ? 3.2 : 2.4), 1));
        painter.setTransform(revealTransform());
        painter.drawPixmap(QPointF(0, 0), m_snapshot);
    }

    TailSide m_side;
    GlassTheme m_theme;
    QVariantAnimation *m_animation = nullptr;
    QPixmap m_snapshot;
    QPointF m_originFraction{0, 0};
    QSizeF m_buttonSize;
    bool m_hasButton = false;
    bool m_buttonRight = false;
    bool m_buttonBottom = false;
    qreal m_progress = 1;
    bool m_animating = false;
    bool m_capturing = false;
    int m_tailOffset = 0;
    qreal m_pad = 0;
    bool m_rim = true;
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
            // Même fond et même liseré que la bulle, sans pointe.
            BubbleMenu *subMenu = new BubbleMenu(BubbleMenu::TailSide::None, menu);
            subMenu->setRim(m_rim);
            subMenu->setTitle(text);
            subMenu->setIcon(icon);
            menu->addMenu(subMenu);
            subMenu->setEnabled(enabled);
            subMenu->setAttribute(Qt::WA_TranslucentBackground);
            // Comme pour le menu du bureau : le sous-menu est rattaché à la
            // fenêtre de son menu, sinon Wayland ne sait pas où le poser.
            connect(subMenu, &QMenu::aboutToShow, subMenu, [subMenu, menu]() {
                subMenu->winId();
                if (subMenu->windowHandle() && menu->windowHandle()) {
                    subMenu->windowHandle()->setTransientParent(menu->windowHandle());
                    // Les marges transparentes des deux menus s'ajouteraient :
                    // on rapproche le sous-menu (comme avant ces marges).
                    // Le sous-menu se pose PAR-DESSUS son menu : il part de la
                    // ligne qui l'ouvre, légèrement en retrait du bord gauche.
                    const int pad = subMenu->pad();
                    const int inset = 14;
                    const int parentWidth = menu->width();
                    subMenu->windowHandle()->setProperty(
                        "_q_waylandPopupOffset", QPoint(inset - parentWidth, -pad));
                    const QRect row = menu->actionGeometry(subMenu->menuAction());
                    subMenu->setRevealFromButton(
                        QSizeF(parentWidth - 2 * pad - inset, row.isNull() ? 30 : row.height()),
                        false, false);
                }
            });
            addItems(subMenu, children);
            continue;
        }

        QAction *action = menu->addAction(icon, text);
        action->setEnabled(enabled);
        if (map.contains(QStringLiteral("checked"))) {
            action->setCheckable(true);
            action->setChecked(map.value(QStringLiteral("checked")).toBool());
        }
        const QString shortcut = map.value(QStringLiteral("shortcut")).toString();
        if (!shortcut.isEmpty()) {
            // Affiché à droite de l'entrée ; ne sert qu'à l'affichage.
            action->setShortcut(QKeySequence(shortcut));
            action->setShortcutContext(Qt::WidgetShortcut);
        }
        connect(action, &QAction::triggered, this, [this, id]() {
            Q_EMIT triggered(id);
        });
    }
}

bool DockMenu::popup(QWindow *parentWindow, qreal x, qreal y,
                     const QString &direction, const QVariantList &items,
                     bool bubble, bool rim, const QRectF &button)
{
    if (!parentWindow || items.isEmpty() || !available()) {
        return false;
    }

    close();

    BubbleMenu *bubbleMenu = nullptr;
    BubbleMenu *shapedMenu = nullptr;
    PositionedMenu *positionedMenu = nullptr;
    QMenu *menu = nullptr;
    if (bubble) {
        const BubbleMenu::TailSide side = direction == QLatin1String("down")
            ? BubbleMenu::TailSide::Top
            : direction == QLatin1String("right") ? BubbleMenu::TailSide::Left
            : direction == QLatin1String("left") ? BubbleMenu::TailSide::Right
            : BubbleMenu::TailSide::Bottom;
        bubbleMenu = new BubbleMenu(side);
        shapedMenu = bubbleMenu;
        positionedMenu = bubbleMenu;
        menu = bubbleMenu;
    } else {
        // Menu du Dock : même fond et même liseré que la bulle, sans pointe.
        shapedMenu = new BubbleMenu(BubbleMenu::TailSide::None);
        positionedMenu = shapedMenu;
        menu = positionedMenu;
    }
    menu->setAttribute(Qt::WA_TranslucentBackground);
    m_rim = rim;
    shapedMenu->setRim(rim);
    if (!bubble) {
        // La goutte part du point où le menu a été demandé.
        shapedMenu->setRevealOrigin(direction == QLatin1String("up") ? QPointF(0, 1)
            : direction == QLatin1String("left") ? QPointF(1, 0) : QPointF(0, 0));
    }
    addItems(menu, items);
    m_menu = menu;

    connect(menu, &QMenu::aboutToShow, this, [this]() {
        setVisible(true);
        Q_EMIT opened();
    });
    connect(menu, &QMenu::aboutToHide, this, [this, menu]() {
        qInfo() << "macOS Dock: menu closed";
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
    const QPoint local(qRound(x), qRound(y));
    const QPoint anchor = parentWindow->mapToGlobal(local);
    QPoint position = anchor;

    // Sous Wayland, c'est le compositeur qui place le popup, d'après un
    // « positionneur » : un point d'ancrage DANS la fenêtre du Dock, le côté du
    // popup qui s'y accroche, et le sens dans lequel il s'étend. On le décrit
    // explicitement (au lieu de laisser Qt le deviner d'après des coordonnées
    // d'écran, fausses pour une fenêtre layer-shell : le popup serait recalé ou
    // ancré hors de la fenêtre).
    Qt::Edges anchorEdges = Qt::TopEdge | Qt::LeftEdge;
    Qt::Edges gravityEdges = Qt::BottomEdge | Qt::RightEdge;
    QPoint offset;
    // slide_x = 1, slide_y = 2, flip_x = 4, flip_y = 8 (xdg_positioner)
    uint constraintAdjustment = 1 | 2;

    if (bubbleMenu) {
        // La bulle est centrée sur l'icône, la pointe tournée vers elle. La
        // fenêtre a une marge transparente (pad) autour de la bulle : on la
        // décale pour que la pointe reste à bubbleGap de l'icône.
        const int gap = bubbleGap;
        const int pad = bubbleMenu->pad();
        switch (bubbleMenu->side()) {
        case BubbleMenu::TailSide::Bottom:
            position = {anchor.x() - size.width() / 2,
                        anchor.y() - gap - size.height() + pad};
            bubbleMenu->setTailOffset(size.width() / 2);
            anchorEdges = Qt::TopEdge;
            gravityEdges = Qt::TopEdge;
            offset = QPoint(0, -gap + pad);
            break;
        case BubbleMenu::TailSide::Top:
            position = {anchor.x() - size.width() / 2, anchor.y() + gap - pad};
            bubbleMenu->setTailOffset(size.width() / 2);
            anchorEdges = Qt::BottomEdge;
            gravityEdges = Qt::BottomEdge;
            offset = QPoint(0, gap - pad);
            break;
        case BubbleMenu::TailSide::Left:
            position = {anchor.x() + gap - pad, anchor.y() - size.height() / 2};
            bubbleMenu->setTailOffset(size.height() / 2);
            anchorEdges = Qt::RightEdge;
            gravityEdges = Qt::RightEdge;
            offset = QPoint(gap - pad, 0);
            break;
        case BubbleMenu::TailSide::Right:
            position = {anchor.x() - gap - size.width() + pad,
                        anchor.y() - size.height() / 2};
            bubbleMenu->setTailOffset(size.height() / 2);
            anchorEdges = Qt::LeftEdge;
            gravityEdges = Qt::LeftEdge;
            offset = QPoint(-gap + pad, 0);
            break;
        case BubbleMenu::TailSide::None:
            break;
        }
    } else if (button.isValid()) {
        // Menu posé sur le bouton qui l'a ouvert (voir popup() dans le .h).
        const int pad = shapedMenu->pad();
        const bool up = direction == QLatin1String("up");
        const bool toLeft = direction == QLatin1String("left");
        position.rx() += toLeft ? pad - size.width() : -pad;
        position.ry() += up ? pad - size.height() : -pad;
        gravityEdges = (up ? Qt::TopEdge : Qt::BottomEdge)
            | (toLeft ? Qt::LeftEdge : Qt::RightEdge);
        offset = QPoint(toLeft ? pad : -pad, up ? pad : -pad);
        if (up) {
            constraintAdjustment = 1 | 8 | 2;
        }
        shapedMenu->setRevealFromButton(button.size(), toLeft, up);
    } else if (direction == QLatin1String("up")) {
        position.ry() -= size.height();
        gravityEdges = Qt::TopEdge | Qt::RightEdge;
        constraintAdjustment = 1 | 8 | 2;
    } else if (direction == QLatin1String("left")) {
        position.rx() -= size.width();
        gravityEdges = Qt::BottomEdge | Qt::LeftEdge;
    }

    if (QWindow *handle = menu->windowHandle()) {
        handle->setProperty("_q_waylandPopupAnchorRect",
                            QRect(local, QSize(1, 1)));
        handle->setProperty("_q_waylandPopupAnchor",
                            QVariant::fromValue(anchorEdges));
        handle->setProperty("_q_waylandPopupGravity",
                            QVariant::fromValue(gravityEdges));
        handle->setProperty("_q_waylandPopupConstraintAdjustment",
                            constraintAdjustment);
        handle->setProperty("_q_waylandPopupOffset", offset);
    }

    qInfo().noquote() << "macOS Dock: opening a menu at" << local
                      << "bubble" << bubble << "size" << size;
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
