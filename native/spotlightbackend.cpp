#include "spotlightbackend.h"

#include <QCollator>
#include <QDateTime>
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusPendingCall>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QDesktopServices>
#include <QDir>
#include <QDirIterator>
#include <QElapsedTimer>
#include <QFile>
#include <QFileInfo>
#include <QGuiApplication>
#include <QClipboard>
#include <QLocale>
#include <QMetaObject>
#include <QMimeDatabase>
#include <QMimeType>
#include <QPointer>
#include <QProcess>
#include <QProcessEnvironment>
#include <QRegularExpression>
#include <QSaveFile>
#include <QSet>
#include <QStandardPaths>
#include <QUrl>
#include <QXmlStreamReader>
#include <QtConcurrent/QtConcurrentRun>

#include <algorithm>
#include <memory>

#include <KApplicationTrader>
#include <KIO/ApplicationLauncherJob>
#include <KService>

namespace
{
const QString ownServiceName = QStringLiteral("org.macosdock.Spotlight");
const QString krunnerServiceName = QStringLiteral("org.kde.krunner");

// Catégories du Spotlight (identifiants stables, traduits côté QML).
QString spotlightCategory(const QStringList &categories)
{
    const auto has = [&categories](const char *name) {
        return categories.contains(QLatin1String(name), Qt::CaseInsensitive);
    };

    if (has("InstantMessaging") || has("Chat") || has("IRCClient") || has("Email")
        || has("Telephony") || has("TelephonyTools") || has("VideoConference")) {
        return QStringLiteral("social");
    }
    if (has("Photography") || (has("Video") && !has("Player") && !has("TV"))) {
        return QStringLiteral("photovideo");
    }
    if (has("Graphics") || has("2DGraphics") || has("3DGraphics") || has("VectorGraphics")
        || has("RasterGraphics") || has("Publishing") || has("AudioVideoEditing")
        || has("Midi") || has("Sequencer")) {
        return QStringLiteral("creativity");
    }
    if (has("Game") || has("Audio") || has("Music") || has("Player") || has("TV")
        || has("Radio") || has("Amusement") || has("Emulator") || has("Video")) {
        return QStringLiteral("entertainment");
    }
    if (has("Education") || has("Science") || has("Reference") || has("Dictionary")
        || has("Documentation") || has("WebBrowser") || has("Literature") || has("Languages")
        || has("Math") || has("Astronomy") || has("Geography")) {
        return QStringLiteral("information");
    }
    if (has("Office") || has("WordProcessor") || has("Spreadsheet") || has("Presentation")
        || has("Calendar") || has("ProjectManagement") || has("Finance") || has("Database")
        || has("Development") || has("IDE") || has("TextEditor") || has("ContactManagement")) {
        return QStringLiteral("productivity");
    }
    if (has("System") || has("Settings") || has("DesktopSettings") || has("Utility")
        || has("Core") || has("TerminalEmulator") || has("FileManager") || has("Monitor")
        || has("Archiving") || has("Compression") || has("Security") || has("PackageManager")
        || has("HardwareSettings") || has("FileTools") || has("Accessibility")
        || has("Network")) {
        return QStringLiteral("utilities");
    }
    return QStringLiteral("other");
}

QString dataDirectory()
{
    return QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation)
        + QStringLiteral("/macosdock");
}

QString safeStorageName(const QString &name)
{
    static const QRegularExpression allowed(QStringLiteral("^[A-Za-z0-9._-]{1,64}$"));
    return allowed.match(name).hasMatch() && !name.startsWith(QLatin1Char('.'))
        ? name : QString();
}

QString withTilde(const QString &path)
{
    const QString home = QDir::homePath();
    if (path == home) {
        return QStringLiteral("~");
    }
    if (path.startsWith(home + QLatin1Char('/'))) {
        return QStringLiteral("~") + path.mid(home.size());
    }
    return path;
}

