#pragma once

#include <QObject>
#include <QString>
#include <QVariantMap>

class QProcess;

/**
 * Règle le flou de KWin depuis le Dock.
 *
 * Deux effets KWin peuvent flouter l'arrière-plan : le flou standard
 * (« blur », groupe kwinrc [Effect-blur]) et l'effet « Glass » du projet
 * liquid-glass-kde (« glass », groupe [Effect-blurplus]). Les valeurs sont
 * écrites avec kwriteconfig6, l'effet voulu est chargé à la place de l'autre
 * s'il ne l'est pas déjà, puis rechargé par D-Bus.
 *
 * Ces réglages sont globaux à KWin : le Dock n'a pas de moyen de régler le
 * flou d'une seule fenêtre.
 */
class GlassEffectSettings : public QObject
{
    Q_OBJECT

public:
    explicit GlassEffectSettings(QObject *parent = nullptr);

    /**
     * effect : "blur" (flou standard) ou "glass" (effet Glass). keys : nom de
     * clé kwinrc -> valeur booléenne, entière ou décimale. L'appel ne bloque
     * pas : plusieurs appels rapprochés sont regroupés (le dernier gagne).
     */
    Q_INVOKABLE void apply(const QString &effect, const QVariantMap &keys);

    /** Vrai si l'effet Glass est actuellement chargé dans KWin. */
    Q_INVOKABLE bool glassLoaded() const;

private:
    void start(const QString &effect, const QVariantMap &keys);
    void finish(const QString &effect);

    QProcess *m_process = nullptr;
    bool m_hasPending = false;
    QString m_pendingEffect;
    QVariantMap m_pendingKeys;
};
