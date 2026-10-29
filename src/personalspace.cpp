#include "personalspace.h"

#include <QDate>
#include <QDateTime>
#include <QMap>
#include <QSqlError>
#include <QSqlQuery>

namespace {
QString databaseError(const QString &action, const QSqlQuery &query)
{
    return action + QStringLiteral("：") + query.lastError().text();
}

int scalar(const QSqlDatabase &database, const QString &sql, bool *okay)
{
    QSqlQuery query(database);
    if (!query.exec(sql) || !query.next()) {
        *okay = false;
        return 0;
    }
    return query.value(0).toInt();
}
}

PersonalSpace::PersonalSpace(const QSqlDatabase &database, QObject *parent)
    : QObject(parent), m_database(database)
{
    if (!m_database.isOpen()) {
        setError(QStringLiteral("个人数据数据库尚未打开。"));
        return;
    }
    if (ensureSchema() && loadSettings()) refresh();
}

void PersonalSpace::setError(const QString &message)
{
    if (m_error == message) return;
    m_error = message;
    emit errorChanged();
}

bool PersonalSpace::ensureSchema()
{
    QSqlQuery query(m_database);
    if (!query.exec(QStringLiteral("CREATE TABLE IF NOT EXISTS personal_settings("
                                   "key TEXT PRIMARY KEY,value TEXT NOT NULL)"))) {
        setError(databaseError(QStringLiteral("初始化偏好设置失败"), query));
        return false;
    }
    return true;
}

bool PersonalSpace::loadSettings()
{
    QSqlQuery query(m_database);
    if (!query.exec(QStringLiteral("SELECT key,value FROM personal_settings"))) {
        setError(databaseError(QStringLiteral("读取偏好设置失败"), query));
        return false;
    }
    bool migrateTheme = false;
    while (query.next()) {
        const QString key = query.value(0).toString();
        const QString value = query.value(1).toString();
        if (key == QStringLiteral("nickname") && !value.trimmed().isEmpty()) m_nickname = value;
        else if (key == QStringLiteral("avatar") && QStringList{QStringLiteral("山"), QStringLiteral("月"), QStringLiteral("竹"), QStringLiteral("鹤")}.contains(value)) m_avatar = value;
        else if (key == QStringLiteral("reading_font_size")) m_readingFontSize = qBound(18, value.toInt(), 32);
        else if (key == QStringLiteral("animations_enabled")) m_animationsEnabled = value == QStringLiteral("1");
        else if (key == QStringLiteral("theme")) {
            m_theme = value == QStringLiteral("烟青") ? value : QStringLiteral("月白");
            migrateTheme = value != m_theme;
        }
    }
    query.finish();
    if (migrateTheme) {
        QSqlQuery migration(m_database);
        migration.prepare(QStringLiteral("UPDATE personal_settings SET value=? WHERE key='theme'"));
        migration.addBindValue(m_theme);
        if (!migration.exec()) {
            setError(databaseError(QStringLiteral("更新旧版主题设置失败"), migration));
            return false;
        }
    }
    emit settingsChanged();
    return true;
}

QString PersonalSpace::localDate(const QString &timestamp)
{
    QDateTime time = QDateTime::fromString(timestamp, Qt::ISODateWithMs);
    if (!time.isValid()) time = QDateTime::fromString(timestamp, Qt::ISODate);
    return time.isValid() ? time.toLocalTime().toString(QStringLiteral("yyyy-MM-dd"))
                          : timestamp.left(10);
}

QString PersonalSpace::modeTitle(const QString &mode)
{
    if (mode == QStringLiteral("feihua")) return QStringLiteral("飞花令");
    if (mode == QStringLiteral("puzzle")) return QStringLiteral("残卷修复");
    if (mode == QStringLiteral("fill")) return QStringLiteral("诗句填空");
    if (mode == QStringLiteral("chain")) return QStringLiteral("诗词接龙");
    if (mode == QStringLiteral("quiz")) return QStringLiteral("知识挑战");
    return QStringLiteral("错题重练");
}

