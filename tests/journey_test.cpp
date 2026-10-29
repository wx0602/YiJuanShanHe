#include "../src/journeymodel.h"

#include <QCoreApplication>
#include <QFile>
#include <QTemporaryDir>
#include <QTextStream>
#include <QSqlDatabase>
#include <QSqlQuery>

static bool check(bool condition, const QString &message)
{
    if (!condition) QTextStream(stderr) << "FAILED: " << message << Qt::endl;
    return condition;
}

int main(int argc, char *argv[])
{
    QCoreApplication app(argc, argv);
    JourneyModel journey;
    if (!check(journey.errorMessage().isEmpty() && journey.poetOptions().size() == 8,
               QStringLiteral("independent journey and poet JSON load"))) return 1;

    int linkedReadings = 0;
    for (const QString &id : {QStringLiteral("taoyuanming"), QStringLiteral("libai"),
                              QStringLiteral("dufu"), QStringLiteral("baijuyi"),
                              QStringLiteral("ouyangxiu"), QStringLiteral("sushi"),
                              QStringLiteral("luyou"), QStringLiteral("xinqiji")}) {
        if (!check(journey.selectPoet(id) && journey.stopCount() >= 6
                   && journey.stages().size() == 4 && !journey.selectedPoet().value(QStringLiteral("name")).toString().isEmpty(),
                   QStringLiteral("poet and stages: ") + id)) return 1;
        int previousYear = 0;
        for (const QVariant &value : journey.stops()) {
            const QVariantMap stop = value.toMap();
            const int year = stop.value(QStringLiteral("year")).toInt();
            if (!check(year >= previousYear
                       && stop.value(QStringLiteral("lon")).toDouble() >= 70
                       && stop.value(QStringLiteral("lat")).toDouble() >= 16
                       && !stop.value(QStringLiteral("detail")).toString().isEmpty()
                       && !stop.value(QStringLiteral("context")).toString().isEmpty()
                       && stop.value(QStringLiteral("source")).toString().startsWith(QStringLiteral("http")),
                       QStringLiteral("chronological sourced map stop: ") + id)) return 1;
            previousYear = year;
        }
        journey.seek(journey.stopCount() + 10);
        if (!check(journey.currentIndex() == journey.stopCount() - 1,
                   QStringLiteral("seek clamps to final stop: ") + id)) return 1;
        journey.previous();
        if (!check(journey.currentIndex() == journey.stopCount() - 2,
                   QStringLiteral("previous stop: ") + id)) return 1;
        journey.seekStage(0);
        if (!check(journey.activeStage() == 0,
                   QStringLiteral("timeline stage linkage: ") + id)) return 1;
        const QVariantMap routeCamera = journey.cameraFor(1200, 550, false, 1.0, -1);
        const QVariantMap overviewCamera = journey.cameraFor(1200, 550, true, 1.0, -1);
        if (!check(routeCamera.value(QStringLiteral("zoom")).toDouble()
                       > overviewCamera.value(QStringLiteral("zoom")).toDouble(),
                   QStringLiteral("route view expands the historical stop range: ") + id)) return 1;
        const QVariantMap focusedCamera = journey.cameraFor(1200, 550, false, .62, 0);
        const QVariantMap first = journey.stops().first().toMap();
        const double zoom = focusedCamera.value(QStringLiteral("zoom")).toDouble();
        const double screenX = (1200 - 700 * zoom) / 2
            + focusedCamera.value(QStringLiteral("panX")).toDouble()
            + (first.value(QStringLiteral("lon")).toDouble() - 70) * 10 * zoom;
        if (!check(screenX > 0 && screenX < 1200 * .62,
                   QStringLiteral("selected stop stays visible beside the notebook: ") + id)) return 1;
        for (int index = 0; index < journey.stopCount(); ++index) {
            const QVariantMap stop = journey.stops().at(index).toMap();
            journey.seek(index);
            const QVariantMap reading = journey.stagePoem();
            if (!check(!reading.value(QStringLiteral("title")).toString().isEmpty()
                       && !reading.value(QStringLiteral("content")).toString().isEmpty()
                       && !reading.value(QStringLiteral("context")).toString().isEmpty()
                       && reading.value(QStringLiteral("period")).toString()
                              == stop.value(QStringLiteral("date")).toString(),
                       QStringLiteral("station poem follows edited reading data: ")
                           + stop.value(QStringLiteral("id")).toString())) return 1;
            ++linkedReadings;
            const QVariantMap camera = journey.cameraFor(1468, 620, false, .62, index);
            const double scale = camera.value(QStringLiteral("zoom")).toDouble();
            const double x = (1468 - 700 * scale) / 2
                + camera.value(QStringLiteral("panX")).toDouble()
                + (stop.value(QStringLiteral("lon")).toDouble() - 70) * 10 * scale;
            const double y = (620 - 400 * scale) / 2
                + camera.value(QStringLiteral("panY")).toDouble()
                + (56 - stop.value(QStringLiteral("lat")).toDouble()) * 10 * scale;
            if (!check(x > 25 && x < 1468 * .62 - 25 && y > 25 && y < 595,
                       QStringLiteral("every selected station stays visible with the notebook: ") + id)) return 1;
        }
        if (!check(journey.placeEvents().size() >= 1,
                   QStringLiteral("events at a geographic point remain selectable: ") + id)) return 1;
    }
    if (!check(linkedReadings == 57, QStringLiteral("all edited station poems are linked"))) return 1;
    QSqlDatabase poems = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), QStringLiteral("journey-poems"));
    poems.setDatabaseName(QStringLiteral(":memory:"));
    if (!check(poems.open(), QStringLiteral("read-only poem lookup fixture opens"))) return 1;
    QSqlQuery poemQuery(poems);
    if (!check(poemQuery.exec(QStringLiteral("CREATE TABLE poems (id INTEGER PRIMARY KEY, title TEXT, author TEXT, dynasty TEXT, content TEXT)"))
                   && poemQuery.exec(QStringLiteral("INSERT INTO poems VALUES (8, '江油小记', '李白', '唐', '江油山中月色明。')"))
                   && poemQuery.exec(QStringLiteral("INSERT INTO poems VALUES (9, '江油他作', '杜甫', '唐', '江油山中月色明。')"))
                   && poemQuery.exec(QStringLiteral("INSERT INTO poems VALUES (10, '清平调・其一', '李白', '唐', '云想衣裳花想容。')"))
                   && poemQuery.exec(QStringLiteral("INSERT INTO poems VALUES (11, '侠客行', '李白', '唐', '赵客缦胡缨。')"))
                   && poemQuery.exec(QStringLiteral("INSERT INTO poems VALUES (12, '赠卫八处士', '杜甫', '唐', '人生不相见。')"))
                   && poemQuery.exec(QStringLiteral("INSERT INTO poems VALUES (13, '春夜喜雨', '杜甫', '唐', '好雨知时节。')"))
                   && poemQuery.exec(QStringLiteral("INSERT INTO poems VALUES (14, '定风波·莫听穿林打叶声', '苏轼', '宋', '莫听穿林打叶声。')")),
               QStringLiteral("poem fixture data"))) return 1;
    journey.selectPoet(QStringLiteral("libai"));
    journey.seek(0);
    journey.setPoemDatabase(poems);
    if (!check(journey.relatedPoems().size() == 1
               && journey.relatedPoems().first().toMap().value(QStringLiteral("id")).toInt() == 8,
               QStringLiteral("notebook links only existing author and place matches"))) return 1;
    journey.selectPoet(QStringLiteral("libai"));
    journey.setSpeed(2.0);
    journey.play();
    if (!check(journey.playing() && journey.speed() == 2.0,
               QStringLiteral("playback and speed control"))) return 1;
    journey.pause();
    journey.restart();
    if (!check(journey.playing() && journey.currentIndex() == 0,
               QStringLiteral("replay begins at first stop"))) return 1;
    journey.pause();
    if (!check(!journey.playing() && !journey.selectPoet(QStringLiteral("unknown")),
               QStringLiteral("pause and invalid poet handled"))) return 1;

    QTemporaryDir temporary;
    const QString invalidPath = temporary.filePath(QStringLiteral("invalid.json"));
    QFile invalid(invalidPath);
    if (!check(invalid.open(QIODevice::WriteOnly), QStringLiteral("create malformed fixture"))) return 1;
    invalid.write("broken JSON"); invalid.close();
    JourneyModel broken(QStringLiteral(":/data/poets.json"), invalidPath);
    if (!check(!broken.errorMessage().isEmpty() && broken.poetOptions().isEmpty(),
               QStringLiteral("malformed independent journey data handled"))) return 1;
    QTextStream(stdout) << "journey tests passed" << Qt::endl;
    return 0;
}
