#pragma once

#include <QObject>
#include <QSqlDatabase>
#include <QString>
#include <QVector>

class HomeController final : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString poemTitle READ poemTitle NOTIFY poemChanged)
    Q_PROPERTY(QString poemAuthor READ poemAuthor NOTIFY poemChanged)
    Q_PROPERTY(QString poemDynasty READ poemDynasty NOTIFY poemChanged)
    Q_PROPERTY(QString poemExcerpt READ poemExcerpt NOTIFY poemChanged)
    Q_PROPERTY(int poemPosition READ poemPosition NOTIFY poemChanged)
    Q_PROPERTY(int poemCount READ poemCount NOTIFY poemChanged)
    Q_PROPERTY(QString errorMessage READ errorMessage NOTIFY errorMessageChanged)

public:
    explicit HomeController(QObject *parent = nullptr);
    ~HomeController() override;

    QString poemTitle() const;
    QString poemAuthor() const;
    QString poemDynasty() const;
    QString poemExcerpt() const;
    int poemPosition() const;
    int poemCount() const;
    QString errorMessage() const;
    QSqlDatabase database() const { return m_database; }

    Q_INVOKABLE void nextPoem();
    Q_INVOKABLE void previousPoem();

signals:
    void poemChanged();
    void errorMessageChanged();

private:
    struct Poem {
        int id = 0;
        QString title;
        QString author;
        QString dynasty;
        QString excerpt;
    };

    bool openDatabase();
    bool createSchemaAndSeed();
    bool loadPoems();
    void setError(const QString &message);
    const Poem *currentPoem() const;

    QSqlDatabase m_database;
    QVector<Poem> m_poems;
    int m_index = -1;
    QString m_errorMessage;
};
