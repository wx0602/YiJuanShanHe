#pragma once

#include <QObject>
#include <QNetworkAccessManager>
#include <QSqlDatabase>
#include <QTimer>
#include <QUrl>
#include <QVariantList>
#include <QVariantMap>

class QNetworkReply;

class AiAssistant final : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QVariantList sessions READ sessions NOTIFY sessionsChanged)
    Q_PROPERTY(QVariantList messages READ messages NOTIFY messagesChanged)
    Q_PROPERTY(QVariantList poemChoices READ poemChoices NOTIFY poemChoicesChanged)
    Q_PROPERTY(QVariantMap context READ context NOTIFY contextChanged)
    Q_PROPERTY(QString sessionId READ sessionId NOTIFY sessionChanged)
    Q_PROPERTY(QString mode READ mode NOTIFY sessionChanged)
    Q_PROPERTY(QString liveText READ liveText NOTIFY liveChanged)
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)
    Q_PROPERTY(QString errorMessage READ errorMessage NOTIFY statusChanged)
    Q_PROPERTY(QString statusMessage READ statusMessage NOTIFY statusChanged)

public:
    explicit AiAssistant(const QSqlDatabase &database, const QUrl &endpoint = {},
                         QObject *parent = nullptr);
    QVariantList sessions() const { return m_sessions; }
    QVariantList messages() const { return m_messages; }
    QVariantList poemChoices() const { return m_poemChoices; }
    QVariantMap context() const { return m_context; }
    QString sessionId() const { return m_sessionId; }
    QString mode() const { return m_mode; }
    QString liveText() const { return m_liveText; }
    bool busy() const { return m_busy; }
    QString errorMessage() const { return m_error; }
    QString statusMessage() const { return m_status; }

    Q_INVOKABLE bool newChat(const QString &mode = QStringLiteral("chat"));
    Q_INVOKABLE bool selectSession(const QString &id);
    Q_INVOKABLE bool deleteSession(const QString &id);
    Q_INVOKABLE bool usePoem(int poemId);
    Q_INVOKABLE bool addComparePoem(int poemId);
    Q_INVOKABLE bool openWithPoem(int poemId);
    Q_INVOKABLE bool openWithPoet(const QString &name, const QString &description);
    Q_INVOKABLE bool openWithImagery(const QString &name, const QString &description);
    Q_INVOKABLE void searchPoems(const QString &keyword);
    Q_INVOKABLE bool send(const QString &message);
    Q_INVOKABLE bool regenerate();
    Q_INVOKABLE bool continueAnswer();
    Q_INVOKABLE void cancel();
    Q_INVOKABLE void copyText(const QString &text) const;

signals:
    void sessionsChanged();
    void messagesChanged();
    void poemChoicesChanged();
    void contextChanged();
    void sessionChanged();
    void liveChanged();
    void busyChanged();
    void statusChanged();

private:
    bool ensureSchema();
    bool loadSessions();
    bool loadMessages();
    bool saveContext();
    QVariantMap poem(int id) const;
    QVariantList candidatePoems(const QString &query) const;
    bool appendMessage(const QString &role, const QString &content);
    bool startRequest();
    void consumeStream();
    void finishRequest();
    void fail(const QString &message);
    void setStatus(const QString &message);
    QString defaultPrompt() const;
    static bool validMode(const QString &mode);

    QSqlDatabase m_database;
    QUrl m_endpoint;
    QNetworkAccessManager m_network;
    QNetworkReply *m_reply = nullptr;
    QTimer m_timeout;
    QByteArray m_streamBuffer;
    QVariantList m_sessions, m_messages, m_poemChoices;
    QVariantMap m_context;
    QString m_sessionId, m_mode = QStringLiteral("chat"), m_liveText, m_error, m_status;
    bool m_busy = false;
    bool m_streamDone = false;
    bool m_streamTruncated = false;
    bool m_regenerating = false;
};
