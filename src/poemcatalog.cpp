#include "poemcatalog.h"
#include "shicicalendar.h"

#include <QCryptographicHash>
#include <QDateTime>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSqlError>
#include <QSqlQuery>
#include <QSet>
#include <QVariant>

namespace {
constexpr int kPageSize = 30;

struct CuratedMetadata {
    const char *form;
    const char *theme;
};

// Metadata for the 16 source-checked poems already shipped by HomeController.
const CuratedMetadata kCurated[] = {
    {"七言绝句", "山水"}, {"五言律诗", "四时"}, {"五言律诗", "山水"},
    {"七言绝句", "山水"}, {"五言绝句", "登临"}, {"七言绝句", "山水"},
    {"五言绝句", "山水"}, {"七言绝句", "思乡"}, {"五言绝句", "思乡"},
    {"七言绝句", "送别"}, {"七言绝句", "行旅"}, {"七言绝句", "羁旅"},
    {"五言古诗", "亲情"}, {"七言绝句", "山水"}, {"词", "江南"},
    {"五言古诗", "登临"}
};

QStringList distinctOptions(const QSqlDatabase &database, const QString &column)
{
    QStringList result{QStringLiteral("全部")};
    QSqlQuery query(database);
    if (!query.exec(QStringLiteral("SELECT DISTINCT %1 FROM poems WHERE trim(%1) <> '' ORDER BY %1 COLLATE NOCASE").arg(column)))
        return result;
    while (query.next())
        result.append(query.value(0).toString());
    return result;
}
}

PoemCatalog::PoemCatalog(const QSqlDatabase &database, QObject *parent,
                         const ShiciCalendar *shici)
    : QAbstractListModel(parent), m_database(database), m_shici(shici)
{
    if (m_shici && !m_shici->errorMessage().isEmpty()) {
        setError(m_shici->errorMessage());
        return;
    }
    if (ensureSchema() && (!m_shici || syncShici()) && refreshOptions()) {
        m_ready = true;
        search({}, {}, {}, {}, {}, {});
    }
}

int PoemCatalog::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : m_rows.size();
}

QVariant PoemCatalog::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_rows.size())
        return {};
    const Row &row = m_rows.at(index.row());
    switch (role) {
    case IdRole: return row.id;
    case TitleRole: return row.title;
    case AuthorRole: return row.author;
    case DynastyRole: return row.dynasty;
    case ExcerptRole: return row.excerpt;
    case FormRole: return row.form;
    case ThemeRole: return row.theme;
    case FavoriteRole: return row.favorite;
    default: return {};
    }
}

QHash<int, QByteArray> PoemCatalog::roleNames() const
{
    return {{IdRole, "poemId"}, {TitleRole, "poemTitle"},
            {AuthorRole, "poemAuthor"}, {DynastyRole, "poemDynasty"},
            {ExcerptRole, "poemExcerpt"}, {FormRole, "poemForm"},
            {ThemeRole, "poemTheme"}, {FavoriteRole, "poemFavorite"}};
}

void PoemCatalog::setError(const QString &message)
{
    if (m_errorMessage == message)
        return;
    m_errorMessage = message;
    emit errorMessageChanged();
}

bool PoemCatalog::ensureColumn(const QString &name, const QString &sqlType)
{
    QSqlQuery info(m_database);
    if (!info.exec(QStringLiteral("PRAGMA table_info(poems)"))) {
        setError(QStringLiteral("读取诗词表结构失败：") + info.lastError().text());
        return false;
    }
    while (info.next()) {
        if (info.value(1).toString() == name)
            return true;
    }
    QSqlQuery alter(m_database);
    if (!alter.exec(QStringLiteral("ALTER TABLE poems ADD COLUMN %1 %2").arg(name, sqlType))) {
        setError(QStringLiteral("升级诗词表失败：") + alter.lastError().text());
        return false;
    }
    return true;
}