QVariantMap fileEntry(const QString &path, bool isDirectory, qint64 modifiedMs)
{
    static thread_local QMimeDatabase mimeDatabase;
    const QFileInfo info(path);
    QString icon = QStringLiteral("unknown");
    QString kind;
    if (isDirectory) {
        icon = QStringLiteral("inode-directory");
        kind = QStringLiteral("inode/directory");
    } else {
        const QMimeType mime = mimeDatabase.mimeTypeForFile(path, QMimeDatabase::MatchExtension);
        if (mime.isValid()) {
            icon = mime.iconName();
            kind = mime.comment();
        }
    }
    QVariantMap entry;
    entry.insert(QStringLiteral("name"), info.fileName());
    entry.insert(QStringLiteral("path"), path);
    entry.insert(QStringLiteral("directory"), withTilde(info.absolutePath()));
    entry.insert(QStringLiteral("isDir"), isDirectory);
    entry.insert(QStringLiteral("icon"), icon);
    entry.insert(QStringLiteral("kind"), kind);
    entry.insert(QStringLiteral("modified"), modifiedMs);
    return entry;
}

struct FileHit
{
    QString path;
    QString lowerName;
    bool isDirectory = false;
    qint64 modifiedMs = 0;
    int rank = 0;
    int depth = 0;
};

// Parcours du dossier personnel : fichiers non cachés dont le nom contient
// tous les mots recherchés. Limité en temps et en nombre d'entrées ; s'arrête
// dès que la recherche est remplacée par une plus récente.
QVariantList walkFiles(const QString &root, const QStringList &tokens,
                       const std::shared_ptr<std::atomic<int>> &generation, int myGeneration)
{
    static const QSet<QString> skipped = {
        QStringLiteral("node_modules"), QStringLiteral("__pycache__"),
        QStringLiteral("venv"), QStringLiteral("target"), QStringLiteral("snap"),
        QStringLiteral("Steam"), QStringLiteral("proc"),
    };
    constexpr int maxDepth = 8;
    constexpr int maxEntries = 250000;
    constexpr qint64 maxMilliseconds = 2500;

    QElapsedTimer timer;
    timer.start();
    int visited = 0;
    QList<FileHit> hits;

    QList<QPair<QString, int>> stack;
    stack.append({root, 0});
    while (!stack.isEmpty()) {
        const auto [directory, depth] = stack.takeLast();
        QDirIterator iterator(directory,
                              QDir::AllEntries | QDir::NoDotAndDotDot | QDir::NoSymLinks);
        while (iterator.hasNext()) {
            iterator.next();
            if ((++visited & 127) == 0) {
                if (generation->load() != myGeneration) {
                    return {};
                }
                if (visited > maxEntries || timer.elapsed() > maxMilliseconds) {
                    stack.clear();
                    break;
                }
            }
            const QFileInfo info = iterator.fileInfo();
            const QString name = info.fileName();
            const bool isDirectory = info.isDir();
            if (isDirectory && depth < maxDepth && !skipped.contains(name)) {
                stack.append({info.absoluteFilePath(), depth + 1});
            }

            const QString lowerName = name.toLower();
            bool matches = true;
            for (const QString &token : tokens) {
                if (!lowerName.contains(token)) {
                    matches = false;
                    break;
                }
            }
            if (!matches) {
                continue;
            }
            FileHit hit;
            hit.path = info.absoluteFilePath();
            hit.lowerName = lowerName;
            hit.isDirectory = isDirectory;
            hit.modifiedMs = info.lastModified().toMSecsSinceEpoch();
            hit.depth = depth;
            if (lowerName.startsWith(tokens.first())) {
                hit.rank = 0;
            } else if (lowerName.contains(QLatin1Char(' ') + tokens.first())
                       || lowerName.contains(QLatin1Char('_') + tokens.first())
                       || lowerName.contains(QLatin1Char('-') + tokens.first())
                       || lowerName.contains(QLatin1Char('.') + tokens.first())) {
                hit.rank = 1;
            } else {
                hit.rank = 2;
            }
            hits.append(hit);
            if (hits.size() >= 600) {
                stack.clear();
                break;
            }
        }
    }

    std::sort(hits.begin(), hits.end(), [](const FileHit &a, const FileHit &b) {
        if (a.rank != b.rank) {
            return a.rank < b.rank;
        }
        if (a.depth != b.depth) {
            return a.depth < b.depth;
        }
        if (a.lowerName.size() != b.lowerName.size()) {
            return a.lowerName.size() < b.lowerName.size();
        }
        return a.lowerName < b.lowerName;
    });

    QVariantList results;
    for (int i = 0; i < hits.size() && i < 40; ++i) {
        results.append(fileEntry(hits.at(i).path, hits.at(i).isDirectory, hits.at(i).modifiedMs));
    }
    return results;
}
}

