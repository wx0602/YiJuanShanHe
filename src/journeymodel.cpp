#include "journeymodel.h"

#include <QFile>
#include <QHash>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonParseError>
#include <QSet>
#include <QSqlQuery>
#include <QtGlobal>
#include <algorithm>
#include <cmath>

namespace {
QJsonArray readArray(const QString &path, QString &error)
{
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly)) {
        error = QStringLiteral("无法读取行旅资料：") + file.errorString();
        return {};
    }
    QJsonParseError parseError;
    const QJsonDocument document = QJsonDocument::fromJson(file.readAll(), &parseError);
    if (parseError.error != QJsonParseError::NoError || !document.isArray()) {
        error = QStringLiteral("行旅资料 JSON 格式错误：") + parseError.errorString();
        return {};
    }
    return document.array();
}
}

JourneyModel::JourneyModel(const QString &poetsPath, const QString &journeysPath, QObject *parent)
    : QObject(parent)
{
    QString error;
    const QJsonArray poets = readArray(poetsPath, error);
    if (!error.isEmpty()) { setError(error); return; }
    const QJsonArray journeys = readArray(journeysPath, error);
    if (!error.isEmpty()) { setError(error); return; }

    QHash<QString, QJsonObject> profiles;
    for (const QJsonValue &value : poets) {
        const QJsonObject object = value.toObject();
        const QString id = object.value(QStringLiteral("id")).toString();
        if (!id.isEmpty()) profiles.insert(id, object);
    }
    QSet<QString> allStopIds;
    for (const QJsonValue &value : journeys) {
        const QJsonObject object = value.toObject();
        const QString id = object.value(QStringLiteral("poetId")).toString();
        if (id.isEmpty() || !profiles.contains(id)) {
            setError(QStringLiteral("行旅人物编号无法对应生平资料。"));
            m_journeys.clear(); return;
        }
        const QJsonObject profile = profiles.value(id);
        Journey journey;
        journey.id = id;
        journey.name = profile.value(QStringLiteral("name")).toString();
        journey.dynasty = profile.value(QStringLiteral("dynasty")).toString();
        journey.years = profile.value(QStringLiteral("years")).toString();
        journey.intro = profile.value(QStringLiteral("intro")).toString();
        journey.tone = profile.value(QStringLiteral("tone")).toString();
        journey.subtitle = object.value(QStringLiteral("subtitle")).toString();
        journey.stages = profile.value(QStringLiteral("stages")).toArray().toVariantList();
        const QJsonArray rawStops = object.value(QStringLiteral("stops")).toArray();
        for (const QJsonValue &stopValue : rawStops) {
            if (!stopValue.isObject()) continue;
            const QJsonObject stop = stopValue.toObject();
            const QString stopId = stop.value(QStringLiteral("id")).toString();
            const double lon = stop.value(QStringLiteral("lon")).toDouble();
            const double lat = stop.value(QStringLiteral("lat")).toDouble();
            const int year = stop.value(QStringLiteral("year")).toInt();
            const int stage = stop.value(QStringLiteral("stage")).toInt(-1);
            if (stopId.isEmpty() || allStopIds.contains(stopId)
                || stop.value(QStringLiteral("place")).toString().isEmpty()
                || stop.value(QStringLiteral("event")).toString().isEmpty()
                || stop.value(QStringLiteral("detail")).toString().isEmpty()
                || stop.value(QStringLiteral("source")).toString().isEmpty()
                || year <= 0 || lon < 70 || lon > 138 || lat < 16 || lat > 56
                || stage < 0 || stage >= journey.stages.size()) {
                setError(QStringLiteral("行旅站点资料无效或编号重复。"));
                m_journeys.clear(); return;
            }
            allStopIds.insert(stopId);
            journey.stops.append(stop.toVariantMap());
        }
        if (journey.stops.isEmpty()) {
            setError(QStringLiteral("人物缺少行旅站点。"));
            m_journeys.clear(); return;
        }
        std::stable_sort(journey.stops.begin(), journey.stops.end(), [](const QVariant &a, const QVariant &b) {
            return a.toMap().value(QStringLiteral("year")).toInt()
                < b.toMap().value(QStringLiteral("year")).toInt();
        });
        m_journeys.append(journey);
    }
    if (m_journeys.isEmpty()) {
        setError(QStringLiteral("没有可用的诗人行旅资料。"));
        return;
    }
    QFile readingsFile(QStringLiteral(":/data/journey-readings.json"));
    if (!readingsFile.open(QIODevice::ReadOnly)) {
        setError(QStringLiteral("无法读取行旅阶段诗笺。"));
        return;
    }
    QJsonParseError readingsError;
    const QJsonDocument readings = QJsonDocument::fromJson(readingsFile.readAll(), &readingsError);
    if (readingsError.error != QJsonParseError::NoError
        || (!readings.isArray() && !readings.isObject())) {
        setError(QStringLiteral("行旅阶段诗笺格式错误。"));
        return;
    }
    const QJsonArray readingArray = readings.isArray()
        ? readings.array()
        : readings.object().value(QStringLiteral("stationPoems")).toArray();
    for (const QJsonValue &value : readingArray) {
        if (!value.isObject()) continue;
        QVariantMap reading = value.toObject().toVariantMap();
        // The editable data now uses concise `poem` and `explanation` fields.
        // Keep the former field names available to the existing QML as well.
        if (reading.value(QStringLiteral("content")).toString().isEmpty())
            reading.insert(QStringLiteral("content"), reading.value(QStringLiteral("poem")));
        if (reading.value(QStringLiteral("context")).toString().isEmpty())
            reading.insert(QStringLiteral("context"), reading.value(QStringLiteral("explanation")));
        if (!reading.value(QStringLiteral("stopId")).toString().isEmpty()
            && !reading.value(QStringLiteral("title")).toString().isEmpty()
            && !reading.value(QStringLiteral("content")).toString().isEmpty())
            m_stationReadingLinks.append(reading);
    }
    m_selectedId = m_journeys.first().id;
    m_timer.setSingleShot(false);
    connect(&m_timer, &QTimer::timeout, this, &JourneyModel::next);
    updateTimer();
}