bool PoemCatalog::ensureSchema()
{
    if (!m_database.isOpen()) {
        setError(QStringLiteral("诗词数据库尚未打开。"));
        return false;
    }
    QSqlQuery query(m_database);
    if (!query.exec(QStringLiteral("PRAGMA foreign_keys = ON"))) {
        setError(QStringLiteral("启用数据库约束失败：") + query.lastError().text());
        return false;
    }
    if (m_shici && !query.exec(QStringLiteral(
            "CREATE TABLE IF NOT EXISTS poems ("
            "id INTEGER PRIMARY KEY, title TEXT NOT NULL, author TEXT NOT NULL, "
            "dynasty TEXT NOT NULL, content TEXT NOT NULL, excerpt TEXT NOT NULL, "
            "source_note TEXT NOT NULL)"))) {
        setError(QStringLiteral("创建诗海拾珍数据表失败：") + query.lastError().text());
        return false;
    }
    const QStringList columns{QStringLiteral("form"), QStringLiteral("theme"),
                              QStringLiteral("annotation"), QStringLiteral("translation"),
                              QStringLiteral("appreciation")};
    for (const QString &column : columns) {
        if (!ensureColumn(column, QStringLiteral("TEXT NOT NULL DEFAULT ''")))
            return false;
    }
    QStringList statements{
        QStringLiteral("CREATE INDEX IF NOT EXISTS poems_filters ON poems(dynasty, author, form, theme)"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS favorites (poem_id INTEGER PRIMARY KEY REFERENCES poems(id) ON DELETE CASCADE, created_at TEXT NOT NULL)"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS notes (poem_id INTEGER PRIMARY KEY REFERENCES poems(id) ON DELETE CASCADE, body TEXT NOT NULL, updated_at TEXT NOT NULL)"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS reading_history (poem_id INTEGER PRIMARY KEY REFERENCES poems(id) ON DELETE CASCADE, last_read_at TEXT NOT NULL, read_count INTEGER NOT NULL DEFAULT 1)")
    };
    if (!m_shici)
        statements.prepend(QStringLiteral("CREATE UNIQUE INDEX IF NOT EXISTS poems_identity_unique ON poems(title, author, content)"));
    else
        statements.append(QStringLiteral("CREATE TABLE IF NOT EXISTS shici_sync (key TEXT PRIMARY KEY, value TEXT NOT NULL)"));
    for (const QString &sql : statements) {
        if (!query.exec(sql)) {
            setError(QStringLiteral("初始化典藏数据失败：") + query.lastError().text());
            return false;
        }
    }

    if (m_shici) return true;
    QSqlQuery update(m_database);
    if (!update.prepare(QStringLiteral("UPDATE poems SET form=?, theme=? WHERE id=? AND (form='' OR theme='')"))) {
        setError(QStringLiteral("诗词分类准备失败：") + update.lastError().text());
        return false;
    }
    for (int i = 0; i < int(sizeof(kCurated) / sizeof(kCurated[0])); ++i) {
        update.bindValue(0, QString::fromUtf8(kCurated[i].form));
        update.bindValue(1, QString::fromUtf8(kCurated[i].theme));
        update.bindValue(2, i + 1);
        if (!update.exec()) {
            setError(QStringLiteral("诗词分类保存失败：") + update.lastError().text());
            return false;
        }
    }
    return true;
}

bool PoemCatalog::syncShici()
{
    if (!m_shici || m_shici->poemCount() != 64) {
        setError(QStringLiteral("shici.txt 必须包含完整的 64 首诗词。"));
        return false;
    }
    QByteArray fingerprint;
    for (int day = 1; day <= 64; ++day) {
        const QVariantMap poem = m_shici->poemAt(day);
        fingerprint += poem.value(QStringLiteral("title")).toString().toUtf8() + '\x1f';
        fingerprint += poem.value(QStringLiteral("attribution")).toString().toUtf8() + '\x1f';
        fingerprint += poem.value(QStringLiteral("content")).toString().toUtf8() + '\x1e';
        fingerprint += poem.value(QStringLiteral("annotation")).toString().toUtf8() + '\x1e';
        fingerprint += poem.value(QStringLiteral("translation")).toString().toUtf8() + '\x1e';
        fingerprint += poem.value(QStringLiteral("appreciation")).toString().toUtf8() + '\x1e';
    }
    const QString hash = QString::fromLatin1(QCryptographicHash::hash(fingerprint,
                                       QCryptographicHash::Sha256).toHex());
    QSqlQuery current(m_database);
    if (!current.exec(QStringLiteral("SELECT value FROM shici_sync WHERE key='content'"))) {
        setError(QStringLiteral("读取诗词同步状态失败：") + current.lastError().text());
        return false;
    }
    if (current.next() && current.value(0).toString() == hash)
        return true;

    if (!m_database.transaction()) {
        setError(QStringLiteral("诗词同步事务启动失败：") + m_database.lastError().text());
        return false;
    }
    QSqlQuery query(m_database);
    if (!query.prepare(QStringLiteral(
            "INSERT INTO poems(id,title,author,dynasty,content,excerpt,source_note,"
            "form,theme,annotation,translation,appreciation) "
            "VALUES(?,?,?,?,?,?,?,'','',?,?,?) "
            "ON CONFLICT(id) DO UPDATE SET title=excluded.title,author=excluded.author,"
            "dynasty=excluded.dynasty,content=excluded.content,excerpt=excluded.excerpt,"
            "source_note=excluded.source_note,form='',theme='',"
            "annotation=excluded.annotation,translation=excluded.translation,"
            "appreciation=excluded.appreciation"))) {
        m_database.rollback();
        setError(QStringLiteral("准备诗词同步失败：") + query.lastError().text());
        return false;
    }
    for (int day = 1; day <= 64; ++day) {
        const QVariantMap poem = m_shici->poemAt(day);
        const QString attribution = poem.value(QStringLiteral("attribution")).toString();
        int separator = attribution.indexOf(QChar(0x00b7));
        if (separator < 0) separator = attribution.indexOf(QChar(0x30fb));
        const bool hasDynasty = separator > 0 && !attribution.startsWith(QChar(0x300a));
        const QString dynasty = hasDynasty ? attribution.left(separator).trimmed() : QStringLiteral("");
        const QString author = hasDynasty ? attribution.mid(separator + 1).trimmed() : attribution;
        const QString content = poem.value(QStringLiteral("content")).toString();
        query.bindValue(0, day);
        query.bindValue(1, poem.value(QStringLiteral("title")));
        query.bindValue(2, author);
        query.bindValue(3, dynasty);
        query.bindValue(4, content);
        query.bindValue(5, content.section(QChar('\n'), 0, 0).left(90));
        query.bindValue(6, QStringLiteral("shici.txt"));
        query.bindValue(7, poem.value(QStringLiteral("annotation")));
        query.bindValue(8, poem.value(QStringLiteral("translation")));
        query.bindValue(9, poem.value(QStringLiteral("appreciation")));
        if (!query.exec()) {
            m_database.rollback();
            setError(QStringLiteral("同步第 %1 首诗失败：").arg(day) + query.lastError().text());
            return false;
        }
    }
    QSqlQuery meta(m_database);
    meta.prepare(QStringLiteral("INSERT INTO shici_sync(key,value) VALUES('content',?) "
                                "ON CONFLICT(key) DO UPDATE SET value=excluded.value"));
    meta.addBindValue(hash);
    if (!meta.exec() || !m_database.commit()) {
        m_database.rollback();
        setError(QStringLiteral("保存诗词同步状态失败：") + m_database.lastError().text());
        return false;
    }
    return true;
}

bool PoemCatalog::refreshOptions()
{
    if (!m_database.isOpen())
        return false;
    m_dynasties = distinctOptions(m_database, QStringLiteral("dynasty"));
    m_authors = distinctOptions(m_database, QStringLiteral("author"));
    m_forms = distinctOptions(m_database, QStringLiteral("form"));
    m_themes = distinctOptions(m_database, QStringLiteral("theme"));
    emit optionsChanged();
    return true;
}

QString PoemCatalog::whereClause(QVariantList &values) const
{
    QString where = QStringLiteral(" WHERE 1=1");
    if (!m_keyword.isEmpty()) {
        where += QStringLiteral(" AND (instr(lower(p.title), lower(?)) > 0 OR instr(lower(p.author), lower(?)) > 0 OR instr(lower(p.content), lower(?)) > 0)");
        values << m_keyword << m_keyword << m_keyword;
    }
    const auto addFilter = [&](const QString &value, const QString &column) {
        if (!value.isEmpty() && value != QStringLiteral("全部")) {
            where += QStringLiteral(" AND p.%1 = ?").arg(column);
            values << value;
        }
    };
    addFilter(m_dynasty, QStringLiteral("dynasty"));
    addFilter(m_author, QStringLiteral("author"));
    addFilter(m_form, QStringLiteral("form"));
    addFilter(m_theme, QStringLiteral("theme"));
    return where;
}

QString PoemCatalog::orderClause() const
{
    if (m_sort == QStringLiteral("标题"))
        return QStringLiteral(" ORDER BY p.title COLLATE NOCASE, p.id");
    if (m_sort == QStringLiteral("作者"))
        return QStringLiteral(" ORDER BY p.author COLLATE NOCASE, p.id");
    if (m_sort == QStringLiteral("朝代"))
        return QStringLiteral(" ORDER BY p.dynasty COLLATE NOCASE, p.id");
    if (m_sort == QStringLiteral("收藏优先"))
        return QStringLiteral(" ORDER BY CASE WHEN f.poem_id IS NULL THEN 1 ELSE 0 END, p.id");
    return QStringLiteral(" ORDER BY p.id");
}

bool PoemCatalog::updateResultCount()
{
    QVariantList values;
    QSqlQuery query(m_database);
    if (!query.prepare(QStringLiteral("SELECT COUNT(*) FROM poems p") + whereClause(values))) {
        setError(QStringLiteral("统计搜索结果失败：") + query.lastError().text());
        return false;
    }
    for (const QVariant &value : values)
        query.addBindValue(value);
    if (!query.exec() || !query.next()) {
        setError(QStringLiteral("统计搜索结果失败：") + query.lastError().text());
        return false;
    }
    m_resultCount = query.value(0).toInt();
    emit resultCountChanged();
    return true;
}

void PoemCatalog::search(const QString &keyword, const QString &dynasty,
                         const QString &author, const QString &form,
                         const QString &theme, const QString &sort)
{
    if (!m_ready || !m_database.isOpen()) {
        if (!m_ready && !m_errorMessage.isEmpty()) return;
        setError(QStringLiteral("诗词数据库不可用。"));
        return;
    }
    m_keyword = keyword.trimmed();
    m_dynasty = dynasty;
    m_author = author;
    m_form = form;
    m_theme = theme;
    m_sort = sort;
    beginResetModel();
    m_rows.clear();
    endResetModel();
    emit hasMoreChanged();
    if (!updateResultCount()) {
        clearSelection();
        return;
    }
    loadNextPage();
    if (!m_opened)
        return;
    if (!m_rows.isEmpty()) {
        bool stillVisible = false;
        for (const Row &row : m_rows)
            stillVisible |= row.id == m_selectedId;
        if (!stillVisible)
            selectPoem(m_rows.first().id);
    } else {
        clearSelection();
    }
}

void PoemCatalog::activate()
{
    m_opened = true;
    if (m_selectedId == 0 && !m_rows.isEmpty())
        selectPoem(m_rows.first().id);
}

void PoemCatalog::loadNextPage()
{
    if (!m_database.isOpen() || !hasMore())
        return;
    QVariantList values;
    const QString sql = QStringLiteral(
        "SELECT p.id,p.title,p.author,p.dynasty,p.excerpt,p.form,p.theme,"
        "CASE WHEN f.poem_id IS NULL THEN 0 ELSE 1 END "
        "FROM poems p LEFT JOIN favorites f ON f.poem_id=p.id")
        + whereClause(values) + orderClause() + QStringLiteral(" LIMIT ? OFFSET ?");
    QSqlQuery query(m_database);
    if (!query.prepare(sql)) {
        setError(QStringLiteral("诗词查询准备失败：") + query.lastError().text());
        return;
    }
    for (const QVariant &value : values)
        query.addBindValue(value);
    query.addBindValue(kPageSize);
    query.addBindValue(m_rows.size());
    if (!query.exec()) {
        setError(QStringLiteral("诗词查询失败：") + query.lastError().text());
        return;
    }
    QVector<Row> page;
    while (query.next()) {
        page.append({query.value(0).toInt(), query.value(1).toString(),
                     query.value(2).toString(), query.value(3).toString(),
                     query.value(4).toString(), query.value(5).toString(),
                     query.value(6).toString(), query.value(7).toBool()});
    }
    if (!page.isEmpty()) {
        beginInsertRows({}, m_rows.size(), m_rows.size() + page.size() - 1);
        m_rows += page;
        endInsertRows();
    }
    emit hasMoreChanged();
    setError({});
}

void PoemCatalog::clearSelection()
{
    m_selectedId = 0;
    m_selectedTitle.clear(); m_selectedAuthor.clear(); m_selectedDynasty.clear();
    m_selectedForm.clear(); m_selectedTheme.clear(); m_selectedContent.clear();
    m_selectedAnnotation.clear(); m_selectedTranslation.clear(); m_selectedAppreciation.clear();
    m_selectedNote.clear(); m_selectedFavorite = false;
    emit selectedChanged();
}

void PoemCatalog::selectPoem(int id)
{
    if (id <= 0 || !m_database.isOpen())
        return;
    QSqlQuery query(m_database);
    if (!query.prepare(QStringLiteral(
            "SELECT p.title,p.author,p.dynasty,p.form,p.theme,p.content,"
            "p.annotation,p.translation,p.appreciation,n.body,"
            "CASE WHEN f.poem_id IS NULL THEN 0 ELSE 1 END "
            "FROM poems p LEFT JOIN notes n ON n.poem_id=p.id "
            "LEFT JOIN favorites f ON f.poem_id=p.id WHERE p.id=?"))) {
        setError(QStringLiteral("读取诗词详情失败：") + query.lastError().text());
        return;
    }
    query.addBindValue(id);
    if (!query.exec() || !query.next()) {
        setError(QStringLiteral("诗词详情不存在或读取失败。"));
        return;
    }
    m_selectedId = id;
    m_selectedTitle = query.value(0).toString();
    m_selectedAuthor = query.value(1).toString();
    m_selectedDynasty = query.value(2).toString();
    m_selectedForm = query.value(3).toString();
    m_selectedTheme = query.value(4).toString();
    m_selectedContent = query.value(5).toString();
    m_selectedAnnotation = query.value(6).toString();
    m_selectedTranslation = query.value(7).toString();
    m_selectedAppreciation = query.value(8).toString();
    m_selectedNote = query.value(9).toString();
    m_selectedFavorite = query.value(10).toBool();
    emit selectedChanged();

    QSqlQuery history(m_database);
    history.prepare(QStringLiteral(
        "INSERT INTO reading_history(poem_id,last_read_at,read_count) VALUES(?,?,1) "
        "ON CONFLICT(poem_id) DO UPDATE SET last_read_at=excluded.last_read_at, "
        "read_count=reading_history.read_count+1"));
    history.addBindValue(id);
    history.addBindValue(QDateTime::currentDateTimeUtc().toString(Qt::ISODateWithMs));
    if (!history.exec())
        setError(QStringLiteral("阅读历史保存失败：") + history.lastError().text());
    else {
        setError({});
        emit historyChanged();
    }
}

void PoemCatalog::updateVisibleFavorite(int id, bool favorite)
{
    for (int i = 0; i < m_rows.size(); ++i) {
        if (m_rows[i].id == id) {
            m_rows[i].favorite = favorite;
            emit dataChanged(index(i), index(i), {FavoriteRole});
            break;
        }
    }
}

void PoemCatalog::toggleFavorite()
{
    if (m_selectedId <= 0)
        return;
    QSqlQuery query(m_database);
    if (m_selectedFavorite) {
        query.prepare(QStringLiteral("DELETE FROM favorites WHERE poem_id=?"));
        query.addBindValue(m_selectedId);
    } else {
        query.prepare(QStringLiteral("INSERT OR IGNORE INTO favorites(poem_id,created_at) VALUES(?,?)"));
        query.addBindValue(m_selectedId);
        query.addBindValue(QDateTime::currentDateTimeUtc().toString(Qt::ISODateWithMs));
    }
    if (!query.exec()) {
        setError(QStringLiteral("收藏操作失败：") + query.lastError().text());
        return;
    }
    m_selectedFavorite = !m_selectedFavorite;
    updateVisibleFavorite(m_selectedId, m_selectedFavorite);
    emit selectedChanged();
    emit notice(m_selectedFavorite ? QStringLiteral("已加入收藏") : QStringLiteral("已取消收藏"));
    setError({});
}

void PoemCatalog::saveNote(const QString &text)
{
    if (m_selectedId <= 0)
        return;
    if (text.trimmed().isEmpty()) {
        deleteNote();
        return;
    }
    QSqlQuery query(m_database);
    query.prepare(QStringLiteral(
        "INSERT INTO notes(poem_id,body,updated_at) VALUES(?,?,?) "
        "ON CONFLICT(poem_id) DO UPDATE SET body=excluded.body,updated_at=excluded.updated_at"));
    query.addBindValue(m_selectedId);
    query.addBindValue(text);
    query.addBindValue(QDateTime::currentDateTimeUtc().toString(Qt::ISODateWithMs));
    if (!query.exec()) {
        setError(QStringLiteral("笔记保存失败：") + query.lastError().text());
        return;
    }
    m_selectedNote = text;
    emit selectedChanged();
    emit notice(QStringLiteral("笔记已保存"));
    setError({});
}

void PoemCatalog::deleteNote()
{
    if (m_selectedId <= 0)
        return;
    QSqlQuery query(m_database);
    query.prepare(QStringLiteral("DELETE FROM notes WHERE poem_id=?"));
    query.addBindValue(m_selectedId);
    if (!query.exec()) {
        setError(QStringLiteral("笔记删除失败：") + query.lastError().text());
        return;
    }
    m_selectedNote.clear();
    emit selectedChanged();
    emit notice(QStringLiteral("笔记已删除"));
    setError({});
}

void PoemCatalog::refreshPersonalData()
{
    if (!m_database.isOpen()) return;
    QSqlQuery favorites(m_database);
    if (!favorites.exec(QStringLiteral("SELECT poem_id FROM favorites"))) {
        setError(QStringLiteral("刷新收藏状态失败：") + favorites.lastError().text());
        return;
    }
    QSet<int> favoriteIds;
    while (favorites.next()) favoriteIds.insert(favorites.value(0).toInt());
    for (int i = 0; i < m_rows.size(); ++i) {
        const bool favorite = favoriteIds.contains(m_rows[i].id);
        if (m_rows[i].favorite != favorite) {
            m_rows[i].favorite = favorite;
            emit dataChanged(index(i), index(i), {FavoriteRole});
        }
    }
    if (m_selectedId <= 0) return;
    QSqlQuery note(m_database);
    note.prepare(QStringLiteral("SELECT body FROM notes WHERE poem_id=?"));
    note.addBindValue(m_selectedId);
    if (!note.exec()) {
        setError(QStringLiteral("刷新笔记状态失败：") + note.lastError().text());
        return;
    }
    const QString body = note.next() ? note.value(0).toString() : QString();
    const bool favorite = favoriteIds.contains(m_selectedId);
    if (m_selectedNote != body || m_selectedFavorite != favorite) {
        m_selectedNote = body;
        m_selectedFavorite = favorite;
        emit selectedChanged();
    }
}

int PoemCatalog::importJsonFile(const QString &path)
{
    if (m_shici) {
        setError(QStringLiteral("诗海拾珍由 shici.txt 管理，不支持导入其他诗词。"));
        return -1;
    }
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly)) {
        setError(QStringLiteral("无法打开诗词数据文件：") + file.errorString());
        return -1;
    }
    QJsonParseError parseError;
    const QJsonDocument document = QJsonDocument::fromJson(file.readAll(), &parseError);
    if (parseError.error != QJsonParseError::NoError || !document.isArray()) {
        setError(QStringLiteral("诗词数据必须是 JSON 数组：") + parseError.errorString());
        return -1;
    }
    if (!m_database.transaction()) {
        setError(QStringLiteral("诗词导入事务启动失败：") + m_database.lastError().text());
        return -1;
    }
    QSqlQuery query(m_database);
    if (!query.prepare(QStringLiteral(
            "INSERT OR IGNORE INTO poems(title,author,dynasty,content,excerpt,source_note,"
            "form,theme,annotation,translation,appreciation) VALUES(?,?,?,?,?,?,?,?,?,?,?)"))) {
        m_database.rollback();
        setError(QStringLiteral("诗词导入准备失败：") + query.lastError().text());
        return -1;
    }
    int imported = 0;
    for (const QJsonValue &value : document.array()) {
        if (!value.isObject())
            continue;
        const QJsonObject poem = value.toObject();
        const QString title = poem.value(QStringLiteral("title")).toString().trimmed();
        const QString author = poem.value(QStringLiteral("author")).toString().trimmed();
        const QString dynasty = poem.value(QStringLiteral("dynasty")).toString().trimmed();
        const QString content = poem.value(QStringLiteral("content")).toString().trimmed();
        const QString source = poem.value(QStringLiteral("source")).toString().trimmed();
        if (title.isEmpty() || author.isEmpty() || dynasty.isEmpty() || content.isEmpty() || source.isEmpty())
            continue;
        const QString excerpt = poem.value(QStringLiteral("excerpt")).toString().trimmed().isEmpty()
            ? content.section(QLatin1Char('\n'), 0, 1).left(90)
            : poem.value(QStringLiteral("excerpt")).toString().trimmed();
        const auto optional = [&](const char *key) {
            return poem.value(QString::fromLatin1(key)).toString(QStringLiteral(""));
        };
        const QStringList values{title, author, dynasty, content, excerpt, source,
                                 optional("form"), optional("theme"),
                                 optional("annotation"), optional("translation"),
                                 optional("appreciation")};
        for (int i = 0; i < values.size(); ++i)
            query.bindValue(i, values.at(i));
        if (!query.exec()) {
            m_database.rollback();
            setError(QStringLiteral("诗词导入失败：") + query.lastError().text());
            return -1;
        }
        imported += query.numRowsAffected();
    }
    if (!m_database.commit()) {
        setError(QStringLiteral("诗词导入提交失败：") + m_database.lastError().text());
        return -1;
    }
    refreshOptions();
    search(m_keyword, m_dynasty, m_author, m_form, m_theme, m_sort);
    emit notice(QStringLiteral("已导入 %1 首新诗词").arg(imported));
    return imported;
}