bool PersonalSpace::loadStats()
{
    bool okay = true;
    const int favorites = scalar(m_database, QStringLiteral("SELECT COUNT(*) FROM favorites"), &okay);
    const int notes = scalar(m_database, QStringLiteral("SELECT COUNT(*) FROM notes"), &okay);
    const int read = scalar(m_database, QStringLiteral("SELECT COUNT(*) FROM reading_history"), &okay);
    const int attempts = scalar(m_database, QStringLiteral("SELECT COUNT(*) FROM interaction_attempts"), &okay);
    const int correct = scalar(m_database, QStringLiteral("SELECT COUNT(*) FROM interaction_attempts WHERE correct=1"), &okay);
    if (!okay) {
        setError(QStringLiteral("读取个人统计失败，请检查本地数据库。"));
        return false;
    }
    m_stats = {{QStringLiteral("favorites"), favorites}, {QStringLiteral("notes"), notes},
               {QStringLiteral("read"), read}, {QStringLiteral("attempts"), attempts},
               {QStringLiteral("accuracy"), attempts ? qRound(100.0 * correct / attempts) : 0}};
    return true;
}

bool PersonalSpace::loadFavorites()
{
    QString sql = QStringLiteral("SELECT p.id,p.title,p.author,p.dynasty,p.excerpt,f.created_at "
                                 "FROM favorites f JOIN poems p ON p.id=f.poem_id WHERE 1=1");
    QVariantList values;
    if (!m_favoriteKeyword.isEmpty()) {
        sql += QStringLiteral(" AND (instr(lower(p.title),lower(?))>0 OR instr(lower(p.author),lower(?))>0)");
        values << m_favoriteKeyword << m_favoriteKeyword;
    }
    sql += m_favoriteSort == QStringLiteral("title") ? QStringLiteral(" ORDER BY p.title COLLATE NOCASE,p.id")
           : m_favoriteSort == QStringLiteral("author") ? QStringLiteral(" ORDER BY p.author COLLATE NOCASE,p.id")
           : QStringLiteral(" ORDER BY f.created_at DESC,p.id DESC");
    QSqlQuery query(m_database);
    if (!query.prepare(sql)) { setError(databaseError(QStringLiteral("准备收藏查询失败"), query)); return false; }
    for (const QVariant &value : values) query.addBindValue(value);
    if (!query.exec()) { setError(databaseError(QStringLiteral("读取收藏失败"), query)); return false; }
    QVariantList rows;
    while (query.next())
        rows.append(QVariantMap{{QStringLiteral("id"), query.value(0).toInt()},
                                {QStringLiteral("title"), query.value(1).toString()},
                                {QStringLiteral("author"), query.value(2).toString()},
                                {QStringLiteral("dynasty"), query.value(3).toString()},
                                {QStringLiteral("excerpt"), query.value(4).toString()},
                                {QStringLiteral("date"), localDate(query.value(5).toString())}});
    m_favorites = rows;
    return true;
}

bool PersonalSpace::loadNotes()
{
    QSqlQuery authors(m_database);
    if (!authors.exec(QStringLiteral("SELECT DISTINCT p.author FROM notes n JOIN poems p ON p.id=n.poem_id "
                                      "ORDER BY p.author COLLATE NOCASE"))) {
        setError(databaseError(QStringLiteral("读取笔记诗人失败"), authors)); return false;
    }
    m_authors = {QStringLiteral("全部诗人")};
    while (authors.next()) m_authors.append(authors.value(0).toString());

    QString sql = QStringLiteral("SELECT p.id,p.title,p.author,p.dynasty,n.body,n.updated_at "
                                 "FROM notes n JOIN poems p ON p.id=n.poem_id WHERE 1=1");
    if (!m_noteAuthor.isEmpty() && m_noteAuthor != QStringLiteral("全部诗人"))
        sql += QStringLiteral(" AND p.author=?");
    sql += m_noteSort == QStringLiteral("oldest") ? QStringLiteral(" ORDER BY n.updated_at,p.id")
           : m_noteSort == QStringLiteral("author") ? QStringLiteral(" ORDER BY p.author COLLATE NOCASE,n.updated_at DESC")
           : QStringLiteral(" ORDER BY n.updated_at DESC,p.id DESC");
    QSqlQuery query(m_database);
    if (!query.prepare(sql)) { setError(databaseError(QStringLiteral("准备笔记查询失败"), query)); return false; }
    if (!m_noteAuthor.isEmpty() && m_noteAuthor != QStringLiteral("全部诗人")) query.addBindValue(m_noteAuthor);
    if (!query.exec()) { setError(databaseError(QStringLiteral("读取笔记失败"), query)); return false; }
    QVariantList rows;
    while (query.next())
        rows.append(QVariantMap{{QStringLiteral("id"), query.value(0).toInt()},
                                {QStringLiteral("title"), query.value(1).toString()},
                                {QStringLiteral("author"), query.value(2).toString()},
                                {QStringLiteral("dynasty"), query.value(3).toString()},
                                {QStringLiteral("body"), query.value(4).toString()},
                                {QStringLiteral("date"), localDate(query.value(5).toString())}});
    m_notes = rows;
    return true;
}

