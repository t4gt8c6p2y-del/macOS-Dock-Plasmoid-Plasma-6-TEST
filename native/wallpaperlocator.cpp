#include "wallpaperlocator.h"

#include <QColor>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QHash>
#include <QImageReader>
#include <QRegularExpression>
#include <QSize>
#include <QStandardPaths>
#include <QStringList>
#include <QTextStream>
#include <QUrl>
#include <QVariant>

#include <algorithm>
#include <cmath>

namespace
{
// Les paquets de fonds d'écran Plasma contiennent plusieurs tailles
// (contents/images/1920x1080.jpg …) : on prend la plus grande.
QString imageInDirectory(const QString &directoryPath)
{
    const QStringList filters{QStringLiteral("*.png"),
                              QStringLiteral("*.jpg"),
                              QStringLiteral("*.jpeg"),
                              QStringLiteral("*.webp"),
                              QStringLiteral("*.avif"),
                              QStringLiteral("*.bmp")};
    const QStringList directories{directoryPath + QStringLiteral("/contents/images"), directoryPath};
    const QRegularExpression sizePattern(QStringLiteral("^(\\d+)x(\\d+)"));

    for (const QString &directory : directories) {
        const QDir dir(directory);
        const QFileInfoList files = dir.entryInfoList(filters, QDir::Files, QDir::Name);
        QString best;
        qint64 bestArea = -1;
        for (const QFileInfo &file : files) {
            qint64 area = 0;
            const QRegularExpressionMatch match = sizePattern.match(file.completeBaseName());
            if (match.hasMatch()) {
                area = match.captured(1).toLongLong() * match.captured(2).toLongLong();
            }
            if (area > bestArea) {
                bestArea = area;
                best = file.absoluteFilePath();
            }
        }
        if (!best.isEmpty()) {
            return best;
        }
    }
    return QString();
}
}

WallpaperLocator::WallpaperLocator(QObject *parent)
    : QObject(parent)
{
}

QVariantMap WallpaperLocator::currentWallpaper(int screenIndex) const
{
    QVariantMap result;

    const QString configPath = QStandardPaths::locate(QStandardPaths::GenericConfigLocation,
                                                      QStringLiteral("plasma-org.kde.plasma.desktop-appletsrc"));
    if (configPath.isEmpty()) {
        return result;
    }
    QFile file(configPath);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        return result;
    }

    const QRegularExpression containmentPattern(QStringLiteral("^\\[Containments\\]\\[(\\d+)\\]$"));
    const QRegularExpression wallpaperPattern(
        QStringLiteral("^\\[Containments\\]\\[(\\d+)\\]\\[Wallpaper\\]\\[[^\\]]+\\]\\[General\\]$"));

    QHash<QString, QString> images;
    QHash<QString, QString> fillModes;
    QHash<QString, int> screens;
    QHash<QString, QString> plugins;

    QTextStream in(&file);
    QString section;
    while (!in.atEnd()) {
        const QString line = in.readLine().trimmed();
        if (line.startsWith(QLatin1Char('['))) {
            section = line;
            continue;
        }
        const int equals = line.indexOf(QLatin1Char('='));
        if (equals <= 0) {
            continue;
        }
        const QString key = line.left(equals).trimmed();
        const QString value = line.mid(equals + 1).trimmed();

        QRegularExpressionMatch match = containmentPattern.match(section);
        if (match.hasMatch()) {
            const QString id = match.captured(1);
            if (key == QLatin1String("lastScreen")) {
                screens.insert(id, value.toInt());
            } else if (key == QLatin1String("plugin")) {
                plugins.insert(id, value);
            }
            continue;
        }
        match = wallpaperPattern.match(section);
        if (match.hasMatch()) {
            const QString id = match.captured(1);
            if (key == QLatin1String("Image")) {
                images.insert(id, value);
            } else if (key == QLatin1String("FillMode")) {
                fillModes.insert(id, value);
            }
        }
    }

    QString chosenId;
    for (auto it = images.constBegin(); it != images.constEnd(); ++it) {
        const QString &id = it.key();
        if (plugins.value(id).contains(QLatin1String("panel"))) {
            continue;
        }
        if (screens.contains(id) && screens.value(id) == screenIndex) {
            chosenId = id;
            break;
        }
        if (chosenId.isEmpty()) {
            chosenId = id;
        }
    }
    if (chosenId.isEmpty()) {
        return result;
    }

    const QString value = images.value(chosenId);
    QString localPath;
    if (value.startsWith(QLatin1String("file://"))) {
        localPath = QUrl(value).toLocalFile();
    } else if (!value.contains(QLatin1String("://"))) {
        localPath = value;
    } else {
        return result;
    }

    const QFileInfo info(localPath);
    if (info.isDir()) {
        localPath = imageInDirectory(info.absoluteFilePath());
    }
    if (localPath.isEmpty() || !QFileInfo::exists(localPath)) {
        return result;
    }

    bool fillOk = false;
    int fillMode = fillModes.value(chosenId).toInt(&fillOk);
    if (!fillOk) {
        fillMode = 2;
    }

    result.insert(QStringLiteral("source"), QUrl::fromLocalFile(localPath).toString());
    result.insert(QStringLiteral("fillMode"), fillMode);
    return result;
}

