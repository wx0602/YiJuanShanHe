#include "homecontroller.h"

#include <QDebug>
#include <QDir>
#include <QSqlError>
#include <QSqlQuery>
#include <QStandardPaths>
#include <QVariant>

namespace {
constexpr auto kConnectionName = "home-poetry";

struct SeedPoem {
    const char *title;
    const char *author;
    const char *dynasty;
    const char *content;
    const char *excerpt;
    const char *source;
};

// Classical originals are in the public domain. The excerpts below are
// verbatim lines from the stored works, not generated placeholder text.
const SeedPoem kSeedPoems[] = {
    {"望庐山瀑布", "李白", "唐", "日照香炉生紫烟，遥看瀑布挂前川。\n飞流直下三千尺，疑是银河落九天。", "飞流直下三千尺，\n疑是银河落九天。", "https://zh.wikisource.org/zh-hans/望廬山瀑布"},
    {"春夜喜雨", "杜甫", "唐", "好雨知时节，当春乃发生。\n随风潜入夜，润物细无声。\n野径云俱黑，江船火独明。\n晓看红湿处，花重锦官城。", "随风潜入夜，\n润物细无声。", "https://zh.wikisource.org/wiki/春夜喜雨"},
    {"山居秋暝", "王维", "唐", "空山新雨后，天气晚来秋。\n明月松间照，清泉石上流。\n竹喧归浣女，莲动下渔舟。\n随意春芳歇，王孙自可留。", "明月松间照，\n清泉石上流。", "https://zh.wikisource.org/zh/山居秋暝"},
    {"饮湖上初晴后雨·其二", "苏轼", "宋", "水光潋滟晴方好，山色空蒙雨亦奇。\n欲把西湖比西子，淡妆浓抹总相宜。", "水光潋滟晴方好，\n山色空蒙雨亦奇。", "https://zh.wikisource.org/zh-hans/御選四朝詩_(四庫全書本)/宋詩卷66"},
    {"登鹳雀楼", "王之涣", "唐", "白日依山尽，黄河入海流。\n欲穷千里目，更上一层楼。", "白日依山尽，\n黄河入海流。", "https://zh.wikisource.org/zh-hans/登鸛雀樓_(王之渙)"},
    {"题西林壁", "苏轼", "宋", "横看成岭侧成峰，远近高低各不同。\n不识庐山真面目，只缘身在此山中。", "横看成岭侧成峰，\n远近高低各不同。", "https://zh.wikisource.org/zh-hans/題西林壁_(蘇軾)"},
    {"江雪", "柳宗元", "唐", "千山鸟飞绝，万径人踪灭。\n孤舟蓑笠翁，独钓寒江雪。", "孤舟蓑笠翁，\n独钓寒江雪。", "https://zh.wikisource.org/zh-hans/御選唐詩_(四庫全書本)/卷27"},
    {"泊船瓜洲", "王安石", "宋", "京口瓜洲一水间，钟山只隔数重山。\n春风又绿江南岸，明月何时照我还？", "春风又绿江南岸，\n明月何时照我还？", "https://www.edb.gov.hk/attachment/tc/curriculum-development/kla/chi-edu/recommended-passages/KS2_15.pdf"},
    {"静夜思", "李白", "唐", "床前明月光，疑是地上霜。\n举头望明月，低头思故乡。", "举头望明月，\n低头思故乡。", "https://zh.wikisource.org/zh-hans/靜夜思"},
    {"送元二使安西", "王维", "唐", "渭城朝雨浥轻尘，客舍青青柳色新。\n劝君更尽一杯酒，西出阳关无故人。", "劝君更尽一杯酒，\n西出阳关无故人。", "https://zh.wikisource.org/zh-hans/送元二使安西"},
    {"早发白帝城", "李白", "唐", "朝辞白帝彩云间，千里江陵一日还。\n两岸猿声啼不住，轻舟已过万重山。", "两岸猿声啼不住，\n轻舟已过万重山。", "https://zh.wikisource.org/zh-hans/早發白帝城"},
    {"枫桥夜泊", "张继", "唐", "月落乌啼霜满天，江枫渔火对愁眠。\n姑苏城外寒山寺，夜半钟声到客船。", "月落乌啼霜满天，\n江枫渔火对愁眠。", "https://zh.wikisource.org/zh-hans/楓橋夜泊"},
    {"游子吟", "孟郊", "唐", "慈母手中线，游子身上衣。\n临行密密缝，意恐迟迟归。\n谁言寸草心，报得三春晖。", "谁言寸草心，\n报得三春晖。", "https://zh.wikisource.org/zh-hans/遊子吟_(孟郊)"},
    {"滁州西涧", "韦应物", "唐", "独怜幽草涧边生，上有黄鹂深树鸣。\n春潮带雨晚来急，野渡无人舟自横。", "春潮带雨晚来急，\n野渡无人舟自横。", "https://zh.wikisource.org/zh-hans/滁州西澗"},
    {"忆江南·其一", "白居易", "唐", "江南好，风景旧曾谙。\n日出江花红胜火，春来江水绿如蓝。\n能不忆江南。", "日出江花红胜火，\n春来江水绿如蓝。", "https://zh.wikisource.org/zh-hans/憶江南詞三首"},
    {"望岳", "杜甫", "唐", "岱宗夫如何，齐鲁青未了。\n造化钟神秀，阴阳割昏晓。\n荡胸生层云，决眦入归鸟。\n会当凌绝顶，一览众山小。", "会当凌绝顶，\n一览众山小。", "https://zh.wikisource.org/zh-hans/望嶽"}
};
}

