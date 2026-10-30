#pragma once

#include <QObject>
#include <QPointer>
#include <QString>
#include <QVariantList>

class QMenu;
class QWindow;

/**
 * Menu contextuel natif (QMenu) pour le Dock.
 *
 * Les menus QML (QtQuick.Controls) ne sont pas habillés par le style Qt de
 * l'utilisateur (Kvantum) et ne reçoivent ni le flou ni l'effet « Glass » de
 * KWin. Un QMenu, lui, est exactement le widget qu'utilise le menu du clic
 * droit sur le bureau : il hérite donc du thème Liquid Glass.
 *
 * Le contenu est décrit par une liste de dictionnaires :
 *   { id, text, icon, enabled }              entrée
 *   { id, text, icon, enabled, children }    sous-menu
 *   { separator: true }                      trait de séparation
 */
class DockMenu : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool available READ available CONSTANT)
    Q_PROPERTY(bool visible READ isVisible NOTIFY visibleChanged)

public:
    explicit DockMenu(QObject *parent = nullptr);
    ~DockMenu() override;

    /** Faux si le processus n'a pas de QApplication (pas de widgets). */
    bool available() const;
    bool isVisible() const;

    /**
     * Ouvre le menu à l'endroit du clic. (x, y) sont en coordonnées de la
     * fenêtre parent. direction : "up" (le menu s'ouvre au-dessus du point,
     * Dock en bas), "down", "left" ou "right".
     */
    Q_INVOKABLE bool popup(QWindow *parentWindow, qreal x, qreal y,
                           const QString &direction, const QVariantList &items);
    Q_INVOKABLE void close();

Q_SIGNALS:
    void triggered(const QString &id);
    void opened();
    void closed();
    void visibleChanged();

private:
    void addItems(QMenu *menu, const QVariantList &items);
    void setVisible(bool visible);

    QPointer<QMenu> m_menu;
    bool m_visible = false;
};
