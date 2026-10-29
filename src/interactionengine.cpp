#include "interactionengine.h"

#include <QDateTime>
#include <QHash>
#include <QRandomGenerator>
#include <QRegularExpression>
#include <QSet>
#include <QSqlError>
#include <QSqlQuery>
#include <QUuid>
#include <algorithm>

namespace {
template<typename T> void shuffle(QVector<T> &items)
{
    for (int i = items.size() - 1; i > 0; --i)
        items.swapItemsAt(i, QRandomGenerator::global()->bounded(i + 1));
}

bool hanText(const QString &text)
{
    for (const QChar ch : text) {
        const ushort value = ch.unicode();
        if (value < 0x3400 || value > 0x9fff) return false;
    }
    return !text.isEmpty();
}

QStringList pairedClauses(const QString &line)
{
    QString text = line.trimmed();
    if (text.size() < 10 || text.size() > 30) return {};
    const QChar last = text.back();
    if (last != QChar(0x3002) && last != QChar(0xff01) && last != QChar(0xff1f)) return {};
    text.chop(1);
    int comma = text.indexOf(QChar(0xff0c));
    if (comma < 0) comma = text.indexOf(QChar(','));
    if (comma < 0 || text.indexOf(QChar(0xff0c), comma + 1) >= 0
        || text.indexOf(QChar(','), comma + 1) >= 0) return {};
    const QString first = text.left(comma).trimmed();
    const QString second = text.mid(comma + 1).trimmed();
    if (first.size() < 4 || first.size() > 12 || second.size() < 4 || second.size() > 12
        || !hanText(first) || !hanText(second)) return {};
    return {first, second};
}

QString modeName(const QString &mode)
{
    if (mode == QStringLiteral("feihua")) return QStringLiteral("飞花令");
    if (mode == QStringLiteral("puzzle")) return QStringLiteral("残卷修复");
    if (mode == QStringLiteral("fill")) return QStringLiteral("诗句填空");
    if (mode == QStringLiteral("chain")) return QStringLiteral("诗词接龙");
    if (mode == QStringLiteral("quiz")) return QStringLiteral("知识挑战");
    return QStringLiteral("错题重练");
}
}

InteractionEngine::InteractionEngine(const QSqlDatabase &database, QObject *parent)
    : QObject(parent), m_database(database)
{
    m_turnTimer.setInterval(1000);
    connect(&m_turnTimer, &QTimer::timeout, this, [this]() {
        if (m_phase != QStringLiteral("asking") || !current()
            || current()->mode != QStringLiteral("feihua")) { m_turnTimer.stop(); return; }
        if (--m_timeLeft <= 0) {
            m_timeLeft = 0;
            m_timedOut = true;
            m_turnTimer.stop();
            skip();
        } else emit stateChanged();
    });
    if (m_database.isOpen() && ensureSchema() && loadPoems()) refreshRecords();
    else if (m_error.isEmpty()) setError(QStringLiteral("诗词库尚未准备好，无法开始互动。"));
}

void InteractionEngine::setError(const QString &message)
{
    m_error = message;
    emit stateChanged();
}

