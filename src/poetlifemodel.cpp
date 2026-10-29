#include "poetlifemodel.h"

#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonParseError>
#include <QSet>
#include <algorithm>

namespace {
QVariantList sortedObjects(const QJsonArray &array, const QString &sortKey)
{
    QVariantList result;
    for (const QJsonValue &item : array) {
        if (item.isObject())
            result.append(item.toObject().toVariantMap());
    }
    std::stable_sort(result.begin(), result.end(), [&](const QVariant &left, const QVariant &right) {
        return left.toMap().value(sortKey).toInt() < right.toMap().value(sortKey).toInt();
    });
    return result;
}
}

PoetLifeModel::PoetLifeModel(const QString &jsonPath, QObject *parent)
    : QAbstractListModel(parent)
{
    QFile file(jsonPath);
    if (!file.open(QIODevice::ReadOnly)) {
        setError(QStringLiteral("无法读取独立的人物资料文件：") + file.errorString());
        return;
    }
    QJsonParseError parseError;
    const QJsonDocument document = QJsonDocument::fromJson(file.readAll(), &parseError);
    if (parseError.error != QJsonParseError::NoError || !document.isArray()) {
        setError(QStringLiteral("人物资料 JSON 格式错误：") + parseError.errorString());
        return;
    }
    QSet<QString> ids;
    for (const QJsonValue &value : document.array()) {
        if (!value.isObject())
            continue;
        const QJsonObject object = value.toObject();
        Poet poet;
        poet.id = object.value(QStringLiteral("id")).toString().trimmed();
        poet.name = object.value(QStringLiteral("name")).toString().trimmed();
        poet.dynasty = object.value(QStringLiteral("dynasty")).toString().trimmed();
        poet.years = object.value(QStringLiteral("years")).toString().trimmed();
        poet.birthYear = object.value(QStringLiteral("birthYear")).toInt();
        poet.deathYear = object.value(QStringLiteral("deathYear")).toInt();
        if (poet.id.isEmpty() || poet.name.isEmpty() || poet.dynasty.isEmpty()
            || poet.birthYear <= 0 || poet.deathYear < poet.birthYear || ids.contains(poet.id)) {
            setError(QStringLiteral("人物资料缺少必需字段、年份无效或编号重复。"));
            m_poets.clear();
            return;
        }
        ids.insert(poet.id);
        poet.epithet = object.value(QStringLiteral("epithet")).toString();
        poet.courtesy = object.value(QStringLiteral("courtesy")).toString();
        poet.tone = object.value(QStringLiteral("tone")).toString();
        poet.motto = object.value(QStringLiteral("motto")).toString();
        poet.intro = object.value(QStringLiteral("intro")).toString();
        poet.sources = object.value(QStringLiteral("sources")).toArray().toVariantList();
        poet.stages = sortedObjects(object.value(QStringLiteral("stages")).toArray(), QStringLiteral("start"));
        poet.events = sortedObjects(object.value(QStringLiteral("events")).toArray(), QStringLiteral("year"));
        m_poets.append(poet);
    }
    if (m_poets.isEmpty()) {
        setError(QStringLiteral("人物资料文件中没有有效档案。"));
        return;
    }
    m_selectedId = m_poets.first().id;
    m_compareA = m_poets.first().id;
    m_compareB = m_poets.size() > 1 ? m_poets.at(1).id : QString();
    search({});
}

int PoetLifeModel::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : m_visible.size();
}

QVariant PoetLifeModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_visible.size())
        return {};
    const Poet &poet = m_poets.at(m_visible.at(index.row()));
    switch (role) {
    case IdRole: return poet.id;
    case NameRole: return poet.name;
    case DynastyRole: return poet.dynasty;
    case YearsRole: return poet.years;
    case EpithetRole: return poet.epithet;
    case CourtesyRole: return poet.courtesy;
    case ToneRole: return poet.tone;
    default: return {};
    }
}

