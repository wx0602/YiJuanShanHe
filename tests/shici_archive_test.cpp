#include "../src/poemcatalog.h"
#include "../src/shicicalendar.h"

#include <QCoreApplication>
#include <QFile>
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
    if (!check(temporary.isValid(), QStringLiteral("temporary directory"))) return 1;
    QSqlDatabase database = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"),
                                                       QStringLiteral("shici-test"));
    database.setDatabaseName(temporary.filePath(QStringLiteral("archive.sqlite")));
    if (!check(database.open(), QStringLiteral("isolated archive database opens"))) return 1;
    ShiciCalendar shici;
    if (!check(shici.errorMessage().isEmpty() && shici.poemCount() == 64,
               QStringLiteral("64 supplied poems parse"))) return 1;

    {
        PoemCatalog catalog(database, nullptr, &shici);
        if (!check(catalog.errorMessage().isEmpty() && catalog.resultCount() == 64
                   && catalog.rowCount() == 30 && catalog.hasMore(),
                   QStringLiteral("64 source poems imported and paged"))) return 1;
        catalog.loadNextPage();
        catalog.loadNextPage();
        if (!check(catalog.rowCount() == 64 && !catalog.hasMore(),
                   QStringLiteral("remaining source poems load"))) return 1;
        catalog.selectPoem(64);
        if (!check(catalog.selectedTitle() == QStringLiteral("感遇十二首（其一）")
                   && catalog.selectedAuthor() == QStringLiteral("张九龄")
                   && catalog.selectedDynasty() == QStringLiteral("唐")
                   && catalog.selectedContent().contains(QStringLiteral("草木有本心"))
                   && !catalog.selectedAnnotation().isEmpty()
                   && !catalog.selectedTranslation().isEmpty()
                   && !catalog.selectedAppreciation().isEmpty(),
                   QStringLiteral("complete original and supplied reading material"))) return 1;
        catalog.toggleFavorite();
        catalog.saveNote(QStringLiteral("读后手记"));
        if (!check(catalog.selectedFavorite() && catalog.selectedNote() == QStringLiteral("读后手记"),
                   QStringLiteral("favorite and note saved"))) return 1;
        catalog.search(QStringLiteral("草木有本心"), {}, {}, {}, {}, {});
        if (!check(catalog.resultCount() == 1 && catalog.rowCount() == 1,
                   QStringLiteral("Chinese full text SQL search"))) return 1;
        catalog.search({}, QStringLiteral("唐"), QStringLiteral("张九龄"), {}, {}, {});
        if (!check(catalog.resultCount() == 1,
                   QStringLiteral("author and dynasty SQL filters"))) return 1;
    }

    {
        PoemCatalog reopened(database, nullptr, &shici);
        reopened.selectPoem(64);
        if (!check(reopened.resultCount() == 64 && reopened.selectedFavorite()
                   && reopened.selectedNote() == QStringLiteral("读后手记"),
                   QStringLiteral("user data survives restart without duplicate import"))) return 1;
        QSqlQuery history(database);
        history.exec(QStringLiteral("SELECT read_count FROM reading_history WHERE poem_id=64"));
        if (!check(history.next() && history.value(0).toInt() >= 2,
                   QStringLiteral("reading history persists"))) return 1;
    }

    QFile source(QStringLiteral(":/shici.txt"));
    const QString changedPath = temporary.filePath(QStringLiteral("changed-shici.txt"));
    QFile changed(changedPath);
    if (!check(source.open(QIODevice::ReadOnly) && changed.open(QIODevice::WriteOnly),
               QStringLiteral("editable fixture opens"))) return 1;
    QByteArray changedBytes = source.readAll();
    changedBytes.replace(QStringLiteral("草木有本心").toUtf8(),
                         QStringLiteral("草木存本心").toUtf8());
    changed.write(changedBytes); changed.close();
    ShiciCalendar edited(changedPath);
    {
        PoemCatalog synced(database, nullptr, &edited);
        synced.selectPoem(64);
        if (!check(synced.selectedContent().contains(QStringLiteral("草木存本心"))
                   && synced.selectedNote() == QStringLiteral("读后手记"),
                   QStringLiteral("changed text synchronizes while preserving note"))) return 1;
    }
    ShiciCalendar missing(temporary.filePath(QStringLiteral("missing.txt")));
    PoemCatalog invalid(database, nullptr, &missing);
    if (!check(invalid.resultCount() == 0 && !invalid.errorMessage().isEmpty(),
               QStringLiteral("invalid source never shows stale database contents"))) return 1;

    QTextStream(stdout) << "shici archive tests passed" << Qt::endl;
    return 0;
}