// --- Services D-Bus ---------------------------------------------------------

SpotlightDBusService::SpotlightDBusService(SpotlightBackend *backend)
    : QObject(backend)
    , m_backend(backend)
{
}

void SpotlightDBusService::toggle()
{
    m_backend->emitToggle();
}

void SpotlightDBusService::show()
{
    m_backend->emitShow();
}

void SpotlightDBusService::hide()
{
    m_backend->emitHide();
}

void SpotlightDBusService::query(const QString &text)
{
    m_backend->emitQuery(text);
}

void SpotlightDBusService::openAssistant()
{
    m_backend->emitOpenAssistant();
}

KRunnerCompatService::KRunnerCompatService(SpotlightBackend *backend)
    : QObject(backend)
    , m_backend(backend)
{
}

void KRunnerCompatService::display()
{
    m_backend->emitShow();
}

void KRunnerCompatService::toggleDisplay()
{
    m_backend->emitToggle();
}

void KRunnerCompatService::displayWithClipboardContents()
{
    if (QGuiApplication::clipboard()) {
        m_backend->emitQuery(QGuiApplication::clipboard()->text());
    } else {
        m_backend->emitShow();
    }
}

void KRunnerCompatService::query(const QString &term)
{
    m_backend->emitQuery(term);
}

void KRunnerCompatService::queryClipboard()
{
    displayWithClipboardContents();
}

void KRunnerCompatService::querySingleRunner(const QString &runnerId, const QString &term)
{
    Q_UNUSED(runnerId)
    m_backend->emitQuery(term);
}

void KRunnerCompatService::displaySingleRunner(const QString &runnerId)
{
    Q_UNUSED(runnerId)
    m_backend->emitShow();
}

void KRunnerCompatService::showTaskManager()
{
    QProcess::startDetached(QStringLiteral("plasma-systemmonitor"), {});
}

void KRunnerCompatService::showSystemActivity()
{
    QProcess::startDetached(QStringLiteral("plasma-systemmonitor"), {});
}

void KRunnerCompatService::clearHistory()
{
}

KRunnerApplicationService::KRunnerApplicationService(SpotlightBackend *backend)
    : QObject(backend)
    , m_backend(backend)
{
}

void KRunnerApplicationService::Activate(const QVariantMap &platformData)
{
    Q_UNUSED(platformData)
    m_backend->emitToggle();
}

void KRunnerApplicationService::Open(const QStringList &uris, const QVariantMap &platformData)
{
    Q_UNUSED(uris)
    Q_UNUSED(platformData)
    m_backend->emitShow();
}

void KRunnerApplicationService::ActivateAction(const QString &actionName,
                                               const QVariantList &parameter,
                                               const QVariantMap &platformData)
{
    Q_UNUSED(actionName)
    Q_UNUSED(parameter)
    Q_UNUSED(platformData)
    m_backend->emitShow();
}

// --- SpotlightBackend -------------------------------------------------------

SpotlightBackend::SpotlightBackend(QObject *parent)
    : QObject(parent)
    , m_fileGeneration(std::make_shared<std::atomic<int>>(0))
{
    m_ownService = new SpotlightDBusService(this);
    m_krunnerService = new KRunnerCompatService(this);
    m_applicationService = new KRunnerApplicationService(this);

    // Si un autre exemplaire du Dock (autre écran) possède déjà les noms, on
    // réessaie de temps en temps : il prend le relais quand l'autre disparaît.
    m_retryTimer.setInterval(4000);
    connect(&m_retryTimer, &QTimer::timeout, this, &SpotlightBackend::updateDBusRegistration);
    m_retryTimer.start();
    QTimer::singleShot(0, this, &SpotlightBackend::updateDBusRegistration);
}

