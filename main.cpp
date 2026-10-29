#include "src/homecontroller.h"
#include "src/poemcatalog.h"
#include "src/poetlifemodel.h"
#include "src/journeymodel.h"
#include "src/shicicalendar.h"
#include "src/interactionengine.h"
#include "src/personalspace.h"
#include "src/imageryexplorer.h"
#include "src/aiassistant.h"

#include <QGuiApplication>
#include <QDir>
#include <QFile>
#include <QQuickWindow>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QSqlDatabase>
#include <QStandardPaths>
#include <QTimer>
#include <QUrl>

#ifndef YIJUANSHANHE_AI_SERVICE_URL
#define YIJUANSHANHE_AI_SERVICE_URL "http://127.0.0.1:8765"
#endif

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    QCoreApplication::setOrganizationName(QStringLiteral("YiJuanShanHe"));
    QCoreApplication::setApplicationName(QStringLiteral("YiJuanShanHe"));
    QQuickStyle::setStyle(QStringLiteral("Basic"));

    const QStringList args = QCoreApplication::arguments();
    HomeController home;
    const QString configuredPoetsFile = qEnvironmentVariable("YIJUANSHANHE_POETS_FILE");
    const QString localPoetsFile = QDir(QCoreApplication::applicationDirPath())
                                       .filePath(QStringLiteral("data/poets.json"));
    const QString poetsFile = !configuredPoetsFile.isEmpty() ? configuredPoetsFile
                             : QFile::exists(localPoetsFile) ? localPoetsFile
                                                              : QStringLiteral(":/data/poets.json");
    PoetLifeModel poets(poetsFile);
    const QString configuredJourneysFile = qEnvironmentVariable("YIJUANSHANHE_JOURNEYS_FILE");
    const QString localJourneysFile = QDir(QCoreApplication::applicationDirPath())
                                          .filePath(QStringLiteral("data/journeys.json"));
    const QString journeysFile = !configuredJourneysFile.isEmpty() ? configuredJourneysFile
                                 : QFile::exists(localJourneysFile) ? localJourneysFile
                                                                    : QStringLiteral(":/data/journeys.json");
    JourneyModel journey(poetsFile, journeysFile);
    const QString configuredShiciFile = qEnvironmentVariable("YIJUANSHANHE_SHICI_FILE");
    const QString localShiciFile = QDir(QCoreApplication::applicationDirPath())
                                       .filePath(QStringLiteral("shici.txt"));
    const QString shiciFile = !configuredShiciFile.isEmpty() ? configuredShiciFile
                              : QFile::exists(localShiciFile) ? localShiciFile
                                                               : QStringLiteral(":/shici.txt");
    ShiciCalendar shiciCalendar(shiciFile);
    const QString configuredDataDir = qEnvironmentVariable("YIJUANSHANHE_DATA_DIR");
    const QString dataDir = configuredDataDir.isEmpty()
        ? QStandardPaths::writableLocation(QStandardPaths::AppDataLocation) : configuredDataDir;
    QSqlDatabase archiveDatabase = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"),
                                                              QStringLiteral("shici-archive"));
    if (!dataDir.isEmpty() && QDir().mkpath(dataDir)) {
        archiveDatabase.setDatabaseName(QDir(dataDir).filePath(QStringLiteral("shici_archive.sqlite")));
        archiveDatabase.open();
    }
    PoemCatalog catalog(archiveDatabase, nullptr, &shiciCalendar);
    journey.setPoemDatabase(archiveDatabase);
    const QString configuredImageryFile = qEnvironmentVariable("YIJUANSHANHE_IMAGERY_FILE");
    const QString localImageryFile = QDir(QCoreApplication::applicationDirPath())
                                         .filePath(QStringLiteral("data/imagery.json"));
    const QString imageryFile = !configuredImageryFile.isEmpty() ? configuredImageryFile
                                : QFile::exists(localImageryFile) ? localImageryFile
                                                                 : QStringLiteral(":/data/imagery.json");
    ImageryExplorer imagery(archiveDatabase, imageryFile);
    InteractionEngine interaction(archiveDatabase);
    PersonalSpace personal(archiveDatabase);
    const QString aiUrl = qEnvironmentVariable("YIJUANSHANHE_AI_SERVICE_URL",
                                                QString::fromUtf8(YIJUANSHANHE_AI_SERVICE_URL));
    AiAssistant ai(archiveDatabase, QUrl(aiUrl));
    QObject::connect(&catalog, &PoemCatalog::selectedChanged, &personal, &PersonalSpace::refresh);
    QObject::connect(&catalog, &PoemCatalog::historyChanged, &personal, &PersonalSpace::refresh);
    QObject::connect(&interaction, &InteractionEngine::recordsChanged, &personal, &PersonalSpace::refresh);
    QObject::connect(&personal, &PersonalSpace::libraryChanged, &catalog, &PoemCatalog::refreshPersonalData);
    const int interactionModeArg = args.indexOf(QStringLiteral("--interaction-mode"));
    if (interactionModeArg >= 0 && interactionModeArg + 1 < args.size()) {
        const QString requested = args.at(interactionModeArg + 1);
        if (requested.startsWith(QStringLiteral("puzzle-")))
            interaction.startPuzzle(requested.mid(7), 5);
        else interaction.start(requested, 5);
    }
    const int calendarMonthArg = args.indexOf(QStringLiteral("--calendar-month"));
    if (calendarMonthArg >= 0 && calendarMonthArg + 1 < args.size()) {
        const QDate requested = QDate::fromString(args.at(calendarMonthArg + 1) + QStringLiteral("-01"),
                                                  QStringLiteral("yyyy-MM-dd"));
        if (requested.isValid())
            shiciCalendar.shiftMonth((requested.year() - shiciCalendar.year()) * 12
                                     + requested.month() - shiciCalendar.month());
    }
    const int calendarDayArg = args.indexOf(QStringLiteral("--calendar-day"));
    if (calendarDayArg >= 0 && calendarDayArg + 1 < args.size())
        shiciCalendar.selectDay(args.at(calendarDayArg + 1).toInt());
    const int journeyPoetArg = args.indexOf(QStringLiteral("--journey-poet"));
    if (journeyPoetArg >= 0 && journeyPoetArg + 1 < args.size())
        journey.selectPoet(args.at(journeyPoetArg + 1));
    const int journeyStopArg = args.indexOf(QStringLiteral("--journey-stop"));
    if (journeyStopArg >= 0 && journeyStopArg + 1 < args.size())
        journey.seek(args.at(journeyStopArg + 1).toInt());
    const int importArg = args.indexOf(QStringLiteral("--import-poems"));
    if (importArg >= 0 && importArg + 1 < args.size()) {
        PoemCatalog legacyCatalog(home.database());
        legacyCatalog.importJsonFile(args.at(importArg + 1));
    }
    const int selectArg = args.indexOf(QStringLiteral("--select-poem"));
    if (selectArg >= 0 && selectArg + 1 < args.size())
        catalog.selectPoem(args.at(selectArg + 1).toInt());
    const int aiPoemArg = args.indexOf(QStringLiteral("--ai-poem"));
    if (aiPoemArg >= 0 && aiPoemArg + 1 < args.size())
        ai.openWithPoem(args.at(aiPoemArg + 1).toInt());
    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("homeController"), &home);
    engine.rootContext()->setContextProperty(QStringLiteral("catalog"), &catalog);
    engine.rootContext()->setContextProperty(QStringLiteral("imagery"), &imagery);
    engine.rootContext()->setContextProperty(QStringLiteral("poets"), &poets);
    engine.rootContext()->setContextProperty(QStringLiteral("journey"), &journey);
    engine.rootContext()->setContextProperty(QStringLiteral("shiciCalendar"), &shiciCalendar);
    engine.rootContext()->setContextProperty(QStringLiteral("interaction"), &interaction);
    engine.rootContext()->setContextProperty(QStringLiteral("personal"), &personal);
    engine.rootContext()->setContextProperty(QStringLiteral("ai"), &ai);
    engine.rootContext()->setContextProperty(QStringLiteral("startPage"),
                                             (args.contains(QStringLiteral("--open-ai")) || aiPoemArg >= 0)
                                                 ? QStringLiteral("ai")
                                                 : args.contains(QStringLiteral("--open-personal"))
                                                 ? QStringLiteral("personal")
                                                 : args.contains(QStringLiteral("--open-interaction"))
                                                 ? QStringLiteral("interaction")
                                                 : args.contains(QStringLiteral("--open-journey"))
                                                 ? QStringLiteral("journey")
                                                 : args.contains(QStringLiteral("--open-lives"))
                                                 ? QStringLiteral("lives")
                                                 : args.contains(QStringLiteral("--open-imagery"))
                                                 ? QStringLiteral("imagery")
                                                 : args.contains(QStringLiteral("--open-poetry"))
                                                     ? QStringLiteral("poetry") : QStringLiteral("home"));
    engine.loadFromModule("YiJuanShanHe", "Main");
    if (engine.rootObjects().isEmpty())
        return -1;

    auto *mainWindow = qobject_cast<QQuickWindow *>(engine.rootObjects().constFirst());
    if (mainWindow && args.contains(QStringLiteral("--capture-min")))
        mainWindow->resize(1180, 760);
    const int personalSectionArg = args.indexOf(QStringLiteral("--personal-section"));
    if (mainWindow && personalSectionArg >= 0 && personalSectionArg + 1 < args.size()) {
        const int section = qBound(0, args.at(personalSectionArg + 1).toInt(), 4);
        QTimer::singleShot(650, mainWindow, [mainWindow, section]() {
            if (auto *space = mainWindow->findChild<QObject *>(QStringLiteral("personalSpace")))
                space->setProperty("section", section);
        });
    }
    if (mainWindow && args.contains(QStringLiteral("--capture-calendar"))) {
        QTimer::singleShot(650, mainWindow, [mainWindow]() {
            if (auto *scroller = mainWindow->findChild<QObject *>(QStringLiteral("homeScroller")))
                scroller->setProperty("contentY", 423.0);
        });
    }
    if (mainWindow && args.contains(QStringLiteral("--capture-calendar-end"))) {
        QTimer::singleShot(950, mainWindow, [mainWindow]() {
            if (auto *reader = mainWindow->findChild<QObject *>(QStringLiteral("calendarPoemScroll")))
                reader->setProperty("contentY", qMax(0.0, reader->property("contentHeight").toDouble()
                                                       - reader->property("height").toDouble()));
        });
    }
    if (mainWindow && args.contains(QStringLiteral("--capture-immersive"))) {
        QTimer::singleShot(650, mainWindow, [mainWindow]() {
            if (auto *reader = mainWindow->findChild<QObject *>(QStringLiteral("poetryArchive")))
                reader->setProperty("immersive", true);
        });
    }
    const int detailTabArg = args.indexOf(QStringLiteral("--capture-detail-tab"));
    if (mainWindow && detailTabArg >= 0 && detailTabArg + 1 < args.size()) {
        const int tab = qBound(0, args.at(detailTabArg + 1).toInt(), 2);
        QTimer::singleShot(850, mainWindow, [mainWindow, tab]() {
            if (auto *reader = mainWindow->findChild<QObject *>(QStringLiteral("poetryArchive")))
                reader->setProperty("detailTab", tab);
        });
    }
    if (mainWindow && args.contains(QStringLiteral("--capture-lives-compare"))) {
        QTimer::singleShot(650, mainWindow, [mainWindow]() {
            if (auto *lives = mainWindow->findChild<QObject *>(QStringLiteral("poetBiography")))
                lives->setProperty("compareMode", true);
        });
    }
    if (mainWindow && args.contains(QStringLiteral("--capture-imagery-note"))) {
        QTimer::singleShot(650, mainWindow, [mainWindow]() {
            if (auto *atlas = mainWindow->findChild<QObject *>(QStringLiteral("imageryExplore")))
                atlas->setProperty("notebookOpen", true);
        });
    }
    if (mainWindow && args.contains(QStringLiteral("--capture-journey-note"))) {
        QTimer::singleShot(650, mainWindow, [mainWindow]() {
            if (auto *page = mainWindow->findChild<QObject *>(QStringLiteral("poetJourney")))
                page->setProperty("noteOpen", true);
        });
    }
    if (mainWindow && args.contains(QStringLiteral("--capture-journey-overview"))) {
        QTimer::singleShot(650, mainWindow, [mainWindow]() {
            if (auto *page = mainWindow->findChild<QObject *>(QStringLiteral("poetJourney")))
                page->setProperty("overview", true);
        });
    }
    if (mainWindow && args.contains(QStringLiteral("--capture-toggle-theme"))) {
        QTimer::singleShot(900, mainWindow, [&personal]() {
            personal.setTheme(personal.theme() == QStringLiteral("月白")
                                  ? QStringLiteral("烟青") : QStringLiteral("月白"));
        });
    }

    // A deterministic capture mode makes visual checks possible on machines
    // without an interactive desktop session.
    const int captureArg = args.indexOf(QStringLiteral("--capture"));
    if (captureArg >= 0 && captureArg + 1 < args.size()) {
        const QString outputPath = args.at(captureArg + 1);
        const int delayArg = args.indexOf(QStringLiteral("--capture-delay"));
        const int delay = delayArg >= 0 && delayArg + 1 < args.size()
                              ? qBound(1000, args.at(delayArg + 1).toInt(), 10000) : 2200;
        QTimer::singleShot(delay, &app, [&app, &engine, outputPath]() {
            auto *window = qobject_cast<QQuickWindow *>(engine.rootObjects().constFirst());
            const bool saved = window && window->grabWindow().save(outputPath);
            app.exit(saved ? 0 : 3);
        });
    }

    return app.exec();
}
