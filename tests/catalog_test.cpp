#include "../src/homecontroller.h"
#include "../src/poemcatalog.h"

#include <QCoreApplication>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSqlQuery>
#include <QTemporaryDir>
#include <QTextStream>

static bool check(bool condition, const QString &message)
{
    if (!condition)
        QTextStream(stderr) << "FAILED: " << message << Qt::endl;
    return condition;
}

int main(int argc, char *argv[])
{
    QCoreApplication app(argc, argv);
    QTemporaryDir dataDir;
    if (!check(dataDir.isValid(), QStringLiteral("temporary directory")))
        return 1;
    qputenv("YIJUANSHANHE_DATA_DIR", dataDir.path().toUtf8());

    HomeController home;
    if (!check(home.errorMessage().isEmpty() && home.poemCount() == 16,
               QStringLiteral("16 curated poems initialize")))
        return 1;
    QSqlDatabase database = home.database();
    {
        PoemCatalog catalog(database);
        if (!check(catalog.errorMessage().isEmpty() && catalog.resultCount() == 16,
                   QStringLiteral("catalog schema and first query")))
            return 1;
        QSqlQuery history(database);
        history.exec(QStringLiteral("SELECT count(*) FROM reading_history"));
        history.next();
        if (!check(history.value(0).toInt() == 0,
                   QStringLiteral("home startup does not record a read")))
            return 1;

        catalog.search(QStringLiteral("银河"), {}, {}, {}, {}, {});
        if (!check(catalog.resultCount() == 1 && catalog.rowCount() == 1,
                   QStringLiteral("Chinese content search")))
            return 1;
        catalog.search({}, QStringLiteral("唐"), QStringLiteral("李白"),
                       QStringLiteral("七言绝句"), QStringLiteral("山水"), {});
        if (!check(catalog.resultCount() == 1,
                   QStringLiteral("combined SQLite filters")))
            return 1;
        catalog.activate();
        if (!check(catalog.selectedId() == 1 && catalog.selectedContent().contains(QStringLiteral("银河")),
                   QStringLiteral("poem detail")))
            return 1;
        catalog.toggleFavorite();
        catalog.saveNote(QStringLiteral("测试笔记：山河"));
        if (!check(catalog.selectedFavorite() && catalog.selectedNote() == QStringLiteral("测试笔记：山河"),
                   QStringLiteral("favorite and note save")))
            return 1;
    }

    {
        PoemCatalog catalog(database);
        catalog.activate();
        catalog.selectPoem(1);
        if (!check(catalog.selectedFavorite() && catalog.selectedNote() == QStringLiteral("测试笔记：山河"),
                   QStringLiteral("favorite and note survive controller restart")))
            return 1;
        QSqlQuery history(database);
        history.exec(QStringLiteral("SELECT read_count FROM reading_history WHERE poem_id=1"));
        if (!check(history.next() && history.value(0).toInt() >= 2,
                   QStringLiteral("reading history persists")))
            return 1;
        catalog.deleteNote();
        catalog.toggleFavorite();
        if (!check(catalog.selectedNote().isEmpty() && !catalog.selectedFavorite(),
                   QStringLiteral("note deletion and unfavorite")))
            return 1;

        QJsonArray fixture;
        for (int i = 0; i < 35; ++i) {
            QJsonObject poem;
            poem.insert(QStringLiteral("title"), QStringLiteral("导入验证 %1").arg(i));
            poem.insert(QStringLiteral("author"), QStringLiteral("测试作者"));
            poem.insert(QStringLiteral("dynasty"), QStringLiteral("唐"));
            poem.insert(QStringLiteral("content"), QStringLiteral("此为临时数据库测试文本。"));
            poem.insert(QStringLiteral("source"), QStringLiteral("https://example.test/fixture"));
            fixture.append(poem);
        }
        const QString fixturePath = dataDir.filePath(QStringLiteral("fixture.json"));
        QFile file(fixturePath);
        if (!check(file.open(QIODevice::WriteOnly), QStringLiteral("test fixture file")))
            return 1;
        file.write(QJsonDocument(fixture).toJson());
        file.close();
        const int firstImport = catalog.importJsonFile(fixturePath);
        const int secondImport = catalog.importJsonFile(fixturePath);
        if (!check(firstImport == 35 && secondImport == 0,
                   QStringLiteral("JSON import deduplicates")))
            return 1;
        catalog.search({}, {}, {}, {}, {}, {});
        if (!check(catalog.resultCount() == 51 && catalog.rowCount() == 30 && catalog.hasMore(),
                   QStringLiteral("first page of large result set")))
            return 1;
        catalog.loadNextPage();
        if (!check(catalog.rowCount() == 51 && !catalog.hasMore(),
                   QStringLiteral("incremental loading")))
            return 1;
    }
    QTextStream(stdout) << "catalog tests passed" << Qt::endl;
    return 0;
}
