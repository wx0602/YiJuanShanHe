#include "shicicalendar.h"

#include <QFile>
#include <QRegularExpression>
#include <array>
#include <utility>

ShiciCalendar::ShiciCalendar(const QString &path, QObject *parent, const QDate &today)
    : QObject(parent), m_today(today.isValid() ? today : QDate::currentDate()),
      m_month(m_today.year(), m_today.month(), 1), m_selected(m_today)
{
    load(path);
    m_todayTimer.setInterval(30000);
    connect(&m_todayTimer, &QTimer::timeout, this, &ShiciCalendar::refreshToday);
    m_todayTimer.start();
}

void ShiciCalendar::load(const QString &path)
{
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly)) {
        m_error = QStringLiteral("无法读取 shici.txt：") + file.errorString();
        return;
    }
    QString source = QString::fromUtf8(file.readAll());
    if (source.startsWith(QChar(0xfeff))) source.remove(0, 1);
    source.replace(QStringLiteral("\r\n"), QStringLiteral("\n"));
    source.replace(QChar('\r'), QChar('\n'));
    const QStringList lines = source.split(QChar('\n'));
    const QRegularExpression header(QStringLiteral(R"(^\s*([0-9]{1,2})\s+(.+?)\s*｜\s*(.+?)\s*$)"));
    QVector<Poem> parsed;
    std::array<QStringList, 4> sections;
    int section = 0;
    auto finish = [&]() -> bool {
        if (parsed.isEmpty()) return true;
        QString results[4];
        for (int i = 0; i < 4; ++i) {
            while (!sections[i].isEmpty() && sections[i].first().trimmed().isEmpty()) sections[i].removeFirst();
            while (!sections[i].isEmpty() && sections[i].last().trimmed().isEmpty()) sections[i].removeLast();
            results[i] = sections[i].join(QChar('\n'));
            sections[i].clear();
            if (results[i].trimmed().isEmpty()) return false;
        }
        Poem &poem = parsed.last();
        poem.content = results[0];
        poem.annotation = results[1];
        poem.translation = results[2];
        poem.appreciation = results[3];
        return true;
    };
    for (const QString &line : lines) {
        const QRegularExpressionMatch match = header.match(line);
        if (match.hasMatch()) {
            if (!finish()) {
                m_error = QStringLiteral("shici.txt 中第 %1 首缺少正文或译注赏析。").arg(parsed.size());
                return;
            }
            const int number = match.captured(1).toInt();
            if (number != parsed.size() + 1 || match.captured(2).trimmed().isEmpty()
                || match.captured(3).trimmed().isEmpty()) {
                m_error = QStringLiteral("shici.txt 诗词编号、标题或署名格式有误（应连续编号 1～64）。");
                return;
            }
            parsed.append({match.captured(2).trimmed(), match.captured(3).trimmed(), {}, {}, {}, {}});
            section = 0;
        } else if (!parsed.isEmpty()) {
            const QString label = line.trimmed();
            int nextSection = 0;
            if (label == QStringLiteral("【注释】")) nextSection = 1;
            else if (label == QStringLiteral("【译文】")) nextSection = 2;
            else if (label == QStringLiteral("【赏析】")) nextSection = 3;
            if (nextSection) {
                if (nextSection != section + 1) {
                    m_error = QStringLiteral("shici.txt 中第 %1 首的译注分段顺序有误。").arg(parsed.size());
                    return;
                }
                section = nextSection;
            } else {
                sections[section].append(line);
            }
        } else if (!line.trimmed().isEmpty()) {
            m_error = QStringLiteral("shici.txt 开头存在无法识别的内容。");
            return;
        }
    }
    if (!finish()) {
        m_error = QStringLiteral("shici.txt 中第 %1 首缺少正文或译注赏析。").arg(parsed.size());
        return;
    }
    if (parsed.size() != 64) {
        m_error = QStringLiteral("shici.txt 应包含 64 首诗，实际解析到 %1 首。").arg(parsed.size());
        return;
    }
    m_poems = std::move(parsed);
}

const ShiciCalendar::Poem *ShiciCalendar::selectedPoem() const
{
    const int index = m_selected.day() - 1;
    return index >= 0 && index < m_poems.size() ? &m_poems.at(index) : nullptr;
}

QVariantMap ShiciCalendar::poemAt(int day) const
{
    const int index = day - 1;
    if (index < 0 || index >= m_poems.size()) return {};
    const Poem &poem = m_poems.at(index);
    return {{QStringLiteral("title"), poem.title},
            {QStringLiteral("attribution"), poem.attribution},
            {QStringLiteral("content"), poem.content},
            {QStringLiteral("annotation"), poem.annotation},
            {QStringLiteral("translation"), poem.translation},
            {QStringLiteral("appreciation"), poem.appreciation}};
}

QVariantList ShiciCalendar::days() const
{
    QVariantList result;
    const int blanks = m_month.dayOfWeek() - 1;
    for (int i = 0; i < blanks; ++i) result.append(0);
    for (int day = 1; day <= daysInMonth(); ++day) result.append(day);
    while (result.size() % 7) result.append(0);
    return result;
}

QString ShiciCalendar::monthLabel() const
{
    return QStringLiteral("%1 年 %2 月").arg(year()).arg(month(), 2, 10, QChar('0'));
}

QString ShiciCalendar::selectedDateLabel() const
{
    return QStringLiteral("%1 年 %2 月 %3 日").arg(m_selected.year())
        .arg(m_selected.month(), 2, 10, QChar('0'))
        .arg(m_selected.day(), 2, 10, QChar('0'));
}

QString ShiciCalendar::title() const { const Poem *p = selectedPoem(); return p ? p->title : QString(); }
QString ShiciCalendar::attribution() const { const Poem *p = selectedPoem(); return p ? p->attribution : QString(); }
QString ShiciCalendar::content() const { const Poem *p = selectedPoem(); return p ? p->content : QString(); }
QString ShiciCalendar::preview() const
{
    const Poem *p = selectedPoem();
    return p ? p->content.section(QChar('\n'), 0, 0) : QString();
}

void ShiciCalendar::shiftMonth(int offset)
{
    if (offset == 0) return;
    const QDate target = m_month.addMonths(offset);
    if (!target.isValid()) return;
    m_month = target;
    m_selected = QDate(year(), month(), qMin(m_selected.day(), daysInMonth()));
    m_userSelected = true;
    emit monthChanged();
    emit todayChanged();
    emit selectionChanged();
}

void ShiciCalendar::selectDay(int day)
{
    if (day < 1 || day > daysInMonth()) return;
    const QDate date(year(), month(), day);
    if (date == m_selected) return;
    m_selected = date;
    m_userSelected = true;
    emit selectionChanged();
}

void ShiciCalendar::goToday()
{
    m_userSelected = false;
    const QDate month(m_today.year(), m_today.month(), 1);
    if (month != m_month) { m_month = month; emit monthChanged(); emit todayChanged(); }
    if (m_selected != m_today) { m_selected = m_today; emit selectionChanged(); }
}

void ShiciCalendar::setTodayForTest(const QDate &today)
{
    if (!today.isValid() || today == m_today) return;
    m_today = today;
    emit todayChanged();
    if (!m_userSelected) goToday();
}

void ShiciCalendar::refreshToday()
{
    setTodayForTest(QDate::currentDate());
}
