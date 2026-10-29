#include "../src/aiassistant.h"

#include <QCoreApplication>
#include <QElapsedTimer>
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>
#include <QRegularExpression>
#include <QSqlQuery>
#include <QTcpServer>
#include <QTcpSocket>
#include <QTemporaryDir>
#include <QTextStream>

static bool check(bool okay, const QString &description)
{
    if (!okay) QTextStream(stderr) << "FAILED: " << description << Qt::endl;
    return okay;
}

static bool waitUntil(const std::function<bool()> &ready, int timeout = 5000)
{
    QElapsedTimer timer; timer.start();
    while (!ready() && timer.elapsed() < timeout)
        QCoreApplication::processEvents(QEventLoop::AllEvents, 30);
    return ready();
}

int main(int argc, char *argv[])
{
    QCoreApplication app(argc, argv);
    QTemporaryDir directory;
    if (!check(directory.isValid(), QStringLiteral("temporary directory"))) return 1;
    QSqlDatabase database = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), QStringLiteral("ai-test"));
    database.setDatabaseName(directory.filePath(QStringLiteral("archive.sqlite")));
    if (!check(database.open(), QStringLiteral("test database opens"))) return 1;
    QSqlQuery schema(database);
    if (!check(schema.exec(QStringLiteral("CREATE TABLE poems(id INTEGER PRIMARY KEY,title TEXT,author TEXT,dynasty TEXT,content TEXT,excerpt TEXT)"))
               && schema.exec(QStringLiteral("INSERT INTO poems VALUES(1,'静夜思','李白','唐','床前明月光，疑是地上霜。','床前明月光，疑是地上霜。')"))
               && schema.exec(QStringLiteral("INSERT INTO poems VALUES(2,'春望','杜甫','唐','国破山河在，城春草木深。','国破山河在，城春草木深。')")),
               QStringLiteral("existing poem fixture populated"))) return 1;

    QTcpServer server;
    if (!check(server.listen(QHostAddress::LocalHost, 0), QStringLiteral("mock backend listens"))) return 1;
    QList<QJsonObject> received;
    QList<QByteArray> headers;
    QObject::connect(&server, &QTcpServer::newConnection, &app, [&]() {
        auto *socket = server.nextPendingConnection();
        auto *buffer = new QByteArray;
        QObject::connect(socket, &QTcpSocket::readyRead, socket, [socket, buffer, &received, &headers]() {
            *buffer += socket->readAll();
            const int boundary = buffer->indexOf("\r\n\r\n");
            if (boundary < 0) return;
            const QByteArray header = buffer->left(boundary);
            const QRegularExpression pattern(QStringLiteral("Content-Length: (\\d+)"), QRegularExpression::CaseInsensitiveOption);
            const auto match = pattern.match(QString::fromLatin1(header));
            if (!match.hasMatch()) return;
            const int length = match.captured(1).toInt();
            if (buffer->size() < boundary + 4 + length) return;
            headers.append(header);
            received.append(QJsonDocument::fromJson(buffer->mid(boundary + 4, length)).object());
            const QByteArray first = "HTTP/1.1 200 OK\r\nContent-Type: text/event-stream\r\nConnection: close\r\n\r\n";
            const QByteArray part1 = "data: {\"delta\":\"诗意\"}\n\n";
            const QByteArray part2 = "data: {\"delta\":\"悠长\"}\n\n";
            const QByteArray ending = received.size() == 1
                ? "data: {\"done\":true,\"truncated\":true}\n\n"
                : "data: {\"done\":true}\n\n";
            socket->write(first + part1 + part2 + ending);
            socket->flush(); socket->disconnectFromHost();
            buffer->clear();
        });
        QObject::connect(socket, &QObject::destroyed, &app, [buffer]() { delete buffer; });
        QObject::connect(socket, &QTcpSocket::disconnected, socket, &QObject::deleteLater);
    });

    const QUrl endpoint(QStringLiteral("http://127.0.0.1:%1").arg(server.serverPort()));
    qputenv("YIJUANSHANHE_AI_ACCESS_TOKEN", "test-client-token");
    QString sessionId;
    {
        AiAssistant ai(database, endpoint);
        if (!check(ai.poemChoices().size() == 2, QStringLiteral("unfiltered local poem picker"))) return 1;
        ai.searchPoems(QStringLiteral("李白"));
        if (!check(ai.poemChoices().size() == 1, QStringLiteral("local poem search"))) return 1;
        if (!check(ai.newChat(QStringLiteral("analysis")) && ai.usePoem(1),
                   QStringLiteral("analysis session carries a real poem"))) return 1;
        sessionId = ai.sessionId();
        if (!check(ai.send({}) && waitUntil([&]() { return !ai.busy(); }),
                   QStringLiteral("asynchronous SSE request completes"))) return 1;
        if (!check(ai.errorMessage().isEmpty() && ai.messages().size() == 2
                   && ai.messages().last().toMap().value(QStringLiteral("content")).toString() == QStringLiteral("诗意悠长")
                   && ai.statusMessage().contains(QStringLiteral("长度上限"))
                   && received.size() == 1
                   && headers.first().contains("Bearer test-client-token")
                   && received.first().value(QStringLiteral("context")).toObject().value(QStringLiteral("poems")).toArray().size() == 1,
                   QStringLiteral("streaming answer and original poem context"))) return 1;
        if (!check(ai.continueAnswer() && waitUntil([&]() { return !ai.busy(); })
                   && ai.messages().size() == 4 && received.size() == 2
                   && received.last().value(QStringLiteral("messages")).toArray().last().toObject()
                          .value(QStringLiteral("content")).toString().contains(QStringLiteral("继续")),
                   QStringLiteral("truncated answer can continue in the same session"))) return 1;
        if (!check(ai.regenerate() && waitUntil([&]() { return !ai.busy(); })
                   && ai.messages().size() == 4 && received.size() == 3,
                   QStringLiteral("regenerate replaces previous answer"))) return 1;
        if (!check(ai.newChat(QStringLiteral("compare")) && ai.addComparePoem(1)
                   && ai.addComparePoem(2) && ai.send({}) && waitUntil([&]() { return !ai.busy(); })
                   && received.last().value(QStringLiteral("context")).toObject().value(QStringLiteral("poems")).toArray().size() == 2,
                   QStringLiteral("comparison sends two local poems"))) return 1;
        if (!check(ai.selectSession(sessionId) && ai.messages().size() == 4,
                   QStringLiteral("old conversation switches without data loss"))) return 1;
        const QString second = ai.sessions().first().toMap().value(QStringLiteral("id")).toString();
        if (!check(ai.deleteSession(second) && ai.sessions().size() == 1,
                   QStringLiteral("one session deleted without clearing others"))) return 1;
    }
    {
        AiAssistant reopened(database, endpoint);
        if (!check(reopened.sessions().size() == 1 && reopened.selectSession(sessionId)
                   && reopened.messages().size() == 4,
                   QStringLiteral("history persists after reopening"))) return 1;
        server.close();
        if (!check(reopened.regenerate() && waitUntil([&]() { return !reopened.busy(); })
                   && reopened.messages().size() == 4
                   && reopened.messages().last().toMap().value(QStringLiteral("content")).toString() == QStringLiteral("诗意悠长"),
                   QStringLiteral("failed regeneration keeps previous answer"))) return 1;
        if (!check(reopened.send(QStringLiteral("再说一说")) && waitUntil([&]() { return !reopened.busy(); })
                   && !reopened.errorMessage().isEmpty(),
                   QStringLiteral("offline backend reports friendly error"))) return 1;
    }
    QSqlQuery original(database);
    original.exec(QStringLiteral("SELECT content FROM poems WHERE id=1")); original.next();
    if (!check(original.value(0).toString() == QStringLiteral("床前明月光，疑是地上霜。"),
               QStringLiteral("original poem content untouched"))) return 1;
    QTextStream(stdout) << "AI assistant tests passed" << Qt::endl;
    return 0;
}
