#include "../src/personalspace.h"
#include "../src/interactionengine.h"
#include "../src/poemcatalog.h"
#include "../src/shicicalendar.h"

#include <QCoreApplication>
#include <QDate>
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
    QTemporaryDir directory;
    if (!check(directory.isValid(), QStringLiteral("temporary directory"))) return 1;
    QSqlDatabase db = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), QStringLiteral("personal-test"));
    db.setDatabaseName(directory.filePath(QStringLiteral("archive.sqlite")));
    if (!check(db.open(), QStringLiteral("database opens"))) return 1;
    ShiciCalendar source;
    PoemCatalog archive(db, nullptr, &source);
    InteractionEngine interaction(db);
    PersonalSpace personal(db);
    QObject::connect(&archive, &PoemCatalog::selectedChanged, &personal, &PersonalSpace::refresh);
    QObject::connect(&archive, &PoemCatalog::historyChanged, &personal, &PersonalSpace::refresh);
    QObject::connect(&interaction, &InteractionEngine::recordsChanged, &personal, &PersonalSpace::refresh);
    QObject::connect(&personal, &PersonalSpace::libraryChanged, &archive, &PoemCatalog::refreshPersonalData);
    if (!check(archive.resultCount() == 64 && personal.errorMessage().isEmpty(),
               QStringLiteral("existing archive and personal data initialize"))) return 1;
    QSqlQuery original(db);
    original.exec(QStringLiteral("SELECT content FROM poems WHERE id=1")); original.next();
    const QString firstPoem = original.value(0).toString();

    archive.selectPoem(1);
    archive.toggleFavorite();
    archive.saveNote(QStringLiteral("旧笔记：山河"));
    if (!check(personal.stats().value(QStringLiteral("favorites")).toInt() == 1
               && personal.stats().value(QStringLiteral("notes")).toInt() == 1
               && personal.stats().value(QStringLiteral("read")).toInt() == 1
               && personal.favorites().size() == 1 && personal.notes().size() == 1,
               QStringLiteral("existing favorites, notes, reading data reused"))) return 1;

    personal.setFavoriteQuery(QStringLiteral("贯休"), QStringLiteral("author"));
    if (!check(personal.favorites().size() == 1, QStringLiteral("Chinese favorite search"))) return 1;
    personal.setFavoriteQuery(QStringLiteral("不存在"), QStringLiteral("latest"));
    if (!check(personal.favorites().isEmpty() && personal.stats().value(QStringLiteral("favorites")).toInt() == 1,
               QStringLiteral("filtered list does not change totals"))) return 1;
    personal.setFavoriteQuery({}, {});
    personal.setNoteQuery(QStringLiteral("贯休"), QStringLiteral("oldest"));
    if (!check(personal.notes().size() == 1, QStringLiteral("note author filter"))) return 1;
    personal.setHistoryDate(QDate::currentDate().toString(QStringLiteral("yyyy-MM-dd")));
    if (!check(personal.history().size() == 1, QStringLiteral("local reading date filter"))) return 1;

    if (!check(personal.saveNote(1, QStringLiteral("新笔记：留白")), QStringLiteral("note edit"))) return 1;
    if (!check(!personal.saveNote(1, QStringLiteral("  "))
               && archive.selectedNote() == QStringLiteral("新笔记：留白")
               && !personal.errorMessage().isEmpty(),
               QStringLiteral("invalid blank note does not erase existing text"))) return 1;
    if (!check(archive.selectedNote() == QStringLiteral("新笔记：留白"),
               QStringLiteral("archive reflects edited note without opening poem"))) return 1;
    if (!check(personal.removeFavorite(1), QStringLiteral("favorite removal"))) return 1;
    if (!check(!archive.selectedFavorite() && personal.stats().value(QStringLiteral("favorites")).toInt() == 0,
               QStringLiteral("archive reflects favorite removal"))) return 1;

    if (!check(interaction.start(QStringLiteral("chain"), 1), QStringLiteral("interaction starts"))) return 1;
    interaction.submit(interaction.expectedAnswerForTest()); interaction.next();
    if (!check(personal.stats().value(QStringLiteral("attempts")).toInt() == 1
               && personal.stats().value(QStringLiteral("accuracy")).toInt() == 100
                && personal.modes().at(0).toMap().value(QStringLiteral("title")).toString() == QStringLiteral("飞花令")
               && personal.modes().at(1).toMap().value(QStringLiteral("attempts")).toInt() == 1
                && personal.modes().at(2).toMap().value(QStringLiteral("title")).toString() == QStringLiteral("残卷修复")
               && personal.rounds().size() == 1,
               QStringLiteral("real interaction statistics reused"))) return 1;

    if (!check(personal.theme() == QStringLiteral("月白"),
               QStringLiteral("moonwhite is the default theme"))) return 1;
    if (!check(!personal.saveSettings({}, QStringLiteral("竹"), 28, false, QStringLiteral("烟青"))
               && personal.nickname() == QStringLiteral("山河旅人"),
               QStringLiteral("invalid nickname does not change saved settings"))) return 1;
    if (!check(!personal.setTheme(QStringLiteral("夜墨"))
               && personal.theme() == QStringLiteral("月白"),
               QStringLiteral("retired theme is rejected"))) return 1;
    if (!check(personal.saveSettings(QStringLiteral("听松客"), QStringLiteral("竹"), 28,
                                     false, QStringLiteral("烟青")), QStringLiteral("settings saved"))) return 1;
    if (!check(personal.setTheme(QStringLiteral("月白"))
               && personal.theme() == QStringLiteral("月白"),
               QStringLiteral("topbar theme switch saves immediately"))) return 1;
    if (!check(personal.deleteNote(1) && personal.clearHistory(),
               QStringLiteral("note and history delete"))) return 1;
    if (!check(archive.selectedNote().isEmpty() && personal.stats().value(QStringLiteral("read")).toInt() == 0,
               QStringLiteral("personal deletes reflected in archive and totals"))) return 1;

    PersonalSpace reopened(db);
    if (!check(reopened.nickname() == QStringLiteral("听松客") && reopened.avatar() == QStringLiteral("竹")
               && reopened.readingFontSize() == 28 && !reopened.animationsEnabled()
               && reopened.theme() == QStringLiteral("月白")
               && reopened.stats().value(QStringLiteral("attempts")).toInt() == 1
               && reopened.notes().isEmpty() && reopened.history().isEmpty(),
               QStringLiteral("settings and learning data survive reopen"))) return 1;
    QSqlQuery oldTheme(db);
    if (!check(oldTheme.exec(QStringLiteral("UPDATE personal_settings SET value='夜墨' WHERE key='theme'")),
               QStringLiteral("legacy theme fixture saved"))) return 1;
    PersonalSpace migrated(db);
    QSqlQuery storedTheme(db);
    storedTheme.exec(QStringLiteral("SELECT value FROM personal_settings WHERE key='theme'"));
    if (!check(storedTheme.next() && migrated.theme() == QStringLiteral("月白")
               && storedTheme.value(0).toString() == QStringLiteral("月白"),
               QStringLiteral("legacy night theme migrates to moonwhite"))) return 1;
    QSqlQuery unchanged(db);
    unchanged.exec(QStringLiteral("SELECT content FROM poems WHERE id=1")); unchanged.next();
    if (!check(unchanged.value(0).toString() == firstPoem,
               QStringLiteral("original poem text is unchanged"))) return 1;
    QTextStream(stdout) << "personal space tests passed" << Qt::endl;
    return 0;
}