bool PersonalSpace::loadHistory()
{
    QSqlQuery query(m_database);
    if (!query.exec(QStringLiteral("SELECT p.id,p.title,p.author,p.dynasty,h.last_read_at,h.read_count "
                                   "FROM reading_history h JOIN poems p ON p.id=h.poem_id "
                                   "ORDER BY h.last_read_at DESC,p.id DESC"))) {
        setError(databaseError(QStringLiteral("读取阅读足迹失败"), query)); return false;
    }
    QVariantList rows;
    while (query.next()) {
        const QString timestamp = query.value(4).toString();
        const QString date = localDate(timestamp);
        if (!m_historyDate.isEmpty() && m_historyDate != date) continue;
        QDateTime time = QDateTime::fromString(timestamp, Qt::ISODateWithMs);
        rows.append(QVariantMap{{QStringLiteral("id"), query.value(0).toInt()},
                                {QStringLiteral("title"), query.value(1).toString()},
                                {QStringLiteral("author"), query.value(2).toString()},
                                {QStringLiteral("dynasty"), query.value(3).toString()},
                                {QStringLiteral("date"), date},
                                {QStringLiteral("time"), time.isValid() ? time.toLocalTime().toString(QStringLiteral("HH:mm")) : QString()},
                                {QStringLiteral("count"), query.value(5).toInt()}});
    }
    m_history = rows;
    return true;
}

