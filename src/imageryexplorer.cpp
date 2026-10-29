#include "imageryexplorer.h"

#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QMap>
#include <QRegularExpression>
#include <QSet>
#include <QSqlError>
#include <QSqlQuery>
#include <QtMath>
#include <algorithm>
#include <utility>

ImageryExplorer::ImageryExplorer(const QSqlDatabase &database, const QString &dictionaryPath,
                                 QObject *parent)
    : QObject(parent), m_database(database), m_dictionaryPath(dictionaryPath)
{
    if (loadDictionary()) refresh();
}

bool ImageryExplorer::loadDictionary()
{
    QFile file(m_dictionaryPath.isEmpty() ? QStringLiteral(":/data/imagery.json") : m_dictionaryPath);
    if (!file.open(QIODevice::ReadOnly)) {
        m_error = QStringLiteral("意象词典无法读取：") + file.fileName();
        emit changed();
        return false;
    }
    QJsonParseError parseError;
    const QJsonDocument document = QJsonDocument::fromJson(file.readAll(), &parseError);
    if (parseError.error != QJsonParseError::NoError || !document.isArray()) {
        m_error = QStringLiteral("意象词典格式无效：") + parseError.errorString();
        emit changed();
        return false;
    }
    QSet<QString> seen;
    for (const QJsonValue &value : document.array()) {
        const QJsonObject entry = value.toObject();
        Term term;
        term.key = entry.value(QStringLiteral("key")).toString().trimmed();
        term.category = entry.value(QStringLiteral("category")).toString();
        term.description = entry.value(QStringLiteral("description")).toString();
        for (const QJsonValue &alias : entry.value(QStringLiteral("aliases")).toArray())
            if (!alias.toString().isEmpty()) term.aliases.append(alias.toString());
        for (const QJsonValue &excluded : entry.value(QStringLiteral("exclusions")).toArray())
            if (!excluded.toString().isEmpty()) term.exclusions.append(excluded.toString());
        if (term.key.isEmpty() || term.aliases.isEmpty() || seen.contains(term.key)) {
            m_error = QStringLiteral("意象词典含空词条或重复名称。");
            emit changed();
            return false;
        }
        seen.insert(term.key);
        m_terms.append(term);
        if (!m_categories.contains(term.category)) m_categories.append(term.category);
    }
    if (m_terms.isEmpty()) {
        m_error = QStringLiteral("意象词典为空。");
        emit changed();
        return false;
    }
    if (indexOf(m_center) < 0) m_center = m_terms.first().key;
    return true;
}

int ImageryExplorer::indexOf(const QString &key) const
{
    for (int i = 0; i < m_terms.size(); ++i)
        if (m_terms.at(i).key == key) return i;
    return -1;
}

bool ImageryExplorer::matches(const QString &text, const Term &term) const
{
    for (const QString &alias : term.aliases) {
        int from = 0;
        while ((from = text.indexOf(alias, from)) >= 0) {
            bool excluded = false;
            for (const QString &stop : term.exclusions) {
                int at = 0;
                while ((at = text.indexOf(stop, at)) >= 0) {
                    if (at <= from && at + stop.size() >= from + alias.size()) {
                        excluded = true;
                        break;
                    }
                    ++at;
                }
                if (excluded) break;
            }
            if (!excluded) return true;
            from += alias.size();
        }
    }
    return false;
}

void ImageryExplorer::refresh()
{
    m_allPoems.clear();
    m_dynasties = {QStringLiteral("全部朝代")};
    if (!m_database.isOpen()) {
        m_error = QStringLiteral("诗词数据库尚未打开。");
        rebuild();
        return;
    }
    QSqlQuery query(m_database);
    if (!query.exec(QStringLiteral("SELECT id, title, author, dynasty, content FROM poems ORDER BY id"))) {
        m_error = QStringLiteral("读取诗词失败：") + query.lastError().text();
        rebuild();
        return;
    }
    m_error.clear();
    while (query.next()) {
        Poem poem;
        poem.id = query.value(0).toInt();
        poem.title = query.value(1).toString();
        poem.author = query.value(2).toString();
        poem.dynasty = query.value(3).toString();
        poem.content = query.value(4).toString();
        if (!m_dynasties.contains(poem.dynasty)) m_dynasties.append(poem.dynasty);
        for (int i = 0; i < m_terms.size(); ++i)
            if (matches(poem.content, m_terms.at(i))) poem.matches.append(i);
        m_allPoems.append(poem);
    }
    rebuild();
}