HomeController::HomeController(QObject *parent) : QObject(parent)
{
    if (openDatabase() && createSchemaAndSeed())
        loadPoems();
}

HomeController::~HomeController()
{
    const QString connection = m_database.connectionName();
    m_database.close();
    m_database = QSqlDatabase();
    if (!connection.isEmpty())
        QSqlDatabase::removeDatabase(connection);
}

bool HomeController::openDatabase()
{
    const QString overrideDir = qEnvironmentVariable("YIJUANSHANHE_DATA_DIR");
    const QString dataDir = overrideDir.isEmpty()
        ? QStandardPaths::writableLocation(QStandardPaths::AppDataLocation)
        : overrideDir;
    if (dataDir.isEmpty() || !QDir().mkpath(dataDir)) {
        setError(QStringLiteral("无法创建本地数据目录。"));
        return false;
    }

    m_database = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), QString::fromLatin1(kConnectionName));
    m_database.setDatabaseName(QDir(dataDir).filePath(QStringLiteral("poetry.sqlite")));
    if (!m_database.open()) {
        setError(QStringLiteral("无法打开诗词数据库：") + m_database.lastError().text());
        return false;
    }
    return true;
}

bool HomeController::createSchemaAndSeed()
{
    QSqlQuery query(m_database);
    if (!query.exec(QStringLiteral(
            "CREATE TABLE IF NOT EXISTS poems ("
            "id INTEGER PRIMARY KEY, "
            "title TEXT NOT NULL, author TEXT NOT NULL, dynasty TEXT NOT NULL, "
            "content TEXT NOT NULL, excerpt TEXT NOT NULL, "
            "source_note TEXT NOT NULL)"))) {
        setError(QStringLiteral("数据库初始化失败：") + query.lastError().text());
        return false;
    }

    if (!query.exec(QStringLiteral("PRAGMA user_version")) || !query.next()) {
        setError(QStringLiteral("读取数据库版本失败：") + query.lastError().text());
        return false;
    }
    if (query.value(0).toInt() >= 1)
        return true;

    if (!m_database.transaction()) {
        setError(QStringLiteral("数据库事务启动失败：") + m_database.lastError().text());
        return false;
    }

    QSqlQuery insert(m_database);
    if (!insert.prepare(QStringLiteral(
            "INSERT OR IGNORE INTO poems "
            "(id, title, author, dynasty, content, excerpt, source_note) "
            "VALUES (?, ?, ?, ?, ?, ?, ?)"))) {
        m_database.rollback();
        setError(QStringLiteral("诗词导入准备失败：") + insert.lastError().text());
        return false;
    }

    for (int i = 0; i < int(sizeof(kSeedPoems) / sizeof(kSeedPoems[0])); ++i) {
        const SeedPoem &poem = kSeedPoems[i];
        insert.bindValue(0, i + 1);
        insert.bindValue(1, QString::fromUtf8(poem.title));
        insert.bindValue(2, QString::fromUtf8(poem.author));
        insert.bindValue(3, QString::fromUtf8(poem.dynasty));
        insert.bindValue(4, QString::fromUtf8(poem.content));
        insert.bindValue(5, QString::fromUtf8(poem.excerpt));
        insert.bindValue(6, QString::fromUtf8(poem.source));
        if (!insert.exec()) {
            m_database.rollback();
            setError(QStringLiteral("诗词导入失败：") + insert.lastError().text());
            return false;
        }
        QSqlQuery sourceUpdate(m_database);
        sourceUpdate.prepare(QStringLiteral("UPDATE poems SET source_note = ? WHERE id = ?"));
        sourceUpdate.addBindValue(QString::fromUtf8(poem.source));
        sourceUpdate.addBindValue(i + 1);
        if (!sourceUpdate.exec()) {
            m_database.rollback();
            setError(QStringLiteral("诗词来源保存失败：") + sourceUpdate.lastError().text());
            return false;
        }
    }

    if (!m_database.commit()) {
        setError(QStringLiteral("数据库保存失败：") + m_database.lastError().text());
        return false;
    }
    if (!query.exec(QStringLiteral("PRAGMA user_version = 1"))) {
        setError(QStringLiteral("记录数据库版本失败：") + query.lastError().text());
        return false;
    }
    return true;
}