const JourneyModel::Journey *JourneyModel::selected() const
{
    for (const Journey &journey : m_journeys) {
        if (journey.id == m_selectedId) return &journey;
    }
    return nullptr;
}

QVariantList JourneyModel::poetOptions() const
{
    QVariantList result;
    for (const Journey &journey : m_journeys)
        result.append(QVariantMap{{QStringLiteral("id"), journey.id},
                                  {QStringLiteral("name"), journey.name},
                                  {QStringLiteral("dynasty"), journey.dynasty},
                                  {QStringLiteral("years"), journey.years},
                                  {QStringLiteral("tone"), journey.tone}});
    return result;
}

QString JourneyModel::selectedPoetId() const { return m_selectedId; }

QVariantMap JourneyModel::selectedPoet() const
{
    const Journey *journey = selected();
    if (!journey) return {};
    return {{QStringLiteral("id"), journey->id},
            {QStringLiteral("name"), journey->name},
            {QStringLiteral("dynasty"), journey->dynasty},
            {QStringLiteral("years"), journey->years},
            {QStringLiteral("intro"), journey->intro},
            {QStringLiteral("tone"), journey->tone},
            {QStringLiteral("subtitle"), journey->subtitle}};
}

QVariantList JourneyModel::stages() const { const Journey *j = selected(); return j ? j->stages : QVariantList{}; }
QVariantList JourneyModel::stops() const { const Journey *j = selected(); return j ? j->stops : QVariantList{}; }
int JourneyModel::stopCount() const { const Journey *j = selected(); return j ? j->stops.size() : 0; }
QVariantMap JourneyModel::currentStop() const
{
    const Journey *j = selected();
    return j && m_currentIndex >= 0 && m_currentIndex < j->stops.size()
        ? j->stops.at(m_currentIndex).toMap() : QVariantMap{};
}
int JourneyModel::activeStage() const { return currentStop().value(QStringLiteral("stage")).toInt(); }

void JourneyModel::setPoemDatabase(const QSqlDatabase &database)
{
    m_poemDatabase = database;
    emit positionChanged();
}