QString ImageryExplorer::excerpt(const Poem &poem) const
{
    const QStringList lines = poem.content.split(QRegularExpression(QStringLiteral("[\n。！？]")), Qt::SkipEmptyParts);
    const int centerIndex = indexOf(m_center);
    const int pairIndex = indexOf(m_pair);
    QString centerLine, pairLine;
    for (const QString &line : lines) {
        if (centerIndex >= 0 && matches(line, m_terms.at(centerIndex))
            && (pairIndex < 0 || matches(line, m_terms.at(pairIndex))))
            return line.trimmed() + QStringLiteral("。 ");
        if (centerLine.isEmpty() && centerIndex >= 0 && matches(line, m_terms.at(centerIndex)))
            centerLine = line.trimmed();
        if (pairLine.isEmpty() && pairIndex >= 0 && matches(line, m_terms.at(pairIndex)))
            pairLine = line.trimmed();
    }
    if (!centerLine.isEmpty() && !pairLine.isEmpty())
        return centerLine + QStringLiteral("。") + pairLine + QStringLiteral("。");
    if (!centerLine.isEmpty()) return centerLine + QStringLiteral("。 ");
    return lines.isEmpty() ? QString() : lines.first().trimmed() + QStringLiteral("。 ");
}

QString ImageryExplorer::markedExcerpt(const QString &text) const
{
    struct Span { int start; int length; };
    QVector<Span> spans;
    for (const QString &key : {m_center, m_pair}) {
        const int termIndex = indexOf(key);
        if (termIndex < 0) continue;
        const Term &term = m_terms.at(termIndex);
        for (const QString &alias : term.aliases) {
            int at = 0;
            while ((at = text.indexOf(alias, at)) >= 0) {
                bool excluded = false;
                for (const QString &stop : term.exclusions) {
                    int pos = 0;
                    while ((pos = text.indexOf(stop, pos)) >= 0) {
                        if (pos <= at && pos + stop.size() >= at + alias.size()) { excluded = true; break; }
                        ++pos;
                    }
                    if (excluded) break;
                }
                if (!excluded) spans.append({at, int(alias.size())});
                at += alias.size();
            }
        }
    }
    std::sort(spans.begin(), spans.end(), [](const Span &a, const Span &b) {
        return a.start == b.start ? a.length > b.length : a.start < b.start;
    });
    QString result;
    int cursor = 0;
    for (const Span &span : spans) {
        if (span.start < cursor) continue;
        result += text.mid(cursor, span.start - cursor).toHtmlEscaped();
        result += QStringLiteral("<font color='#76572F'>")
                  + text.mid(span.start, span.length).toHtmlEscaped() + QStringLiteral("</font>");
        cursor = span.start + span.length;
    }
    return result + text.mid(cursor).toHtmlEscaped();
}