SpotlightBackend::~SpotlightBackend()
{
    m_fileGeneration->fetch_add(1);
    QDBusConnection bus = QDBusConnection::sessionBus();
    if (m_krunnerRegistered) {
        bus.unregisterObject(QStringLiteral("/App"));
        bus.unregisterObject(QStringLiteral("/org/kde/krunner"));
        bus.unregisterService(krunnerServiceName);
    }
    if (m_ownRegistered) {
        bus.unregisterObject(QStringLiteral("/Spotlight"));
        bus.unregisterService(ownServiceName);
    }
}

bool SpotlightBackend::dbusActive() const
{
    return m_ownRegistered;
}

bool SpotlightBackend::replaceLauncher() const
{
    return m_replaceLauncher;
}

void SpotlightBackend::setReplaceLauncher(bool replace)
{
    if (m_replaceLauncher == replace) {
        return;
    }
    m_replaceLauncher = replace;
    updateDBusRegistration();
    Q_EMIT replaceLauncherChanged();
}

void SpotlightBackend::registerOwnService()
{
    QDBusConnection bus = QDBusConnection::sessionBus();
    if (!bus.isConnected()) {
        return;
    }
    if (bus.registerService(ownServiceName)) {
        bus.registerObject(QStringLiteral("/Spotlight"), m_ownService,
                           QDBusConnection::ExportScriptableSlots);
        m_ownRegistered = true;
        Q_EMIT dbusActiveChanged();
    }
}

void SpotlightBackend::registerKRunnerService()
{
    QDBusConnection bus = QDBusConnection::sessionBus();
    if (!bus.isConnected()) {
        return;
    }
    if (bus.registerService(krunnerServiceName)) {
        bus.registerObject(QStringLiteral("/App"), m_krunnerService,
                           QDBusConnection::ExportScriptableSlots);
        bus.registerObject(QStringLiteral("/org/kde/krunner"), m_applicationService,
                           QDBusConnection::ExportScriptableSlots);
        m_krunnerRegistered = true;
    }
}

void SpotlightBackend::releaseKRunnerService()
{
    if (!m_krunnerRegistered) {
        return;
    }
    QDBusConnection bus = QDBusConnection::sessionBus();
    bus.unregisterObject(QStringLiteral("/App"));
    bus.unregisterObject(QStringLiteral("/org/kde/krunner"));
    bus.unregisterService(krunnerServiceName);
    m_krunnerRegistered = false;
}

void SpotlightBackend::updateDBusRegistration()
{
    if (!m_ownRegistered) {
        registerOwnService();
    }
    if (m_replaceLauncher) {
        if (m_ownRegistered && !m_krunnerRegistered) {
            registerKRunnerService();
        }
    } else {
        releaseKRunnerService();
    }
}

void SpotlightBackend::emitToggle()
{
    Q_EMIT toggleRequested();
}

void SpotlightBackend::emitShow()
{
    Q_EMIT showRequested();
}

void SpotlightBackend::emitHide()
{
    Q_EMIT hideRequested();
}

void SpotlightBackend::emitQuery(const QString &text)
{
    Q_EMIT queryRequested(text);
}

void SpotlightBackend::emitOpenAssistant()
{
    Q_EMIT assistantRequested();
}

// --- Applications -----------------------------------------------------------

