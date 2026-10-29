#include "aiassistant.h"

#include <QClipboard>
#include <QDateTime>
#include <QGuiApplication>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QRegularExpression>
#include <QSqlError>
#include <QSqlQuery>
#include <QUuid>
#include <algorithm>

namespace {
QString utcNow() { return QDateTime::currentDateTimeUtc().toString(Qt::ISODateWithMs); }
QString sqlError(const QString &prefix, const QSqlQuery &query)
{ return prefix + QStringLiteral("：") + query.lastError().text(); }
}

AiAssistant::AiAssistant(const QSqlDatabase &database, const QUrl &endpoint, QObject *parent)
    : QObject(parent), m_database(database), m_endpoint(endpoint)
{
    if (m_endpoint.isEmpty()) m_endpoint = QUrl(QStringLiteral("http://127.0.0.1:8765/api/chat"));
    else if (!m_endpoint.path().endsWith(QStringLiteral("/api/chat"))) {
        QString path = m_endpoint.path();
        if (!path.endsWith('/')) path += '/';
        m_endpoint.setPath(path + QStringLiteral("api/chat"));
    }
    m_timeout.setSingleShot(true);
    m_timeout.setInterval(90000);
    connect(&m_timeout, &QTimer::timeout, this, [this]() {
        if (!m_reply) return;
        const QString message = QStringLiteral("AI 服务响应超时，请稍后重试。已保留你的提问。");
        m_reply->abort();
        fail(message);
    });
    if (!m_database.isOpen() || !ensureSchema()) return;
    loadSessions();
    searchPoems({});
}

bool AiAssistant::validMode(const QString &mode)
{
    return mode == QStringLiteral("chat") || mode == QStringLiteral("analysis")
           || mode == QStringLiteral("recommend") || mode == QStringLiteral("compare");
}

