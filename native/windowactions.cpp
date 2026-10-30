#include "windowactions.h"

#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDBusMessage>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QDBusReply>
#include <QDBusServiceWatcher>
#include <QDebug>
#include <QDesktopServices>
#include <QFileInfo>
#include <QGuiApplication>
#include <QMetaObject>
#include <QStringList>
#include <QWindow>
#include <QVariant>

#include <KService>

namespace
{
constexpr int virtualDesktopRequestTimeoutMs = 5000;
}

WindowActions::WindowActions(QObject *parent)
    : QObject(parent)
{
    const QDBusConnection bus = QDBusConnection::sessionBus();
    m_serviceWatcher = new QDBusServiceWatcher(
        QStringLiteral("org.kde.KWin"), bus,
        QDBusServiceWatcher::WatchForRegistration
            | QDBusServiceWatcher::WatchForUnregistration,
        this);

    connect(m_serviceWatcher, &QDBusServiceWatcher::serviceRegistered,
            this, [this]() { setKWinAvailable(true); });
    connect(m_serviceWatcher, &QDBusServiceWatcher::serviceUnregistered,
            this, [this]() { setKWinAvailable(false); });

    if (bus.isConnected() && bus.interface()) {
        const QDBusReply<bool> registered =
            bus.interface()->isServiceRegistered(QStringLiteral("org.kde.KWin"));
        if (registered.isValid()) {
            m_kwinAvailable = registered.value();
        }
    }
}

bool WindowActions::interactiveForceQuitAvailable() const
{
    return m_kwinAvailable;
}

bool WindowActions::startInteractiveForceQuit()
{
    const QDBusConnection bus = QDBusConnection::sessionBus();
    if (!m_kwinAvailable || !bus.isConnected()) {
        return false;
    }

    QDBusMessage message = QDBusMessage::createMethodCall(
        QStringLiteral("org.kde.KWin"), QStringLiteral("/KWin"),
        QStringLiteral("org.kde.KWin"), QStringLiteral("killWindow"));
    bus.asyncCall(message);
    return true;
}

void WindowActions::requestVirtualDesktopActivation(int desktopNumber)
{
    const QDBusConnection bus = QDBusConnection::sessionBus();
    if (desktopNumber <= 0 || !m_kwinAvailable
            || !bus.isConnected()) {
        return;
    }

    QDBusMessage message = QDBusMessage::createMethodCall(
        QStringLiteral("org.kde.KWin"),
        QStringLiteral("/KWin"),
        QStringLiteral("org.kde.KWin"),
        QStringLiteral("setCurrentDesktop"));
    message.setArguments({desktopNumber});
    auto *watcher = new QDBusPendingCallWatcher(
        bus.asyncCall(message, virtualDesktopRequestTimeoutMs), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this,
            [watcher]() {
                const QDBusPendingReply<bool> reply = *watcher;
                if (reply.isError()) {
                    qWarning() << "Failed to activate virtual desktop:"
                               << reply.error().message();
                } else if (!reply.value()) {
                    qWarning() << "KWin rejected virtual desktop activation";
                }
                watcher->deleteLater();
            });
}

bool WindowActions::createVirtualDesktop(int position)
{
    const QDBusConnection bus = QDBusConnection::sessionBus();
    if (position < 0 || m_desktopCreationPending || !m_kwinAvailable
            || !bus.isConnected()) {
        return false;
    }

    QDBusMessage message = QDBusMessage::createMethodCall(
        QStringLiteral("org.kde.KWin"),
        QStringLiteral("/VirtualDesktopManager"),
        QStringLiteral("org.kde.KWin.VirtualDesktopManager"),
        QStringLiteral("createDesktop"));
    message.setArguments({
        QVariant::fromValue(static_cast<uint>(position)),
        QString()
    });
    m_desktopCreationPending = true;
    auto *watcher = new QDBusPendingCallWatcher(
        bus.asyncCall(message, virtualDesktopRequestTimeoutMs), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this,
            [this, watcher]() {
                const QDBusPendingReply<> reply = *watcher;
                const bool succeeded = !reply.isError();
                if (!succeeded) {
                    qWarning() << "Failed to create virtual desktop:"
                               << reply.error().message();
                }
                m_desktopCreationPending = false;
                watcher->deleteLater();
                Q_EMIT virtualDesktopCreationFinished(succeeded);
            });
    return true;
}