bool InteractionEngine::ensureSchema()
{
    const QStringList statements{
        QStringLiteral("CREATE TABLE IF NOT EXISTS interaction_attempts ("
                       "id INTEGER PRIMARY KEY,session_key TEXT NOT NULL,mode TEXT NOT NULL,"
                       "kind TEXT NOT NULL,poem_id INTEGER NOT NULL,prompt TEXT NOT NULL,"
                       "answer TEXT NOT NULL,user_answer TEXT NOT NULL,correct INTEGER NOT NULL,"
                       "hinted INTEGER NOT NULL,created_at TEXT NOT NULL)"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS interaction_rounds ("
                       "id INTEGER PRIMARY KEY,session_key TEXT NOT NULL UNIQUE,"
                       "mode TEXT NOT NULL,question_count INTEGER NOT NULL,correct_count INTEGER NOT NULL,"
                       "score INTEGER NOT NULL,finished_at TEXT NOT NULL)"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS interaction_mistakes ("
                       "id INTEGER PRIMARY KEY,mode TEXT NOT NULL,kind TEXT NOT NULL,"
                       "poem_id INTEGER NOT NULL,prompt TEXT NOT NULL,subtitle TEXT NOT NULL,"
                       "answer TEXT NOT NULL,source_line TEXT NOT NULL,wrong_count INTEGER NOT NULL,"
                       "resolved INTEGER NOT NULL,last_wrong_at TEXT NOT NULL,"
                       "UNIQUE(mode,kind,poem_id,prompt,answer))"),
        QStringLiteral("CREATE INDEX IF NOT EXISTS interaction_mistakes_open "
                       "ON interaction_mistakes(resolved,last_wrong_at)")
    };
    QSqlQuery query(m_database);
    for (const QString &sql : statements) {
        if (!query.exec(sql)) {
            setError(QStringLiteral("学习记录初始化失败：") + query.lastError().text());
            return false;
        }
    }
    return true;
}

bool InteractionEngine::loadPoems()
{
    QSqlQuery query(m_database);
    if (!query.exec(QStringLiteral("SELECT id,title,author,dynasty,content FROM poems ORDER BY id"))) {
        setError(QStringLiteral("读取诗词库失败：") + query.lastError().text());
        return false;
    }
    m_poems.clear();
    while (query.next()) {
        Poem poem{query.value(0).toInt(), query.value(1).toString(),
                  query.value(2).toString(), query.value(3).toString(), query.value(4).toString()};
        if (poem.id > 0 && !poem.title.isEmpty() && !poem.content.isEmpty()) m_poems.append(poem);
    }
    if (m_poems.isEmpty()) {
        setError(QStringLiteral("诗词库中没有可用的原文，暂时无法出题。"));
        return false;
    }
    m_feihuaLines.clear();
    QSet<QString> seen;
    const QRegularExpression split(QStringLiteral("[，。！？；、\\r\\n]+"));
    for (const Poem &poem : m_poems) {
        for (const QString &part : poem.content.split(split, Qt::SkipEmptyParts)) {
            const QString line = part.trimmed();
            const QString key = normalizeAnswer(line);
            if (line.size() < 4 || line.size() > 14 || !hanText(line) || seen.contains(key)) continue;
            seen.insert(key);
            m_feihuaLines.append({line, key, poem.title, poem.author, poem.id});
        }
    }
    return true;
}

QString InteractionEngine::normalizeAnswer(const QString &text)
{
    QString normalized;
    normalized.reserve(text.size());
    for (const QChar ch : text)
        if (ch.isLetterOrNumber()) normalized.append(ch.toLower());
    return normalized;
}

QVector<InteractionEngine::Question> InteractionEngine::pairQuestions(const QString &mode) const
{
    struct Pair { int poemId; QString title, line, first, second; };
    QVector<Pair> pairs;
    QHash<QString, QSet<QString>> answersByPrompt;
    for (const Poem &poem : m_poems) {
        for (const QString &line : poem.content.split(QChar('\n'))) {
            const QStringList clauses = pairedClauses(line);
            if (clauses.size() != 2) continue;
            const QString first = normalizeAnswer(clauses.at(0));
            const QString second = normalizeAnswer(clauses.at(1));
            answersByPrompt[first].insert(second);
            pairs.append({poem.id, poem.title, line.trimmed(), clauses.at(0), clauses.at(1)});
        }
    }
    QVector<Question> result;
    QSet<QString> seen;
    for (const Pair &pair : pairs) {
        const QString first = normalizeAnswer(pair.first);
        const QString second = normalizeAnswer(pair.second);
        if (mode == QStringLiteral("chain") && answersByPrompt.value(first).size() != 1) continue;
        const QString identity = first + QChar('/') + second;
        if (seen.contains(identity)) continue;
        seen.insert(identity);
        Question q;
        q.mode = mode; q.kind = mode; q.poemId = pair.poemId;
        q.poemTitle = pair.title; q.sourceLine = pair.line;
        if (mode == QStringLiteral("chain")) {
            q.prompt = pair.first;
            q.subtitle = QStringLiteral("接出同一诗句的下一半 · 《%1》").arg(pair.title);
            q.answer = pair.second;
        } else {
            const int length = qMin(pair.second.size() - 1,
                                    QRandomGenerator::global()->bounded(2, 5));
            const int start = QRandomGenerator::global()->bounded(pair.second.size() - length + 1);
            q.answer = pair.second.mid(start, length);
            QString hidden = pair.second;
            hidden.replace(start, length, QString(length, QChar(0x25a1)));
            q.prompt = pair.first + QChar(0xff0c) + hidden + pair.line.back();
            q.subtitle = QStringLiteral("补全方框中的文字 · 《%1》").arg(pair.title);
        }
        result.append(q);
    }
    return result;
}

QStringList InteractionEngine::makeOptions(const QString &kind, const QString &answer) const
{
    QSet<QString> unique;
    for (const Poem &poem : m_poems) {
        const QString value = kind == QStringLiteral("author") ? poem.author
                            : kind == QStringLiteral("title") ? poem.title : poem.dynasty;
        if (!value.isEmpty() && value != answer
            && !(kind == QStringLiteral("author") && value.startsWith(QChar(0x300a))))
            unique.insert(value);
    }
    if (unique.size() < 3) return {};
    QVector<QString> distractors = unique.values().toVector();
    shuffle(distractors);
    QStringList options{answer, distractors.at(0), distractors.at(1), distractors.at(2)};
    for (int i = options.size() - 1; i > 0; --i)
        options.swapItemsAt(i, QRandomGenerator::global()->bounded(i + 1));
    return options;
}

QVector<InteractionEngine::Question> InteractionEngine::quizQuestions() const
{
    QHash<QString, int> lineCount;
    QHash<int, QString> excerpts;
    for (const Poem &poem : m_poems) {
        for (const QString &line : poem.content.split(QChar('\n'))) {
            if (pairedClauses(line).size() != 2) continue;
            excerpts.insert(poem.id, line.trimmed());
            break;
        }
        if (excerpts.contains(poem.id))
            ++lineCount[normalizeAnswer(excerpts.value(poem.id))];
    }
    QVector<Question> result;
    for (const Poem &poem : m_poems) {
        const QString excerpt = excerpts.value(poem.id);
        if (excerpt.isEmpty() || lineCount.value(normalizeAnswer(excerpt)) != 1) continue;
        const struct { const char *kind; QString answer; QString prompt; } variants[] = {
            {"author", poem.author, QStringLiteral("这句诗的作者是谁？\n%1").arg(excerpt)},
            {"title", poem.title, QStringLiteral("这句诗出自哪一篇？\n%1").arg(excerpt)},
            {"dynasty", poem.dynasty, QStringLiteral("这句诗的作者属于哪一朝代？\n%1").arg(excerpt)}
        };
        for (const auto &variant : variants) {
            const QString kind = QString::fromLatin1(variant.kind);
            if (variant.answer.isEmpty() || (kind == QStringLiteral("author")
                                             && variant.answer.startsWith(QChar(0x300a)))) continue;
            const QStringList options = makeOptions(kind, variant.answer);
            if (options.size() != 4) continue;
            Question q;
            q.mode = QStringLiteral("quiz"); q.kind = kind;
            q.poemId = poem.id; q.poemTitle = poem.title;
            q.sourceLine = excerpt; q.prompt = variant.prompt;
            q.subtitle = kind == QStringLiteral("author") ? QStringLiteral("作者辨认")
                         : kind == QStringLiteral("title") ? QStringLiteral("标题匹配")
                                                             : QStringLiteral("朝代判断");
            q.answer = variant.answer; q.options = options;
            result.append(q);
        }
    }
    return result;
}

QVector<InteractionEngine::Question> InteractionEngine::puzzleQuestions(const QString &difficulty) const
{
    QVector<Question> result;
    for (const Poem &poem : m_poems) {
        QStringList rows;
        for (const QString &raw : poem.content.split(QChar('\n'))) {
            const QString row = raw.trimmed();
            if (!row.isEmpty()) rows.append(row);
        }
        Question q;
        q.mode = QStringLiteral("puzzle");
        q.kind = QStringLiteral("puzzle|") + difficulty;
        q.difficulty = difficulty;
        q.poemId = poem.id;
        q.poemTitle = poem.title;
        q.fullPoem = poem.content;
        if (difficulty == QStringLiteral("hard")) {
            QStringList clauses;
            const QRegularExpression split(QStringLiteral("[，。！？；、]+"));
            for (const QString &row : rows) {
                for (const QString &part : row.split(split, Qt::SkipEmptyParts)) {
                    const QString clause = part.trimmed();
                    if (clause.size() >= 7 && clause.size() <= 12 && hanText(clause))
                        clauses.append(clause);
                }
            }
            if (clauses.isEmpty()) continue;
            q.answer = clauses.at(QRandomGenerator::global()->bounded(clauses.size()));
            q.targetPieces.clear();
            for (int i = 0; i < q.answer.size(); i += 2)
                q.targetPieces.append(q.answer.mid(i, 2));
            q.prompt = QStringLiteral("将散落的字词拼回原句");
            q.subtitle = QStringLiteral("《%1》 · %2 · 字词拼接").arg(poem.title, poem.author);
        } else {
            if (rows.size() < 4 || rows.size() > 8) continue;
            if (std::any_of(rows.cbegin(), rows.cend(), [](const QString &row) {
                return row.size() < 8 || row.size() > 38;
            })) continue;
            q.targetPieces = rows;
            q.answer = rows.join(QChar('\n'));
            q.prompt = difficulty == QStringLiteral("challenge")
                ? QStringLiteral("辨出原诗，排除混入的诗句")
                : QStringLiteral("按原诗次序修复残卷");
            q.subtitle = QStringLiteral("《%1》 · %2 · %3")
                .arg(poem.title, poem.author,
                     difficulty == QStringLiteral("challenge") ? QStringLiteral("辨句挑战")
                                                               : QStringLiteral("诗句归位"));
        }
        q.sourceLine = q.answer;
        buildPuzzleTiles(q);
        result.append(q);
    }
    return result;
}

void InteractionEngine::buildPuzzleTiles(Question &q) const
{
    if (q.targetPieces.isEmpty()) {
        if (q.difficulty == QStringLiteral("hard")) {
            for (int i = 0; i < q.answer.size(); i += 2)
                q.targetPieces.append(q.answer.mid(i, 2));
        } else q.targetPieces = q.answer.split(QChar('\n'), Qt::SkipEmptyParts);
    }
    const auto poem = std::find_if(m_poems.cbegin(), m_poems.cend(),
                                   [&](const Poem &item) { return item.id == q.poemId; });
    if (poem != m_poems.cend()) q.fullPoem = poem->content;
    QSqlQuery material(m_database);
    material.prepare(QStringLiteral("SELECT appreciation,annotation FROM poems WHERE id=?"));
    material.addBindValue(q.poemId);
    if (material.exec() && material.next()) {
        const QString appreciation = material.value(0).toString().trimmed();
        const QString annotation = material.value(1).toString().trimmed();
        q.background = !appreciation.isEmpty() ? appreciation : annotation;
        q.backgroundLabel = !appreciation.isEmpty() ? QStringLiteral("原有赏析")
                           : !annotation.isEmpty() ? QStringLiteral("原有注释") : QString();
    }
    QVector<QVariantMap> tiles;
    for (int i = 0; i < q.targetPieces.size(); ++i)
        tiles.append({{QStringLiteral("id"), i}, {QStringLiteral("text"), q.targetPieces.at(i)}});
    if (q.difficulty == QStringLiteral("challenge")) {
        QSet<QString> seen;
        for (const QString &piece : q.targetPieces) seen.insert(normalizeAnswer(piece));
        QVector<QString> extras;
        for (const Poem &other : m_poems) {
            if (other.id == q.poemId) continue;
            for (const QString &raw : other.content.split(QChar('\n'))) {
                const QString line = raw.trimmed();
                const QString key = normalizeAnswer(line);
                if (line.size() < 8 || line.size() > 38 || seen.contains(key)) continue;
                seen.insert(key);
                extras.append(line);
            }
        }
        shuffle(extras);
        for (int i = 0; i < qMin(3, extras.size()); ++i)
            tiles.append({{QStringLiteral("id"), q.targetPieces.size() + i},
                          {QStringLiteral("text"), extras.at(i)}});
    }
    shuffle(tiles);
    q.tiles.clear();
    for (const QVariantMap &tile : tiles) q.tiles.append(tile);
}

void InteractionEngine::preparePuzzleTurn()
{
    if (!current() || current()->mode != QStringLiteral("puzzle")) return;
    Question &q = m_round[m_index];
    if (q.tiles.isEmpty()) buildPuzzleTiles(q);
    m_puzzleSlots = QVector<int>(q.targetPieces.size(), -1);
    m_timeLeft = 0;
}

bool InteractionEngine::prepareFeihuaTurn()
{
    if (m_feihuaLines.size() < 3) {
        setError(QStringLiteral("诗词库中可用于飞花令的独立诗句不足。"));
        return false;
    }
    struct Rule { QChar first, second; QVector<int> lines; };
    const QString preferred = QStringLiteral("月花风山春秋云水江夜雪酒柳雨天日海梦心乡");
    const int stage = m_index * 3 / qMax(1, m_round.size());
    QVector<Rule> rules;
    for (int level = stage; level >= 0 && rules.isEmpty(); --level) {
        for (const QChar first : preferred) {
            const QString secondChoices = level >= 2 ? preferred : QString();
            const int variants = level >= 2 ? secondChoices.size() : 1;
            for (int variant = 0; variant < variants; ++variant) {
                const QChar second = level >= 2 ? secondChoices.at(variant) : QChar();
                if (!second.isNull() && second == first) continue;
                Rule rule{first, second, {}};
                for (int i = 0; i < m_feihuaLines.size(); ++i) {
                    const FeihuaLine &line = m_feihuaLines.at(i);
                    if (m_usedLines.contains(line.normalized) || !line.text.contains(first)
                        || (!second.isNull() && !line.text.contains(second))) continue;
                    rule.lines.append(i);
                }
                if (rule.lines.size() >= 3) rules.append(rule);
            }
        }
    }
    if (rules.isEmpty()) {
        setError(QStringLiteral("可用诗句已用尽，本轮提前结算。"));
        return false;
    }
    const Rule rule = rules.at(QRandomGenerator::global()->bounded(rules.size()));
    QVector<int> choices = rule.lines;
    shuffle(choices);
    const FeihuaLine &computer = m_feihuaLines.at(choices.at(0));
    const FeihuaLine &sample = m_feihuaLines.at(choices.at(1));
    Question &q = m_round[m_index];
    q.mode = QStringLiteral("feihua");
    q.command = QString(rule.first);
    q.extraCommand = rule.second.isNull() ? QString() : QString(rule.second);
    q.minLength = 0;
    q.kind = QStringLiteral("feihua|") + q.command + QChar('|') + q.extraCommand
             + QChar('|') + QString::number(q.minLength);
    q.prompt = QStringLiteral("令字「%1」").arg(q.command);
    q.subtitle = !q.extraCommand.isEmpty()
        ? QStringLiteral("加令「%1」 · 两字须同在一句").arg(q.extraCommand)
        : QStringLiteral("说出包含令字的诗句，按本回合规则判定");
    q.computerLine = computer.text;
    q.computerSource = QStringLiteral("《%1》 · %2").arg(computer.title, computer.author);
    q.answer = sample.text;
    q.sourceLine = sample.text;
    q.poemId = sample.poemId;
    q.poemTitle = sample.title;
    m_usedLines.insert(computer.normalized);
    m_timeLeft = stage == 0 ? 25 : stage == 1 ? 20 : 16;
    m_timedOut = false;
    m_turnTimer.start();
    return true;
}

const InteractionEngine::FeihuaLine *InteractionEngine::findFeihuaLine(const QString &given) const
{
    const QString key = normalizeAnswer(given);
    for (const FeihuaLine &line : m_feihuaLines)
        if (line.normalized == key) return &line;
    return nullptr;
}

QString InteractionEngine::placedPuzzleText(const Question &q) const
{
    QStringList ordered;
    for (const int id : m_puzzleSlots) {
        QString text;
        for (const QVariant &tile : q.tiles) {
            const QVariantMap value = tile.toMap();
            if (value.value(QStringLiteral("id")).toInt() == id) {
                text = value.value(QStringLiteral("text")).toString();
                break;
            }
        }
        ordered.append(text);
    }
    return ordered.join(q.difficulty == QStringLiteral("hard") ? QString() : QStringLiteral("\n"));
}

bool InteractionEngine::puzzleCorrect(const Question &q) const
{
    if (m_puzzleSlots.size() != q.targetPieces.size()) return false;
    for (int i = 0; i < m_puzzleSlots.size(); ++i) {
        const int id = m_puzzleSlots.at(i);
        if (id < 0) return false;
        QString text;
        for (const QVariant &tile : q.tiles) {
            const QVariantMap value = tile.toMap();
            if (value.value(QStringLiteral("id")).toInt() == id) {
                text = value.value(QStringLiteral("text")).toString();
                break;
            }
        }
        if (text != q.targetPieces.at(i)) return false;
    }
    return true;
}

void InteractionEngine::placePiece(int tileId, int slotIndex)
{
    const Question *q = current();
    if (m_phase != QStringLiteral("asking") || !q || q->mode != QStringLiteral("puzzle")
        || slotIndex < 0 || slotIndex >= m_puzzleSlots.size()) return;
    bool known = false;
    for (const QVariant &tile : q->tiles)
        if (tile.toMap().value(QStringLiteral("id")).toInt() == tileId) { known = true; break; }
    if (!known) return;
    for (int &id : m_puzzleSlots)
        if (id == tileId) id = -1;
    m_puzzleSlots[slotIndex] = tileId;
    m_statusMessage.clear();
    emit stateChanged();
    if (puzzleCorrect(*q)) submitPuzzle();
}

void InteractionEngine::removePiece(int slotIndex)
{
    if (m_phase != QStringLiteral("asking") || !current()
        || current()->mode != QStringLiteral("puzzle")
        || slotIndex < 0 || slotIndex >= m_puzzleSlots.size()) return;
    m_puzzleSlots[slotIndex] = -1;
    emit stateChanged();
}

void InteractionEngine::submitPuzzle()
{
    const Question *q = current();
    if (m_phase != QStringLiteral("asking") || !q || q->mode != QStringLiteral("puzzle")) return;
    if (std::any_of(m_puzzleSlots.cbegin(), m_puzzleSlots.cend(), [](int id) { return id < 0; })) {
        m_statusMessage = QStringLiteral("先把诗卷中的空位填满，再提交修复。");
        emit stateChanged();
        return;
    }
    resolve(placedPuzzleText(*q), false, false);
}

QVector<InteractionEngine::Question> InteractionEngine::candidates(const QString &mode) const
{
    if (mode == QStringLiteral("chain")) return pairQuestions(mode);
    return {};
}

const InteractionEngine::Question *InteractionEngine::current() const
{
    return m_index >= 0 && m_index < m_round.size() ? &m_round.at(m_index) : nullptr;
}

QVariantMap InteractionEngine::question() const
{
    const Question *q = current();
    if (!q) return {};
    QVariantList placedSlots;
    for (const int id : m_puzzleSlots) placedSlots.append(id);
    return {{QStringLiteral("mode"), q->mode}, {QStringLiteral("kind"), q->kind},
            {QStringLiteral("prompt"), q->prompt}, {QStringLiteral("subtitle"), q->subtitle},
            {QStringLiteral("poemTitle"), q->poemTitle}, {QStringLiteral("options"), q->options},
            {QStringLiteral("command"), q->command}, {QStringLiteral("extraCommand"), q->extraCommand},
            {QStringLiteral("computerLine"), q->computerLine},
            {QStringLiteral("computerSource"), q->computerSource},
            {QStringLiteral("usedCount"), m_usedLines.size()},
            {QStringLiteral("difficulty"), q->difficulty}, {QStringLiteral("tiles"), q->tiles},
            {QStringLiteral("slots"), placedSlots}, {QStringLiteral("slotCount"), q->targetPieces.size()},
            {QStringLiteral("fullPoem"), m_phase == QStringLiteral("asking") ? QString() : q->fullPoem},
            {QStringLiteral("background"), m_phase == QStringLiteral("asking") ? QString() : q->background},
            {QStringLiteral("backgroundLabel"), q->backgroundLabel}};
}

QString InteractionEngine::expectedAnswerForTest() const
{
    const Question *q = current();
    return q ? q->answer : QString();
}

bool InteractionEngine::beginRound(const QString &mode, QVector<Question> questions, int count)
{
    if (questions.isEmpty()) {
        setError(QStringLiteral("当前诗词库中没有足够可靠的%1题目。").arg(modeName(mode)));
        return false;
    }
    shuffle(questions);
    const int requested = qBound(1, count, 30);
    const int actual = qMin(requested, questions.size());
    m_round = questions.mid(0, actual);
    m_mode = mode; m_phase = QStringLiteral("asking");
    m_session = QUuid::createUuid().toString(QUuid::WithoutBraces);
    m_index = 0; m_score = 0; m_correctCount = 0; m_streak = 0;
    m_hinted = false; m_hintText.clear(); m_feedback.clear(); m_answer.clear();
    m_turnTimer.stop(); m_timeLeft = 0; m_timedOut = false;
    m_usedLines.clear(); m_puzzleSlots.clear();
    m_roundResults.clear(); m_error.clear();
    m_statusMessage = actual < requested
        ? QStringLiteral("题库中有 %1 道可用题目，本轮已调整为 %1 题。").arg(actual)
        : QString();
    if (mode == QStringLiteral("feihua") && !prepareFeihuaTurn()) {
        m_phase = QStringLiteral("idle"); m_round.clear();
        return false;
    }
    if (current() && current()->mode == QStringLiteral("puzzle")) preparePuzzleTurn();
    emit stateChanged();
    return true;
}

bool InteractionEngine::start(const QString &mode, int count)
{
    if (!m_database.isOpen() || m_poems.isEmpty()) {
        setError(QStringLiteral("诗词库尚未准备好，无法开始挑战。"));
        return false;
    }
    if (mode == QStringLiteral("feihua")) {
        QVector<Question> turns(qBound(1, count, 20));
        return beginRound(mode, turns, count);
    }
    if (mode == QStringLiteral("puzzle")) return startPuzzle(QStringLiteral("simple"), count);
    if (mode != QStringLiteral("chain")) {
        setError(QStringLiteral("此玩法已更新，请选择飞花令、诗词接龙或残卷修复。"));
        return false;
    }
    return beginRound(mode, candidates(mode), count);
}

bool InteractionEngine::startPuzzle(const QString &difficulty, int count)
{
    if (!QStringList{QStringLiteral("simple"), QStringLiteral("hard"),
                     QStringLiteral("challenge")}.contains(difficulty)) {
        setError(QStringLiteral("请选择有效的残卷难度。"));
        return false;
    }
    if (!m_database.isOpen() || m_poems.isEmpty()) {
        setError(QStringLiteral("诗词库尚未准备好，无法开始残卷修复。"));
        return false;
    }
    return beginRound(QStringLiteral("puzzle"), puzzleQuestions(difficulty), count);
}

bool InteractionEngine::startRetry()
{
    if (!m_database.isOpen()) {
        setError(QStringLiteral("学习记录数据库尚未打开。"));
        return false;
    }
    QSqlQuery query(m_database);
    if (!query.exec(QStringLiteral("SELECT mode,kind,poem_id,prompt,subtitle,answer,source_line "
                                   "FROM interaction_mistakes WHERE resolved=0 "
                                   "AND mode IN ('feihua','chain','puzzle') ORDER BY last_wrong_at DESC"))) {
        setError(QStringLiteral("读取错题失败：") + query.lastError().text());
        return false;
    }
    QVector<Question> retry;
    while (query.next()) {
        Question q;
        q.mode = query.value(0).toString(); q.kind = query.value(1).toString();
        q.poemId = query.value(2).toInt(); q.prompt = query.value(3).toString();
        q.subtitle = query.value(4).toString(); q.answer = query.value(5).toString();
        q.sourceLine = query.value(6).toString();
        const auto poem = std::find_if(m_poems.cbegin(), m_poems.cend(),
                                       [&](const Poem &value) { return value.id == q.poemId; });
        if (poem == m_poems.cend() || !poem->content.contains(q.sourceLine)) continue;
        q.poemTitle = poem->title;
        if (q.mode == QStringLiteral("feihua")) {
            const QStringList rule = q.kind.split(QChar('|'));
            if (rule.size() != 4 || rule.at(0) != QStringLiteral("feihua")) continue;
            q.command = rule.at(1); q.extraCommand = rule.at(2);
            q.minLength = 0;
            if (q.subtitle.contains(QStringLiteral("七字")))
                q.subtitle = QStringLiteral("说出包含令字的诗句，按本回合规则判定");
            if (q.command.size() != 1 || !findFeihuaLine(q.answer)) continue;
        }
        if (q.mode == QStringLiteral("puzzle")) {
            const QStringList rule = q.kind.split(QChar('|'));
            if (rule.size() != 2 || rule.at(0) != QStringLiteral("puzzle")) continue;
            q.difficulty = rule.at(1);
            if (!QStringList{QStringLiteral("simple"), QStringLiteral("hard"),
                             QStringLiteral("challenge")}.contains(q.difficulty)) continue;
            buildPuzzleTiles(q);
        }
        if (q.kind == QStringLiteral("author") && q.answer != poem->author) continue;
        if (q.kind == QStringLiteral("title") && q.answer != poem->title) continue;
        if (q.kind == QStringLiteral("dynasty") && q.answer != poem->dynasty) continue;
        if (q.mode == QStringLiteral("quiz")) {
            q.options = makeOptions(q.kind, q.answer);
            if (q.options.size() != 4) continue;
        }
        retry.append(q);
    }
    if (retry.isEmpty()) {
        setError(QStringLiteral("暂无可重练的错题。"));
        return false;
    }
    return beginRound(QStringLiteral("retry"), retry, qMin(10, retry.size()));
}

void InteractionEngine::hint()
{
    if (m_phase != QStringLiteral("asking") || !current()) return;
    const Question &q = *current();
    m_hinted = true;
    if (q.mode == QStringLiteral("feihua")) {
        m_hintText = QStringLiteral("提示：可试试《%1》，其中一句以「%2」开头。答对可得 6 分。")
                         .arg(q.poemTitle, q.answer.left(1));
    } else if (q.mode == QStringLiteral("puzzle")) {
        int slot = 0;
        while (slot < m_puzzleSlots.size() && m_puzzleSlots.at(slot) >= 0) ++slot;
        if (slot >= q.targetPieces.size()) slot = 0;
        m_hintText = QStringLiteral("提示：第 %1 格应是「%2」。答对可得 6 分。")
                         .arg(slot + 1).arg(q.targetPieces.value(slot));
    } else m_hintText = q.options.isEmpty()
        ? QStringLiteral("提示：答案共 %1 字，首字是「%2」。本题答对可得 6 分。")
              .arg(normalizeAnswer(q.answer).size()).arg(q.answer.left(1))
        : QStringLiteral("提示：正确选项以「%1」开头。本题答对可得 6 分。")
              .arg(q.answer.left(1));
    emit stateChanged();
}

void InteractionEngine::resolve(const QString &given, bool skipped, bool revealed)
{
    const Question *q = current();
    if (m_phase != QStringLiteral("asking") || !q) return;
    const QString normalized = normalizeAnswer(given);
    if (!skipped && !revealed && normalized.isEmpty()) {
        m_statusMessage = QStringLiteral("先写下答案，再提交。也可以使用提示或跳过。");
        emit stateChanged();
        return;
    }
    const FeihuaLine *feihua = q->mode == QStringLiteral("feihua") ? findFeihuaLine(given) : nullptr;
    const bool feihuaRepeated = q->mode == QStringLiteral("feihua")
        && m_usedLines.contains(normalized);
    const bool feihuaValid = q->mode == QStringLiteral("feihua")
        && normalized.contains(q->command)
        && (q->extraCommand.isEmpty() || normalized.contains(q->extraCommand))
        && !feihuaRepeated;
    const bool correct = !skipped && !revealed
        && (q->mode == QStringLiteral("feihua") ? feihuaValid
            : q->mode == QStringLiteral("puzzle") ? puzzleCorrect(*q)
                                                    : normalized == normalizeAnswer(q->answer));
    const QString acceptedAnswer = correct && q->mode == QStringLiteral("feihua")
        ? (feihua ? feihua->text : given.trimmed()) : q->answer;
    const int acceptedPoemId = correct && q->mode == QStringLiteral("feihua")
        ? (feihua ? feihua->poemId : 0) : q->poemId;
    const QString acceptedTitle = correct && q->mode == QStringLiteral("feihua")
        ? (feihua ? feihua->title : QString()) : q->poemTitle;
    m_turnTimer.stop();
    const QString now = QDateTime::currentDateTimeUtc().toString(Qt::ISODateWithMs);
    if (!m_database.transaction()) {
        setError(QStringLiteral("无法保存答题记录：") + m_database.lastError().text());
        return;
    }
    QSqlQuery attempt(m_database);
    attempt.prepare(QStringLiteral("INSERT INTO interaction_attempts(" 
                                   "session_key,mode,kind,poem_id,prompt,answer,user_answer,correct,hinted,created_at) "
                                   "VALUES(?,?,?,?,?,?,?,?,?,?)"));
    attempt.addBindValue(m_session); attempt.addBindValue(q->mode); attempt.addBindValue(q->kind);
    attempt.addBindValue(acceptedPoemId); attempt.addBindValue(q->prompt);
    attempt.addBindValue(acceptedAnswer); attempt.addBindValue(given.isNull() ? QStringLiteral("") : given);
    attempt.addBindValue(correct ? 1 : 0); attempt.addBindValue(m_hinted ? 1 : 0);
    attempt.addBindValue(now);
    if (!attempt.exec()) {
        m_database.rollback(); setError(QStringLiteral("保存答题记录失败：") + attempt.lastError().text()); return;
    }
    QSqlQuery mistake(m_database);
    if (correct) {
        mistake.prepare(QStringLiteral("UPDATE interaction_mistakes SET resolved=1 "
                                       "WHERE mode=? AND kind=? AND poem_id=? AND prompt=? AND answer=?"));
        mistake.addBindValue(q->mode); mistake.addBindValue(q->kind);
        mistake.addBindValue(q->poemId); mistake.addBindValue(q->prompt); mistake.addBindValue(q->answer);
    } else {
        mistake.prepare(QStringLiteral(
            "INSERT INTO interaction_mistakes(mode,kind,poem_id,prompt,subtitle,answer,"
            "source_line,wrong_count,resolved,last_wrong_at) VALUES(?,?,?,?,?,?,?,1,0,?) "
            "ON CONFLICT(mode,kind,poem_id,prompt,answer) DO UPDATE SET "
            "wrong_count=wrong_count+1,resolved=0,last_wrong_at=excluded.last_wrong_at"));
        mistake.addBindValue(q->mode); mistake.addBindValue(q->kind);
        mistake.addBindValue(q->poemId); mistake.addBindValue(q->prompt);
        mistake.addBindValue(q->subtitle); mistake.addBindValue(q->answer);
        mistake.addBindValue(q->sourceLine); mistake.addBindValue(now);
    }
    if (!mistake.exec()) {
        m_database.rollback(); setError(QStringLiteral("保存错题状态失败：") + mistake.lastError().text()); return;
    }
    if (!m_database.commit()) {
        m_database.rollback(); setError(QStringLiteral("提交学习记录失败：") + m_database.lastError().text()); return;
    }
    if (correct) {
        ++m_correctCount; ++m_streak;
        m_score += (m_hinted ? 6 : 10) + (!m_hinted && m_streak >= 3 ? 2 : 0);
        if (q->mode == QStringLiteral("feihua")) m_usedLines.insert(normalized);
    } else {
        m_streak = 0;
    }
    m_answer = acceptedAnswer;
    m_feedback = q->mode == QStringLiteral("feihua")
        ? (correct ? QStringLiteral("接令成功，金印落卷。")
           : m_timedOut ? QStringLiteral("沙漏已尽，下一回合再试。")
           : feihuaRepeated
               ? QStringLiteral("这一句已出过，不可重用。")
               : QStringLiteral("诗句未满足本回合的令字或限定。"))
        : q->mode == QStringLiteral("puzzle")
        ? (correct ? QStringLiteral("残卷已复原，墨痕重合。")
           : revealed ? QStringLiteral("原卷已展开，记住诗句次序。")
           : skipped ? QStringLiteral("这一卷先收入错题笺。")
                     : QStringLiteral("词句位置还未吻合，看看原卷。"))
        : correct ? QStringLiteral("答对了，诗意相通。")
                 : revealed ? QStringLiteral("已展开正确答案，记住这一句。")
                 : skipped ? QStringLiteral("这一题先放入错题笺。")
                           : QStringLiteral("还差一点，看看原句。 ");
    m_phase = QStringLiteral("feedback");
    m_statusMessage.clear(); m_error.clear();
    m_roundResults.append(QVariantMap{{QStringLiteral("prompt"), q->prompt},
                                      {QStringLiteral("answer"), acceptedAnswer},
                                      {QStringLiteral("given"), given},
                                      {QStringLiteral("poemTitle"), acceptedTitle},
                                      {QStringLiteral("correct"), correct},
                                      {QStringLiteral("mode"), q->mode}});
    refreshRecords();
    emit stateChanged();
}

void InteractionEngine::submit(const QString &answer) { resolve(answer, false, false); }
void InteractionEngine::skip() { resolve({}, true, false); }
void InteractionEngine::showAnswer() { resolve({}, false, true); }

void InteractionEngine::advance()
{
    next();
}

void InteractionEngine::next()
{
    if (m_phase != QStringLiteral("feedback")) return;
    if (m_index + 1 >= m_round.size()) { finishRound(); return; }
    ++m_index;
    m_phase = QStringLiteral("asking");
    m_hinted = false; m_hintText.clear(); m_feedback.clear(); m_answer.clear();
    m_statusMessage.clear();
    m_timedOut = false; m_timeLeft = 0;
    if (m_mode == QStringLiteral("retry")) m_usedLines.clear();
    if (m_mode == QStringLiteral("feihua") && !prepareFeihuaTurn()) {
        m_round.resize(m_index);
        m_index = m_round.size() - 1;
        finishRound();
        return;
    }
    if (current() && current()->mode == QStringLiteral("puzzle")) preparePuzzleTurn();
    emit stateChanged();
}

void InteractionEngine::finishRound()
{
    QSqlQuery query(m_database);
    query.prepare(QStringLiteral("INSERT OR IGNORE INTO interaction_rounds(" 
                                 "session_key,mode,question_count,correct_count,score,finished_at) "
                                 "VALUES(?,?,?,?,?,?)"));
    query.addBindValue(m_session); query.addBindValue(m_mode);
    query.addBindValue(m_round.size()); query.addBindValue(m_correctCount);
    query.addBindValue(m_score);
    query.addBindValue(QDateTime::currentDateTimeUtc().toString(Qt::ISODateWithMs));
    if (!query.exec()) setError(QStringLiteral("成绩保存失败：") + query.lastError().text());
    m_phase = QStringLiteral("finished");
    refreshRecords();
    emit stateChanged();
}

void InteractionEngine::abort()
{
    m_turnTimer.stop(); m_timeLeft = 0; m_timedOut = false;
    m_usedLines.clear(); m_puzzleSlots.clear();
    m_phase = QStringLiteral("idle");
    m_round.clear(); m_roundResults.clear(); m_mode.clear(); m_index = 0;
    m_score = 0; m_correctCount = 0; m_streak = 0;
    m_feedback.clear(); m_hintText.clear(); m_answer.clear(); m_statusMessage.clear();
    m_error.clear();
    emit stateChanged();
}

void InteractionEngine::refreshRecords()
{
    QSqlQuery attempts(m_database);
    attempts.exec(QStringLiteral("SELECT COUNT(*),COALESCE(SUM(correct),0) FROM interaction_attempts"));
    int count = 0, correct = 0;
    if (attempts.next()) { count = attempts.value(0).toInt(); correct = attempts.value(1).toInt(); }
    QSqlQuery rounds(m_database);
    rounds.exec(QStringLiteral("SELECT COUNT(*),COALESCE(MAX(score),0) FROM interaction_rounds"));
    int roundCount = 0, best = 0;
    if (rounds.next()) { roundCount = rounds.value(0).toInt(); best = rounds.value(1).toInt(); }
    QSqlQuery open(m_database);
    open.exec(QStringLiteral("SELECT COUNT(*) FROM interaction_mistakes WHERE resolved=0 "
                             "AND mode IN ('feihua','chain','puzzle')"));
    int mistakeCount = 0;
    if (open.next()) mistakeCount = open.value(0).toInt();
    m_stats = {{QStringLiteral("attempts"), count}, {QStringLiteral("accuracy"),
                count ? qRound(100.0 * correct / count) : 0},
               {QStringLiteral("bestScore"), best}, {QStringLiteral("rounds"), roundCount},
               {QStringLiteral("mistakes"), mistakeCount}};

    m_recentRounds.clear();
    QSqlQuery history(m_database);
    if (history.exec(QStringLiteral("SELECT mode,question_count,correct_count,score,finished_at "
                                    "FROM interaction_rounds ORDER BY id DESC"))) {
        while (history.next()) {
            m_recentRounds.append(QVariantMap{{QStringLiteral("mode"), modeName(history.value(0).toString())},
                                            {QStringLiteral("count"), history.value(1).toInt()},
                                            {QStringLiteral("correct"), history.value(2).toInt()},
                                            {QStringLiteral("score"), history.value(3).toInt()},
                                            {QStringLiteral("date"), history.value(4).toString().left(10)}});
        }
    }
    m_mistakes.clear();
    QSqlQuery mistakes(m_database);
    if (mistakes.exec(QStringLiteral("SELECT mode,prompt,answer,wrong_count FROM interaction_mistakes "
                                     "WHERE resolved=0 AND mode IN ('feihua','chain','puzzle') "
                                     "ORDER BY last_wrong_at DESC"))) {
        while (mistakes.next()) {
            m_mistakes.append(QVariantMap{{QStringLiteral("mode"), modeName(mistakes.value(0).toString())},
                                          {QStringLiteral("prompt"), mistakes.value(1).toString()},
                                          {QStringLiteral("answer"), mistakes.value(2).toString()},
                                          {QStringLiteral("wrongCount"), mistakes.value(3).toInt()}});
        }
    }
    emit recordsChanged();
}
