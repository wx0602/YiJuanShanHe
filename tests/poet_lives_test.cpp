#include "../src/poetlifemodel.h"

#include <QCoreApplication>
#include <QFile>
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
    PoetLifeModel poets;
    if (!check(poets.errorMessage().isEmpty() && poets.resultCount() == 8,
               QStringLiteral("eight independent JSON profiles load"))) return 1;

    for (const QString &id : {QStringLiteral("taoyuanming"), QStringLiteral("libai"),
                              QStringLiteral("dufu"), QStringLiteral("baijuyi"),
                              QStringLiteral("ouyangxiu"), QStringLiteral("sushi"),
                              QStringLiteral("luyou"), QStringLiteral("xinqiji")}) {
        if (!check(poets.selectPoet(id), QStringLiteral("poet selection: ") + id)) return 1;
        const QVariantMap profile = poets.selectedProfile();
        if (!check(!profile.value(QStringLiteral("name")).toString().isEmpty()
                   && !profile.value(QStringLiteral("intro")).toString().isEmpty()
                   && profile.value(QStringLiteral("sources")).toList().size() > 0,
                   QStringLiteral("complete sourced profile: ") + id)) return 1;
        if (!check(poets.selectedStages().size() == 4 && poets.selectedEvents().size() >= 5,
                   QStringLiteral("stages and events: ") + id)) return 1;
        int lastYear = 0;
        for (const QVariant &item : poets.selectedEvents()) {
            const QVariantMap event = item.toMap();
            const int year = event.value(QStringLiteral("year")).toInt();
            if (!check(year >= lastYear && !event.value(QStringLiteral("source")).toString().isEmpty()
                       && !event.value(QStringLiteral("detail")).toString().isEmpty(),
                       QStringLiteral("chronological sourced event: ") + id)) return 1;
            lastYear = year;
        }
    }
    poets.selectPoet(QStringLiteral("sushi"));
    poets.search(QStringLiteral("东坡"));
    if (!check(poets.resultCount() == 1 && poets.index(0, 0).data(PoetLifeModel::IdRole).toString() == QStringLiteral("sushi"),
               QStringLiteral("search by epithet"))) return 1;
    poets.search(QStringLiteral("不存在的人物"));
    if (!check(poets.resultCount() == 0 && poets.selectedId() == QStringLiteral("sushi"),
               QStringLiteral("empty result preserves selected profile"))) return 1;
    poets.search({});
    if (!check(poets.setComparison(0, QStringLiteral("sushi"))
               && !poets.setComparison(1, QStringLiteral("sushi"))
               && poets.setComparison(1, QStringLiteral("libai"))
               && poets.compareAProfile().value(QStringLiteral("name")) == QStringLiteral("苏轼")
               && poets.compareBEvents().size() >= 5,
               QStringLiteral("independent distinct poet comparison"))) return 1;

    QTemporaryDir temporary;
    const QString invalidPath = temporary.filePath(QStringLiteral("invalid.json"));
    QFile invalid(invalidPath);
    if (!check(invalid.open(QIODevice::WriteOnly), QStringLiteral("create malformed fixture"))) return 1;
    invalid.write("not json"); invalid.close();
    PoetLifeModel broken(invalidPath);
    if (!check(!broken.errorMessage().isEmpty() && broken.resultCount() == 0,
               QStringLiteral("malformed JSON handled"))) return 1;
    QTextStream(stdout) << "poet lives tests passed" << Qt::endl;
    return 0;
}
