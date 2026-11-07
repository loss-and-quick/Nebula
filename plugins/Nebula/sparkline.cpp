#include "sparkline.h"

#include <QLinearGradient>
#include <QPainter>
#include <QPainterPath>
#include <QtMath>

#include <algorithm>
#include <cmath>

namespace {

QColor withAlpha(const QColor &c, qreal a)
{
    QColor out = c;
    out.setAlphaF(float(a));
    return out;
}

void canvasArcTo(QPainterPath &path, const QPointF &p1, const QPointF &p2, qreal r)
{
    const QPointF p0 = path.currentPosition();
    const QPointF v1 = p0 - p1;
    const QPointF v2 = p2 - p1;
    const qreal l1 = std::hypot(v1.x(), v1.y());
    const qreal l2 = std::hypot(v2.x(), v2.y());
    const qreal cross = v1.x() * v2.y() - v1.y() * v2.x();
    if (r <= 0 || l1 < 1e-9 || l2 < 1e-9 || std::abs(cross) < 1e-9 * l1 * l2) {
        path.lineTo(p1);
        return;
    }

    const QPointF u1 = v1 / l1;
    const QPointF u2 = v2 / l2;
    const qreal cosTheta = std::clamp(u1.x() * u2.x() + u1.y() * u2.y(), -1.0, 1.0);
    const qreal half = std::acos(cosTheta) / 2;
    const qreal d = r / std::tan(half);
    const QPointF t1 = p1 + u1 * d;
    const QPointF t2 = p1 + u2 * d;
    QPointF bis = u1 + u2;
    bis /= std::hypot(bis.x(), bis.y());
    const QPointF c = p1 + bis * (r / std::sin(half));

    auto angleOf = [&c](const QPointF &p) {
        return qRadiansToDegrees(std::atan2(-(p.y() - c.y()), p.x() - c.x()));
    };
    const qreal start = angleOf(t1);
    qreal sweep = angleOf(t2) - start;
    while (sweep > 180)
        sweep -= 360;
    while (sweep < -180)
        sweep += 360;

    path.lineTo(t1);
    path.arcTo(QRectF(c.x() - r, c.y() - r, 2 * r, 2 * r), start, sweep);
}

}

Sparkline::Sparkline(QQuickItem *parent)
    : QQuickPaintedItem(parent)
{
    setAntialiasing(true);
}

template <typename T>
void Sparkline::setStyle(T &field, const T &value)
{
    if (field == value)
        return;
    field = value;
    emit styleChanged();
    update();
}

void Sparkline::setValues(const QList<qreal> &values)
{
    const QList<qreal> trimmed = values.mid(qMax(0, int(values.size()) - qMax(0, m_maxPoints)));
    if (m_values == trimmed)
        return;
    m_values = trimmed;
    emit valuesChanged();
    update();
}

void Sparkline::setMaxPoints(int v)
{
    setStyle(m_maxPoints, qMax(0, v));
    setValues(m_values);
}
void Sparkline::setLineColor(const QColor &v) { setStyle(m_lineColor, v); }
void Sparkline::setAreaColor(const QColor &v) { setStyle(m_areaColor, v); }
void Sparkline::setLineWidth(qreal v) { setStyle(m_lineWidth, v); }
void Sparkline::setFilled(bool v) { setStyle(m_filled, v); }
void Sparkline::setMaxOverride(qreal v) { setStyle(m_maxOverride, v); }
void Sparkline::setCornerRadius(qreal v) { setStyle(m_cornerRadius, v); }
void Sparkline::setGradientFill(bool v) { setStyle(m_gradientFill, v); }
void Sparkline::setLogScale(bool v) { setStyle(m_logScale, v); }
void Sparkline::setBars(bool v) { setStyle(m_bars, v); }
void Sparkline::setBarWidth(qreal v) { setStyle(m_barWidth, v); }
void Sparkline::setBarGap(qreal v) { setStyle(m_barGap, v); }

qreal Sparkline::norm(qreal v, qreal maxVal) const
{
    if (m_logScale)
        return std::log1p(std::max(0.0, v)) / std::log1p(maxVal);
    return v / maxVal;
}

void Sparkline::paint(QPainter *painter)
{
    if (m_values.size() < 2)
        return;
    painter->setRenderHint(QPainter::Antialiasing, true);
    const qreal peak = *std::max_element(m_values.cbegin(), m_values.cend());
    const qreal maxVal = m_maxOverride > 0 ? m_maxOverride : std::max(peak, 1.0);
    if (m_bars)
        paintBars(painter, maxVal);
    else
        paintLine(painter, maxVal);
}

void Sparkline::paintBars(QPainter *painter, qreal maxVal)
{
    const qreal w = width();
    const qreal h = height();
    const qreal slot = m_barWidth + m_barGap;
    const int count = std::max(1, int(std::floor((w + m_barGap) / slot)));
    const int first = std::max(0, int(m_values.size()) - count);
    const int shown = int(m_values.size()) - first;

    painter->setPen(Qt::NoPen);
    for (int i = 0; i < shown; i++) {
        const qreal bh = std::max(2.0, norm(m_values.at(first + i), maxVal) * h * 0.95);
        const qreal x = w - (shown - i) * slot + m_barGap;
        painter->setBrush(i == shown - 1 ? m_lineColor : withAlpha(m_lineColor, 0.55));
        painter->drawRoundedRect(QRectF(x, h - bh, m_barWidth, bh), m_barWidth / 2, m_barWidth / 2);
    }
}

void Sparkline::paintLine(QPainter *painter, qreal maxVal)
{
    const qreal w = width();
    const qreal h = height();
    const int n = int(m_values.size());
    const qreal stepX = w / qreal(std::max(1, m_maxPoints - 1));
    const qreal offsetX = (m_maxPoints - n) * stepX;
    const qreal r = std::min(m_cornerRadius, stepX / 2);

    auto pt = [&](int i) {
        return QPointF(offsetX + i * stepX, h - norm(m_values.at(i), maxVal) * h * 0.9);
    };

    auto trace = [&](QPainterPath &path, bool move) {
        if (move)
            path.moveTo(pt(0));
        else
            path.lineTo(pt(0));
        for (int i = 1; i < n - 1; i++) {
            if (r > 0.01)
                canvasArcTo(path, pt(i), pt(i + 1), r);
            else
                path.lineTo(pt(i));
        }
        path.lineTo(pt(n - 1));
    };

    if (m_filled) {
        QPainterPath area;
        area.moveTo(pt(0).x(), h);
        trace(area, false);
        area.lineTo(pt(n - 1).x(), h);
        area.closeSubpath();
        painter->setPen(Qt::NoPen);
        if (m_gradientFill) {
            QLinearGradient g(0, 0, 0, h);
            g.setColorAt(0, withAlpha(m_lineColor, 0.2));
            g.setColorAt(1, withAlpha(m_lineColor, 0));
            painter->setBrush(g);
        } else {
            painter->setBrush(m_areaColor);
        }
        painter->drawPath(area);
    }

    QPainterPath line;
    trace(line, true);
    painter->setBrush(Qt::NoBrush);
    painter->setPen(QPen(m_lineColor, m_lineWidth, Qt::SolidLine, Qt::RoundCap, Qt::RoundJoin));
    painter->drawPath(line);
}
