#include "../src/interactionengine.h"
#include "../src/poemcatalog.h"
#include "../src/shicicalendar.h"

#include <QCoreApplication>
#include <QElapsedTimer>
#include <QEventLoop>
#include <QSet>
#include <QSqlQuery>
#include <QTemporaryDir>
#include <QTextStream>

static bool check(bool okay, const QString &description)
{
    if (!okay) QTextStream(stderr) << "FAILED: " << description << Qt::endl;
    return okay;
}

int main(int argc, char *argv[])
{
    QCoreApplication app(argc, argv);
    QTemporaryDir directory;
    if (!check(directory.isValid(), QStringLiteral("temporary directory"))) return 1;
    QSqlDatabase db = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), QStringLiteral("interaction-test"));
    db.setDatabaseName(directory.filePath(QStringLiteral("poetry.sqlite")));
    if (!check(db.open(), QStringLiteral("database opens"))) return 1;
    ShiciCalendar source;
    if (!check(source.poemCount() == 64, QStringLiteral("existing 64 poems parse"))) return 1;
    PoemCatalog archive(db, nullptr, &source);
    if (!check(archive.resultCount() == 64, QStringLiteral("existing archive populates"))) return 1;

    QSqlQuery before(db);
    before.exec(QStringLiteral("SELECT COUNT(*),SUM(LENGTH(content)) FROM poems"));
    before.next();
    const int poemCount = before.value(0).toInt();
    const int contentLength = before.value(1).toInt();

    {
        InteractionEngine game(db);
        if (!check(game.errorMessage().isEmpty(), QStringLiteral("interaction schema opens"))) return 1;
        if (!check(InteractionEngine::normalizeAnswer(QStringLiteral("  春，眠。 不觉晓！ "))
                   == QStringLiteral("春眠不觉晓"), QStringLiteral("punctuation and space normalization"))) return 1;
        if (!check(!game.start(QStringLiteral("fill"), 5) && !game.start(QStringLiteral("quiz"), 5),
                   QStringLiteral("retired modes are unavailable"))) return 1;
        if (!check(game.start(QStringLiteral("chain"), 5) && game.questionCount() == 5,
                   QStringLiteral("chain still generates five real questions"))) return 1;
        game.submit(QStringLiteral("答案错误")); game.advance();
        if (!check(game.phase() == QStringLiteral("asking") && game.questionNumber() == 2,
                   QStringLiteral("chain advances to its second turn through the UI action"))) return 1;
        game.showAnswer(); game.next();
        game.skip(); game.next();
        game.submit(QStringLiteral(" ，") + game.expectedAnswerForTest() + QStringLiteral("。 "));
        if (!check(game.correctCount() == 1 && game.score() == 10,
                   QStringLiteral("chain accepts punctuation variants"))) return 1;
        game.next(); game.submit(game.expectedAnswerForTest()); game.next();
        if (!check(game.phase() == QStringLiteral("finished") && game.roundResults().size() == 5,
                   QStringLiteral("chain round finishes"))) return 1;
        if (!check(game.start(QStringLiteral("chain"), 2)
                   && game.phase() == QStringLiteral("asking") && game.questionCount() == 2,
                   QStringLiteral("chain can start another round after results"))) return 1;
        game.abort();

        if (!check(game.start(QStringLiteral("feihua"), 5), QStringLiteral("feihua starts"))) return 1;
        QVariantMap feihua = game.question();
        if (!check(!feihua.value(QStringLiteral("command")).toString().isEmpty()
                   && feihua.value(QStringLiteral("computerLine")).toString()
                          .contains(feihua.value(QStringLiteral("command")).toString())
                   && game.timeLeft() > 0,
                   QStringLiteral("computer opens with a real matching line and timer"))) return 1;
        const int openingSeconds = game.timeLeft();
        QElapsedTimer clock; clock.start();
        while (clock.elapsed() < 1250) QCoreApplication::processEvents(QEventLoop::AllEvents, 25);
        if (!check(game.timeLeft() < openingSeconds,
                   QStringLiteral("feihua countdown advances in C++"))) return 1;
        game.submit(feihua.value(QStringLiteral("computerLine")).toString());
        if (!check(game.phase() == QStringLiteral("feedback") && game.correctCount() == 0
                   && game.feedback().contains(QStringLiteral("不可重用")),
                   QStringLiteral("computer line cannot be repeated"))) return 1;
        game.next();
        feihua = game.question();
        game.submit(QStringLiteral(" ，") + game.expectedAnswerForTest() + QStringLiteral("。 "));
        if (!check(game.correctCount() == 1 && game.score() == 10,
                   QStringLiteral("real matching verse scores with punctuation ignored"))) return 1;
        game.next(); game.hint();
        if (!check(!game.hintText().isEmpty(), QStringLiteral("feihua hint available"))) return 1;
        game.skip(); game.next(); game.showAnswer(); game.next();
        if (!check(game.timeLeft() == 16
                   && !game.question().value(QStringLiteral("subtitle")).toString().contains(QStringLiteral("七字")),
                   QStringLiteral("later feihua turns shorten the timer without a length rule"))) return 1;
        game.skip(); game.next();
        if (!check(game.phase() == QStringLiteral("finished") && game.roundResults().size() == 5,
                   QStringLiteral("feihua round finishes"))) return 1;
        if (!check(game.start(QStringLiteral("feihua"), 2)
                   && game.phase() == QStringLiteral("asking") && game.questionCount() == 2,
                   QStringLiteral("feihua can start another round after results"))) return 1;
        game.abort();

        for (const QString &difficulty : {QStringLiteral("simple"), QStringLiteral("hard"),
                                           QStringLiteral("challenge")}) {
            if (!check(game.startPuzzle(difficulty, 1) && game.questionCount() == 1,
                       difficulty + QStringLiteral(" puzzle starts"))) return 1;
            const QVariantMap puzzle = game.question();
            const QString answer = game.expectedAnswerForTest();
            QStringList target;
            if (difficulty == QStringLiteral("hard")) {
                for (int i = 0; i < answer.size(); i += 2) target.append(answer.mid(i, 2));
            } else target = answer.split(QChar('\n'));
            const QVariantList tiles = puzzle.value(QStringLiteral("tiles")).toList();
            if (!check(puzzle.value(QStringLiteral("slotCount")).toInt() == target.size()
                       && tiles.size() >= target.size()
                       && (difficulty != QStringLiteral("challenge") || tiles.size() > target.size()),
                       difficulty + QStringLiteral(" puzzle pieces come from source poems"))) return 1;
            game.submitPuzzle();
            if (!check(game.phase() == QStringLiteral("asking") && !game.statusMessage().isEmpty(),
                       QStringLiteral("incomplete scroll cannot be submitted"))) return 1;
            if (difficulty == QStringLiteral("challenge")) {
                const int extraId = target.size();
                game.placePiece(extraId, 0);
                if (!check(game.question().value(QStringLiteral("slots")).toList().at(0).toInt() == extraId,
                           QStringLiteral("distractor can be placed"))) return 1;
                game.removePiece(0);
            }
            QSet<int> placed;
            for (int slot = 0; slot < target.size(); ++slot) {
                int id = -1;
                for (const QVariant &item : tiles) {
                    const QVariantMap tile = item.toMap();
                    if (tile.value(QStringLiteral("text")).toString() == target.at(slot)
                        && !placed.contains(tile.value(QStringLiteral("id")).toInt())) {
                        id = tile.value(QStringLiteral("id")).toInt(); break;
                    }
                }
                if (!check(id >= 0, QStringLiteral("original piece found in shuffled bank"))) return 1;
                placed.insert(id);
                game.placePiece(id, slot);
            }
            if (!check(game.phase() == QStringLiteral("feedback") && game.correctCount() == 1
                       && !game.question().value(QStringLiteral("fullPoem")).toString().isEmpty(),
                       difficulty + QStringLiteral(" puzzle restores and reveals full poem"))) return 1;
            game.next();
            if (!check(game.phase() == QStringLiteral("finished"),
                       QStringLiteral("puzzle round records result"))) return 1;
        }
        if (!check(game.stats().value(QStringLiteral("rounds")).toInt() == 5
                   && game.stats().value(QStringLiteral("attempts")).toInt() == 13
                   && game.stats().value(QStringLiteral("accuracy")).toInt() == 46
                   && game.stats().value(QStringLiteral("bestScore")).toInt() == 20
                   && game.stats().value(QStringLiteral("mistakes")).toInt() > 0,
                   QStringLiteral("learning totals saved"))) return 1;
    }

    {
        InteractionEngine reopened(db);
        if (!check(reopened.stats().value(QStringLiteral("rounds")).toInt() == 5
                   && reopened.recentRounds().size() == 5
                   && !reopened.mistakes().isEmpty(), QStringLiteral("records persist after restart"))) return 1;
        if (!check(reopened.startRetry() && reopened.questionCount() > 0,
                   QStringLiteral("wrong question retry loads"))) return 1;
        const int oldMistakes = reopened.stats().value(QStringLiteral("mistakes")).toInt();
        reopened.submit(reopened.expectedAnswerForTest());
        if (!check(reopened.stats().value(QStringLiteral("mistakes")).toInt() == oldMistakes - 1,
                   QStringLiteral("correct retry resolves a wrong question"))) return 1;
        reopened.abort();
        if (!check(reopened.startPuzzle(QStringLiteral("challenge"), 1),
                   QStringLiteral("challenge can be replayed"))) return 1;
        const int slotCount = reopened.question().value(QStringLiteral("slotCount")).toInt();
        reopened.placePiece(slotCount, 0);
        for (int i = 1; i < slotCount; ++i) reopened.placePiece(i, i);
        reopened.submitPuzzle();
        if (!check(reopened.phase() == QStringLiteral("feedback") && reopened.correctCount() == 0
                   && reopened.feedback().contains(QStringLiteral("还未吻合"))
                   && !reopened.question().value(QStringLiteral("fullPoem")).toString().isEmpty(),
                   QStringLiteral("distractor is rejected and original poem is shown"))) return 1;
    }
    QSqlQuery after(db);
    after.exec(QStringLiteral("SELECT COUNT(*),SUM(LENGTH(content)) FROM poems"));
    after.next();
    if (!check(after.value(0).toInt() == poemCount && after.value(1).toInt() == contentLength,
               QStringLiteral("original poem rows and content remain unchanged"))) return 1;

    {
        InteractionEngine outsideCorpus(db);
        if (!check(outsideCorpus.start(QStringLiteral("feihua"), 2),
                   QStringLiteral("outside-corpus feihua round starts"))) return 1;
        // Includes every possible command, but is deliberately absent from the local poem library.
        const QString newLine = QStringLiteral("月花风山春秋云水江夜雪酒柳雨天日海梦心乡");
        QSqlQuery absence(db);
        absence.prepare(QStringLiteral("SELECT COUNT(*) FROM poems WHERE content LIKE ?"));
        absence.addBindValue(QStringLiteral("%") + newLine + QStringLiteral("%"));
        if (!check(absence.exec() && absence.next() && absence.value(0).toInt() == 0,
                   QStringLiteral("test verse is absent from local library"))) return 1;
        outsideCorpus.submit(QStringLiteral("，") + newLine + QStringLiteral("。 "));
        if (!check(outsideCorpus.phase() == QStringLiteral("feedback")
                   && outsideCorpus.correctCount() == 1 && outsideCorpus.score() == 10
                   && outsideCorpus.correctAnswer() == QStringLiteral("，") + newLine + QStringLiteral("。")
                   && outsideCorpus.question().value(QStringLiteral("usedCount")).toInt() == 2,
                   QStringLiteral("rule-compliant verse outside library scores and is marked used"))) return 1;
        QSqlQuery saved(db);
        saved.prepare(QStringLiteral("SELECT poem_id,correct FROM interaction_attempts "
                                     "WHERE session_key=(SELECT session_key FROM interaction_attempts "
                                     "ORDER BY id DESC LIMIT 1) ORDER BY id DESC LIMIT 1"));
        if (!check(saved.exec() && saved.next() && saved.value(0).toInt() == 0
                   && saved.value(1).toInt() == 1,
                   QStringLiteral("external verse is saved without attribution to a local poem"))) return 1;
        outsideCorpus.next();
        outsideCorpus.submit(newLine);
        if (!check(outsideCorpus.phase() == QStringLiteral("feedback")
                   && outsideCorpus.correctCount() == 1 && outsideCorpus.score() == 10
                   && outsideCorpus.feedback().contains(QStringLiteral("不可重用")),
                   QStringLiteral("external verse cannot be reused with different punctuation"))) return 1;
        outsideCorpus.next();
        if (!check(outsideCorpus.start(QStringLiteral("feihua"), 2),
                   QStringLiteral("second rule-only feihua round starts"))) return 1;
        outsideCorpus.skip();
        outsideCorpus.next();
        const QString shortLine = outsideCorpus.question().value(QStringLiteral("command")).toString()
                                  + QStringLiteral("照清江月");
        outsideCorpus.submit(shortLine);
        if (!check(outsideCorpus.correctCount() == 1 && outsideCorpus.score() == 10,
                   QStringLiteral("short verse is accepted without the old seven-character gate"))) return 1;
    }

    QSqlDatabase ambiguous = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), QStringLiteral("ambiguous-test"));
    ambiguous.setDatabaseName(directory.filePath(QStringLiteral("ambiguous.sqlite")));
    if (!check(ambiguous.open(), QStringLiteral("ambiguous fixture database opens"))) return 1;
    QSqlQuery fixture(ambiguous);
    if (!check(fixture.exec(QStringLiteral("CREATE TABLE poems(id INTEGER PRIMARY KEY,title TEXT,author TEXT,dynasty TEXT,content TEXT)"))
               && fixture.exec(QStringLiteral("INSERT INTO poems VALUES(1,'甲篇','甲','唐','春风又绿江南岸，明月何时照我还。')"))
               && fixture.exec(QStringLiteral("INSERT INTO poems VALUES(2,'乙篇','乙','宋','春风又绿江南岸，河水悠悠东流去。')")),
               QStringLiteral("ambiguous fixture populated"))) return 1;
    InteractionEngine limited(ambiguous);
    if (!check(!limited.start(QStringLiteral("chain"), 5)
               && !limited.startPuzzle(QStringLiteral("simple"), 5),
               QStringLiteral("ambiguous chain and inadequate puzzle data excluded"))) return 1;
    QTextStream(stdout) << "interaction tests passed" << Qt::endl;
    return 0;
}
