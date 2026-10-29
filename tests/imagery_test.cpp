#include "../src/imageryexplorer.h"
#include "../src/poemcatalog.h"
#include "../src/shicicalendar.h"

#include <QCoreApplication>
#include <QSqlQuery>
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
    QTemporaryDir temporary;
    if (!check(temporary.isValid(), QStringLiteral("temp database"))) return 1;
    QSqlDatabase database = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), QStringLiteral("imagery-test"));
    database.setDatabaseName(temporary.filePath(QStringLiteral("archive.sqlite")));
    if (!check(database.open(), QStringLiteral("database opens"))) return 1;
    ShiciCalendar source;
    PoemCatalog catalog(database, nullptr, &source);
    ImageryExplorer imagery(database);
    if (!check(imagery.error().isEmpty() && imagery.corpusCount() == 64
               && imagery.center() == QStringLiteral("月") && imagery.centerCount() > 0,
               QStringLiteral("source archive and dictionary load"))) return 1;
    if (!check(imagery.nodes().size() >= 9 && imagery.nodes().size() <= 11,
               QStringLiteral("real neighboring imagery limited to ten"))) return 1;
    if (!check(!imagery.skyEdges().isEmpty() && imagery.skyEdges().size() <= 18,
               QStringLiteral("panoramic sky uses a restrained set of real co-occurrences"))) return 1;
    for (const QVariant &value : imagery.skyEdges()) {
        const QVariantMap edge = value.toMap();
        if (!check(edge.value(QStringLiteral("count")).toInt() > 0
                   && !edge.value(QStringLiteral("from")).toString().isEmpty()
                   && !edge.value(QStringLiteral("to")).toString().isEmpty(),
                   QStringLiteral("sky links have real positive frequencies and named ends"))) return 1;
    }
    const int moonCount = imagery.centerCount();
    imagery.selectPair(QStringLiteral("酒"));
    if (!check(imagery.pairCount() > 0 && imagery.pairCount() < moonCount
               && imagery.poems().size() == imagery.pairCount(),
               QStringLiteral("pair results are an intersection"))) return 1;
    for (const QVariant &value : imagery.poems()) {
        const int id = value.toMap().value(QStringLiteral("id")).toInt();
        catalog.selectPoem(id);
        if (!check(catalog.selectedId() == id && !catalog.selectedContent().isEmpty(),
                   QStringLiteral("imagery poem ID opens archive detail"))) return 1;
    }
    imagery.setDynasty(QStringLiteral("唐"));
    for (const QVariant &value : imagery.poems())
        if (!check(value.toMap().value(QStringLiteral("dynasty")).toString() == QStringLiteral("唐"),
                   QStringLiteral("dynasty filter applies to pair results"))) return 1;
    imagery.setQuery(QStringLiteral("无此意象"));
    if (!check(imagery.items().isEmpty() && imagery.skyEdges().isEmpty() && imagery.nodes().size() > 0,
               QStringLiteral("empty search does not invent results or destroy graph"))) return 1;
    imagery.setQuery({}); imagery.setDynasty(QStringLiteral("全部朝代"));
    imagery.setCategory(QStringLiteral("草木"));
    for (int i = 1; i < imagery.nodes().size(); ++i) {
        const QString key = imagery.nodes().at(i).toMap().value(QStringLiteral("key")).toString();
        if (!check(key == QStringLiteral("花") || key == QStringLiteral("柳"),
                   QStringLiteral("category filter limits graph neighbors"))) return 1;
    }

    QSqlDatabase fixture = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), QStringLiteral("imagery-fixture"));
    fixture.setDatabaseName(QStringLiteral(":memory:"));
    if (!check(fixture.open(), QStringLiteral("fixture database opens"))) return 1;
    QSqlQuery create(fixture);
    if (!check(create.exec(QStringLiteral("CREATE TABLE poems (id INTEGER PRIMARY KEY, title TEXT, author TEXT, dynasty TEXT, content TEXT)")),
               QStringLiteral("fixture schema"))) return 1;
    if (!check(create.exec(QStringLiteral("INSERT INTO poems VALUES (101, '别称', '甲', '唐', '婵娟与杜康，明月明月对酒歌。')"))
               && create.exec(QStringLiteral("INSERT INTO poems VALUES (102, '排除', '乙', '宋', '岁月千秋，江山风流，靖康耻犹未雪。')")),
               QStringLiteral("fixture rows"))) return 1;
    ImageryExplorer checkFixture(fixture);
    if (!check(checkFixture.centerCount() == 1 && checkFixture.corpusCount() == 2,
               QStringLiteral("aliases count once per poem; exclusions ignore non-imagery uses"))) return 1;
    checkFixture.selectPair(QStringLiteral("酒"));
    if (!check(checkFixture.pairCount() == 1 && checkFixture.poems().first().toMap().value(QStringLiteral("id")).toInt() == 101,
               QStringLiteral("alias pair preserves source ID"))) return 1;
    checkFixture.selectPair(QStringLiteral("风"));
    if (!check(checkFixture.pairCount() == 0 && checkFixture.poems().isEmpty(),
               QStringLiteral("unrelated pair returns no invented poems"))) return 1;
    checkFixture.setCenter(QStringLiteral("秋"));
    if (!check(checkFixture.centerCount() == 0 && checkFixture.nodes().size() == 1 && checkFixture.poems().isEmpty(),
               QStringLiteral("zero hit imagery has empty result"))) return 1;
    QTextStream(stdout) << "imagery tests passed" << Qt::endl;
    return 0;
}