QString WindowActions::canonicalDirectoryUrl(const QUrl &url) const
{
    QString localPath;
    if (url.isLocalFile()) {
        localPath = url.toLocalFile();
    } else if (url.scheme().isEmpty()) {
        localPath = url.toString();
    } else {
        return {};
    }

    const QFileInfo directory(localPath);
    if (!directory.exists() || !directory.isDir()) {
        return {};
    }

    QString path = directory.canonicalFilePath();
    if (path.isEmpty()) {
        path = directory.absoluteFilePath();
    }
    return QUrl::fromLocalFile(path).toString();
}

bool WindowActions::showLauncherLocation(const QString &launcherUrl)
{
    QString path;
    const QUrl url(launcherUrl);
    if (url.isLocalFile()) {
        path = url.toLocalFile();
    }

    if (path.isEmpty() || !QFileInfo::exists(path)) {
        path.clear();
        QString storageId = launcherUrl.trimmed();
        if (storageId.startsWith(QLatin1String("application://"))) {
            storageId.remove(0, 14);
        } else if (storageId.startsWith(QLatin1String("applications:"))) {
            storageId.remove(0, 13);
        } else if (url.isLocalFile()) {
            storageId = QFileInfo(url.toLocalFile()).fileName();
        }
        const qsizetype queryIndex = storageId.indexOf(QLatin1Char('?'));
        if (queryIndex >= 0) {
            storageId.truncate(queryIndex);
        }
        storageId = QUrl::fromPercentEncoding(storageId.toUtf8());
        if (storageId.isEmpty()) {
            return false;
        }
        if (!storageId.endsWith(QLatin1String(".desktop"))) {
            storageId += QLatin1String(".desktop");
        }

        KService::Ptr service = KService::serviceByStorageId(storageId);
        if (!service) {
            QString name = storageId;
            name.chop(8);
            service = KService::serviceByDesktopName(name);
        }
        if (service) {
            path = service->entryPath();
        }
    }

    if (path.isEmpty() || !QFileInfo::exists(path)) {
        return false;
    }

    const QString itemUrl = QUrl::fromLocalFile(path).toString();
    const QString folder = QFileInfo(path).absolutePath();
    const QDBusConnection bus = QDBusConnection::sessionBus();
    if (!bus.isConnected()) {
        return QDesktopServices::openUrl(QUrl::fromLocalFile(folder));
    }

    // org.freedesktop.FileManager1 opens the folder and selects the file; when
    // no file manager answers, the folder is simply opened.
    QDBusMessage message = QDBusMessage::createMethodCall(
        QStringLiteral("org.freedesktop.FileManager1"),
        QStringLiteral("/org/freedesktop/FileManager1"),
        QStringLiteral("org.freedesktop.FileManager1"),
        QStringLiteral("ShowItems"));
    message.setArguments({QStringList{itemUrl}, QString()});
    auto *watcher = new QDBusPendingCallWatcher(
        bus.asyncCall(message, virtualDesktopRequestTimeoutMs), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this,
            [watcher, folder]() {
                const QDBusPendingReply<> reply = *watcher;
                if (reply.isError()) {
                    QDesktopServices::openUrl(QUrl::fromLocalFile(folder));
                }
                watcher->deleteLater();
            });
    return true;
}

void WindowActions::setKWinAvailable(bool available)
{
    if (m_kwinAvailable == available) {
        return;
    }

    m_kwinAvailable = available;
    Q_EMIT interactiveForceQuitAvailableChanged();
}

int WindowActions::closeForeignPopups()
{
    int closed = 0;
    const QList<QWindow *> windows = QGuiApplication::allWindows();
    for (QWindow *window : windows) {
        if (!window || !window->isVisible() || window->type() != Qt::Popup) {
            continue;
        }
        const QByteArray className = window->metaObject()->className();
        // Popups of Plasma applets (launcher, system tray...) are left alone.
        if (className.startsWith("PlasmaQuick")) {
            // Logged so that a menu that is wrongly left open (and keeps the
            // pointer) can be identified from the journal.
            qInfo().noquote() << "macOS Dock: leaving this popup open:"
                              << className << window->objectName();
            continue;
        }
        bool ours = false;
        for (const QWindow *parent = window->transientParent(); parent;
             parent = parent->transientParent()) {
            if (parent->objectName().startsWith(QLatin1String("macOSDock"))) {
                ours = true;
                break;
            }
        }
        if (ours) {
            continue;
        }
        qInfo().noquote() << "macOS Dock: closing a menu of this process:"
                          << className << window->objectName();
        QMetaObject::invokeMethod(window, "close", Qt::QueuedConnection);
        ++closed;
    }
    return closed;
}
