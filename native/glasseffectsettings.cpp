#include "glasseffectsettings.h"

#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusReply>
#include <QDebug>
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

// Mémorise dans kwinrc quel effet est activé (pris en compte au prochain
// démarrage de KWin).
void writePluginState(const QString &effect)
{
    const QString other = effect == glassEffect ? blurEffect : glassEffect;
    const auto write = [](const QString &key, const QString &value) {
        QProcess::startDetached(QStringLiteral("kwriteconfig6"),
                                {QStringLiteral("--file"), QStringLiteral("kwinrc"),
                                 QStringLiteral("--group"), QStringLiteral("Plugins"),
                                 QStringLiteral("--key"), key, value});
    };
    write(effect + QStringLiteral("Enabled"), QStringLiteral("true"));
    write(other + QStringLiteral("Enabled"), QStringLiteral("false"));
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

void GlassEffectSettings::apply(const QString &effect, const QVariantMap &keys)
{
    if (effect != glassEffect && effect != blurEffect) {
        return;
    }
    if (m_process) {
        // Une écriture est en cours : on ne garde que la dernière demande.
        m_pendingEffect = effect;
        m_pendingKeys = keys;
        m_hasPending = true;
        return;
    }
    start(effect, keys);
}

void GlassEffectSettings::start(const QString &effect, const QVariantMap &keys)
{
    static const QRegularExpression validKey(QStringLiteral("^[A-Za-z0-9]+$"));

    const QString group = effect == glassEffect ? QStringLiteral("Effect-blurplus")
                                                : QStringLiteral("Effect-blur");

    // Le groupe puis les paires clé/valeur sont passés comme arguments au
    // script : rien n'est interprété par le shell, aucun échappement n'est
    // nécessaire.
    QStringList arguments;
    arguments << QStringLiteral("-c")
              << QStringLiteral("group=\"$1\"; shift; while [ $# -ge 2 ]; do "
                                "kwriteconfig6 --file kwinrc --group \"$group\" "
                                "--key \"$1\" \"$2\"; shift 2; done")
              << QStringLiteral("sh") << group;
    for (auto it = keys.cbegin(); it != keys.cend(); ++it) {
        const QString value = configValue(it.value());
        if (!validKey.match(it.key()).hasMatch() || value.isEmpty()) {
            continue;
        }
        arguments << it.key() << value;
    }

    m_process = new QProcess(this);
    connect(m_process, &QProcess::finished, this,
            [this, effect](int exitCode, QProcess::ExitStatus) {
                if (exitCode != 0) {
                    qWarning() << "GlassEffectSettings : kwriteconfig6 a échoué, code" << exitCode
                               << m_process->readAllStandardError();
                }
                m_process->deleteLater();
                m_process = nullptr;
                finish(effect);
                if (m_hasPending) {
                    m_hasPending = false;
                    start(m_pendingEffect, m_pendingKeys);
                }
            });
    connect(m_process, &QProcess::errorOccurred, this,
            [this](QProcess::ProcessError error) {
                if (error != QProcess::FailedToStart || !m_process) {
                    return;
                }
                // kwriteconfig6 / sh introuvable : « finished » ne viendra pas.
                qWarning() << "GlassEffectSettings : impossible de lancer sh / kwriteconfig6";
                m_process->deleteLater();
                m_process = nullptr;
                m_hasPending = false;
            });
    m_process->start(QStringLiteral("sh"), arguments);
}

void GlassEffectSettings::finish(const QString &effect)
{
    QDBusInterface effects(kwinService, effectsPath, effectsInterface,
                           QDBusConnection::sessionBus());
    if (!effects.isValid()) {
        qWarning() << "GlassEffectSettings : KWin injoignable par D-Bus";
        return;
    }

    if (!isLoaded(effects, effect)) {
        // Un seul des deux effets de flou doit être chargé : l'autre est
        // déchargé. Si le nouveau ne peut pas être chargé (Glass pas
        // installé, par exemple), on rétablit l'autre.
        const QString other = effect == glassEffect ? blurEffect : glassEffect;
        effects.call(QStringLiteral("unloadEffect"), other);
        const QDBusReply<bool> loaded = effects.call(QStringLiteral("loadEffect"), effect);
        if (!loaded.isValid() || !loaded.value()) {
            qWarning() << "GlassEffectSettings : l'effet" << effect
                       << "n'a pas pu être chargé (installé ? compatible avec cette version de KWin ?)";
            effects.call(QStringLiteral("loadEffect"), other);
            return;
        }
        writePluginState(effect);
    }

    effects.call(QDBus::NoBlock, QStringLiteral("reconfigureEffect"), effect);
}