QVariantList SpotlightBackend::applications() const
{
    const KService::List services = KApplicationTrader::query([](const KService::Ptr &service) {
        return service->isApplication() && !service->noDisplay() && !service->exec().isEmpty();
    });

    QSet<QString> seen;
    QVariantList result;
    for (const KService::Ptr &service : services) {
        const QString id = service->storageId();
        // Les lanceurs « Spotlight » et « Siri IA » du Dock n'ont rien à faire
        // dans la grille du Spotlight lui-même.
        if (id.isEmpty() || id.startsWith(QLatin1String("macosdock-")) || seen.contains(id)) {
            continue;
        }
        seen.insert(id);
        QVariantMap entry;
        entry.insert(QStringLiteral("name"), service->name());
        entry.insert(QStringLiteral("genericName"), service->genericName());
        entry.insert(QStringLiteral("comment"), service->comment());
        entry.insert(QStringLiteral("icon"), service->icon());
        entry.insert(QStringLiteral("desktopId"), id);
        entry.insert(QStringLiteral("category"), spotlightCategory(service->categories()));
        entry.insert(QStringLiteral("keywords"), service->keywords().join(QLatin1Char(' ')));
        result.append(entry);
    }

    QCollator collator(QLocale::system());
    collator.setCaseSensitivity(Qt::CaseInsensitive);
    std::sort(result.begin(), result.end(), [&collator](const QVariant &a, const QVariant &b) {
        return collator.compare(a.toMap().value(QStringLiteral("name")).toString(),
                                b.toMap().value(QStringLiteral("name")).toString()) < 0;
    });
    return result;
}

bool SpotlightBackend::launchApplication(const QString &desktopId)
{
    const KService::Ptr service = KService::serviceByStorageId(desktopId);
    if (!service) {
        return false;
    }
    auto *job = new KIO::ApplicationLauncherJob(service);
    job->start();
    return true;
}

bool SpotlightBackend::showApplicationLocation(const QString &desktopId)
{
    const KService::Ptr service = KService::serviceByStorageId(desktopId);
    if (!service || service->entryPath().isEmpty()) {
        return false;
    }
    revealPath(service->entryPath());
    return true;
}

// --- Fichiers ---------------------------------------------------------------

void SpotlightBackend::searchFiles(const QString &query)
{
    const QString needle = query.trimmed().toLower();
    const int generation = m_fileGeneration->fetch_add(1) + 1;
    if (needle.size() < 2) {
        Q_EMIT filesFound(query.trimmed(), QVariantList());
        return;
    }
    const QStringList tokens = needle.split(QRegularExpression(QStringLiteral("\\s+")),
                                            Qt::SkipEmptyParts);
    if (tokens.isEmpty()) {
        Q_EMIT filesFound(query.trimmed(), QVariantList());
        return;
    }

    const QPointer<SpotlightBackend> self(this);
    const std::shared_ptr<std::atomic<int>> counter = m_fileGeneration;
    const QString home = QDir::homePath();
    const QString shown = query.trimmed();
    auto future = QtConcurrent::run([self, counter, generation, tokens, home, shown]() {
        const QVariantList results = walkFiles(home, tokens, counter, generation);
        if (counter->load() != generation) {
            return;
        }
        QMetaObject::invokeMethod(
            self.data(),
            [self, counter, generation, shown, results]() {
                if (self && counter->load() == generation) {
                    Q_EMIT self->filesFound(shown, results);
                }
            },
            Qt::QueuedConnection);
    });
    Q_UNUSED(future)
}

void SpotlightBackend::cancelFileSearch()
{
    m_fileGeneration->fetch_add(1);
}

QVariantList SpotlightBackend::recentFiles(int limit) const
{
    const QString path = QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation)
        + QStringLiteral("/recently-used.xbel");
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly)) {
        return {};
    }

    struct Recent
    {
        QString path;
        qint64 modified;
    };
    QList<Recent> recents;
    QXmlStreamReader reader(&file);
    while (!reader.atEnd()) {
        reader.readNext();
        if (!reader.isStartElement() || reader.name() != QLatin1String("bookmark")) {
            continue;
        }
        const QUrl url(reader.attributes().value(QStringLiteral("href")).toString());
        if (!url.isLocalFile()) {
            continue;
        }
        const QString local = url.toLocalFile();
        const QFileInfo info(local);
        if (!info.exists()) {
            continue;
        }
        QDateTime stamp = QDateTime::fromString(
            reader.attributes().value(QStringLiteral("modified")).toString(), Qt::ISODate);
        if (!stamp.isValid()) {
            stamp = info.lastModified();
        }
        recents.append({local, stamp.toMSecsSinceEpoch()});
    }
    std::sort(recents.begin(), recents.end(),
              [](const Recent &a, const Recent &b) { return a.modified > b.modified; });

    QVariantList result;
    QSet<QString> seen;
    for (const Recent &recent : std::as_const(recents)) {
        if (result.size() >= qMax(1, limit)) {
            break;
        }
        if (seen.contains(recent.path)) {
            continue;
        }
        seen.insert(recent.path);
        result.append(fileEntry(recent.path, QFileInfo(recent.path).isDir(), recent.modified));
    }
    return result;
}

