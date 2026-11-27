#pragma once

#include <QObject>
#include <QRectF>
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
 *   { ..., checked }                         entrée à cocher
 *   { ..., shortcut }                        raccourci affiché (« Ctrl+1 »)
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
     *
     * bubble = faux : menu ordinaire, dont un coin est posé sur le point.
     * bubble = vrai : bulle centrée sur le point, avec une pointe arrondie
     * (en « V ») dirigée vers lui ; le point est alors le bord de l'icône.
     *
     * rim = vrai : liseré blanc lumineux (menus du Dock). rim = faux : pas de
     * liseré blanc, seulement un trait sombre très fin (menus de Spotlight et
     * de Siri IA).
     *
     * button (facultatif, menu sans pointe) : rectangle du bouton qui a ouvert
     * le menu, en coordonnées de la fenêtre. Le menu se pose alors SUR le
     * bouton (coin du menu = coin du bouton, vers le bas, le haut ou la gauche
     * selon direction) et s'ouvre en partant de la taille du bouton, comme si
     * le bouton s'agrandissait en menu. (x, y) est alors le coin du bouton où
     * le menu s'accroche.
     */
    Q_INVOKABLE bool popup(QWindow *parentWindow, qreal x, qreal y,
                           const QString &direction, const QVariantList &items,
                           bool bubble = false, bool rim = true,
                           const QRectF &button = QRectF());
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
    bool m_rim = true;
    bool m_animated = false;
};