void ImageryExplorer::rebuild()
{
    m_items.clear(); m_nodes.clear(); m_edges.clear(); m_skyEdges.clear(); m_poems.clear();
    m_centerCount = 0; m_pairCount = 0; m_corpusCount = 0;
    const int centerIndex = indexOf(m_center);
    const int pairIndex = indexOf(m_pair);
    QVector<int> counts(m_terms.size());
    QVector<int> links(m_terms.size());
    for (const Poem &poem : m_allPoems) {
        if (!m_dynasty.isEmpty() && poem.dynasty != m_dynasty) continue;
        ++m_corpusCount;
        for (int i : poem.matches) ++counts[i];
        if (centerIndex >= 0 && poem.matches.contains(centerIndex)) {
            ++m_centerCount;
            for (int i : poem.matches) if (i != centerIndex) ++links[i];
            if (pairIndex < 0 || poem.matches.contains(pairIndex)) {
                QVariantMap row;
                row.insert(QStringLiteral("id"), poem.id);
                row.insert(QStringLiteral("title"), poem.title);
                row.insert(QStringLiteral("author"), poem.author);
                row.insert(QStringLiteral("dynasty"), poem.dynasty);
                row.insert(QStringLiteral("excerpt"), markedExcerpt(excerpt(poem)));
                m_poems.append(row);
            }
        }
    }
    m_pairCount = pairIndex < 0 ? 0 : m_poems.size();
    m_description = centerIndex < 0 ? QString() : m_terms.at(centerIndex).description;
    for (int i = 0; i < m_terms.size(); ++i) {
        if (counts[i] == 0) continue;
        const Term &term = m_terms.at(i);
        if (!m_category.isEmpty() && term.category != m_category) continue;
        if (!m_query.isEmpty() && !term.key.contains(m_query)
            && !std::any_of(term.aliases.cbegin(), term.aliases.cend(),
                            [this](const QString &alias) { return alias.contains(m_query); })) continue;
        m_items.append(QVariantMap{{QStringLiteral("key"), term.key},
                                  {QStringLiteral("category"), term.category},
                                  {QStringLiteral("count"), counts[i]},
                                  {QStringLiteral("linkCount"), links[i]}});
    }
    std::sort(m_items.begin(), m_items.end(), [](const QVariant &a, const QVariant &b) {
        return a.toMap().value(QStringLiteral("count")).toInt()
               > b.toMap().value(QStringLiteral("count")).toInt();
    });
    // A separate view of pair co-occurrences supplies the panoramic chart.
    // The archive counts, selected pair, and poem results above remain unchanged.
    QSet<int> visibleTerms;
    for (const QVariant &item : std::as_const(m_items))
        visibleTerms.insert(indexOf(item.toMap().value(QStringLiteral("key")).toString()));
    QMap<QPair<int, int>, int> pairCounts;
    for (const Poem &poem : std::as_const(m_allPoems)) {
        if (!m_dynasty.isEmpty() && poem.dynasty != m_dynasty) continue;
        for (int a = 0; a < poem.matches.size(); ++a) {
            const int first = poem.matches.at(a);
            if (!visibleTerms.contains(first)) continue;
            for (int b = a + 1; b < poem.matches.size(); ++b) {
                const int second = poem.matches.at(b);
                if (!visibleTerms.contains(second)) continue;
                pairCounts[qMakePair(qMin(first, second), qMax(first, second))]++;
            }
        }
    }
    struct SkyLink { int first; int second; int count; };
    QVector<SkyLink> skyLinks;
    for (auto it = pairCounts.cbegin(); it != pairCounts.cend(); ++it)
        skyLinks.append({it.key().first, it.key().second, it.value()});
    std::sort(skyLinks.begin(), skyLinks.end(), [](const SkyLink &a, const SkyLink &b) {
        if (a.count != b.count) return a.count > b.count;
        if (a.first != b.first) return a.first < b.first;
        return a.second < b.second;
    });
    QVector<int> skyDegree(m_terms.size());
    for (const SkyLink &link : std::as_const(skyLinks)) {
        if (m_skyEdges.size() >= 18) break;
        if (skyDegree[link.first] >= 3 || skyDegree[link.second] >= 3) continue;
        m_skyEdges.append(QVariantMap{{QStringLiteral("from"), m_terms.at(link.first).key},
                                     {QStringLiteral("to"), m_terms.at(link.second).key},
                                     {QStringLiteral("count"), link.count}});
        ++skyDegree[link.first];
        ++skyDegree[link.second];
    }
    if (centerIndex >= 0) {
        m_nodes.append(QVariantMap{{QStringLiteral("key"), m_center},
                                   {QStringLiteral("count"), m_centerCount},
                                   {QStringLiteral("linkCount"), 0},
                                   {QStringLiteral("x"), 0.5}, {QStringLiteral("y"), 0.5},
                                   {QStringLiteral("center"), true}});
        QVector<int> neighbors;
        for (int i = 0; i < links.size(); ++i)
            if (links[i] > 0 && (m_category.isEmpty() || m_terms.at(i).category == m_category))
                neighbors.append(i);
        std::sort(neighbors.begin(), neighbors.end(), [&](int a, int b) {
            return links[a] == links[b] ? counts[a] > counts[b] : links[a] > links[b];
        });
        const int shown = qMin(10, neighbors.size());
        for (int position = 0; position < shown; ++position) {
            const int i = neighbors.at(position);
            const double angle = -M_PI_2 + position * 2.0 * M_PI / shown;
            const double radius = position % 2 == 0 ? 0.36 : 0.42;
            const double x = 0.5 + radius * qCos(angle);
            const double y = 0.5 + radius * qSin(angle);
            m_nodes.append(QVariantMap{{QStringLiteral("key"), m_terms.at(i).key},
                                       {QStringLiteral("count"), counts[i]},
                                       {QStringLiteral("linkCount"), links[i]},
                                       {QStringLiteral("x"), x}, {QStringLiteral("y"), y},
                                       {QStringLiteral("center"), false}});
            m_edges.append(QVariantMap{{QStringLiteral("x1"), 0.5}, {QStringLiteral("y1"), 0.5},
                                       {QStringLiteral("x2"), x}, {QStringLiteral("y2"), y},
                                       {QStringLiteral("count"), links[i]},
                                       {QStringLiteral("key"), m_terms.at(i).key}});
        }
    }
    emit changed();
}

void ImageryExplorer::setCenter(const QString &key)
{
    if (indexOf(key) < 0) return;
    m_center = key;
    m_pair.clear();
    rebuild();
}

void ImageryExplorer::selectPair(const QString &key)
{
    if (key == m_center) { clearPair(); return; }
    if (indexOf(key) < 0) return;
    m_pair = key;
    rebuild();
}

void ImageryExplorer::clearPair()
{
    if (m_pair.isEmpty()) return;
    m_pair.clear();
    rebuild();
}

void ImageryExplorer::setDynasty(const QString &value)
{
    const QString next = value == QStringLiteral("全部朝代") ? QString() : value;
    if (m_dynasty == next) return;
    m_dynasty = next;
    rebuild();
}

void ImageryExplorer::setCategory(const QString &value)
{
    const QString next = value == QStringLiteral("全部意象") ? QString() : value;
    if (m_category == next) return;
    m_category = next;
    rebuild();
}

void ImageryExplorer::setQuery(const QString &value)
{
    const QString next = value.trimmed();
    if (m_query == next) return;
    m_query = next;
    rebuild();
}