QHash<int, QByteArray> PoetLifeModel::roleNames() const
{
    return {{IdRole, "poetId"}, {NameRole, "poetName"},
            {DynastyRole, "poetDynasty"}, {YearsRole, "poetYears"},
            {EpithetRole, "poetEpithet"}, {CourtesyRole, "poetCourtesy"},
            {ToneRole, "poetTone"}};
}

const PoetLifeModel::Poet *PoetLifeModel::find(const QString &id) const
{
    for (const Poet &poet : m_poets) {
        if (poet.id == id)
            return &poet;
    }
    return nullptr;
}

QVariantMap PoetLifeModel::profile(const QString &id) const
{
    const Poet *poet = find(id);
    if (!poet)
        return {};
    return {{QStringLiteral("id"), poet->id}, {QStringLiteral("name"), poet->name},
            {QStringLiteral("dynasty"), poet->dynasty}, {QStringLiteral("years"), poet->years},
            {QStringLiteral("birthYear"), poet->birthYear}, {QStringLiteral("deathYear"), poet->deathYear},
            {QStringLiteral("epithet"), poet->epithet}, {QStringLiteral("courtesy"), poet->courtesy},
            {QStringLiteral("tone"), poet->tone}, {QStringLiteral("motto"), poet->motto},
            {QStringLiteral("intro"), poet->intro}, {QStringLiteral("sources"), poet->sources}};
}

QVariantList PoetLifeModel::stages(const QString &id) const
{
    const Poet *poet = find(id);
    return poet ? poet->stages : QVariantList{};
}

QVariantList PoetLifeModel::events(const QString &id) const
{
    const Poet *poet = find(id);
    return poet ? poet->events : QVariantList{};
}

QVariantMap PoetLifeModel::selectedProfile() const { return profile(m_selectedId); }
QVariantList PoetLifeModel::selectedStages() const { return stages(m_selectedId); }
QVariantList PoetLifeModel::selectedEvents() const { return events(m_selectedId); }
QVariantMap PoetLifeModel::compareAProfile() const { return profile(m_compareA); }
QVariantMap PoetLifeModel::compareBProfile() const { return profile(m_compareB); }
QVariantList PoetLifeModel::compareAStages() const { return stages(m_compareA); }
QVariantList PoetLifeModel::compareBStages() const { return stages(m_compareB); }
QVariantList PoetLifeModel::compareAEvents() const { return events(m_compareA); }
QVariantList PoetLifeModel::compareBEvents() const { return events(m_compareB); }

void PoetLifeModel::setError(const QString &message)
{
    if (m_error == message)
        return;
    m_error = message;
    emit errorChanged();
}

void PoetLifeModel::search(const QString &keyword)
{
    const QString needle = keyword.trimmed();
    beginResetModel();
    m_visible.clear();
    for (int i = 0; i < m_poets.size(); ++i) {
        const Poet &poet = m_poets.at(i);
        if (needle.isEmpty() || poet.name.contains(needle, Qt::CaseInsensitive)
            || poet.dynasty.contains(needle, Qt::CaseInsensitive)
            || poet.epithet.contains(needle, Qt::CaseInsensitive)
            || poet.courtesy.contains(needle, Qt::CaseInsensitive))
            m_visible.append(i);
    }
    endResetModel();
    emit resultsChanged();
}

bool PoetLifeModel::selectPoet(const QString &id)
{
    if (!find(id))
        return false;
    if (m_selectedId != id) {
        m_selectedId = id;
        emit selectionChanged();
    }
    return true;
}

bool PoetLifeModel::setComparison(int slot, const QString &id)
{
    if ((slot != 0 && slot != 1) || !find(id))
        return false;
    if ((slot == 0 && id == m_compareB) || (slot == 1 && id == m_compareA))
        return false;
    QString &target = slot == 0 ? m_compareA : m_compareB;
    if (target != id) {
        target = id;
        emit comparisonChanged();
    }
    return true;
}
