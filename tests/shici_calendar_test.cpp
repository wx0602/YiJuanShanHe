#include "../src/shicicalendar.h"

#include <QCoreApplication>
#include <QFile>
#include <QTemporaryDir>
#include <QTextStream>

static bool check(bool condition, const QString &message)
{
    if (!condition) QTextStream(stderr) << "FAILED: " << message << Qt::endl;
    return condition;
}

int main(int argc, char *argv[])
{
    QCoreApplication app(argc, argv);
    ShiciCalendar calendar(QStringLiteral(":/shici.txt"), nullptr, QDate(2024, 2, 29));
    if (!check(calendar.errorMessage().isEmpty() && calendar.poemCount() == 64
               && calendar.year() == 2024 && calendar.month() == 2
               && calendar.daysInMonth() == 29 && calendar.selectedDay() == 29
               && calendar.title() == QStringLiteral("临江仙・滚滚长江东逝水"),
               QStringLiteral("64 poems, leap day and day-to-poem mapping"))) return 1;
    if (!check(calendar.poemAt(64).value(QStringLiteral("title")).toString()
                   == QStringLiteral("感遇十二首（其一）")
               && !calendar.poemAt(64).value(QStringLiteral("appreciation")).toString().isEmpty(),
               QStringLiteral("last archive poem and commentary loaded"))) return 1;
    if (!check(calendar.poemAt(61).value(QStringLiteral("content")).toString()
                   .startsWith(QStringLiteral("自河南经乱"))
               && calendar.poemAt(61).value(QStringLiteral("content")).toString()
                   .contains(QStringLiteral("共看明月应垂泪")),
               QStringLiteral("poem preface and full verse preserved"))) return 1;
    const QVariantList february = calendar.days();
    if (!check(february.size() == 35 && february.at(0).toInt() == 0
               && february.at(3).toInt() == 1 && february.at(31).toInt() == 29,
               QStringLiteral("Monday-first real February grid"))) return 1;

    calendar.shiftMonth(1);
    if (!check(calendar.month() == 3 && calendar.daysInMonth() == 31
               && calendar.selectedDay() == 29,
               QStringLiteral("month change retains available day"))) return 1;
    calendar.selectDay(31);
    if (!check(calendar.selectedDay() == 31
               && calendar.title() == QStringLiteral("旅夜书怀")
               && calendar.content().contains(QStringLiteral("天地一沙鸥。")),
               QStringLiteral("day 31 retains complete original poem"))) return 1;
    calendar.shiftMonth(-1);
    if (!check(calendar.selectedDay() == 29 && calendar.month() == 2,
               QStringLiteral("31st clamps to leap February"))) return 1;
    calendar.selectDay(4);
    if (!check(calendar.title() == QStringLiteral("沁园春·雪")
               && calendar.attribution() == QStringLiteral("毛泽东")
               && calendar.content().contains(QStringLiteral("江山如此多娇"))
               && calendar.content().endsWith(QStringLiteral("还看今朝。"))
               && !calendar.poemAt(4).value(QStringLiteral("annotation")).toString().isEmpty()
               && !calendar.poemAt(4).value(QStringLiteral("translation")).toString().isEmpty()
               && !calendar.poemAt(4).value(QStringLiteral("appreciation")).toString().isEmpty(),
               QStringLiteral("long poem and all supplied reading sections are complete"))) return 1;
    calendar.selectDay(31);
    if (!check(calendar.selectedDay() == 4, QStringLiteral("invalid date is ignored"))) return 1;

    calendar.setTodayForTest(QDate(2025, 1, 31));
    calendar.goToday();
    if (!check(calendar.month() == 1 && calendar.selectedDay() == 31 && calendar.showingToday(),
               QStringLiteral("return to system day"))) return 1;
    calendar.setTodayForTest(QDate(2025, 2, 1));
    if (!check(calendar.month() == 2 && calendar.selectedDay() == 1
               && calendar.title() == QStringLiteral("献钱尚父"),
               QStringLiteral("date rollover updates month and first poem"))) return 1;
    if (!check(calendar.daysInMonth() == 28,
               QStringLiteral("ordinary February has 28 days"))) return 1;
    calendar.shiftMonth(1);
    if (!check(calendar.month() == 3 && calendar.days().size() == 42,
               QStringLiteral("six-week month fits calendar grid"))) return 1;

    QTemporaryDir temporary;
    const QString badPath = temporary.filePath(QStringLiteral("shici.txt"));
    QFile bad(badPath);
    if (!check(bad.open(QIODevice::WriteOnly), QStringLiteral("malformed fixture"))) return 1;
    bad.write(QStringLiteral("01 Test｜唐·Author\n正文\n").toUtf8()); bad.close();
    ShiciCalendar broken(badPath, nullptr, QDate(2025, 1, 1));
    if (!check(broken.poemCount() == 0 && !broken.errorMessage().isEmpty(),
               QStringLiteral("missing body and count produce visible error"))) return 1;
    ShiciCalendar missing(temporary.filePath(QStringLiteral("absent.txt")), nullptr, QDate(2025, 1, 1));
    if (!check(missing.poemCount() == 0 && !missing.errorMessage().isEmpty(),
               QStringLiteral("missing file produces visible error"))) return 1;

    QTextStream(stdout) << "shici calendar tests passed" << Qt::endl;
    return 0;
}
