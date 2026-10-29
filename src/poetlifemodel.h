#pragma once

#include <QAbstractListModel>
#include <QJsonObject>
#include <QVariantList>
#include <QVariantMap>
#include <QVector>

class PoetLifeModel final : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(int resultCount READ resultCount NOTIFY resultsChanged)
    Q_PROPERTY(QString errorMessage READ errorMessage NOTIFY errorChanged)
    Q_PROPERTY(QString selectedId READ selectedId NOTIFY selectionChanged)
    Q_PROPERTY(QVariantMap selectedProfile READ selectedProfile NOTIFY selectionChanged)
    Q_PROPERTY(QVariantList selectedStages READ selectedStages NOTIFY selectionChanged)
    Q_PROPERTY(QVariantList selectedEvents READ selectedEvents NOTIFY selectionChanged)
    Q_PROPERTY(QString compareAId READ compareAId NOTIFY comparisonChanged)
    Q_PROPERTY(QString compareBId READ compareBId NOTIFY comparisonChanged)
    Q_PROPERTY(QVariantMap compareAProfile READ compareAProfile NOTIFY comparisonChanged)
    Q_PROPERTY(QVariantMap compareBProfile READ compareBProfile NOTIFY comparisonChanged)
    Q_PROPERTY(QVariantList compareAStages READ compareAStages NOTIFY comparisonChanged)
    Q_PROPERTY(QVariantList compareBStages READ compareBStages NOTIFY comparisonChanged)
    Q_PROPERTY(QVariantList compareAEvents READ compareAEvents NOTIFY comparisonChanged)
    Q_PROPERTY(QVariantList compareBEvents READ compareBEvents NOTIFY comparisonChanged)

public:
    enum Roles { IdRole = Qt::UserRole + 1, NameRole, DynastyRole, YearsRole,
                 EpithetRole, CourtesyRole, ToneRole };
    explicit PoetLifeModel(const QString &jsonPath = QStringLiteral(":/data/poets.json"), QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    int resultCount() const { return m_visible.size(); }
    QString errorMessage() const { return m_error; }
    QString selectedId() const { return m_selectedId; }
    QVariantMap selectedProfile() const;
    QVariantList selectedStages() const;
    QVariantList selectedEvents() const;
    QString compareAId() const { return m_compareA; }
    QString compareBId() const { return m_compareB; }
    QVariantMap compareAProfile() const;
    QVariantMap compareBProfile() const;
    QVariantList compareAStages() const;
    QVariantList compareBStages() const;
    QVariantList compareAEvents() const;
    QVariantList compareBEvents() const;

    Q_INVOKABLE void search(const QString &keyword);
    Q_INVOKABLE bool selectPoet(const QString &id);
    Q_INVOKABLE bool setComparison(int slot, const QString &id);

signals:
    void resultsChanged();
    void errorChanged();
    void selectionChanged();
    void comparisonChanged();

private:
    struct Poet {
        QString id, name, dynasty, years, epithet, courtesy, tone, motto, intro;
        int birthYear = 0, deathYear = 0;
        QVariantList sources, stages, events;
    };
    const Poet *find(const QString &id) const;
    QVariantMap profile(const QString &id) const;
    QVariantList stages(const QString &id) const;
    QVariantList events(const QString &id) const;
    void setError(const QString &message);
    QVector<Poet> m_poets;
    QVector<int> m_visible;
    QString m_selectedId, m_compareA, m_compareB, m_error;
};
