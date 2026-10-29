#pragma once

#include <QAbstractListModel>
#include <QSqlDatabase>
#include <QStringList>
#include <QVector>

class ShiciCalendar;

class PoemCatalog final : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(int resultCount READ resultCount NOTIFY resultCountChanged)
    Q_PROPERTY(bool hasMore READ hasMore NOTIFY hasMoreChanged)
    Q_PROPERTY(QStringList dynasties READ dynasties NOTIFY optionsChanged)
    Q_PROPERTY(QStringList authors READ authors NOTIFY optionsChanged)
    Q_PROPERTY(QStringList forms READ forms NOTIFY optionsChanged)
    Q_PROPERTY(QStringList themes READ themes NOTIFY optionsChanged)
    Q_PROPERTY(int selectedId READ selectedId NOTIFY selectedChanged)
    Q_PROPERTY(QString selectedTitle READ selectedTitle NOTIFY selectedChanged)
    Q_PROPERTY(QString selectedAuthor READ selectedAuthor NOTIFY selectedChanged)
    Q_PROPERTY(QString selectedDynasty READ selectedDynasty NOTIFY selectedChanged)
    Q_PROPERTY(QString selectedForm READ selectedForm NOTIFY selectedChanged)
    Q_PROPERTY(QString selectedTheme READ selectedTheme NOTIFY selectedChanged)
    Q_PROPERTY(QString selectedContent READ selectedContent NOTIFY selectedChanged)
    Q_PROPERTY(QString selectedAnnotation READ selectedAnnotation NOTIFY selectedChanged)
    Q_PROPERTY(QString selectedTranslation READ selectedTranslation NOTIFY selectedChanged)
    Q_PROPERTY(QString selectedAppreciation READ selectedAppreciation NOTIFY selectedChanged)
    Q_PROPERTY(QString selectedNote READ selectedNote NOTIFY selectedChanged)
    Q_PROPERTY(bool selectedFavorite READ selectedFavorite NOTIFY selectedChanged)
    Q_PROPERTY(QString errorMessage READ errorMessage NOTIFY errorMessageChanged)

public:
    enum Roles {
        IdRole = Qt::UserRole + 1,
        TitleRole, AuthorRole, DynastyRole, ExcerptRole,
        FormRole, ThemeRole, FavoriteRole
    };

    explicit PoemCatalog(const QSqlDatabase &database, QObject *parent = nullptr,
                         const ShiciCalendar *shici = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    int resultCount() const { return m_resultCount; }
    bool hasMore() const { return m_rows.size() < m_resultCount; }
    QStringList dynasties() const { return m_dynasties; }
    QStringList authors() const { return m_authors; }
    QStringList forms() const { return m_forms; }
    QStringList themes() const { return m_themes; }

    int selectedId() const { return m_selectedId; }
    QString selectedTitle() const { return m_selectedTitle; }
    QString selectedAuthor() const { return m_selectedAuthor; }
    QString selectedDynasty() const { return m_selectedDynasty; }
    QString selectedForm() const { return m_selectedForm; }
    QString selectedTheme() const { return m_selectedTheme; }
    QString selectedContent() const { return m_selectedContent; }
    QString selectedAnnotation() const { return m_selectedAnnotation; }
    QString selectedTranslation() const { return m_selectedTranslation; }
    QString selectedAppreciation() const { return m_selectedAppreciation; }
    QString selectedNote() const { return m_selectedNote; }
    bool selectedFavorite() const { return m_selectedFavorite; }
    QString errorMessage() const { return m_errorMessage; }

    Q_INVOKABLE void search(const QString &keyword, const QString &dynasty,
                            const QString &author, const QString &form,
                            const QString &theme, const QString &sort);
    Q_INVOKABLE void loadNextPage();
    Q_INVOKABLE void activate();
    Q_INVOKABLE void selectPoem(int id);
    Q_INVOKABLE void toggleFavorite();
    Q_INVOKABLE void saveNote(const QString &text);
    Q_INVOKABLE void deleteNote();
    Q_INVOKABLE void refreshPersonalData();
    Q_INVOKABLE int importJsonFile(const QString &path);

signals:
    void resultCountChanged();
    void hasMoreChanged();
    void optionsChanged();
    void selectedChanged();
    void errorMessageChanged();
    void notice(const QString &message);
    void historyChanged();

private:
    struct Row {
        int id = 0;
        QString title, author, dynasty, excerpt, form, theme;
        bool favorite = false;
    };

    bool ensureSchema();
    bool syncShici();
    bool ensureColumn(const QString &name, const QString &sqlType);
    bool refreshOptions();
    bool updateResultCount();
    QString whereClause(QVariantList &values) const;
    QString orderClause() const;
    void clearSelection();
    void setError(const QString &message);
    void updateVisibleFavorite(int id, bool favorite);

    QSqlDatabase m_database;
    const ShiciCalendar *m_shici = nullptr;
    bool m_ready = false;
    QVector<Row> m_rows;
    int m_resultCount = 0;
    QString m_keyword, m_dynasty, m_author, m_form, m_theme, m_sort;
    QStringList m_dynasties, m_authors, m_forms, m_themes;

    int m_selectedId = 0;
    QString m_selectedTitle, m_selectedAuthor, m_selectedDynasty;
    QString m_selectedForm, m_selectedTheme, m_selectedContent;
    QString m_selectedAnnotation, m_selectedTranslation, m_selectedAppreciation;
    QString m_selectedNote;
    bool m_selectedFavorite = false;
    QString m_errorMessage;
    bool m_opened = false;
};
