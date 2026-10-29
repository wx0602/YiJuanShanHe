#pragma once

#include <QObject>
#include <QTimer>
#include <QVariantList>
#include <QVariantMap>
#include <QVector>
#include <QSqlDatabase>

class JourneyModel final : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QVariantList poetOptions READ poetOptions CONSTANT)
    Q_PROPERTY(QString selectedPoetId READ selectedPoetId NOTIFY poetChanged)
    Q_PROPERTY(QVariantMap selectedPoet READ selectedPoet NOTIFY poetChanged)
    Q_PROPERTY(QVariantList stages READ stages NOTIFY poetChanged)
    Q_PROPERTY(QVariantList stops READ stops NOTIFY poetChanged)
    Q_PROPERTY(int stopCount READ stopCount NOTIFY poetChanged)
    Q_PROPERTY(int currentIndex READ currentIndex NOTIFY positionChanged)
    Q_PROPERTY(QVariantMap currentStop READ currentStop NOTIFY positionChanged)
    Q_PROPERTY(int activeStage READ activeStage NOTIFY positionChanged)
    Q_PROPERTY(bool playing READ playing NOTIFY playingChanged)
    Q_PROPERTY(double speed READ speed NOTIFY speedChanged)
    Q_PROPERTY(QString errorMessage READ errorMessage NOTIFY errorChanged)
    Q_PROPERTY(QVariantList placeEvents READ placeEvents NOTIFY positionChanged)
    Q_PROPERTY(QVariantList relatedPoems READ relatedPoems NOTIFY positionChanged)
    Q_PROPERTY(QVariantMap stagePoem READ stagePoem NOTIFY positionChanged)

public:
    explicit JourneyModel(const QString &poetsPath = QStringLiteral(":/data/poets.json"),
                          const QString &journeysPath = QStringLiteral(":/data/journeys.json"),
                          QObject *parent = nullptr);

    QVariantList poetOptions() const;
    QString selectedPoetId() const;
    QVariantMap selectedPoet() const;
    QVariantList stages() const;
    QVariantList stops() const;
    int stopCount() const;
    int currentIndex() const { return m_currentIndex; }
    QVariantMap currentStop() const;
    int activeStage() const;
    bool playing() const { return m_playing; }
    double speed() const { return m_speed; }
    QString errorMessage() const { return m_error; }
    QVariantList placeEvents() const;
    QVariantList relatedPoems() const;
    QVariantMap stagePoem() const;
    void setPoemDatabase(const QSqlDatabase &database);
    Q_INVOKABLE QVariantMap cameraFor(double width, double height, bool overview,
                                     double usableFraction = 1.0, int focusIndex = -1) const;

    Q_INVOKABLE bool selectPoet(const QString &id);
    Q_INVOKABLE void seek(int index);
    Q_INVOKABLE void seekStage(int stageIndex);
    Q_INVOKABLE void next();
    Q_INVOKABLE void previous();
    Q_INVOKABLE void play();
    Q_INVOKABLE void pause();
    Q_INVOKABLE void restart();
    Q_INVOKABLE void setSpeed(double speed);

signals:
    void poetChanged();
    void positionChanged();
    void playingChanged();
    void speedChanged();
    void errorChanged();

private:
    struct Journey {
        QString id, name, dynasty, years, intro, tone, subtitle;
        QVariantList stages, stops;
    };
    const Journey *selected() const;
    void setError(const QString &message);
    void updateTimer();

    QVector<Journey> m_journeys;
    QString m_selectedId, m_error;
    int m_currentIndex = 0;
    bool m_playing = false;
    double m_speed = 1.0;
    QTimer m_timer;
    QSqlDatabase m_poemDatabase;
    QVariantList m_stationReadingLinks;
};