QVariantList JourneyModel::placeEvents() const
{
    QVariantList result;
    const Journey *journey = selected();
    if (!journey || m_currentIndex < 0 || m_currentIndex >= journey->stops.size()) return result;
    const QVariantMap current = journey->stops.at(m_currentIndex).toMap();
    const double lon = current.value(QStringLiteral("lon")).toDouble();
    const double lat = current.value(QStringLiteral("lat")).toDouble();
    for (int i = 0; i < journey->stops.size(); ++i) {
        QVariantMap stop = journey->stops.at(i).toMap();
        if (std::abs(stop.value(QStringLiteral("lon")).toDouble() - lon) > .025
            || std::abs(stop.value(QStringLiteral("lat")).toDouble() - lat) > .025) continue;
        stop.insert(QStringLiteral("index"), i);
        result.append(stop);
    }
    return result;
}

QVariantList JourneyModel::relatedPoems() const
{
    QVariantList result;
    if (!m_poemDatabase.isValid() || !m_poemDatabase.isOpen()) return result;
    const QString place = currentStop().value(QStringLiteral("place")).toString()
                              .section(QChar(0x00b7), 0, 0).trimmed();
    const QString author = selectedPoet().value(QStringLiteral("name")).toString();
    if (place.isEmpty() || author.isEmpty()) return result;
    QString escaped = place;
    escaped.replace(QStringLiteral("\\"), QStringLiteral("\\\\"));
    escaped.replace(QStringLiteral("%"), QStringLiteral("\\%"));
    escaped.replace(QStringLiteral("_"), QStringLiteral("\\_"));
    QSqlQuery query(m_poemDatabase);
    if (!query.prepare(QStringLiteral("SELECT id,title,author,dynasty FROM poems "
                                      "WHERE author=:author AND (title LIKE :title ESCAPE '\\' "
                                      "OR content LIKE :content ESCAPE '\\') ORDER BY id LIMIT 4"))) return result;
    query.bindValue(QStringLiteral(":author"), author);
    query.bindValue(QStringLiteral(":title"), QStringLiteral("%") + escaped + QStringLiteral("%"));
    query.bindValue(QStringLiteral(":content"), QStringLiteral("%") + escaped + QStringLiteral("%"));
    if (!query.exec()) return result;
    while (query.next())
        result.append(QVariantMap{{QStringLiteral("id"), query.value(0)},
                                  {QStringLiteral("title"), query.value(1)},
                                  {QStringLiteral("author"), query.value(2)},
                                  {QStringLiteral("dynasty"), query.value(3)}});
    return result;
}

QVariantMap JourneyModel::stagePoem() const
{
    const QVariantMap stop = currentStop();
    if (stop.isEmpty()) return {};

    for (const QVariant &value : m_stationReadingLinks) {
        QVariantMap link = value.toMap();
        if (link.value(QStringLiteral("stopId")).toString()
            != stop.value(QStringLiteral("id")).toString()) continue;
        const QString poetId = link.value(QStringLiteral("poetId")).toString();
        if (!poetId.isEmpty() && poetId != m_selectedId) continue;
        if (link.contains(QStringLiteral("stage"))
            && link.value(QStringLiteral("stage")).toInt() != activeStage()) continue;
        if (link.value(QStringLiteral("period")).toString().isEmpty())
            link.insert(QStringLiteral("period"), stop.value(QStringLiteral("date")));
        if (link.value(QStringLiteral("author")).toString().isEmpty())
            link.insert(QStringLiteral("author"), selectedPoet().value(QStringLiteral("name")));
        return link;
    }
    return {};
}

