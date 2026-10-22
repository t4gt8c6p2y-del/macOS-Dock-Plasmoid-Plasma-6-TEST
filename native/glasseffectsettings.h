#pragma once

#include <QObject>
#include <QString>
#include <QVariantMap>

class QProcess;

/**
 * Règle l'effet KWin « Glass » (flou et verre liquide) depuis le Dock.
 *
 * Les valeurs sont écrites dans kwinrc, groupe [Effect-blurplus], avec
 * kwriteconfig6, puis l'effet est rechargé par D-Bus. C'est la même méthode
 * que l'application de réglages du projet liquid-glass-kde : l'effet est
 * global à KWin, ses réglages ne sont donc pas propres au Dock.
 */
class GlassEffectSettings : public QObject
{
    Q_OBJECT

public:
    explicit GlassEffectSettings(QObject *parent = nullptr);

    /**
     * Écrit les clés données (nom de clé kwinrc -> valeur booléenne, entière
     * ou décimale), puis recharge l'effet. Si ensureGlassLoaded est vrai et
     * que l'effet Glass n'est pas chargé, il remplace le flou standard de
     * KWin ; s'il n'est pas installé, le flou standard est rétabli.
     * L'appel ne bloque pas : plusieurs appels rapprochés sont regroupés.
     */
    Q_INVOKABLE void apply(const QVariantMap &keys, bool ensureGlassLoaded);

    /** Vrai si l'effet Glass est actuellement chargé dans KWin. */
    Q_INVOKABLE bool glassLoaded() const;

private:
    void start(const QVariantMap &keys, bool ensureGlassLoaded);
    void finish(bool ensureGlassLoaded);

    QProcess *m_process = nullptr;
    bool m_hasPending = false;
    QVariantMap m_pendingKeys;
    bool m_pendingEnsure = false;
};