bool PersonalSpace::loadLearning()
{
    QMap<QString, QVariantMap> modes;
    for (const QString &name : {QStringLiteral("feihua"), QStringLiteral("chain"), QStringLiteral("puzzle")})
        modes.insert(name, {{QStringLiteral("key"), name}, {QStringLiteral("title"), modeTitle(name)},
                            {QStringLiteral("attempts"), 0}, {QStringLiteral("correct"), 0},
                            {QStringLiteral("accuracy"), 0}, {QStringLiteral("best"), 0}});
    QSqlQuery query(m_database);
    if (!query.exec(QStringLiteral("SELECT mode,COUNT(*),COALESCE(SUM(correct),0) "
                                   "FROM interaction_attempts GROUP BY mode"))) {
        setError(databaseError(QStringLiteral("读取学习成绩失败"), query)); return false;
    }
    while (query.next()) {
        const QString mode = query.value(0).toString();
        if (!modes.contains(mode)) continue;
        QVariantMap row = modes.value(mode);
        const int attempts = query.value(1).toInt();
        const int correct = query.value(2).toInt();
        row[QStringLiteral("attempts")] = attempts;
        row[QStringLiteral("correct")] = correct;
        row[QStringLiteral("accuracy")] = attempts ? qRound(100.0 * correct / attempts) : 0;
        modes[mode] = row;
    }
    if (!query.exec(QStringLiteral("SELECT mode,MAX(score) FROM interaction_rounds GROUP BY mode"))) {
        setError(databaseError(QStringLiteral("读取最高成绩失败"), query)); return false;
    }
    while (query.next()) {
        const QString mode = query.value(0).toString();
        if (!modes.contains(mode)) continue;
        QVariantMap row = modes.value(mode);
        row[QStringLiteral("best")] = query.value(1).toInt();
        modes[mode] = row;
    }
    m_modes = {modes.value(QStringLiteral("feihua")), modes.value(QStringLiteral("chain")),
               modes.value(QStringLiteral("puzzle"))};

    QMap<QString, QPair<int, int>> byDate;
    if (!query.exec(QStringLiteral("SELECT created_at,correct FROM interaction_attempts ORDER BY id"))) {
        setError(databaseError(QStringLiteral("读取学习趋势失败"), query)); return false;
    }
    while (query.next()) {
        auto &day = byDate[localDate(query.value(0).toString())];
        ++day.first;
        day.second += query.value(1).toInt();
    }
    m_trend.clear();
    for (int offset = 6; offset >= 0; --offset) {
        const QString date = QDate::currentDate().addDays(-offset).toString(QStringLiteral("yyyy-MM-dd"));
        m_trend.append(QVariantMap{{QStringLiteral("date"), date},
                                   {QStringLiteral("attempts"), byDate.value(date).first},
                                   {QStringLiteral("correct"), byDate.value(date).second}});
    }

    if (!query.exec(QStringLiteral("SELECT mode,question_count,correct_count,score,finished_at "
                                   "FROM interaction_rounds ORDER BY id DESC"))) {
        setError(databaseError(QStringLiteral("读取挑战记录失败"), query)); return false;
    }
    m_rounds.clear();
    while (query.next())
        m_rounds.append(QVariantMap{{QStringLiteral("mode"), modeTitle(query.value(0).toString())},
                                    {QStringLiteral("count"), query.value(1).toInt()},
                                    {QStringLiteral("correct"), query.value(2).toInt()},
                                    {QStringLiteral("score"), query.value(3).toInt()},
                                    {QStringLiteral("date"), localDate(query.value(4).toString())}});

    if (!query.exec(QStringLiteral("SELECT m.mode,m.prompt,m.answer,m.wrong_count,p.title "
                                   "FROM interaction_mistakes m LEFT JOIN poems p ON p.id=m.poem_id "
                                   "WHERE m.resolved=0 AND m.mode IN ('feihua','chain','puzzle') "
                                   "ORDER BY m.last_wrong_at DESC"))) {
        setError(databaseError(QStringLiteral("读取错题失败"), query)); return false;
    }
    m_mistakes.clear();
    while (query.next())
        m_mistakes.append(QVariantMap{{QStringLiteral("mode"), modeTitle(query.value(0).toString())},
                                      {QStringLiteral("prompt"), query.value(1).toString()},
                                      {QStringLiteral("answer"), query.value(2).toString()},
                                      {QStringLiteral("count"), query.value(3).toInt()},
                                      {QStringLiteral("title"), query.value(4).toString()}});
    return true;
}

void PersonalSpace::refresh()
{
    if (!m_database.isOpen()) { setError(QStringLiteral("个人数据数据库尚未打开。")); return; }
    if (!loadStats() || !loadFavorites() || !loadNotes() || !loadHistory() || !loadLearning()) return;
    setError({});
    emit dataChanged();
}

void PersonalSpace::setFavoriteQuery(const QString &keyword, const QString &sort)
{
    m_favoriteKeyword = keyword.trimmed();
    m_favoriteSort = sort;
    refresh();
}

void PersonalSpace::setNoteQuery(const QString &author, const QString &sort)
{
    m_noteAuthor = author;
    m_noteSort = sort;
    refresh();
}

void PersonalSpace::setHistoryDate(const QString &date)
{
    if (!date.isEmpty() && QDate::fromString(date, QStringLiteral("yyyy-MM-dd")).toString(QStringLiteral("yyyy-MM-dd")) != date) {
        setError(QStringLiteral("日期格式应为 yyyy-MM-dd。")); return;
    }
    m_historyDate = date;
    refresh();
}

bool PersonalSpace::removeFavorite(int poemId)
{
    QSqlQuery query(m_database);
    query.prepare(QStringLiteral("DELETE FROM favorites WHERE poem_id=?"));
    query.addBindValue(poemId);
    if (!query.exec()) { setError(databaseError(QStringLiteral("取消收藏失败"), query)); return false; }
    refresh();
    emit libraryChanged();
    return true;
}