bool SpotlightBackend::openPath(const QString &path)
{
    return QDesktopServices::openUrl(QUrl::fromLocalFile(path));
}

void SpotlightBackend::revealPath(const QString &path)
{
    // « Afficher dans le dossier » : le gestionnaire de fichiers sélectionne
    // l'élément (org.freedesktop.FileManager1), sinon on ouvre son dossier.
    QDBusMessage message = QDBusMessage::createMethodCall(
        QStringLiteral("org.freedesktop.FileManager1"), QStringLiteral("/org/freedesktop/FileManager1"),
        QStringLiteral("org.freedesktop.FileManager1"), QStringLiteral("ShowItems"));
    message << QStringList{QUrl::fromLocalFile(path).toString()} << QString();
    auto *watcher = new QDBusPendingCallWatcher(
        QDBusConnection::sessionBus().asyncCall(message, 2000), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [path](QDBusPendingCallWatcher *call) {
        const QDBusPendingReply<> reply = *call;
        if (reply.isError()) {
            QDesktopServices::openUrl(QUrl::fromLocalFile(QFileInfo(path).absolutePath()));
        }
        call->deleteLater();
    });
}

QString SpotlightBackend::homePath() const
{
    return QDir::homePath();
}

// --- Presse-papiers ---------------------------------------------------------

void SpotlightBackend::requestClipboardHistory()
{
    const QDBusMessage message = QDBusMessage::createMethodCall(
        QStringLiteral("org.kde.klipper"), QStringLiteral("/klipper"),
        QStringLiteral("org.kde.klipper.klipper"), QStringLiteral("getClipboardHistoryMenu"));
    auto *watcher = new QDBusPendingCallWatcher(
        QDBusConnection::sessionBus().asyncCall(message, 1500), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this](QDBusPendingCallWatcher *call) {
        const QDBusPendingReply<QStringList> reply = *call;
        if (reply.isError()) {
            Q_EMIT clipboardHistoryReady(QStringList(), false);
        } else {
            Q_EMIT clipboardHistoryReady(reply.value(), true);
        }
        call->deleteLater();
    });
}

void SpotlightBackend::setClipboardText(const QString &text)
{
    QDBusMessage message = QDBusMessage::createMethodCall(
        QStringLiteral("org.kde.klipper"), QStringLiteral("/klipper"),
        QStringLiteral("org.kde.klipper.klipper"), QStringLiteral("setClipboardContents"));
    message << text;
    auto *watcher = new QDBusPendingCallWatcher(
        QDBusConnection::sessionBus().asyncCall(message, 1500), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this,
            [text](QDBusPendingCallWatcher *call) {
                const QDBusPendingReply<> reply = *call;
                if (reply.isError() && QGuiApplication::clipboard()) {
                    QGuiApplication::clipboard()->setText(text);
                }
                call->deleteLater();
            });
}

// --- Commandes --------------------------------------------------------------

QString SpotlightBackend::findExecutable(const QString &name) const
{
    QString found = QStandardPaths::findExecutable(name);
    if (!found.isEmpty()) {
        return found;
    }
    const QString home = QDir::homePath();
    const QStringList extra = {
        home + QStringLiteral("/.opencode/bin"),
        home + QStringLiteral("/.local/bin"),
        home + QStringLiteral("/.bun/bin"),
        home + QStringLiteral("/.npm-global/bin"),
        home + QStringLiteral("/.cargo/bin"),
        QStringLiteral("/usr/local/bin"),
        QStringLiteral("/home/linuxbrew/.linuxbrew/bin"),
        QStringLiteral("/opt/homebrew/bin"),
    };
    return QStandardPaths::findExecutable(name, extra);
}

