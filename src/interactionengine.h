#pragma once

#include <QObject>
#include <QSqlDatabase>
#include <QSet>
#include <QTimer>
#include <QVariantList>
#include <QVariantMap>
#include <QVector>

class InteractionEngine final : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString phase READ phase NOTIFY stateChanged)
    Q_PROPERTY(QString mode READ mode NOTIFY stateChanged)
    Q_PROPERTY(QVariantMap question READ question NOTIFY stateChanged)
    Q_PROPERTY(int questionNumber READ questionNumber NOTIFY stateChanged)
    Q_PROPERTY(int questionCount READ questionCount NOTIFY stateChanged)
    Q_PROPERTY(int score READ score NOTIFY stateChanged)
    Q_PROPERTY(int correctCount READ correctCount NOTIFY stateChanged)
    Q_PROPERTY(int streak READ streak NOTIFY stateChanged)
    Q_PROPERTY(int timeLeft READ timeLeft NOTIFY stateChanged)
    Q_PROPERTY(QString hintText READ hintText NOTIFY stateChanged)
    Q_PROPERTY(QString feedback READ feedback NOTIFY stateChanged)
    Q_PROPERTY(QString correctAnswer READ correctAnswer NOTIFY stateChanged)
    Q_PROPERTY(QString statusMessage READ statusMessage NOTIFY stateChanged)
    Q_PROPERTY(QString errorMessage READ errorMessage NOTIFY stateChanged)
    Q_PROPERTY(QVariantMap stats READ stats NOTIFY recordsChanged)
    Q_PROPERTY(QVariantList recentRounds READ recentRounds NOTIFY recordsChanged)
    Q_PROPERTY(QVariantList mistakes READ mistakes NOTIFY recordsChanged)
    Q_PROPERTY(QVariantList roundResults READ roundResults NOTIFY stateChanged)

public:
    explicit InteractionEngine(const QSqlDatabase &database, QObject *parent = nullptr);

    QString phase() const { return m_phase; }
    QString mode() const { return m_mode; }
    QVariantMap question() const;
    int questionNumber() const { return m_phase == QStringLiteral("idle") ? 0 : m_index + 1; }
    int questionCount() const { return m_round.size(); }
    int score() const { return m_score; }
    int correctCount() const { return m_correctCount; }
    int streak() const { return m_streak; }
    int timeLeft() const { return m_timeLeft; }
    QString hintText() const { return m_hintText; }
    QString feedback() const { return m_feedback; }
    QString correctAnswer() const { return m_phase == QStringLiteral("feedback") ? m_answer : QString(); }
    QString statusMessage() const { return m_statusMessage; }
    QString errorMessage() const { return m_error; }
    QVariantMap stats() const { return m_stats; }
    QVariantList recentRounds() const { return m_recentRounds; }
    QVariantList mistakes() const { return m_mistakes; }
    QVariantList roundResults() const { return m_roundResults; }

    Q_INVOKABLE bool start(const QString &mode, int count);
    Q_INVOKABLE bool startPuzzle(const QString &difficulty, int count);
    Q_INVOKABLE bool startRetry();
    Q_INVOKABLE void submit(const QString &answer);
    Q_INVOKABLE void hint();
    Q_INVOKABLE void skip();
    Q_INVOKABLE void showAnswer();
    Q_INVOKABLE void advance();
    Q_INVOKABLE void next();
    Q_INVOKABLE void abort();
    Q_INVOKABLE void placePiece(int tileId, int slotIndex);
    Q_INVOKABLE void removePiece(int slotIndex);
    Q_INVOKABLE void submitPuzzle();

    QString expectedAnswerForTest() const;
    static QString normalizeAnswer(const QString &text);

signals:
    void stateChanged();
    void recordsChanged();

private:
    struct Poem {
        int id = 0;
        QString title, author, dynasty, content;
    };
    struct Question {
        QString mode, kind, prompt, subtitle, answer, sourceLine, poemTitle;
        int poemId = 0;
        QStringList options;
        QString command, extraCommand, computerLine, computerSource, difficulty;
        QString fullPoem, background, backgroundLabel;
        int minLength = 0;
        QStringList targetPieces;
        QVariantList tiles;
    };
    struct FeihuaLine {
        QString text, normalized, title, author;
        int poemId = 0;
    };

    bool loadPoems();
    bool ensureSchema();
    void refreshRecords();
    QVector<Question> candidates(const QString &mode) const;
    QVector<Question> pairQuestions(const QString &mode) const;
    QVector<Question> quizQuestions() const;
    QVector<Question> puzzleQuestions(const QString &difficulty) const;
    void buildPuzzleTiles(Question &question) const;
    void preparePuzzleTurn();
    bool puzzleCorrect(const Question &question) const;
    QString placedPuzzleText(const Question &question) const;
    bool prepareFeihuaTurn();
    const FeihuaLine *findFeihuaLine(const QString &given) const;
    QStringList makeOptions(const QString &kind, const QString &answer) const;
    bool beginRound(const QString &mode, QVector<Question> questions, int count);
    void resolve(const QString &given, bool skipped, bool revealed);
    void finishRound();
    void setError(const QString &message);
    const Question *current() const;

    QSqlDatabase m_database;
    QVector<Poem> m_poems;
    QVector<FeihuaLine> m_feihuaLines;
    QVector<Question> m_round;
    QString m_phase = QStringLiteral("idle");
    QString m_mode;
    QString m_session;
    int m_index = 0;
    int m_score = 0;
    int m_correctCount = 0;
    int m_streak = 0;
    bool m_hinted = false;
    bool m_timedOut = false;
    int m_timeLeft = 0;
    QTimer m_turnTimer;
    QSet<QString> m_usedLines;
    QVector<int> m_puzzleSlots;
    QString m_hintText, m_feedback, m_answer, m_statusMessage, m_error;
    QVariantMap m_stats;
    QVariantList m_recentRounds, m_mistakes, m_roundResults;
};