bool AiAssistant::ensureSchema()
{
    const QStringList schema{
        QStringLiteral("CREATE TABLE IF NOT EXISTS ai_sessions("
                       "id TEXT PRIMARY KEY,title TEXT NOT NULL,mode TEXT NOT NULL,"
                       "context_json TEXT NOT NULL DEFAULT '{}',created_at TEXT NOT NULL,updated_at TEXT NOT NULL)"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS ai_messages("
                       "id INTEGER PRIMARY KEY AUTOINCREMENT,session_id TEXT NOT NULL "
                       "REFERENCES ai_sessions(id) ON DELETE CASCADE,role TEXT NOT NULL,"
                       "content TEXT NOT NULL,created_at TEXT NOT NULL)"),
        QStringLiteral("CREATE INDEX IF NOT EXISTS ai_messages_session ON ai_messages(session_id,id)")
    };
    QSqlQuery query(m_database);
    for (const QString &statement : schema) {
        if (!query.exec(statement)) { fail(sqlError(QStringLiteral("会话存储初始化失败"), query)); return false; }
    }
    return true;
}

void AiAssistant::fail(const QString &message)
{
    m_error = message;
    m_status.clear();
    emit statusChanged();
}

void AiAssistant::setStatus(const QString &message)
{
    m_status = message;
    m_error.clear();
    emit statusChanged();
}

bool AiAssistant::loadSessions()
{
    QSqlQuery query(m_database);
    if (!query.exec(QStringLiteral("SELECT id,title,mode,updated_at FROM ai_sessions ORDER BY updated_at DESC,id DESC"))) {
        fail(sqlError(QStringLiteral("读取会话失败"), query)); return false;
    }
    QVariantList rows;
    while (query.next()) {
        rows.append(QVariantMap{{QStringLiteral("id"), query.value(0).toString()},
                                {QStringLiteral("title"), query.value(1).toString()},
                                {QStringLiteral("mode"), query.value(2).toString()},
                                {QStringLiteral("date"), query.value(3).toString().left(10)}});
    }
    m_sessions = rows;
    emit sessionsChanged();
    return true;
}

bool AiAssistant::loadMessages()
{
    QSqlQuery query(m_database);
    query.prepare(QStringLiteral("SELECT role,content,created_at FROM ai_messages "
                                 "WHERE session_id=? ORDER BY id"));
    query.addBindValue(m_sessionId);
    if (!query.exec()) { fail(sqlError(QStringLiteral("读取对话失败"), query)); return false; }
    QVariantList rows;
    while (query.next())
        rows.append(QVariantMap{{QStringLiteral("role"), query.value(0).toString()},
                                {QStringLiteral("content"), query.value(1).toString()},
                                {QStringLiteral("time"), query.value(2).toString().mid(11, 5)}});
    m_messages = rows;
    emit messagesChanged();
    return true;
}

bool AiAssistant::newChat(const QString &mode)
{
    if (!validMode(mode) || !m_database.isOpen()) { fail(QStringLiteral("无法创建对话：模式或数据库不可用。")); return false; }
    cancel();
    const QString id = QUuid::createUuid().toString(QUuid::WithoutBraces);
    const QString now = utcNow();
    QSqlQuery query(m_database);
    query.prepare(QStringLiteral("INSERT INTO ai_sessions(id,title,mode,context_json,created_at,updated_at) "
                                 "VALUES(?,?,?,'{}',?,?)"));
    query.addBindValue(id); query.addBindValue(QStringLiteral("新对话"));
    query.addBindValue(mode); query.addBindValue(now); query.addBindValue(now);
    if (!query.exec()) { fail(sqlError(QStringLiteral("创建对话失败"), query)); return false; }
    m_sessionId = id; m_mode = mode; m_context.clear(); m_messages.clear(); m_liveText.clear();
    emit sessionChanged(); emit contextChanged(); emit messagesChanged(); emit liveChanged();
    loadSessions();
    setStatus(QStringLiteral("新的一卷已展开。"));
    return true;
}

bool AiAssistant::selectSession(const QString &id)
{
    if (id.isEmpty()) return false;
    cancel();
    QSqlQuery query(m_database);
    query.prepare(QStringLiteral("SELECT mode,context_json FROM ai_sessions WHERE id=?"));
    query.addBindValue(id);
    if (!query.exec() || !query.next()) { fail(QStringLiteral("找不到这段历史对话。")); return false; }
    m_sessionId = id; m_mode = query.value(0).toString();
    m_context = QJsonDocument::fromJson(query.value(1).toByteArray()).object().toVariantMap();
    m_liveText.clear();
    emit sessionChanged(); emit contextChanged(); emit liveChanged();
    setStatus({});
    return loadMessages();
}

bool AiAssistant::deleteSession(const QString &id)
{
    if (id.isEmpty() || !m_database.transaction()) { fail(QStringLiteral("无法删除会话。")); return false; }
    QSqlQuery query(m_database);
    query.prepare(QStringLiteral("DELETE FROM ai_messages WHERE session_id=?")); query.addBindValue(id);
    if (!query.exec()) { m_database.rollback(); fail(sqlError(QStringLiteral("删除消息失败"), query)); return false; }
    query.prepare(QStringLiteral("DELETE FROM ai_sessions WHERE id=?")); query.addBindValue(id);
    if (!query.exec() || !m_database.commit()) {
        m_database.rollback(); fail(QStringLiteral("删除会话失败，请稍后重试。")); return false;
    }
    if (id == m_sessionId) {
        cancel(); m_sessionId.clear(); m_mode = QStringLiteral("chat"); m_context.clear(); m_messages.clear();
        emit sessionChanged(); emit contextChanged(); emit messagesChanged();
    }
    loadSessions();
    setStatus(QStringLiteral("会话已删除。"));
    return true;
}

QVariantMap AiAssistant::poem(int id) const
{
    QSqlQuery query(m_database);
    query.prepare(QStringLiteral("SELECT id,title,author,dynasty,content FROM poems WHERE id=?"));
    query.addBindValue(id);
    if (!query.exec() || !query.next()) return {};
    return {{QStringLiteral("id"), query.value(0).toInt()},
            {QStringLiteral("title"), query.value(1).toString()},
            {QStringLiteral("author"), query.value(2).toString()},
            {QStringLiteral("dynasty"), query.value(3).toString()},
            {QStringLiteral("content"), query.value(4).toString()}};
}

bool AiAssistant::saveContext()
{
    if (m_sessionId.isEmpty()) { fail(QStringLiteral("请先新建对话。")); return false; }
    QSqlQuery query(m_database);
    query.prepare(QStringLiteral("UPDATE ai_sessions SET context_json=?,updated_at=? WHERE id=?"));
    query.addBindValue(QString::fromUtf8(QJsonDocument::fromVariant(m_context).toJson(QJsonDocument::Compact)));
    query.addBindValue(utcNow()); query.addBindValue(m_sessionId);
    if (!query.exec()) { fail(sqlError(QStringLiteral("保存诗词上下文失败"), query)); return false; }
    emit contextChanged();
    loadSessions();
    return true;
}

bool AiAssistant::usePoem(int poemId)
{
    if (m_sessionId.isEmpty() && !newChat(m_mode)) return false;
    const QVariantMap selected = poem(poemId);
    if (selected.isEmpty()) { fail(QStringLiteral("这首诗词在本地典藏中不存在。")); return false; }
    m_context = {{QStringLiteral("kind"), QStringLiteral("poem")},
                 {QStringLiteral("label"), QStringLiteral("《%1》").arg(selected.value(QStringLiteral("title")).toString())},
                 {QStringLiteral("poems"), QVariantList{selected}}};
    return saveContext();
}

bool AiAssistant::addComparePoem(int poemId)
{
    if (m_sessionId.isEmpty() && !newChat(QStringLiteral("compare"))) return false;
    const QVariantMap selected = poem(poemId);
    if (selected.isEmpty()) { fail(QStringLiteral("这首诗词在本地典藏中不存在。")); return false; }
    QVariantList poems = m_context.value(QStringLiteral("poems")).toList();
    for (const QVariant &item : poems)
        if (item.toMap().value(QStringLiteral("id")).toInt() == poemId) {
            fail(QStringLiteral("请为对比选择两首不同的诗词。")); return false;
        }
    if (poems.size() >= 2) poems.removeLast();
    poems.append(selected);
    QString label;
    for (const QVariant &item : poems) {
        if (!label.isEmpty()) label += QStringLiteral(" × ");
        label += QStringLiteral("《%1》").arg(item.toMap().value(QStringLiteral("title")).toString());
    }
    m_context = {{QStringLiteral("kind"), QStringLiteral("compare")},
                 {QStringLiteral("label"), label}, {QStringLiteral("poems"), poems}};
    return saveContext();
}

bool AiAssistant::openWithPoem(int poemId)
{
    return newChat(QStringLiteral("analysis")) && usePoem(poemId);
}

bool AiAssistant::openWithPoet(const QString &name, const QString &description)
{
    if (name.trimmed().isEmpty() || !newChat(QStringLiteral("chat"))) return false;
    m_context = {{QStringLiteral("kind"), QStringLiteral("poet")},
                 {QStringLiteral("label"), name.left(80)},
                 {QStringLiteral("description"), description.left(4000)}};
    return saveContext();
}

bool AiAssistant::openWithImagery(const QString &name, const QString &description)
{
    if (name.trimmed().isEmpty() || !newChat(QStringLiteral("chat"))) return false;
    m_context = {{QStringLiteral("kind"), QStringLiteral("imagery")},
                 {QStringLiteral("label"), name.left(80)},
                 {QStringLiteral("description"), description.left(4000)}};
    return saveContext();
}

void AiAssistant::searchPoems(const QString &keyword)
{
    const QString term = keyword.trimmed();
    QSqlQuery query(m_database);
    if (term.isEmpty()) {
        query.prepare(QStringLiteral("SELECT id,title,author,dynasty FROM poems ORDER BY id LIMIT 64"));
    } else {
        query.prepare(QStringLiteral("SELECT id,title,author,dynasty FROM poems "
                                     "WHERE instr(lower(title),lower(?))>0 OR instr(lower(author),lower(?))>0 "
                                     "ORDER BY id LIMIT 64"));
        query.addBindValue(term); query.addBindValue(term);
    }
    if (!query.exec()) { fail(sqlError(QStringLiteral("检索本地诗词失败"), query)); return; }
    QVariantList rows;
    while (query.next())
        rows.append(QVariantMap{{QStringLiteral("id"), query.value(0).toInt()},
                                {QStringLiteral("title"), query.value(1).toString()},
                                {QStringLiteral("author"), query.value(2).toString()},
                                {QStringLiteral("dynasty"), query.value(3).toString()}});
    m_poemChoices = rows;
    emit poemChoicesChanged();
}

QVariantList AiAssistant::candidatePoems(const QString &queryText) const
{
    struct Candidate { QVariantMap value; int score = 0; };
    QVector<Candidate> items;
    QStringList terms = queryText.toLower().split(QRegularExpression(QStringLiteral("[^\\p{L}\\p{N}]+")), Qt::SkipEmptyParts);
    if (terms.size() == 1 && terms.first().size() > 3) {
        const QString phrase = terms.first();
        for (int i = 0; i + 1 < phrase.size(); ++i) terms.append(phrase.mid(i, 2));
    }
    QSqlQuery query(m_database);
    if (!query.exec(QStringLiteral("SELECT id,title,author,dynasty,excerpt FROM poems ORDER BY id"))) return {};
    while (query.next()) {
        const QString title = query.value(1).toString();
        const QString author = query.value(2).toString();
        const QString excerpt = query.value(4).toString().left(95);
        int score = 0;
        for (const QString &term : terms) {
            if (term.size() < 2) continue;
            score += title.contains(term, Qt::CaseInsensitive) ? 4 : 0;
            score += author.contains(term, Qt::CaseInsensitive) ? 3 : 0;
            score += excerpt.contains(term, Qt::CaseInsensitive) ? 2 : 0;
        }
        items.append({{{QStringLiteral("id"), query.value(0).toInt()},
                       {QStringLiteral("title"), title}, {QStringLiteral("author"), author},
                       {QStringLiteral("dynasty"), query.value(3).toString()},
                       {QStringLiteral("excerpt"), excerpt}}, score});
    }
    std::stable_sort(items.begin(), items.end(), [](const Candidate &a, const Candidate &b) {
        return a.score > b.score;
    });
    const int limit = !items.isEmpty() && items.first().score > 0 ? qMin(24, items.size()) : items.size();
    QVariantList result;
    for (int i = 0; i < limit; ++i) result.append(items.at(i).value);
    return result;
}

QString AiAssistant::defaultPrompt() const
{
    if (m_mode == QStringLiteral("analysis"))
        return QStringLiteral("请依据所选诗词原文，分析其意境、情感、修辞与文化内涵，并区分原文事实与推断。");
    if (m_mode == QStringLiteral("compare"))
        return QStringLiteral("请比较这两首诗的情感、语言风格与意象，指出相似处和差异，并结合原句说明。");
    return {};
}

bool AiAssistant::appendMessage(const QString &role, const QString &content)
{
    QSqlQuery query(m_database);
    query.prepare(QStringLiteral("INSERT INTO ai_messages(session_id,role,content,created_at) VALUES(?,?,?,?)"));
    query.addBindValue(m_sessionId); query.addBindValue(role); query.addBindValue(content); query.addBindValue(utcNow());
    if (!query.exec()) { fail(sqlError(QStringLiteral("保存对话失败"), query)); return false; }
    m_messages.append(QVariantMap{{QStringLiteral("role"), role},
                                  {QStringLiteral("content"), content},
                                  {QStringLiteral("time"), QDateTime::currentDateTime().toString(QStringLiteral("HH:mm"))}});
    emit messagesChanged();
    QSqlQuery session(m_database);
    session.prepare(QStringLiteral("UPDATE ai_sessions SET updated_at=?,title="
                                   "CASE WHEN title='新对话' AND ?='user' THEN ? ELSE title END WHERE id=?"));
    session.addBindValue(utcNow()); session.addBindValue(role);
    session.addBindValue(content.simplified().left(22)); session.addBindValue(m_sessionId);
    if (session.exec()) loadSessions();
    return true;
}

bool AiAssistant::send(const QString &message)
{
    if (m_busy) return false;
    if (m_sessionId.isEmpty() && !newChat(m_mode)) return false;
    QString text = message.trimmed();
    if (text.isEmpty()) text = defaultPrompt();
    if (text.isEmpty()) { fail(QStringLiteral("请先写下想问的问题或阅读期待。")); return false; }
    if (text.size() > 4000) { fail(QStringLiteral("单次提问请控制在 4000 字以内。")); return false; }
    if (m_mode == QStringLiteral("analysis") && m_context.value(QStringLiteral("poems")).toList().isEmpty()) {
        fail(QStringLiteral("请先在右侧选择一首诗词。")); return false;
    }
    if (m_mode == QStringLiteral("compare") && m_context.value(QStringLiteral("poems")).toList().size() != 2) {
        fail(QStringLiteral("请先在右侧选择两首不同的诗词。")); return false;
    }
    if (!appendMessage(QStringLiteral("user"), text)) return false;
    return startRequest();
}

bool AiAssistant::regenerate()
{
    if (m_busy || m_sessionId.isEmpty() || m_messages.isEmpty()) return false;
    m_regenerating = m_messages.last().toMap().value(QStringLiteral("role")) == QStringLiteral("assistant");
    const int userIndex = m_messages.size() - (m_regenerating ? 2 : 1);
    if (userIndex < 0 || m_messages.at(userIndex).toMap().value(QStringLiteral("role")) != QStringLiteral("user")) {
        m_regenerating = false;
        fail(QStringLiteral("没有可重新生成的提问。")); return false;
    }
    return startRequest();
}

bool AiAssistant::continueAnswer()
{
    if (m_busy || m_messages.isEmpty()
        || m_messages.last().toMap().value(QStringLiteral("role")).toString() != QStringLiteral("assistant")) {
        fail(QStringLiteral("请先等待当前回复完成。"));
        return false;
    }
    return send(QStringLiteral("请从上一段结尾处继续写完，避免重复已写的内容。"));
}

bool AiAssistant::startRequest()
{
    if (!m_endpoint.isValid() || (m_endpoint.scheme() != QStringLiteral("http")
                                   && m_endpoint.scheme() != QStringLiteral("https"))) {
        fail(QStringLiteral("AI 服务地址不可用。")); return false;
    }
    QJsonArray messages;
    const int end = m_messages.size() - (m_regenerating ? 1 : 0);
    const int start = qMax(0, end - 16);
    for (int i = start; i < end; ++i) {
        const QVariantMap row = m_messages.at(i).toMap();
        messages.append(QJsonObject{{QStringLiteral("role"), row.value(QStringLiteral("role")).toString()},
                                    {QStringLiteral("content"), row.value(QStringLiteral("content")).toString().left(4000)}});
    }
    QVariantMap context = m_context;
    if (m_mode == QStringLiteral("recommend"))
        context[QStringLiteral("candidates")] = candidatePoems(m_messages.at(end - 1).toMap().value(QStringLiteral("content")).toString());
    QJsonObject body{{QStringLiteral("mode"), m_mode}, {QStringLiteral("messages"), messages},
                     {QStringLiteral("context"), QJsonObject::fromVariantMap(context)}};
    QNetworkRequest request(m_endpoint);
    request.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/json"));
    request.setRawHeader("Accept", "text/event-stream");
    const QByteArray token = qgetenv("YIJUANSHANHE_AI_ACCESS_TOKEN");
    if (!token.isEmpty()) request.setRawHeader("Authorization", "Bearer " + token);
    request.setTransferTimeout(90000);
    m_streamBuffer.clear(); m_liveText.clear(); m_streamDone = false; m_streamTruncated = false;
    emit liveChanged();
    m_busy = true; emit busyChanged();
    setStatus(QStringLiteral("正在请墨……"));
    m_reply = m_network.post(request, QJsonDocument(body).toJson(QJsonDocument::Compact));
    connect(m_reply, &QIODevice::readyRead, this, &AiAssistant::consumeStream);
    connect(m_reply, &QNetworkReply::finished, this, &AiAssistant::finishRequest);
    m_timeout.start();
    return true;
}

void AiAssistant::consumeStream()
{
    if (!m_reply) return;
    m_streamBuffer += m_reply->readAll();
    if (m_streamBuffer.size() > 131072) {
        m_reply->abort(); fail(QStringLiteral("AI 回复过长，已停止生成。")); return;
    }
    m_timeout.start();
    int newline = 0;
    while ((newline = m_streamBuffer.indexOf('\n')) >= 0) {
        QByteArray line = m_streamBuffer.left(newline).trimmed();
        m_streamBuffer.remove(0, newline + 1);
        if (!line.startsWith("data:")) continue;
        line = line.mid(5).trimmed();
        if (line == "[DONE]") { m_streamDone = true; continue; }
        const QJsonObject event = QJsonDocument::fromJson(line).object();
        if (event.contains(QStringLiteral("error"))) {
            const QJsonValue value = event.value(QStringLiteral("error"));
            fail(value.isString() ? value.toString() : value.toObject().value(QStringLiteral("message")).toString());
        }
        if (event.value(QStringLiteral("done")).toBool()) {
            m_streamDone = true;
            m_streamTruncated = event.value(QStringLiteral("truncated")).toBool();
        }
        const QString delta = event.value(QStringLiteral("delta")).toString();
        if (!delta.isEmpty()) { m_liveText += delta; emit liveChanged(); }
    }
}

void AiAssistant::finishRequest()
{
    if (!m_reply) return;
    m_timeout.stop();
    consumeStream();
    const int status = m_reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    if (m_reply->error() != QNetworkReply::NoError && status == 0 && m_error.isEmpty()) {
        fail(QStringLiteral("无法连接 AI 服务。请稍后重试，本地诗词功能仍可正常使用。"));
    } else if (status != 200 && m_error.isEmpty()) {
        const QJsonObject body = QJsonDocument::fromJson(m_streamBuffer).object();
        const QJsonValue value = body.value(QStringLiteral("error"));
        const QString reason = value.isString() ? value.toString() : value.toObject().value(QStringLiteral("message")).toString();
        fail(reason.isEmpty() ? QStringLiteral("AI 服务暂不可用（HTTP %1）。请检查后端是否运行。").arg(status) : reason);
    } else if (m_reply->error() != QNetworkReply::NoError && m_error.isEmpty()) {
        fail(QStringLiteral("无法连接 AI 服务。请稍后重试，本地诗词功能仍可正常使用。"));
    } else if (!m_streamDone && m_error.isEmpty()) {
        fail(QStringLiteral("AI 回复未完整送达，请重新生成。"));
    } else if (m_liveText.isEmpty() && m_error.isEmpty()) {
        fail(QStringLiteral("AI 服务没有返回内容，请稍后重试。"));
    }
    m_reply->deleteLater(); m_reply = nullptr;
    m_busy = false; emit busyChanged();
    if (m_error.isEmpty()) {
        const QString answer = m_liveText;
        if (m_regenerating) {
            QSqlQuery replace(m_database);
            replace.prepare(QStringLiteral("DELETE FROM ai_messages WHERE id=(SELECT MAX(id) FROM ai_messages "
                                           "WHERE session_id=? AND role='assistant')"));
            replace.addBindValue(m_sessionId);
            if (!replace.exec()) fail(sqlError(QStringLiteral("替换旧回复失败"), replace));
            else { m_messages.removeLast(); emit messagesChanged(); }
        }
        if (m_error.isEmpty() && appendMessage(QStringLiteral("assistant"), answer))
            setStatus(m_streamTruncated ? QStringLiteral("回复已到长度上限，可点“继续生成”。")
                                        : QStringLiteral("墨迹已成。"));
    }
    m_regenerating = false;
    m_streamTruncated = false;
    m_liveText.clear(); emit liveChanged();
}

void AiAssistant::cancel()
{
    if (!m_reply) return;
    QNetworkReply *reply = m_reply;
    m_reply = nullptr;
    m_timeout.stop();
    disconnect(reply, nullptr, this, nullptr);
    reply->abort(); reply->deleteLater();
    m_busy = false; m_liveText.clear(); emit busyChanged(); emit liveChanged();
    m_regenerating = false;
    m_streamTruncated = false;
    setStatus(QStringLiteral("已停止生成；你的提问仍保留在会话中。"));
}

void AiAssistant::copyText(const QString &text) const
{
    if (QGuiApplication::clipboard()) QGuiApplication::clipboard()->setText(text);
}
