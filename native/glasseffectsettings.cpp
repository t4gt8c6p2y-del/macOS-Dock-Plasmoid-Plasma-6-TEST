#include "glasseffectsettings.h"

#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusReply>
#include <QMetaType>
#include <QProcess>
#include <QRegularExpression>
#include <QStringList>

namespace {

const QString kwinService = QStringLiteral("org.kde.KWin");
const QString effectsPath = QStringLiteral("/Effects");
const QString effectsInterface = QStringLiteral("org.kde.kwin.Effects");
const QString glassEffect = QStringLiteral("glass");
const QString blurEffect = QStringLiteral("blur");

// Valeur kwinrc d'une valeur QML ; une chaîne vide signale une valeur refusée.
QString configValue(const QVariant &value)
{
    switch (value.typeId()) {
    case QMetaType::Bool:
        return value.toBool() ? QStringLiteral("true") : QStringLiteral("false");
    case QMetaType::Int:
    case QMetaType::UInt:
    case QMetaType::LongLong:
    case QMetaType::ULongLong:
        return QString::number(value.toLongLong());
    case QMetaType::Double:
    case QMetaType::Float:
        return QString::number(value.toDouble(), 'f', 3);
    default:
        return QString();
    }
}

bool isLoaded(QDBusInterface &effects, const QString &name)
{
    const QDBusReply<bool> reply = effects.call(QStringLiteral("isEffectLoaded"), name);
    return reply.isValid() && reply.value();
}

} // namespace

GlassEffectSettings::GlassEffectSettings(QObject *parent)
    : QObject(parent)
{
}

bool GlassEffectSettings::glassLoaded() const
{
    QDBusInterface effects(kwinService, effectsPath, effectsInterface,
                           QDBusConnection::sessionBus());
    return effects.isValid() && isLoaded(effects, glassEffect);
}

void GlassEffectSettings::apply(const QVariantMap &keys, bool ensureGlassLoaded)
{
    if (m_process) {
        // Une écriture est en cours : on ne garde que la dernière demande.
        m_pendingKeys = keys;
        m_pendingEnsure = ensureGlassLoaded;
        m_hasPending = true;
        return;
    }
    start(keys, ensureGlassLoaded);
}

void GlassEffectSettings::start(const QVariantMap &keys, bool ensureGlassLoaded)
{
    static const QRegularExpression validKey(QStringLiteral("^[A-Za-z0-9]+$"));

    // Les paires clé/valeur sont passées comme arguments au script : rien
    // n'est interprété par le shell, aucun échappement n'est nécessaire.
    QStringList arguments;
    arguments << QStringLiteral("-c")
              << QStringLiteral("while [ $# -ge 2 ]; do "
                                "kwriteconfig6 --file kwinrc --group Effect-blurplus "
                                "--key \"$1\" \"$2\"; shift 2; done")
              << QStringLiteral("sh");
    for (auto it = keys.cbegin(); it != keys.cend(); ++it) {
        const QString value = configValue(it.value());
        if (!validKey.match(it.key()).hasMatch() || value.isEmpty()) {
            continue;
        }
        arguments << it.key() << value;
    }

    m_process = new QProcess(this);
    connect(m_process, &QProcess::finished, this,
            [this, ensureGlassLoaded](int, QProcess::ExitStatus) {
                m_process->deleteLater();
                m_process = nullptr;
                finish(ensureGlassLoaded);
                if (m_hasPending) {
                    m_hasPending = false;
                    start(m_pendingKeys, m_pendingEnsure);
                }
            });
    connect(m_process, &QProcess::errorOccurred, this,
            [this](QProcess::ProcessError error) {
                if (error != QProcess::FailedToStart || !m_process) {
                    return;
                }
                // kwriteconfig6 / sh introuvable : « finished » ne viendra pas.
                m_process->deleteLater();
                m_process = nullptr;
                m_hasPending = false;
            });
    m_process->start(QStringLiteral("sh"), arguments);
}

void GlassEffectSettings::finish(bool ensureGlassLoaded)
{
    QDBusInterface effects(kwinService, effectsPath, effectsInterface,
                           QDBusConnection::sessionBus());
    if (!effects.isValid()) {
        return;
    }

    if (ensureGlassLoaded && !isLoaded(effects, glassEffect)) {
        // L'effet Glass remplace le flou standard (les deux ne vont pas
        // ensemble). S'il n'est pas installé, on rétablit le flou standard.
        effects.call(QStringLiteral("unloadEffect"), blurEffect);
        const QDBusReply<bool> loaded = effects.call(QStringLiteral("loadEffect"), glassEffect);
        if (!loaded.isValid() || !loaded.value()) {
            effects.call(QStringLiteral("loadEffect"), blurEffect);
            return;
        }
        QProcess::startDetached(QStringLiteral("kwriteconfig6"),
                                {QStringLiteral("--file"), QStringLiteral("kwinrc"),
                                 QStringLiteral("--group"), QStringLiteral("Plugins"),
                                 QStringLiteral("--key"), QStringLiteral("glassEnabled"),
                                 QStringLiteral("true")});
        QProcess::startDetached(QStringLiteral("kwriteconfig6"),
                                {QStringLiteral("--file"), QStringLiteral("kwinrc"),
                                 QStringLiteral("--group"), QStringLiteral("Plugins"),
                                 QStringLiteral("--key"), QStringLiteral("blurEnabled"),
                                 QStringLiteral("false")});
    }

    effects.call(QDBus::NoBlock, QStringLiteral("reconfigureEffect"), glassEffect);
}
