#pragma once

#include <QQuickPaintedItem>

/**
 * La lumière de la bordure du Dock, dessinée d'un seul tenant.
 *
 * Pour chaque pixel du contour (le trait et la lueur qui s'étend vers
 * l'intérieur), l'intensité ne dépend que de la distance entre ce pixel et la
 * source de lumière (le pointeur) : la formule est donc strictement la même sur
 * les côtés droits, sur les angles et sur les extrémités arrondies. Une
 * seconde source, plus faible, se trouve au point opposé.
 *
 * Le composant couvre tout le fond du Dock ; seul le contour est dessiné.
 */
class BorderLight : public QQuickPaintedItem
{
    Q_OBJECT
    // Force maximale (0..1). 0 = rien n'est dessiné.
    Q_PROPERTY(qreal peak MEMBER m_peak NOTIFY changed)
    // Étendue de la lumière, en pixels.
    Q_PROPERTY(qreal lightRadius MEMBER m_lightRadius NOTIFY changed)
    // Position (dans le composant) des deux sources.
    Q_PROPERTY(qreal lightX1 MEMBER m_lightX1 NOTIFY changed)
    Q_PROPERTY(qreal lightY1 MEMBER m_lightY1 NOTIFY changed)
    Q_PROPERTY(qreal lightX2 MEMBER m_lightX2 NOTIFY changed)
    Q_PROPERTY(qreal lightY2 MEMBER m_lightY2 NOTIFY changed)
    Q_PROPERTY(qreal secondaryScale MEMBER m_secondaryScale NOTIFY changed)
    // Rayon des coins du Dock, épaisseur du trait, profondeur de la lueur
    // intérieure (pixels) et force de sa première rangée (0..1).
    Q_PROPERTY(qreal cornerRadius MEMBER m_cornerRadius NOTIFY changed)
    Q_PROPERTY(qreal lineWidth MEMBER m_lineWidth NOTIFY changed)
    Q_PROPERTY(qreal depth MEMBER m_depth NOTIFY changed)
    Q_PROPERTY(qreal glowScale MEMBER m_glowScale NOTIFY changed)

public:
    explicit BorderLight(QQuickItem *parent = nullptr);

    void paint(QPainter *painter) override;

Q_SIGNALS:
    void changed();

private:
    qreal m_peak = 0;
    qreal m_lightRadius = 140;
    qreal m_lightX1 = 0;
    qreal m_lightY1 = 0;
    qreal m_lightX2 = 0;
    qreal m_lightY2 = 0;
    qreal m_secondaryScale = 0.6;
    qreal m_cornerRadius = 12;
    qreal m_lineWidth = 1;
    qreal m_depth = 6;
    qreal m_glowScale = 0.55;
};
