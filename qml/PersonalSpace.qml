import QtQuick
import QtQuick.Controls
import YiJuanShanHe

Item {
    id: page
    signal openPoem(int poemId)
    signal openArchive()
    signal openMistakes()
    signal notify(string message)
    property int section: -1
    property int learningSection: 0
    property string favoriteSearch: ""
    property int favoriteSort: 0
    property int noteAuthorIndex: 0
    property int noteSort: 0
    property string historyDate: ""
    property string draftName: personal.nickname
    property string draftAvatar: personal.avatar
    property int draftFont: personal.readingFontSize
    property bool draftMotion: personal.animationsEnabled
    property string draftTheme: personal.theme
    property int editingPoemId: 0
    property string pendingAction: ""
    property int pendingId: 0
    readonly property color gold: Theme.gold
    readonly property color paper: Theme.light ? Theme.paper : "#25474A"
    readonly property color paperAlt: Theme.light ? Theme.paperAlt : "#31575A"
    readonly property color ink: Theme.light ? Theme.paperInk : Theme.text
    readonly property color muted: Theme.light ? Theme.paperMuted : Theme.secondary
    readonly property color gilt: Theme.light ? Theme.paperGold : Theme.gold
    readonly property var sections: ["我的旅程", "我的收藏", "我的笔记", "阅读足迹", "学习统计", "偏好设置"]
    readonly property int listCount: section === 0 ? personal.favorites.length
                                     : section === 1 ? personal.notes.length
                                     : section === 2 ? personal.history.length
                                     : section === 3 ? (learningSection === 0 ? personal.rounds.length : personal.mistakes.length) : 0
    onSectionChanged: shell.contentY = 0

    onVisibleChanged: if (visible) personal.refresh()
    Component.onCompleted: if (visible) personal.refresh()
    Connections { target: personal; function onSettingsChanged() { page.draftTheme = personal.theme } }

    function askDelete(action, id) {
        pendingAction = action
        pendingId = id
        confirmPopup.open()
    }
    function showNote(row) {
        editingPoemId = row.id
        noteTitle.text = "《" + row.title + "》 · " + row.author
        noteEditor.text = row.body
        notePopup.open()
    }
    function barHeight(value) {
        var largest = 1
        for (var i = 0; i < personal.trend.length; ++i)
            largest = Math.max(largest, personal.trend[i].attempts)
        return value === 0 ? 0 : Math.max(3, 80 * value / largest)
    }

    Rectangle { anchors.fill: parent; color: Theme.background }
    Flickable {
        id: shell
        anchors.fill: parent; contentWidth: width
        contentHeight: contentFrame.y + contentFrame.height + 28
        clip: true; boundsBehavior: Flickable.StopAtBounds
        Item {
            id: contentFrame
            x: 24; y: 22; width: shell.width - 48
            height: contentPanel.y + contentPanel.height + (afterword.visible ? afterword.height + 28 : 18)

            Rectangle {
                id: profileCard
                x: 0; y: 0; width: parent.width; height: 151; radius: 15
                color: Theme.surface; border.color: Theme.border
                clip: true
                opacity: 1
                NumberAnimation on opacity { from: 0; to: 1; duration: personal.animationsEnabled ? 420 : 0; running: page.visible }
                ArtBackground {
                    anchors.fill: parent
                    lightSource: "qrc:/picture/b420b20827e9cefed34f0277a69dd4dd.jpg"
                    lightClip: Qt.rect(0, 1210, 1440, 730)
                    darkSource: "qrc:/picture/ec99fa2a133e9c6dd4e0ad5755896c68.jpg"
                    darkClip: Qt.rect(0, 0, 1440, 2230)
                    lightVeil: "#8AFFFCF5"
                    darkVeil: "#A818383D"
                }
                Rectangle {
                    x: 25; y: 22; width: 103; height: 103; radius: 52
                    color: Theme.card; border.color: page.gold; border.width: 2
                    Rectangle { anchors.centerIn: parent; width: 86; height: 86; radius: 43; color: "transparent"; border.color: Theme.border }
                    Text { anchors.centerIn: parent; text: personal.avatar; color: Theme.text; font.family: "SimSun"; font.pixelSize: 54 }
                }
                Text { x: 153; y: 22; text: "山 河 手 记  /  PERSONAL JOURNAL"; color: page.gold; font.family: "Georgia"; font.pixelSize: 11; font.letterSpacing: 1.4 }
                Text { x: 151; y: 52; text: personal.nickname; color: Theme.text; font.family: "SimSun"; font.pixelSize: 30; elide: Text.ElideRight; width: parent.width - 350 }
                Text { x: 153; y: 103; text: "收藏所爱，记下所悟，循诗重游。"; color: Theme.text; font.family: "Microsoft YaHei UI"; font.pixelSize: 12 }
                Rectangle {
                    anchors.right: parent.right; anchors.rightMargin: 27; y: 49; width: 126; height: 42; radius: 7
                    color: profileHover.containsMouse ? Theme.cardAlt : Theme.card; border.color: Theme.border
                    Text { anchors.centerIn: parent; text: "编辑个人资料  ↗"; color: Theme.text; font.family: "SimSun"; font.pixelSize: 13 }
                    MouseArea { id: profileHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: page.section = 4 }
                }
            }

            Rectangle {
                id: statRow; x: 0; y: 165; width: parent.width; height: 72; radius: 10
                color: Theme.light ? "#F7F1E6" : "#24474B"; border.color: Theme.border
                Row {
                    anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10
                Repeater {
                    model: [
                        {title: "收藏诗词", value: personal.stats.favorites || 0, unit: "首"},
                        {title: "读过诗词", value: personal.stats.read || 0, unit: "首"},
                        {title: "个人笔记", value: personal.stats.notes || 0, unit: "则"},
                        {title: "累计答题", value: personal.stats.attempts || 0, unit: "次"},
                        {title: "答题正确率", value: (personal.stats.accuracy || 0) + "%", unit: ""}
                    ]
                    delegate: Item {
                        required property var modelData
                        required property int index
                        width: (statRow.width - 20) / 5; height: 72
                        Text { anchors.horizontalCenter: parent.horizontalCenter; y: 10; text: modelData.title; color: Theme.secondary; font.family: "SimSun"; font.pixelSize: 11 }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; y: 31; text: modelData.value + " " + modelData.unit; color: Theme.text; font.family: "Georgia"; font.pixelSize: 21 }
                        Rectangle { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; width: 1; height: 35; color: Theme.line; visible: index < 4 }
                    }
                }
                }
            }

            Row {
                id: tabs; x: 0; y: 252; width: parent.width; height: 40; spacing: 8
                Repeater {
                    model: page.sections
                    delegate: Rectangle {
                        required property string modelData
                        required property int index
                        width: index === 0 ? 110 : 104; height: 38; radius: 6
                        color: page.section === index - 1 ? Theme.selected : (tabMouse.containsMouse ? Theme.hover : "transparent")
                        border.color: page.section === index - 1 ? Theme.borderStrong : "transparent"
                        Behavior on color { ColorAnimation { duration: personal.animationsEnabled ? 180 : 0 } }
                        Text { anchors.centerIn: parent; text: modelData; color: Theme.text; font.family: "SimSun"; font.pixelSize: 14 }
                        MouseArea { id: tabMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: page.section = index - 1 }
                    }
                }
            }

            Rectangle {
                id: contentPanel
                x: 0; y: 307; width: parent.width
                height: page.section === -1 ? 596 : page.section === 4 ? 482
                        : page.section === 3 ? Math.min(620, Math.max(370, 340 + page.listCount * (page.learningSection === 0 ? 54 : 72)))
                        : Math.min(620, Math.max(230, 128 + page.listCount * (page.section === 1 ? 133 : page.section === 2 ? 75 : 102)))
                radius: 14; color: page.section === -1 ? Theme.surface : page.paper; border.color: Theme.borderStrong
                clip: true
                Rectangle { x: 14; y: 14; width: parent.width - 28; height: parent.height - 28; radius: 8; color: "transparent"; border.color: Theme.border }

                PersonalOverview {
                    anchors.fill: parent
                    visible: page.section === -1
                    onNavigate: function(destination) { page.section = destination }
                    onOpenPoem: function(poemId) { page.openPoem(poemId) }
                    onOpenArchive: page.openArchive()
                    onOpenMistakes: page.openMistakes()
                    onEditNote: function(row) { page.showNote(row) }
                }

                Item {
                    anchors.fill: parent; visible: page.section === 0
                    Text { x: 30; y: 19; text: "珍藏诗卷"; color: page.ink; font.family: "SimSun"; font.pixelSize: 23 }
                    Text { x: 149; y: 27; text: personal.favorites.length + " 首"; color: page.gilt; font.pixelSize: 12 }
                    Rectangle {
                        x: 28; y: 61; width: Math.min(270, parent.width * .38); height: 36; radius: 6
                        color: page.paper; border.color: Theme.border
                        TextField {
                            id: favoriteField; anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 8
                            placeholderText: "搜索标题或诗人"; placeholderTextColor: page.muted
                            color: page.ink; font.pixelSize: 13; background: Item {}
                            onTextChanged: { page.favoriteSearch = text; favoriteTimer.restart() }
                        }
                        Timer { id: favoriteTimer; interval: 220; onTriggered: personal.setFavoriteQuery(favoriteField.text, ["latest", "title", "author"][page.favoriteSort]) }
                    }
                    Rectangle {
                        x: Math.min(310, parent.width * .38 + 39); y: 61; width: 125; height: 36; radius: 6
                        color: page.paperAlt; border.color: Theme.borderStrong
                        Text { anchors.centerIn: parent; text: ["最近收藏", "按标题", "按诗人"][page.favoriteSort] + "  ▾"; color: page.ink; font.pixelSize: 12 }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { page.favoriteSort = (page.favoriteSort + 1) % 3; personal.setFavoriteQuery(page.favoriteSearch || favoriteField.text, ["latest", "title", "author"][page.favoriteSort]) } }
                    }
                    ListView {
                        id: favoriteList; x: 22; y: 111; width: parent.width - 44; height: parent.height - 130
                        clip: true; spacing: 8; model: personal.favorites; boundsBehavior: Flickable.StopAtBounds
                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                        delegate: Rectangle {
                            required property var modelData
                            width: favoriteList.width - 6; height: 92; radius: 8
                            color: favoriteMouse.containsMouse ? page.paperAlt : page.paper; border.color: favoriteMouse.containsMouse ? Theme.borderStrong : Theme.border
                            Behavior on color { ColorAnimation { duration: personal.animationsEnabled ? 150 : 0 } }
                            Rectangle { x: 0; y: 15; width: 3; height: 62; color: page.gold }
                            Text { x: 17; y: 13; width: parent.width - 214; text: "《" + modelData.title + "》"; color: page.ink; font.family: "SimSun"; font.pixelSize: 19; elide: Text.ElideRight }
                            Text { x: 18; y: 48; width: parent.width - 208; text: (modelData.dynasty ? modelData.dynasty + " · " : "") + modelData.author + "   /   " + modelData.excerpt.replace(/\n/g, "  "); color: page.muted; font.family: "SimSun"; font.pixelSize: 12; elide: Text.ElideRight }
                            Text { anchors.right: parent.right; anchors.rightMargin: 111; y: 30; text: "读诗  ↗"; color: page.ink; font.pixelSize: 13 }
                            Text { anchors.right: parent.right; anchors.rightMargin: 20; y: 30; text: "取消收藏"; color: Theme.danger; font.pixelSize: 12
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: page.askDelete("favorite", modelData.id) } }
                            MouseArea { id: favoriteMouse; x: 0; y: 0; width: parent.width - 115; height: parent.height; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: page.openPoem(modelData.id) }
                        }
                        Text { anchors.centerIn: parent; visible: parent.count === 0; text: "还没有符合条件的收藏。诗海拾珍，静候你来。"; color: page.muted; font.family: "SimSun"; font.pixelSize: 15 }
                    }
                }

                Item {
                    anchors.fill: parent; visible: page.section === 1
                    Text { x: 30; y: 19; text: "案头札记"; color: page.ink; font.family: "SimSun"; font.pixelSize: 23 }
                    Text { x: 147; y: 27; text: personal.notes.length + " 则"; color: page.gilt; font.pixelSize: 12 }
                    Rectangle {
                        x: 28; y: 61; width: 160; height: 36; radius: 6; color: page.paperAlt; border.color: Theme.borderStrong
                        Text { anchors.centerIn: parent; width: parent.width - 16; text: (personal.authors[page.noteAuthorIndex] || "全部诗人") + "  ▾"; color: page.ink; elide: Text.ElideRight; horizontalAlignment: Text.AlignHCenter; font.pixelSize: 12 }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { page.noteAuthorIndex = (page.noteAuthorIndex + 1) % Math.max(1, personal.authors.length); personal.setNoteQuery(personal.authors[page.noteAuthorIndex] || "", ["latest", "oldest", "author"][page.noteSort]) } }
                    }
                    Rectangle {
                        x: 198; y: 61; width: 138; height: 36; radius: 6; color: page.paperAlt; border.color: Theme.borderStrong
                        Text { anchors.centerIn: parent; text: ["最近修改", "最早修改", "按诗人"][page.noteSort] + "  ▾"; color: page.ink; font.pixelSize: 12 }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { page.noteSort = (page.noteSort + 1) % 3; personal.setNoteQuery(personal.authors[page.noteAuthorIndex] || "", ["latest", "oldest", "author"][page.noteSort]) } }
                    }
                    ListView {
                        id: noteList; x: 22; y: 111; width: parent.width - 44; height: parent.height - 130
                        model: personal.notes; clip: true; spacing: 8; boundsBehavior: Flickable.StopAtBounds
                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                        delegate: Rectangle {
                            required property var modelData
                            width: noteList.width - 6; height: 108; radius: 8
                            color: noteMouse.containsMouse ? page.paperAlt : page.paper; border.color: noteMouse.containsMouse ? Theme.borderStrong : Theme.border
                            Behavior on color { ColorAnimation { duration: personal.animationsEnabled ? 150 : 0 } }
                            Text { x: 18; y: 10; width: parent.width - 225; text: "《" + modelData.title + "》  ·  " + modelData.author; color: page.ink; font.family: "SimSun"; font.pixelSize: 18; elide: Text.ElideRight }
                            Text { x: 19; y: 39; width: parent.width - 37; height: 38; text: modelData.body; color: page.ink; font.family: "SimSun"; font.pixelSize: 13; wrapMode: Text.Wrap; elide: Text.ElideRight; maximumLineCount: 2 }
                            Text { x: 19; y: 83; text: "最近修改  " + modelData.date; color: page.gilt; font.pixelSize: 10 }
                            Text { anchors.right: parent.right; anchors.rightMargin: 104; y: 13; text: "编辑"; color: page.ink; font.pixelSize: 12
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: page.showNote(modelData) } }
                            Text { anchors.right: parent.right; anchors.rightMargin: 24; y: 13; text: "删除"; color: Theme.danger; font.pixelSize: 12
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: page.askDelete("note", modelData.id) } }
                            MouseArea { id: noteMouse; x: 0; y: 0; width: parent.width - 230; height: 36; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: page.openPoem(modelData.id) }
                        }
                        Text { anchors.centerIn: parent; visible: parent.count === 0; text: "暂无笔记。从一首诗开始写下所思。"; color: page.muted; font.family: "SimSun"; font.pixelSize: 15 }
                    }
                }

                Item {
                    anchors.fill: parent; visible: page.section === 2
                    Text { x: 30; y: 19; text: "循诗足迹"; color: page.ink; font.family: "SimSun"; font.pixelSize: 23 }
                    Text { x: 149; y: 27; text: personal.history.length + " 条"; color: page.gilt; font.pixelSize: 12 }
                    Rectangle {
                        x: 28; y: 61; width: 155; height: 36; radius: 6; color: page.paper; border.color: Theme.border
                        TextField {
                            id: dateField; anchors.fill: parent; anchors.leftMargin: 11; anchors.rightMargin: 5
                            placeholderText: "yyyy-MM-dd"; placeholderTextColor: page.muted; color: page.ink
                            font.family: "Georgia"; font.pixelSize: 13; background: Item {}
                            onAccepted: personal.setHistoryDate(text)
                        }
                    }
                    Rectangle { x: 193; y: 61; width: 57; height: 36; radius: 6; color: page.paperAlt; border.color: Theme.borderStrong
                        Text { anchors.centerIn: parent; text: "查询"; color: page.ink; font.pixelSize: 12 }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: personal.setHistoryDate(dateField.text) } }
                    Rectangle { x: 260; y: 61; width: 57; height: 36; radius: 6; color: page.paperAlt; border.color: Theme.borderStrong
                        Text { anchors.centerIn: parent; text: "全部"; color: page.ink; font.pixelSize: 12 }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { dateField.text = ""; personal.setHistoryDate("") } } }
                    Rectangle { anchors.right: parent.right; anchors.rightMargin: 29; y: 61; width: 100; height: 36; radius: 6; color: page.paper; border.color: Theme.border
                        Text { anchors.centerIn: parent; text: "清除足迹"; color: Theme.danger; font.pixelSize: 12 }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: page.askDelete("history", 0) } }
                    ListView {
                        id: historyList; x: 36; y: 110; width: parent.width - 58; height: parent.height - 130
                        model: personal.history; clip: true; spacing: 5; boundsBehavior: Flickable.StopAtBounds
                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                        delegate: Item {
                            required property var modelData
                            width: historyList.width - 6; height: 67
                            Rectangle { x: 8; y: 0; width: 1; height: parent.height; color: Theme.goldWash }
                            Rectangle { x: 3; y: 25; width: 11; height: 11; radius: 6; color: page.gold; border.color: Theme.borderStrong }
                            Rectangle {
                                x: 28; y: 2; width: parent.width - 32; height: 61; radius: 7; color: historyMouse.containsMouse ? page.paper : page.paper; border.color: Theme.border
                                Behavior on color { ColorAnimation { duration: personal.animationsEnabled ? 150 : 0 } }
                                Text { x: 17; y: 9; width: parent.width - 185; text: "《" + modelData.title + "》"; color: page.ink; font.family: "SimSun"; font.pixelSize: 17; elide: Text.ElideRight }
                                Text { x: 18; y: 36; text: modelData.author + "  ·  已读 " + modelData.count + " 次"; color: page.muted; font.pixelSize: 11 }
                                Text { anchors.right: parent.right; anchors.rightMargin: 18; y: 20; text: modelData.date + "  " + modelData.time; color: page.gilt; font.family: "Georgia"; font.pixelSize: 11 }
                                MouseArea { id: historyMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: page.openPoem(modelData.id) }
                            }
                        }
                        Text { anchors.centerIn: parent; visible: parent.count === 0; text: "这一天没有阅读足迹。"; color: page.muted; font.family: "SimSun"; font.pixelSize: 15 }
                    }
                }

                Item {
                    anchors.fill: parent; visible: page.section === 3
                    Text { x: 30; y: 19; text: "习诗有迹"; color: page.ink; font.family: "SimSun"; font.pixelSize: 23 }
                    Text { x: 149; y: 27; text: "最近七日 · 答题趋势"; color: page.gilt; font.pixelSize: 12 }
                    Rectangle { anchors.right: parent.right; anchors.rightMargin: 29; y: 18; width: 118; height: 34; radius: 6; color: Theme.card
                        Text { anchors.centerIn: parent; text: "前往错题重练  ↗"; color: Theme.text; font.pixelSize: 11 }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: page.openMistakes() } }
                    ListView {
                        id: learningList; x: 25; y: 62; width: parent.width - 50; height: parent.height - 80
                        clip: true; spacing: 6; boundsBehavior: Flickable.StopAtBounds
                        model: page.learningSection === 0 ? personal.rounds : personal.mistakes
                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                        header: Item {
                            width: learningList.width; height: 274
                            Rectangle { x: 3; y: 0; width: parent.width - 6; height: 105; radius: 8; color: page.paper; border.color: Theme.border }
                            Text { anchors.horizontalCenter: parent.horizontalCenter; y: 39; visible: (personal.stats.attempts || 0) === 0; text: "完成练习后，这里会留下每日答题足迹"; color: page.muted; font.family: "SimSun"; font.pixelSize: 13 }
                            Row {
                                x: 20; y: 12; width: parent.width - 40; height: 87; spacing: 9
                                Repeater {
                                    model: personal.trend
                                    delegate: Item {
                                        required property var modelData
                                        width: (parent.width - 54) / 7; height: 88
                                        Rectangle { x: (parent.width - 19) / 2; y: 75 - page.barHeight(modelData.attempts); width: 19; height: page.barHeight(modelData.attempts); radius: 3; color: Theme.selected }
                                        Rectangle { x: (parent.width - 19) / 2; y: 75 - page.barHeight(modelData.correct); width: 19; height: page.barHeight(modelData.correct); radius: 3; color: page.gold }
                                        Text { anchors.horizontalCenter: parent.horizontalCenter; y: 75; text: modelData.date.slice(5); color: page.muted; font.family: "Georgia"; font.pixelSize: 10 }
                                    }
                                }
                            }
                            Row {
                                x: 3; y: 116; width: parent.width - 6; height: 92; spacing: 8
                                Repeater {
                                    model: personal.modes
                                    delegate: Rectangle {
                                        required property var modelData
                                        width: (parent.width - 16) / 3; height: 92; radius: 8; color: page.paper; border.color: Theme.border
                                        Text { x: 13; y: 11; text: modelData.title; color: page.ink; font.family: "SimSun"; font.pixelSize: 16 }
                                        Text { x: 14; y: 39; text: modelData.attempts + " 次作答  ·  " + modelData.accuracy + "% 正确"; color: page.muted; font.pixelSize: 11 }
                                        Text { x: 14; y: 64; text: "最高 " + modelData.best + " 分"; color: page.gilt; font.family: "Georgia"; font.pixelSize: 12 }
                                    }
                                }
                            }
                            Rectangle { x: 4; y: 217; width: parent.width - 8; height: 1; color: page.paperAlt }
                            Text { x: 5; y: 234; text: "挑战记录"; color: page.learningSection === 0 ? page.gilt : page.muted; font.family: "SimSun"; font.pixelSize: 14
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: page.learningSection = 0 } }
                            Text { x: 103; y: 234; text: "待温习错题  " + personal.mistakes.length; color: page.learningSection === 1 ? page.gilt : page.muted; font.family: "SimSun"; font.pixelSize: 14
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: page.learningSection = 1 } }
                        }
                        delegate: Rectangle {
                            required property var modelData
                            width: learningList.width - 7; height: page.learningSection === 0 ? 48 : 66; radius: 6; color: page.paper; border.color: Theme.border
                            Text { x: 15; y: 8; width: parent.width - 235; text: page.learningSection === 0 ? modelData.mode : modelData.title + "  ·  " + modelData.mode; color: page.ink; font.family: "SimSun"; font.pixelSize: 15; elide: Text.ElideRight }
                            Text { x: 15; y: 35; width: parent.width - 28; visible: page.learningSection === 1; text: modelData.prompt.replace(/\n/g, " ") + "  /  正解：" + modelData.answer; color: page.muted; font.pixelSize: 11; elide: Text.ElideRight }
                            Text { anchors.right: parent.right; anchors.rightMargin: 15; y: 12; text: page.learningSection === 0 ? modelData.correct + "/" + modelData.count + " 正确    " + modelData.score + " 分    " + modelData.date : "错 " + modelData.count + " 次"; color: page.gilt; font.family: "Georgia"; font.pixelSize: 12 }
                        }
                        footer: Text { width: learningList.width; height: learningList.count === 0 ? 48 : 8; visible: learningList.count === 0; text: page.learningSection === 0 ? "尚无完整挑战记录。" : "暂无待温习的错题。"; color: page.muted; font.pixelSize: 12; horizontalAlignment: Text.AlignHCenter }
                    }
                }

                Item {
                    anchors.fill: parent; visible: page.section === 4
                    Flickable {
                        anchors.fill: parent; clip: true; contentWidth: width; contentHeight: 480; boundsBehavior: Flickable.StopAtBounds
                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                        Rectangle {
                            id: preferencePreview
                            x: Math.max(470, parent.width * 0.55); y: 57
                            width: Math.max(0, parent.width - x - 30); height: 302
                            visible: width >= 245
                            radius: 9; color: page.paper; border.color: Theme.borderStrong
                            Rectangle { x: 19; y: 21; width: 3; height: 22; color: page.gold }
                            Text { x: 32; y: 21; text: "手札题签预览"; color: page.ink; font.family: "SimSun"; font.pixelSize: 18 }
                            Text { anchors.right: parent.right; anchors.rightMargin: 18; y: 26; text: "PERSONAL NOTE"; color: page.gilt; font.family: "Georgia"; font.pixelSize: 10 }
                            Rectangle { x: 19; y: 56; width: parent.width - 38; height: 1; color: Theme.border }
                            Rectangle {
                                x: 22; y: 83; width: 66; height: 66; radius: 33
                                color: page.paperAlt; border.color: page.gold; border.width: 2
                                Text { anchors.centerIn: parent; text: page.draftAvatar; color: page.ink; font.family: "SimSun"; font.pixelSize: 31 }
                            }
                            Text { x: 107; y: 91; width: parent.width - 125; text: page.draftName || "山河旅人"; color: page.ink; font.family: "SimSun"; font.pixelSize: 21; elide: Text.ElideRight }
                            Text { x: 107; y: 122; text: "诗以载道，山河为卷。"; color: page.muted; font.family: "SimSun"; font.pixelSize: 12 }
                            Rectangle { x: 22; y: 169; width: parent.width - 44; height: 1; color: Theme.border }
                            Text { x: 22; y: 187; text: "阅读字号 · " + page.draftFont + " px"; color: page.gilt; font.pixelSize: 11 }
                            Text { x: 22; y: 214; width: parent.width - 44; text: "明月松间照，清泉石上流。"; color: page.ink; font.family: "SimSun"; font.pixelSize: Math.min(page.draftFont, 26); elide: Text.ElideRight }
                            Text { x: 22; y: 266; text: "更改偏好后，请点击保存。"; color: page.muted; font.pixelSize: 11 }
                        }
                        Text { x: 30; y: 20; text: "偏好与题签"; color: page.ink; font.family: "SimSun"; font.pixelSize: 23 }
                        Text { anchors.right: parent.right; anchors.rightMargin: 30; y: 29; visible: contentPanel.height < 480; text: "向下滚动，保存设置  ↓"; color: page.gilt; font.pixelSize: 11 }
                        Text { x: 30; y: 68; text: "昵称"; color: page.ink; font.family: "SimSun"; font.pixelSize: 14 }
                        Rectangle { x: 98; y: 58; width: 245; height: 38; radius: 6; color: page.paper; border.color: Theme.border
                            TextField { anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 7; text: page.draftName; onTextEdited: page.draftName = text; color: page.ink; font.pixelSize: 15; background: Item {} } }
                        Text { x: 30; y: 120; text: "头像"; color: page.ink; font.family: "SimSun"; font.pixelSize: 14 }
                        Row { x: 98; y: 108; spacing: 10
                            Repeater { model: ["山", "月", "竹", "鹤"]
                                delegate: Rectangle {
                                    required property string modelData
                                    width: 48; height: 48; radius: 24; color: page.draftAvatar === modelData ? Theme.card : page.paperAlt; border.color: page.draftAvatar === modelData ? page.gold : Theme.borderStrong
                                    Text { anchors.centerIn: parent; text: modelData; color: page.draftAvatar === modelData ? (Theme.light ? Theme.text : Theme.accentText) : page.ink; font.family: "SimSun"; font.pixelSize: 23 }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: page.draftAvatar = modelData }
                                } }
                        }
                        Text { x: 30; y: 185; text: "阅读字号"; color: page.ink; font.family: "SimSun"; font.pixelSize: 14 }
                        Rectangle { x: 119; y: 177; width: 34; height: 34; radius: 6; color: page.paperAlt; border.color: Theme.border; Text { anchors.centerIn: parent; text: "−"; color: page.ink; font.pixelSize: 19 } MouseArea { anchors.fill: parent; onClicked: page.draftFont = Math.max(18, page.draftFont - 1) } }
                        Text { x: 165; y: 184; text: page.draftFont + " px"; color: page.ink; font.family: "Georgia"; font.pixelSize: 15 }
                        Rectangle { x: 229; y: 177; width: 34; height: 34; radius: 6; color: page.paperAlt; border.color: Theme.border; Text { anchors.centerIn: parent; text: "+"; color: page.ink; font.pixelSize: 19 } MouseArea { anchors.fill: parent; onClicked: page.draftFont = Math.min(32, page.draftFont + 1) } }
                        Text { x: 30; y: 247; text: "柔和动效"; color: page.ink; font.family: "SimSun"; font.pixelSize: 14 }
                        Rectangle { x: 121; y: 239; width: 67; height: 33; radius: 17; color: page.draftMotion ? Theme.cardAlt : page.paperAlt; border.color: page.draftMotion ? page.gold : Theme.borderStrong; Rectangle { x: page.draftMotion ? 37 : 3; y: 3; width: 27; height: 27; radius: 14; color: page.draftMotion ? page.gold : page.muted; Behavior on x { NumberAnimation { duration: 160 } } } MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: page.draftMotion = !page.draftMotion } }
                        Text { x: 30; y: 306; text: "主题色调"; color: page.ink; font.family: "SimSun"; font.pixelSize: 14 }
                        Row { x: 119; y: 294; spacing: 10
                            Repeater { model: ["月白", "烟青"]
                                delegate: Rectangle {
                                    required property string modelData
                                    width: 85; height: 39; radius: 6
                                    color: modelData === "月白" ? Theme.previewMoon : Theme.previewSmoke
                                    border.color: page.draftTheme === modelData ? page.gold : Theme.border
                                    border.width: page.draftTheme === modelData ? 2 : 1
                                    Text { anchors.centerIn: parent; text: modelData; color: modelData === "月白" ? Theme.paperInk : Theme.accentText; font.family: "SimSun"; font.pixelSize: 13 }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: page.draftTheme = modelData }
                                } }
                        }
                        Rectangle { x: 30; y: 367; width: Math.min(parent.width - 60, 420); height: 1; color: page.paperAlt }
                        Rectangle { x: 30; y: 390; width: 148; height: 43; radius: 7; color: saveSettingsMouse.containsMouse ? Theme.cardAlt : Theme.card
                            Text { anchors.centerIn: parent; text: "保存偏好设置"; color: Theme.text; font.family: "SimSun"; font.pixelSize: 15 }
                            MouseArea { id: saveSettingsMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: { if (personal.saveSettings(page.draftName, page.draftAvatar, page.draftFont, page.draftMotion, page.draftTheme)) page.notify("偏好设置已保存"); else page.notify(personal.errorMessage) } } }
                        Text { x: 193; y: 401; width: parent.width - 230; text: "偏好仅保存在本机。阅读字号同步至诗词典藏。"; color: page.muted; font.pixelSize: 11; wrapMode: Text.WordWrap }
                    }
                }
                Text { anchors.bottom: parent.bottom; anchors.bottomMargin: 14; anchors.horizontalCenter: parent.horizontalCenter; visible: personal.errorMessage !== ""; text: personal.errorMessage; color: Theme.danger; font.pixelSize: 11; elide: Text.ElideRight; width: parent.width - 70; horizontalAlignment: Text.AlignHCenter }
            }
            Rectangle {
                id: afterword
                x: 0; y: contentPanel.y + contentPanel.height + 12; width: parent.width; height: 96; radius: 9
                visible: page.section >= 0 && page.section <= 2 && page.listCount <= 2
                color: Theme.light ? "#E8DFD0" : "#1D4044"; border.color: Theme.border
                Text { x: 20; y: 15; text: "手札续页"; color: Theme.text; font.family: "SimSun"; font.pixelSize: 18 }
                Text {
                    x: 20; y: 50; width: parent.width - 300
                    text: "已读 " + (personal.stats.read || 0) + " 首  ·  珍藏 " + (personal.stats.favorites || 0) + " 首  ·  写下 " + (personal.stats.notes || 0) + " 则笔记"
                    color: Theme.secondary; font.pixelSize: 12; elide: Text.ElideRight
                }
                Text { anchors.right: parent.right; anchors.rightMargin: 149; y: 37; text: "回到旅程  ↗"; color: Theme.gold; font.family: "SimSun"; font.pixelSize: 13
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: page.section = -1 } }
                Text { anchors.right: parent.right; anchors.rightMargin: 22; y: 37; text: "继续读诗  ↗"; color: Theme.gold; font.family: "SimSun"; font.pixelSize: 13
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: page.openArchive() } }
            }
        }
    }

    Popup {
        id: confirmPopup; modal: true; focus: true
        x: (page.width - width) / 2; y: (page.height - height) / 2
        width: 415; height: 210; closePolicy: Popup.CloseOnEscape
        background: Rectangle { radius: 11; color: page.paper; border.color: Theme.borderStrong }
        contentItem: Item {
            Text { x: 23; y: 20; text: "请确认"; color: page.ink; font.family: "SimSun"; font.pixelSize: 24 }
            Text { x: 23; y: 65; width: parent.width - 46; text: page.pendingAction === "history" ? "清除全部阅读足迹？此操作无法撤销。" : page.pendingAction === "note" ? "删除这则笔记？此操作无法撤销。" : "取消收藏这首诗词？"; wrapMode: Text.WordWrap; color: page.ink; font.pixelSize: 14 }
            Rectangle { x: 22; y: 135; width: 114; height: 38; radius: 6; color: page.paperAlt; border.color: Theme.border; Text { anchors.centerIn: parent; text: "返回"; color: page.ink; font.pixelSize: 13 } MouseArea { anchors.fill: parent; onClicked: confirmPopup.close() } }
            Rectangle { anchors.right: parent.right; anchors.rightMargin: 22; y: 135; width: 114; height: 38; radius: 6; color: Theme.danger; Text { anchors.centerIn: parent; text: "确认"; color: Theme.text; font.pixelSize: 13 }
                MouseArea { anchors.fill: parent; onClicked: {
                    var ok = page.pendingAction === "history" ? personal.clearHistory() : page.pendingAction === "note" ? personal.deleteNote(page.pendingId) : personal.removeFavorite(page.pendingId)
                    if (ok) {
                        if (page.pendingAction === "note") { page.noteAuthorIndex = 0; personal.setNoteQuery("", ["latest", "oldest", "author"][page.noteSort]) }
                        confirmPopup.close(); page.notify("已更新个人空间")
                    } else page.notify(personal.errorMessage)
                } } }
        }
    }

    Popup {
        id: notePopup; modal: true; focus: true
        x: (page.width - width) / 2; y: (page.height - height) / 2
        width: Math.min(650, page.width - 70); height: Math.min(500, page.height - 55)
        closePolicy: Popup.CloseOnEscape
        background: Rectangle { radius: 11; color: page.paper; border.color: Theme.borderStrong }
        contentItem: Item {
            Text { id: noteTitle; x: 24; y: 18; width: parent.width - 48; color: page.ink; font.family: "SimSun"; font.pixelSize: 21; elide: Text.ElideRight }
            Text { x: 24; y: 55; text: "读诗手记"; color: page.gilt; font.pixelSize: 12 }
            Rectangle { x: 23; y: 82; width: parent.width - 46; height: parent.height - 150; radius: 6; color: page.paper; border.color: Theme.borderStrong
                ScrollView { anchors.fill: parent; anchors.margins: 8; clip: true
                    TextArea {
                        id: noteEditor; wrapMode: TextArea.Wrap; color: page.ink
                        font.family: "SimSun"; font.pixelSize: 16
                        background: Item {}
                        selectByMouse: true
                    }
                }
            }
            Rectangle { x: 23; y: parent.height - 53; width: 105; height: 35; radius: 6; color: page.paperAlt; border.color: Theme.borderStrong; Text { anchors.centerIn: parent; text: "取消"; color: page.ink; font.pixelSize: 13 } MouseArea { anchors.fill: parent; onClicked: notePopup.close() } }
            Rectangle { anchors.right: parent.right; anchors.rightMargin: 23; y: parent.height - 53; width: 125; height: 35; radius: 6; color: Theme.card; Text { anchors.centerIn: parent; text: "保存笔记"; color: Theme.text; font.pixelSize: 13 }
                MouseArea { anchors.fill: parent; onClicked: { if (personal.saveNote(page.editingPoemId, noteEditor.text)) { notePopup.close(); page.notify("笔记已保存") } else page.notify(personal.errorMessage) } } }
        }
    }
}
