#pragma once

#include <QObject>
#include <QVariantList>

class QWindow;

/**
 * Demande à KWin de flouter (et, avec l'effet « Glass » de l'utilisateur, de
 * passer au Liquid Glass) ce qui se trouve derrière certaines zones d'une
 * fenêtre du Dock. C'est ce que font les menus Qt habillés par Kvantum : les
 * infobulles et les bulles du Dock reçoivent ainsi le même fond que le menu
 * du clic droit.
 *
 * Chaque zone est un dictionnaire { x, y, width, height, radius } en
 * coordonnées de la fenêtre.
 */
class GlassBlur : public QObject
{
    Q_OBJECT

public:
    explicit GlassBlur(QObject *parent = nullptr);

    /** Remplace les zones floutées de la fenêtre (liste vide : plus de flou). */
    Q_INVOKABLE void apply(QWindow *window, const QVariantList &rects);
    Q_INVOKABLE void clear(QWindow *window);
};