QVariantMap JourneyModel::cameraFor(double width, double height, bool overview,
                                    double usableFraction, int focusIndex) const
{
    const Journey *journey = selected();
    if (!journey || width <= 0 || height <= 0) return {};
    const double usableWidth = width * qBound(.50, usableFraction, 1.0);
    const double fit = std::min(width / 700.0, height / 400.0) * .96;
    double minX = 700, maxX = 0, minY = 400, maxY = 0;
    for (const QVariant &value : journey->stops) {
        const QVariantMap stop = value.toMap();
        const double x = (stop.value(QStringLiteral("lon")).toDouble() - 70.0) * 10.0;
        const double y = (56.0 - stop.value(QStringLiteral("lat")).toDouble()) * 10.0;
        minX = std::min(minX, x); maxX = std::max(maxX, x);
        minY = std::min(minY, y); maxY = std::max(maxY, y);
    }
    const double boundsWidth = std::max(95.0, maxX - minX + 56.0);
    const double boundsHeight = std::max(80.0, maxY - minY + 56.0);
    double routeZoom = std::min(usableWidth * .76 / boundsWidth,
                                height * .68 / boundsHeight);
    // Fill the atlas viewport when the route still fits comfortably. This
    // prevents the artwork's rectangular edge appearing beside short routes.
    const double cover = std::max(width / 700.0, height / 400.0) * 1.08;
    if (boundsWidth * cover <= usableWidth * .86 &&
        boundsHeight * cover <= height * .84)
        routeZoom = std::max(routeZoom, cover);
    const double zoom = overview ? fit : qBound(fit * 1.04, routeZoom, fit * 2.05);
    double targetX = (minX + maxX) / 2.0;
    double targetY = (minY + maxY) / 2.0;
    if (overview && focusIndex < 0) { targetX = 350; targetY = 200; }
    if (focusIndex >= 0 && focusIndex < journey->stops.size()) {
        const QVariantMap stop = journey->stops.at(focusIndex).toMap();
        targetX = (stop.value(QStringLiteral("lon")).toDouble() - 70.0) * 10.0;
        targetY = (56.0 - stop.value(QStringLiteral("lat")).toDouble()) * 10.0;
    }
    const double screenX = usableWidth * .50;
    const double screenY = height * .49;
    double originX = screenX - targetX * zoom;
    double originY = screenY - targetY * zoom;
    if (!overview || focusIndex >= 0) {
        originX = 700.0 * zoom >= usableWidth
            ? qBound(usableWidth - 700.0 * zoom, originX, 0.0)
            : (usableWidth - 700.0 * zoom) / 2.0;
        originY = 400.0 * zoom >= height
            ? qBound(height - 400.0 * zoom, originY, 0.0)
            : (height - 400.0 * zoom) / 2.0;
    }
    return {{QStringLiteral("zoom"), zoom},
            {QStringLiteral("panX"), originX - (width - 700.0 * zoom) / 2.0},
            {QStringLiteral("panY"), originY - (height - 400.0 * zoom) / 2.0}};
}

void JourneyModel::setError(const QString &message)
{
    if (m_error == message) return;
    m_error = message;
    emit errorChanged();
}

bool JourneyModel::selectPoet(const QString &id)
{
    for (const Journey &journey : m_journeys) {
        if (journey.id == id) {
            pause();
            m_selectedId = id;
            m_currentIndex = 0;
            emit poetChanged();
            emit positionChanged();
            return true;
        }
    }
    return false;
}

void JourneyModel::seek(int index)
{
    if (!selected() || stopCount() == 0) return;
    const int clamped = qBound(0, index, stopCount() - 1);
    if (m_currentIndex != clamped) {
        m_currentIndex = clamped;
        emit positionChanged();
    }
    if (m_currentIndex == stopCount() - 1) pause();
    else if (m_playing) m_timer.start();
}

void JourneyModel::next()
{
    if (m_currentIndex + 1 >= stopCount()) { pause(); return; }
    seek(m_currentIndex + 1);
}

void JourneyModel::seekStage(int stageIndex)
{
    const Journey *journey = selected();
    if (!journey || stageIndex < 0 || stageIndex >= journey->stages.size()) return;
    for (int i = 0; i < journey->stops.size(); ++i) {
        if (journey->stops.at(i).toMap().value(QStringLiteral("stage")).toInt() == stageIndex) {
            seek(i);
            return;
        }
    }
}

void JourneyModel::previous()
{
    seek(m_currentIndex - 1);
}

void JourneyModel::updateTimer()
{
    m_timer.setInterval(qRound(1750.0 / m_speed));
    if (m_playing) m_timer.start();
}

void JourneyModel::play()
{
    if (stopCount() <= 1) return;
    if (m_currentIndex == stopCount() - 1) seek(0);
    if (m_playing) return;
    m_playing = true;
    m_timer.start();
    emit playingChanged();
}

void JourneyModel::pause()
{
    if (!m_playing) return;
    m_playing = false;
    m_timer.stop();
    emit playingChanged();
}

void JourneyModel::restart()
{
    pause();
    seek(0);
    play();
}

void JourneyModel::setSpeed(double speed)
{
    if (!std::isfinite(speed)) return;
    const double clamped = qBound(0.5, speed, 3.0);
    if (qFuzzyCompare(m_speed, clamped)) return;
    m_speed = clamped;
    updateTimer();
    emit speedChanged();
}
