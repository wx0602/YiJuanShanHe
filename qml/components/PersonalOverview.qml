import QtQuick
import YiJuanShanHe

Item {
    id: overview
    signal navigate(int destination)
    signal openPoem(int poemId)
    signal openArchive()
    signal openMistakes()
    signal editNote(var row)

    readonly property var latestRead: personal.history.length ? personal.history[0] : ({})
    readonly property var latestNote: personal.notes.length ? personal.notes[0] : ({})
    readonly property int activeDays: {
        let days = 0
        for (let i = 0; i < personal.trend.length; ++i)
            if (personal.trend[i].attempts > 0) ++days
        return days
    }
    readonly property int maxDailyAttempts: {
        let count = 1
        for (let i = 0; i < personal.trend.length; ++i)
            count = Math.max(count, personal.trend[i].attempts)
        return count
    }
    readonly property color body: Theme.text
    readonly property color soft: Theme.secondary
    readonly property color quietPanel: Theme.light ? "#FFFCF5" : "#294C50"
    readonly property color highlightPanel: Theme.light ? "#F0E4CF" : "#31575A"

    Text { x: 30; y: 21; text: "我的诗词旅程"; color: overview.body; font.family: "SimSun"; font.pixelSize: 25 }
    Text { x: 204; y: 30; text: "读过的诗，终会成为自己的山河"; color: overview.soft; font.family: "SimSun"; font.pixelSize: 12 }
    Rectangle { x: 30; y: 62; width: parent.width - 60; height: 1; color: Theme.line }

    Rectangle {
        id: readPanel
        x: 29; y: 78; width: (parent.width - 70) * .54; height: 213; radius: 9
        color: readHover.containsMouse ? overview.highlightPanel : overview.quietPanel
        border.color: Theme.border
        Behavior on color { ColorAnimation { duration: personal.animationsEnabled ? 180 : 0 } }
        Rectangle { x: 0; y: 18; width: 3; height: parent.height - 36; color: Theme.gold }
        Text { x: 20; y: 17; text: "最近阅读  /  CONTINUE READING"; color: Theme.gold; font.family: "Georgia"; font.pixelSize: 11; font.letterSpacing: 1 }
        Text {
            x: 20; y: 52; width: parent.width - 40
            text: personal.history.length ? "《" + overview.latestRead.title + "》" : "尚未写下第一段阅读足迹"
            color: overview.body; font.family: "SimSun"; font.pixelSize: 23; elide: Text.ElideRight
        }
        Text {
            x: 21; y: 91; width: parent.width - 42
            text: personal.history.length ? overview.latestRead.author + "  ·  " + overview.latestRead.date + "  ·  已读 " + overview.latestRead.count + " 次"
                                          : "从诗词典藏读一首诗，旅程便从这里开始。"
            color: overview.soft; font.family: "Microsoft YaHei UI"; font.pixelSize: 12; wrapMode: Text.Wrap
        }
        Rectangle { x: 20; y: 154; width: parent.width - 40; height: 1; color: Theme.line }
        Text { x: 20; y: 171; text: personal.history.length ? "继续读这首诗  ↗" : "前往诗词典藏  ↗"; color: Theme.gold; font.family: "SimSun"; font.pixelSize: 14 }
        MouseArea {
            id: readHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: personal.history.length ? overview.openPoem(overview.latestRead.id) : overview.openArchive()
        }
    }
    Rectangle {
        id: notePanel
        x: readPanel.x + readPanel.width + 12; y: readPanel.y
        width: parent.width - x - 29; height: 213; radius: 9
        color: noteHover.containsMouse ? overview.highlightPanel : overview.quietPanel
        border.color: Theme.border
        Behavior on color { ColorAnimation { duration: personal.animationsEnabled ? 180 : 0 } }
        Text { x: 20; y: 17; text: "诗笺一隅  /  LATEST NOTE"; color: Theme.gold; font.family: "Georgia"; font.pixelSize: 11; font.letterSpacing: 1 }
        Text {
            x: 20; y: 49; width: parent.width - 40
            text: personal.notes.length ? "《" + overview.latestNote.title + "》" : "案头尚无诗笺"
            color: overview.body; font.family: "SimSun"; font.pixelSize: 19; elide: Text.ElideRight
        }
        Text {
            x: 21; y: 83; width: parent.width - 42; height: 70
            text: personal.notes.length ? overview.latestNote.body : "读诗有所感时，可在诗词典藏中写下笔记。"
            color: overview.soft; font.family: "SimSun"; font.pixelSize: 13
            lineHeight: 1.55; wrapMode: Text.Wrap; maximumLineCount: 3; elide: Text.ElideRight
        }
        Rectangle { x: 20; y: 154; width: parent.width - 40; height: 1; color: Theme.line }
        Text { x: 20; y: 171; text: personal.notes.length ? "续写这则诗笺  ↗" : "查看我的笔记  ↗"; color: Theme.gold; font.family: "SimSun"; font.pixelSize: 14 }
        MouseArea {
            id: noteHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: personal.notes.length ? overview.editNote(overview.latestNote) : overview.navigate(1)
        }
    }

    Rectangle {
        id: favoritesPanel
        x: 29; y: 304; width: parent.width - 58; height: 158; radius: 9
        color: overview.quietPanel; border.color: Theme.border
        Text { x: 20; y: 16; text: "珍藏诗卷"; color: overview.body; font.family: "SimSun"; font.pixelSize: 20 }
        Text { x: 130; y: 22; text: "共 " + (personal.stats.favorites || 0) + " 首"; color: Theme.gold; font.pixelSize: 11 }
        Text {
            anchors.right: parent.right; anchors.rightMargin: 19; y: 21
            text: "查看全部  ↗"; color: Theme.gold; font.family: "SimSun"; font.pixelSize: 12
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: overview.navigate(0) }
        }
        Rectangle { x: 20; y: 49; width: parent.width - 40; height: 1; color: Theme.line }
        Row {
            x: 19; y: 61; width: parent.width - 38; height: 79; spacing: 8
            Repeater {
                model: personal.favorites.slice(0, 3)
                delegate: Rectangle {
                    id: poemCard
                    required property var modelData
                    width: (favoritesPanel.width - 54) / 3; height: 77; radius: 6
                    color: poemMouse.containsMouse ? overview.highlightPanel : (Theme.light ? "#F8F1E6" : "#34575A")
                    border.color: Theme.border
                    Behavior on color { ColorAnimation { duration: personal.animationsEnabled ? 170 : 0 } }
                    Text { x: 11; y: 12; width: parent.width - 22; text: "《" + poemCard.modelData.title + "》"; color: overview.body; font.family: "SimSun"; font.pixelSize: 16; elide: Text.ElideRight }
                    Text { x: 12; y: 44; width: parent.width - 24; text: poemCard.modelData.author + "  ·  继续阅读 ↗"; color: overview.soft; font.pixelSize: 11; elide: Text.ElideRight }
                    MouseArea { id: poemMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: overview.openPoem(poemCard.modelData.id) }
                }
            }
        }
        Text {
            x: 21; y: 87; visible: personal.favorites.length === 0
            text: "还没有珍藏诗卷。遇见喜欢的诗，便把它收进手札。"; color: overview.soft; font.family: "SimSun"; font.pixelSize: 13
        }
    }

    Rectangle {
        x: 29; y: 475; width: parent.width - 58; height: 91; radius: 9
        color: Theme.light ? "#EDE2CD" : "#25494C"; border.color: Theme.border
        Text { x: 20; y: 13; text: "学习足迹"; color: overview.body; font.family: "SimSun"; font.pixelSize: 19 }
        Text {
            x: 20; y: 47; width: parent.width * .49
            text: (personal.stats.attempts || 0) > 0
                  ? "已作答 " + personal.stats.attempts + " 次  ·  正确率 " + personal.stats.accuracy + "%"
                  : "诗会尚未开场，去雅集写下第一笔。"
            color: overview.soft; font.pixelSize: 12; elide: Text.ElideRight
        }
        Row {
            anchors.right: parent.right; anchors.rightMargin: 118; y: 15; height: 58; spacing: 5
            visible: overview.activeDays >= 2
            Repeater {
                model: personal.trend
                delegate: Item {
                    required property var modelData
                    width: 20; height: 58
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom
                        anchors.bottomMargin: 10; width: 10
                        height: Math.max(3, 42 * modelData.attempts / overview.maxDailyAttempts)
                        color: Theme.gold; radius: 3
                    }
                }
            }
        }
        Text {
            anchors.right: parent.right; anchors.rightMargin: 18; y: 35
            text: "查看学习记录  ↗"; color: Theme.gold; font.family: "SimSun"; font.pixelSize: 12
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: overview.navigate(3) }
        }
    }
}
