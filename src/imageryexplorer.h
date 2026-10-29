#pragma once

#include <QObject>
#include <QSqlDatabase>
#include <QVariantList>
#include <QStringList>
#include <QVector>

class ImageryExplorer final : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QVariantList items READ items NOTIFY changed)
    Q_PROPERTY(QVariantList nodes READ nodes NOTIFY changed)
    Q_PROPERTY(QVariantList edges READ edges NOTIFY changed)
    Q_PROPERTY(QVariantList skyEdges READ skyEdges NOTIFY changed)
    Q_PROPERTY(QVariantList poems READ poems NOTIFY changed)
    Q_PROPERTY(QStringList dynasties READ dynasties NOTIFY changed)
    Q_PROPERTY(QStringList categories READ categories NOTIFY changed)
    Q_PROPERTY(QString center READ center NOTIFY changed)
    Q_PROPERTY(QString pair READ pair NOTIFY changed)
    Q_PROPERTY(QString description READ description NOTIFY changed)
    Q_PROPERTY(QString dynasty READ dynasty NOTIFY changed)
    Q_PROPERTY(QString category READ category NOTIFY changed)
    Q_PROPERTY(QString query READ query NOTIFY changed)
    Q_PROPERTY(int centerCount READ centerCount NOTIFY changed)
    Q_PROPERTY(int pairCount READ pairCount NOTIFY changed)
    Q_PROPERTY(int corpusCount READ corpusCount NOTIFY changed)
    Q_PROPERTY(QString error READ error NOTIFY changed)

public:
    explicit ImageryExplorer(const QSqlDatabase &database, const QString &dictionaryPath = {},
                             QObject *parent = nullptr);
    QVariantList items() const { return m_items; }
    QVariantList nodes() const { return m_nodes; }
    QVariantList edges() const { return m_edges; }
    QVariantList skyEdges() const { return m_skyEdges; }
    QVariantList poems() const { return m_poems; }
    QStringList dynasties() const { return m_dynasties; }
    QStringList categories() const { return m_categories; }
    QString center() const { return m_center; }
    QString pair() const { return m_pair; }
    QString description() const { return m_description; }
    QString dynasty() const { return m_dynasty; }
    QString category() const { return m_category; }
    QString query() const { return m_query; }
    int centerCount() const { return m_centerCount; }
    int pairCount() const { return m_pairCount; }
    int corpusCount() const { return m_corpusCount; }
    QString error() const { return m_error; }

    Q_INVOKABLE void refresh();
    Q_INVOKABLE void setCenter(const QString &key);
    Q_INVOKABLE void selectPair(const QString &key);
    Q_INVOKABLE void clearPair();
    Q_INVOKABLE void setDynasty(const QString &value);
    Q_INVOKABLE void setCategory(const QString &value);
    Q_INVOKABLE void setQuery(const QString &value);

signals:
    void changed();

private:
    struct Term { QString key, category, description; QStringList aliases, exclusions; };
    struct Poem { int id = 0; QString title, author, dynasty, content; QVector<int> matches; };
    bool loadDictionary();
    bool matches(const QString &text, const Term &term) const;
    QString excerpt(const Poem &poem) const;
    QString markedExcerpt(const QString &text) const;
    void rebuild();
    int indexOf(const QString &key) const;

    QSqlDatabase m_database;
    QString m_dictionaryPath;
    QVector<Term> m_terms;
    QVector<Poem> m_allPoems;
    QVariantList m_items, m_nodes, m_edges, m_skyEdges, m_poems;
    QStringList m_dynasties{QStringLiteral("全部朝代")};
    QStringList m_categories{QStringLiteral("全部意象")};
    QString m_center{QStringLiteral("月")}, m_pair, m_description, m_dynasty, m_category, m_query, m_error;
    int m_centerCount = 0, m_pairCount = 0, m_corpusCount = 0;
};
