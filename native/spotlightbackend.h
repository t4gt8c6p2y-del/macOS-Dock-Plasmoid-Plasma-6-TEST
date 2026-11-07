#pragma once

#include <QHash>
#include <QObject>
#include <QString>
#include <QStringList>
#include <QTimer>
#include <QVariantList>
#include <QVariantMap>

#include <atomic>
#include <memory>

class QProcess;
class SpotlightBackend;

/**
 * Interface D-Bus propre au Dock : org.macosdock.Spotlight sur /Spotlight.
 * C'est la cible de la touche Windows (voir spotlight-integration.sh) et de
 * tout raccourci personnalisé :
 *   dbus-send --session --type=method_call --dest=org.macosdock.Spotlight \
 *       /Spotlight org.macosdock.Spotlight.toggle
 */
class SpotlightDBusService : public QObject
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.macosdock.Spotlight")

public:
    explicit SpotlightDBusService(SpotlightBackend *backend);

public Q_SLOTS:
    Q_SCRIPTABLE void toggle();
    Q_SCRIPTABLE void show();
    Q_SCRIPTABLE void hide();
    Q_SCRIPTABLE void query(const QString &text);
    Q_SCRIPTABLE void openAssistant();

private:
    SpotlightBackend *m_backend;
};

/**
 * Compatibilité avec KRunner (org.kde.krunner.App sur /App). Quand le Dock
 * possède ce nom, tout ce qui appelait KRunner (saisie sur le bureau, Alt+F2,
 * `krunner` en ligne de commande...) ouvre le Spotlight du Dock à la place.
 */
class KRunnerCompatService : public QObject
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.kde.krunner.App")

public:
    explicit KRunnerCompatService(SpotlightBackend *backend);

public Q_SLOTS:
    Q_SCRIPTABLE void display();
    Q_SCRIPTABLE void toggleDisplay();
    Q_SCRIPTABLE void displayWithClipboardContents();
    Q_SCRIPTABLE void query(const QString &term);
    Q_SCRIPTABLE void queryClipboard();
    Q_SCRIPTABLE void querySingleRunner(const QString &runnerId, const QString &term);
    Q_SCRIPTABLE void displaySingleRunner(const QString &runnerId);
    Q_SCRIPTABLE void showTaskManager();
    Q_SCRIPTABLE void showSystemActivity();
    Q_SCRIPTABLE void clearHistory();

private:
    SpotlightBackend *m_backend;
};

/**
 * org.freedesktop.Application sur /org/kde/krunner : quand on lance le
 * programme `krunner` (raccourci global Alt+Espace géré par KGlobalAccel), il
 * transmet l'activation à l'instance existante par cette interface.
 */
class KRunnerApplicationService : public QObject
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.freedesktop.Application")

public:
    explicit KRunnerApplicationService(SpotlightBackend *backend);

public Q_SLOTS:
    Q_SCRIPTABLE void Activate(const QVariantMap &platformData);
    Q_SCRIPTABLE void Open(const QStringList &uris, const QVariantMap &platformData);
    Q_SCRIPTABLE void ActivateAction(const QString &actionName, const QVariantList &parameter,
                                     const QVariantMap &platformData);

private:
    SpotlightBackend *m_backend;
};

/**
 * Services du Spotlight : applications installées, recherche de fichiers,
 * historique du presse-papiers (Klipper), exécution de commandes (assistant
 * IA via le CLI OpenCode), petit stockage de texte, raccourcis D-Bus.
 * Tout ce qui est lent est asynchrone et rend la main à QML par signal.
 */
class SpotlightBackend : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool dbusActive READ dbusActive NOTIFY dbusActiveChanged)
    Q_PROPERTY(bool replaceLauncher READ replaceLauncher WRITE setReplaceLauncher NOTIFY replaceLauncherChanged)

public:
    explicit SpotlightBackend(QObject *parent = nullptr);
    ~SpotlightBackend() override;

    bool dbusActive() const;
    bool replaceLauncher() const;
    void setReplaceLauncher(bool replace);

    // --- Applications ---------------------------------------------------
    /** [{ name, genericName, comment, icon, desktopId, category, keywords }] */
    Q_INVOKABLE QVariantList applications() const;
    Q_INVOKABLE bool launchApplication(const QString &desktopId);
    /** Ouvre « Afficher dans le gestionnaire de fichiers » pour le lanceur. */
    Q_INVOKABLE bool showApplicationLocation(const QString &desktopId);

    // --- Fichiers ---------------------------------------------------------
    Q_INVOKABLE void searchFiles(const QString &query);
    Q_INVOKABLE void cancelFileSearch();
    Q_INVOKABLE QVariantList recentFiles(int limit) const;
    Q_INVOKABLE bool openPath(const QString &path);
    Q_INVOKABLE void revealPath(const QString &path);
    Q_INVOKABLE QString homePath() const;

    // --- Presse-papiers (Klipper) -----------------------------------------
    Q_INVOKABLE void requestClipboardHistory();
    Q_INVOKABLE void setClipboardText(const QString &text);

    // --- Commandes (assistant IA par le CLI OpenCode) ---------------------
    /** Chemin absolu du programme, ou chaîne vide s'il est introuvable. */
    Q_INVOKABLE QString findExecutable(const QString &name) const;
    /** Lance le programme sans shell ; renvoie un identifiant de suivi. */
    Q_INVOKABLE int runProcess(const QString &program, const QStringList &arguments,
                               int timeoutMs);
    Q_INVOKABLE void abortProcess(int id);

    // --- Stockage de texte (~/.local/share/macosdock/) --------------------
    Q_INVOKABLE QString loadText(const QString &name) const;
    Q_INVOKABLE bool saveText(const QString &name, const QString &text);

    /** Applique (ou annule) l'intégration au système : touche Windows, KRunner. */
    Q_INVOKABLE void applyLauncherIntegration(bool enabled);

    /**
     * Change l'icône du lanceur « spotlight » ou « siri » dans le Dock : copie
     * l'image choisie (chemin ou URL file://) dans le dossier de données et la
     * référence dans le .desktop. Chemin vide : icône par défaut.
     */
    Q_INVOKABLE bool applyToolIcon(const QString &tool, const QString &source);

    // Appelés par les services D-Bus.
    void emitToggle();
    void emitShow();
    void emitHide();
    void emitQuery(const QString &text);
    void emitOpenAssistant();

Q_SIGNALS:
    void dbusActiveChanged();
    void replaceLauncherChanged();
    void toggleRequested();
    void showRequested();
    void hideRequested();
    void queryRequested(const QString &text);
    void assistantRequested();
    void filesFound(const QString &query, const QVariantList &results);
    void clipboardHistoryReady(const QStringList &items, bool available);
    void processFinished(int id, int exitCode, const QString &standardOutput,
                         const QString &standardError, bool timedOut);

private:
    void updateDBusRegistration();
    void registerOwnService();
    void registerKRunnerService();
    void releaseKRunnerService();

    SpotlightDBusService *m_ownService = nullptr;
    KRunnerCompatService *m_krunnerService = nullptr;
    KRunnerApplicationService *m_applicationService = nullptr;
    bool m_ownRegistered = false;
    bool m_krunnerRegistered = false;
    bool m_replaceLauncher = true;
    QTimer m_retryTimer;

    std::shared_ptr<std::atomic<int>> m_fileGeneration;
    int m_nextProcessId = 0;
    QHash<int, QProcess *> m_processes;
};