bool PersonalSpace::saveNote(int poemId, const QString &body)
{
    if (body.trimmed().isEmpty()) { setError(QStringLiteral("笔记内容不能为空；如需删除，请使用删除按钮。")); return false; }
    QSqlQuery query(m_database);
    query.prepare(QStringLiteral("INSERT INTO notes(poem_id,body,updated_at) VALUES(?,?,?) "
                                 "ON CONFLICT(poem_id) DO UPDATE SET body=excluded.body,updated_at=excluded.updated_at"));
    query.addBindValue(poemId); query.addBindValue(body);
    query.addBindValue(QDateTime::currentDateTimeUtc().toString(Qt::ISODateWithMs));
    if (!query.exec()) { setError(databaseError(QStringLiteral("保存笔记失败"), query)); return false; }
    refresh();
    emit libraryChanged();
    return true;
}

bool PersonalSpace::deleteNote(int poemId)
{
    QSqlQuery query(m_database);
    query.prepare(QStringLiteral("DELETE FROM notes WHERE poem_id=?"));
    query.addBindValue(poemId);
    if (!query.exec()) { setError(databaseError(QStringLiteral("删除笔记失败"), query)); return false; }
    refresh();
    emit libraryChanged();
    return true;
}

bool PersonalSpace::clearHistory()
{
    QSqlQuery query(m_database);
    if (!query.exec(QStringLiteral("DELETE FROM reading_history"))) {
        setError(databaseError(QStringLiteral("清除阅读足迹失败"), query)); return false;
    }
    refresh();
    return true;
}

bool PersonalSpace::saveSettings(const QString &nickname, const QString &avatar,
                                  int readingFontSize, bool animationsEnabled,
                                  const QString &theme)
{
    const QString cleanName = nickname.trimmed();
    if (cleanName.isEmpty() || cleanName.size() > 20) {
        setError(QStringLiteral("昵称应为 1 至 20 个字符。")); return false;
    }
    if (!QStringList{QStringLiteral("山"), QStringLiteral("月"), QStringLiteral("竹"), QStringLiteral("鹤")}.contains(avatar)
        || readingFontSize < 18 || readingFontSize > 32
        || !QStringList{QStringLiteral("月白"), QStringLiteral("烟青")}.contains(theme)) {
        setError(QStringLiteral("偏好设置包含无效选项。")); return false;
    }
    if (!m_database.transaction()) {
        setError(QStringLiteral("无法开始保存偏好设置：") + m_database.lastError().text()); return false;
    }
    QSqlQuery query(m_database);
    query.prepare(QStringLiteral("INSERT INTO personal_settings(key,value) VALUES(?,?) "
                                 "ON CONFLICT(key) DO UPDATE SET value=excluded.value"));
    const QMap<QString, QString> values{{QStringLiteral("nickname"), cleanName},
                                        {QStringLiteral("avatar"), avatar},
                                        {QStringLiteral("reading_font_size"), QString::number(readingFontSize)},
                                        {QStringLiteral("animations_enabled"), animationsEnabled ? QStringLiteral("1") : QStringLiteral("0")},
                                        {QStringLiteral("theme"), theme}};
    for (auto it = values.cbegin(); it != values.cend(); ++it) {
        query.bindValue(0, it.key()); query.bindValue(1, it.value());
        if (!query.exec()) {
            m_database.rollback(); setError(databaseError(QStringLiteral("保存偏好设置失败"), query)); return false;
        }
    }
    if (!m_database.commit()) {
        m_database.rollback(); setError(QStringLiteral("提交偏好设置失败：") + m_database.lastError().text()); return false;
    }
    m_nickname = cleanName; m_avatar = avatar; m_readingFontSize = readingFontSize;
    m_animationsEnabled = animationsEnabled; m_theme = theme;
    setError({});
    emit settingsChanged();
    return true;
}

bool PersonalSpace::setTheme(const QString &theme)
{
    if (theme != QStringLiteral("月白") && theme != QStringLiteral("烟青")) {
        setError(QStringLiteral("请选择有效的主题。"));
        return false;
    }
    if (m_theme == theme) return true;
    QSqlQuery query(m_database);
    query.prepare(QStringLiteral("INSERT INTO personal_settings(key,value) VALUES('theme',?) "
                                 "ON CONFLICT(key) DO UPDATE SET value=excluded.value"));
    query.addBindValue(theme);
    if (!query.exec()) {
        setError(databaseError(QStringLiteral("保存主题失败"), query));
        return false;
    }
    m_theme = theme;
    setError({});
    emit settingsChanged();
    return true;
}