int SpotlightBackend::runProcess(const QString &program, const QStringList &arguments,
                                 int timeoutMs)
{
    const int id = ++m_nextProcessId;
    auto *process = new QProcess(this);
    m_processes.insert(id, process);

    QProcessEnvironment environment = QProcessEnvironment::systemEnvironment();
    environment.insert(QStringLiteral("NO_COLOR"), QStringLiteral("1"));
    environment.insert(QStringLiteral("TERM"), QStringLiteral("dumb"));
    environment.insert(QStringLiteral("CI"), QStringLiteral("1"));
    // Le CLI se trouve parfois dans un dossier absent du PATH de plasmashell.
    const QString home = QDir::homePath();
    environment.insert(QStringLiteral("PATH"),
                       environment.value(QStringLiteral("PATH")) + QStringLiteral(":") + home
                           + QStringLiteral("/.opencode/bin:") + home
                           + QStringLiteral("/.local/bin:/usr/local/bin"));
    process->setProcessEnvironment(environment);
    // Dossier de travail vide et propre au Dock : l'assistant n'y voit rien.
    QDir().mkpath(dataDirectory() + QStringLiteral("/sandbox"));
    process->setWorkingDirectory(dataDirectory() + QStringLiteral("/sandbox"));
    process->setStandardInputFile(QProcess::nullDevice());

    auto timedOut = std::make_shared<bool>(false);
    auto *timer = new QTimer(process);
    timer->setSingleShot(true);
    connect(timer, &QTimer::timeout, process, [process, timedOut]() {
        *timedOut = true;
        process->kill();
    });

    auto finish = [this, id, process, timedOut](int exitCode, const QString &errorOverride) {
        if (!m_processes.contains(id)) {
            return;
        }
        m_processes.remove(id);
        const QString out = QString::fromUtf8(process->readAllStandardOutput());
        QString err = QString::fromUtf8(process->readAllStandardError());
        if (!errorOverride.isEmpty()) {
            err = errorOverride;
        }
        const bool wasTimeout = *timedOut;
        process->deleteLater();
        Q_EMIT processFinished(id, exitCode, out, err, wasTimeout);
    };

    connect(process, &QProcess::finished, this,
            [finish](int exitCode, QProcess::ExitStatus status) {
                finish(status == QProcess::NormalExit ? exitCode : -1, QString());
            });
    connect(process, &QProcess::errorOccurred, this,
            [finish, process](QProcess::ProcessError error) {
                if (error == QProcess::FailedToStart) {
                    finish(-1, process->errorString());
                }
            });

    process->start(program, arguments);
    timer->start(qMax(1000, timeoutMs));
    return id;
}

void SpotlightBackend::abortProcess(int id)
{
    QProcess *process = m_processes.value(id, nullptr);
    if (process) {
        process->kill();
    }
}

// --- Stockage ---------------------------------------------------------------

QString SpotlightBackend::loadText(const QString &name) const
{
    const QString safe = safeStorageName(name);
    if (safe.isEmpty()) {
        return QString();
    }
    QFile file(dataDirectory() + QLatin1Char('/') + safe);
    if (!file.open(QIODevice::ReadOnly)) {
        return QString();
    }
    return QString::fromUtf8(file.readAll());
}

bool SpotlightBackend::saveText(const QString &name, const QString &text)
{
    const QString safe = safeStorageName(name);
    if (safe.isEmpty() || !QDir().mkpath(dataDirectory())) {
        return false;
    }
    QSaveFile file(dataDirectory() + QLatin1Char('/') + safe);
    if (!file.open(QIODevice::WriteOnly)) {
        return false;
    }
    file.setPermissions(QFileDevice::ReadOwner | QFileDevice::WriteOwner);
    file.write(text.toUtf8());
    return file.commit();
}