QImage WallpaperLocator::loadImage(const QString &path)
{
    const QFileInfo info(path);
    if (!info.exists()) {
        return QImage();
    }
    if (path == m_cachePath && info.lastModified() == m_cacheStamp && !m_cache.isNull()) {
        return m_cache;
    }

    QImageReader reader(path);
    const QSize size = reader.size();
    if (size.isValid() && size.width() > 640) {
        const int height = std::max(1, int(std::lround(640.0 * size.height() / size.width())));
        reader.setScaledSize(QSize(640, height));
    }
    const QImage image = reader.read();
    m_cachePath = path;
    m_cacheStamp = info.lastModified();
    m_cache = image;
    return image;
}

QVariantList WallpaperLocator::sampleColors(const QString &source,
                                            int fillMode,
                                            qreal screenWidth,
                                            qreal screenHeight,
                                            qreal x,
                                            qreal y,
                                            qreal w,
                                            qreal h,
                                            int columns,
                                            int rows)
{
    QVariantList colors;
    if (columns < 1 || rows < 1 || screenWidth < 1 || screenHeight < 1 || w <= 0 || h <= 0) {
        return colors;
    }

    QString path = source;
    if (path.startsWith(QLatin1String("file://"))) {
        path = QUrl(path).toLocalFile();
    }
    const QImage image = loadImage(path);
    if (image.isNull()) {
        return colors;
    }

    const qreal imageWidth = image.width();
    const qreal imageHeight = image.height();

    // Position de l'image à l'écran selon le mode de remplissage.
    qreal scaleX = screenWidth / imageWidth;
    qreal scaleY = screenHeight / imageHeight;
    if (fillMode == 1) {
        scaleX = scaleY = std::min(scaleX, scaleY);
    } else if (fillMode != 0) {
        scaleX = scaleY = std::max(scaleX, scaleY);
    }
    const qreal offsetX = (screenWidth - imageWidth * scaleX) / 2;
    const qreal offsetY = (screenHeight - imageHeight * scaleY) / 2;

    const int taps = 3;
    for (int row = 0; row < rows; ++row) {
        for (int column = 0; column < columns; ++column) {
            qreal red = 0;
            qreal green = 0;
            qreal blue = 0;
            int count = 0;
            for (int ty = 0; ty < taps; ++ty) {
                for (int tx = 0; tx < taps; ++tx) {
                    const qreal screenX = x + w * (column + (tx + 0.5) / taps) / columns;
                    const qreal screenY = y + h * (row + (ty + 0.5) / taps) / rows;
                    const int imageX = std::clamp(int((screenX - offsetX) / scaleX), 0, image.width() - 1);
                    const int imageY = std::clamp(int((screenY - offsetY) / scaleY), 0, image.height() - 1);
                    const QColor pixel = image.pixelColor(imageX, imageY);
                    red += pixel.redF();
                    green += pixel.greenF();
                    blue += pixel.blueF();
                    ++count;
                }
            }
            colors.append(QVariant::fromValue(QColor::fromRgbF(red / count, green / count, blue / count)));
        }
    }
    return colors;
}
