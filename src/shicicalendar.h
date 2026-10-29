#pragma once

#include <QDate>
#include <QObject>
#include <QTimer>
#include <QVariantList>
#include <QVariantMap>
#include <QVector>

class ShiciCalendar final : public QObject
{
    Q_OBJECT
    Q_PROPERTY(int year READ year NOTIFY monthChanged)
    Q_PROPERTY(int month READ month NOTIFY monthChanged)
    Q_PROPERTY(int daysInMonth READ daysInMonth NOTIFY monthChanged)
    Q_PROPERTY(QVariantList days READ days NOTIFY monthChanged)
    Q_PROPERTY(QString monthLabel READ monthLabel NOTIFY monthChanged)
    Q_PROPERTY(QString selectedDateLabel READ selectedDateLabel NOTIFY selectionChanged)
    Q_PROPERTY(int selectedDay READ selectedDay NOTIFY selectionChanged)
    Q_PROPERTY(int todayDay READ todayDay NOTIFY todayChanged)
    Q_PROPERTY(bool showingToday READ showingToday NOTIFY todayChanged)
    Q_PROPERTY(QString title READ title NOTIFY selectionChanged)
    Q_PROPERTY(QString attribution READ attribution NOTIFY selectionChanged)
    Q_PROPERTY(QString content READ content NOTIFY selectionChanged)
    Q_PROPERTY(QString preview READ preview NOTIFY selectionChanged)
    Q_PROPERTY(QString errorMessage READ errorMessage CONSTANT)
    Q_PROPERTY(int poemCount READ poemCount CONSTANT)

public:
    explicit ShiciCalendar(const QString &path = QStringLiteral(":/shici.txt"),
                           QObject *parent = nullptr,
                           const QDate &today = QDate::currentDate());

    int year() const { return m_month.year(); }
    int month() const { return m_month.month(); }
    int daysInMonth() const { return m_month.daysInMonth(); }
    QVariantList days() const;
    QString monthLabel() const;
    QString selectedDateLabel() const;
    int selectedDay() const { return m_selected.day(); }
    int todayDay() const { return m_today.day(); }
    bool showingToday() const { return m_month.year() == m_today.year() && m_month.month() == m_today.month(); }
    QString title() const;
    QString attribution() const;
    QString content() const;
    QString preview() const;
    QString errorMessage() const { return m_error; }
    int poemCount() const { return m_poems.size(); }
    QDate selectedDate() const { return m_selected; }
    QVariantMap poemAt(int day) const;

    Q_INVOKABLE void shiftMonth(int offset);
    Q_INVOKABLE void selectDay(int day);
    Q_INVOKABLE void goToday();
    void setTodayForTest(const QDate &today);

signals:
    void monthChanged();
    void selectionChanged();
    void todayChanged();

private:
    struct Poem { QString title, attribution, content, annotation, translation, appreciation; };
    void load(const QString &path);
    const Poem *selectedPoem() const;
    void refreshToday();

    QVector<Poem> m_poems;
    QDate m_today;
    QDate m_month;
    QDate m_selected;
    QString m_error;
    QTimer m_todayTimer;
    bool m_userSelected = false;
};