bool SpotlightBackend::applyToolIcon(const QString &tool, const QString &source)
{
    if (tool != QLatin1String("spotlight") && tool != QLatin1String("siri")) {
        return false;
    }
    const QString desktopPath = QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation)
        + QStringLiteral("/applications/macosdock-") + tool + QStringLiteral(".desktop");
    if (!QFileInfo::exists(desktopPath)) {
        return false;
    }

    // Anciennes copies d'icône personnalisée.
    const QString iconDir = dataDirectory() + QStringLiteral("/icons");
    QDir().mkpath(iconDir);
    const QStringList old = QDir(iconDir).entryList({tool + QStringLiteral(".*")}, QDir::Files);

    QString wanted = QStringLiteral("macosdock-") + tool;
    QString local = source.trimmed();
    if (local.startsWith(QLatin1String("file:"))) {
        local = QUrl(local).toLocalFile();
    }
    QString copied;
    if (!local.isEmpty()) {
        static const QSet<QString> allowed{QStringLiteral("png"), QStringLiteral("svg"),
            QStringLiteral("svgz"), QStringLiteral("jpg"), QStringLiteral("jpeg"),
            QStringLiteral("webp"), QStringLiteral("bmp"), QStringLiteral("ico"),
            QStringLiteral("xpm")};
        const QFileInfo info(local);
        const QString suffix = info.suffix().toLower();
        if (!info.isFile() || !allowed.contains(suffix)) {
            return false;
        }
        // Même image qu'une copie existante : on la réutilise (rien à recharger).
        QFile sourceFile(info.absoluteFilePath());
        if (!sourceFile.open(QIODevice::ReadOnly)) {
            return false;
        }
        const QByteArray sourceData = sourceFile.readAll();
        sourceFile.close();
        for (const QString &name : old) {
            QFile existing(iconDir + QLatin1Char('/') + name);
            if (existing.open(QIODevice::ReadOnly) && existing.readAll() == sourceData) {
                copied = existing.fileName();
                break;
            }
        }
        if (copied.isEmpty()) {
            // Nom différent à chaque changement : le Dock recharge ainsi l'image.
            copied = iconDir + QLatin1Char('/') + tool + QLatin1Char('.')
                + QString::number(QDateTime::currentSecsSinceEpoch()) + QLatin1Char('.') + suffix;
            if (!QFile::copy(info.absoluteFilePath(), copied)) {
                return false;
            }
        }
        wanted = copied;
    }
    for (const QString &name : old) {
        const QString path = iconDir + QLatin1Char('/') + name;
        if (path != copied) {
            QFile::remove(path);
        }
    }

    QFile in(desktopPath);
    if (!in.open(QIODevice::ReadOnly | QIODevice::Text)) {
        return false;
    }
    const QStringList lines = QString::fromUtf8(in.readAll()).split(QLatin1Char('\n'));
    in.close();
    QStringList out;
    bool changed = false;
    bool replaced = false;
    for (const QString &line : lines) {
        if (!replaced && line.startsWith(QLatin1String("Icon="))) {
            const QString next = QStringLiteral("Icon=") + wanted;
            changed = changed || next != line;
            out << next;
            replaced = true;
        } else {
            out << line;
        }
    }
    if (!replaced || !changed) {
        return replaced;
    }
    QSaveFile file(desktopPath);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        return false;
    }
    file.write(out.join(QLatin1Char('\n')).toUtf8());
    if (!file.commit()) {
        return false;
    }
    QProcess::startDetached(QStringLiteral("kbuildsycoca6"), {});
    return true;
}

void SpotlightBackend::applyLauncherIntegration(bool enabled)
{
    const QString script = dataDirectory() + QStringLiteral("/spotlight-integration.sh");
    if (!QFileInfo::exists(script)) {
        return;
    }
    runProcess(QStringLiteral("/bin/bash"),
               {script, enabled ? QStringLiteral("enable") : QStringLiteral("disable")}, 30000);
}
