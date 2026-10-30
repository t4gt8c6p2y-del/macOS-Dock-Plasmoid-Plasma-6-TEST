#include "dockmenu.h"

#include <QAction>
#include <QApplication>
#include <QIcon>
#include <QMenu>
#include <QPoint>
#include <QSize>
#include <QVariantMap>
#include <QWindow>

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
                     const QString &direction, const QVariantList &items)
{
    if (!parentWindow || items.isEmpty() || !available()) {
        return false;
    }

    close();

    auto *menu = new QMenu;
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
    QPoint position = parentWindow->mapToGlobal(
        QPoint(qRound(x), qRound(y)));
    if (direction == QLatin1String("up")) {
        position.ry() -= size.height();
    } else if (direction == QLatin1String("left")) {
        position.rx() -= size.width();
    }
    menu->popup(position);
    return true;
}

void DockMenu::close()
{
    if (m_menu) {
        m_menu->hide();
    }
}
