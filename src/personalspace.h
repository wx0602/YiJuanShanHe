#pragma once

#include <QObject>
#include <QSqlDatabase>
#include <QVariantList>
#include <QVariantMap>

class PersonalSpace final : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QVariantMap stats READ stats NOTIFY dataChanged)
    Q_PROPERTY(QVariantList favorites READ favorites NOTIFY dataChanged)
    Q_PROPERTY(QVariantList notes READ notes NOTIFY dataChanged)
    Q_PROPERTY(QVariantList history READ history NOTIFY dataChanged)
    Q_PROPERTY(QVariantList modes READ modes NOTIFY dataChanged)
    Q_PROPERTY(QVariantList trend READ trend NOTIFY dataChanged)
    Q_PROPERTY(QVariantList rounds READ rounds NOTIFY dataChanged)
    Q_PROPERTY(QVariantList mistakes READ mistakes NOTIFY dataChanged)
    Q_PROPERTY(QStringList authors READ authors NOTIFY dataChanged)
    Q_PROPERTY(QString nickname READ nickname NOTIFY settingsChanged)
    Q_PROPERTY(QString avatar READ avatar NOTIFY settingsChanged)
    Q_PROPERTY(int readingFontSize READ readingFontSize NOTIFY settingsChanged)
    Q_PROPERTY(bool animationsEnabled READ animationsEnabled NOTIFY settingsChanged)
    Q_PROPERTY(QString theme READ theme NOTIFY settingsChanged)
    Q_PROPERTY(QString errorMessage READ errorMessage NOTIFY errorChanged)

public:
    explicit PersonalSpace(const QSqlDatabase &database, QObject *parent = nullptr);

    QVariantMap stats() const { return m_stats; }
    QVariantList favorites() const { return m_favorites; }
    QVariantList notes() const { return m_notes; }
    QVariantList history() const { return m_history; }
    QVariantList modes() const { return m_modes; }
    QVariantList trend() const { return m_trend; }
    QVariantList rounds() const { return m_rounds; }
    QVariantList mistakes() const { return m_mistakes; }
    QStringList authors() const { return m_authors; }
    QString nickname() const { return m_nickname; }
    QString avatar() const { return m_avatar; }
    int readingFontSize() const { return m_readingFontSize; }
    bool animationsEnabled() const { return m_animationsEnabled; }
    QString theme() const { return m_theme; }
    QString errorMessage() const { return m_error; }

    Q_INVOKABLE void refresh();
    Q_INVOKABLE void setFavoriteQuery(const QString &keyword, const QString &sort);
    Q_INVOKABLE void setNoteQuery(const QString &author, const QString &sort);
    Q_INVOKABLE void setHistoryDate(const QString &date);
    Q_INVOKABLE bool removeFavorite(int poemId);
    Q_INVOKABLE bool saveNote(int poemId, const QString &body);
    Q_INVOKABLE bool deleteNote(int poemId);
    Q_INVOKABLE bool clearHistory();
    Q_INVOKABLE bool saveSettings(const QString &nickname, const QString &avatar,
                                  int readingFontSize, bool animationsEnabled,
                                  const QString &theme);
    Q_INVOKABLE bool setTheme(const QString &theme);

signals:
    void dataChanged();
    void settingsChanged();
    void errorChanged();
    void libraryChanged();

private:
    bool ensureSchema();
    bool loadSettings();
    bool loadStats();
    bool loadFavorites();
    bool loadNotes();
    bool loadHistory();
    bool loadLearning();
    void setError(const QString &message);
    static QString localDate(const QString &timestamp);
    static QString modeTitle(const QString &mode);

    QSqlDatabase m_database;
    QVariantMap m_stats;
    QVariantList m_favorites, m_notes, m_history, m_modes, m_trend, m_rounds, m_mistakes;
    QStringList m_authors;
    QString m_nickname = QStringLiteral("山河旅人");
    QString m_avatar = QStringLiteral("山");
    int m_readingFontSize = 23;
    bool m_animationsEnabled = true;
    QString m_theme = QStringLiteral("月白");
    QString m_favoriteKeyword, m_favoriteSort, m_noteAuthor, m_noteSort, m_historyDate;
    QString m_error;
};