bool HomeController::loadPoems()
{
    QSqlQuery query(m_database);
    if (!query.exec(QStringLiteral("SELECT id, title, author, dynasty, excerpt FROM poems ORDER BY id"))) {
        setError(QStringLiteral("诗词读取失败：") + query.lastError().text());
        return false;
    }

    m_poems.clear();
    while (query.next()) {
        m_poems.append({query.value(0).toInt(), query.value(1).toString(),
                        query.value(2).toString(), query.value(3).toString(),
                        query.value(4).toString()});
    }
    if (m_poems.isEmpty()) {
        setError(QStringLiteral("数据库中暂无诗词。"));
        return false;
    }

    m_index = 0;
    emit poemChanged();
    return true;
}

void HomeController::setError(const QString &message)
{
    if (m_errorMessage == message)
        return;
    m_errorMessage = message;
    qWarning().noquote() << message;
    emit errorMessageChanged();
}

const HomeController::Poem *HomeController::currentPoem() const
{
    return m_index >= 0 && m_index < m_poems.size() ? &m_poems[m_index] : nullptr;
}

QString HomeController::poemTitle() const { return currentPoem() ? currentPoem()->title : QString(); }
QString HomeController::poemAuthor() const { return currentPoem() ? currentPoem()->author : QString(); }
QString HomeController::poemDynasty() const { return currentPoem() ? currentPoem()->dynasty : QString(); }
QString HomeController::poemExcerpt() const { return currentPoem() ? currentPoem()->excerpt : QString(); }
int HomeController::poemPosition() const { return currentPoem() ? m_index + 1 : 0; }
int HomeController::poemCount() const { return m_poems.size(); }
QString HomeController::errorMessage() const { return m_errorMessage; }

void HomeController::nextPoem()
{
    if (m_poems.isEmpty())
        return;
    m_index = (m_index + 1) % m_poems.size();
    emit poemChanged();
}

void HomeController::previousPoem()
{
    if (m_poems.isEmpty())
        return;
    m_index = (m_index + m_poems.size() - 1) % m_poems.size();
    emit poemChanged();
}
