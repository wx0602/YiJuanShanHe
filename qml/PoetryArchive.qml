import QtQuick
import QtQuick.Controls
import YiJuanShanHe

Item {
    id: archive
    property bool immersive: false
    property int detailTab: 0
    signal notify(string message)
    signal openAi(int poemId)

    readonly property color gold: Theme.gold
    readonly property color paper: Theme.paper
    readonly property color paperInk: Theme.paperInk
    readonly property real leftWidth: Math.min(386, Math.max(325, width * .34))

    onVisibleChanged: if (visible) catalog.activate()
    Component.onCompleted: if (visible) catalog.activate()

    function runSearch() {
        catalog.search(searchField.text, dynastyFilter.selected, authorFilter.selected,
                       "", "", sortFilter.selected)
        poemList.positionViewAtBeginning()
    }

    Rectangle { anchors.fill: parent; color: Theme.background }

    Rectangle {
        id: listPanel
        x: 24; y: 23
        width: archive.leftWidth; height: archive.height - 46
        radius: 15; color: Theme.surface
        border.color: Theme.border; border.width: 1
        opacity: archive.immersive ? 0 : 1
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 240 } }

        Text {
            x: 23; y: 19
            text: "典 藏  /  C O L L E C T I O N"
            color: gold
            font.family: "Microsoft YaHei UI"; font.pixelSize: 11; font.letterSpacing: 1.3
        }
        Text {
            x: 23; y: 42
            text: "诗海拾珍"
            color: Theme.text
            font.family: "SimSun"; font.pixelSize: 27
        }
        Text {
            anchors.right: parent.right; anchors.rightMargin: 23; y: 53
            text: catalog.resultCount + " 首"
            color: Theme.text
            font.family: "Microsoft YaHei UI"; font.pixelSize: 12
        }

        Rectangle {
            id: searchBox
            x: 21; y: 92; width: parent.width - 42; height: 44
            radius: 9; color: Theme.background
            border.color: searchField.activeFocus ? gold : Theme.border
            Behavior on border.color { ColorAnimation { duration: 150 } }
            Text {
                x: 14; anchors.verticalCenter: parent.verticalCenter
                text: "⌕"; color: gold
                font.pixelSize: 23
            }
            TextField {
                id: searchField
                x: 44; y: 1; width: parent.width - 59; height: parent.height - 2
                placeholderText: "搜索标题、诗人或诗句"
                placeholderTextColor: Theme.subtle
                color: Theme.text
                font.family: "Microsoft YaHei UI"; font.pixelSize: 13
                selectByMouse: true
                background: Item {}
                onTextChanged: searchTimer.restart()
                onAccepted: archive.runSearch()
            }
            Timer { id: searchTimer; interval: 260; onTriggered: archive.runSearch() }
        }

        Text {
            x: 22; y: 150
            text: "按 朝 代 与 作 者 查 阅"
            color: Theme.secondary
            font.family: "Microsoft YaHei UI"; font.pixelSize: 10; font.letterSpacing: 1.5
        }

        ArchiveFilter {
            id: dynastyFilter
            x: 21; y: 173; width: (listPanel.width - 50) / 2
            label: "朝代"; options: catalog.dynasties
            onPicked: archive.runSearch()
        }
        ArchiveFilter {
            id: authorFilter
            x: dynastyFilter.x + dynastyFilter.width + 8; y: 173
            width: dynastyFilter.width
            label: "作者"; options: catalog.authors
            onPicked: archive.runSearch()
        }
        Text {
            x: 22; y: 224
            text: "原文、注释、译文与赏析"
            color: Theme.secondary; font.family: "Microsoft YaHei UI"; font.pixelSize: 10
        }
        Rectangle { x: 21; y: 251; width: parent.width - 42; height: 1; color: Theme.cardAlt }
        Text {
            x: 22; y: 267
            text: catalog.errorMessage ? "查询遇到问题" : "共找到 " + catalog.resultCount + " 首诗词"
            color: catalog.errorMessage ? Theme.danger : Theme.text
            font.family: "Microsoft YaHei UI"; font.pixelSize: 12
        }
        ArchiveFilter {
            id: sortFilter
            anchors.right: parent.right; anchors.rightMargin: 21
            y: 260; width: 128
            label: "排序"; selected: "原序"
            options: ["原序", "标题", "作者", "朝代", "收藏优先"]
            onPicked: archive.runSearch()
        }

        ListView {
            id: poemList
            x: 12; y: 308
            width: parent.width - 24
            height: parent.height - y - 13
            model: catalog
            clip: true
            spacing: 5
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
                contentItem: Rectangle { implicitWidth: 3; radius: 2; color: Theme.selected }
            }
            delegate: Rectangle {
                id: rowCard
                required property int poemId
                required property string poemTitle
                required property string poemAuthor
                required property string poemDynasty
                required property string poemExcerpt
                required property string poemForm
                required property string poemTheme
                required property bool poemFavorite
                width: poemList.width - 9; height: 104; radius: 9
                color: catalog.selectedId === poemId ? Theme.card : (rowMouse.containsMouse ? Theme.card : "transparent")
                border.color: catalog.selectedId === poemId ? Theme.borderStrong : "transparent"
                Behavior on color { ColorAnimation { duration: 170 } }
                Rectangle {
                    x: 0; y: 21; width: 2; height: 62; radius: 1
                    color: gold; visible: catalog.selectedId === poemId
                }
                Text {
                    x: 17; y: 10; width: parent.width - 69
                    text: rowCard.poemTitle
                    color: Theme.text
                    font.family: "SimSun"; font.pixelSize: 19
                    elide: Text.ElideRight
                }
                Text {
                    anchors.right: parent.right; anchors.rightMargin: 18; y: 13
                    text: rowCard.poemFavorite ? "◆" : ""
                    color: gold; font.pixelSize: 12
                }
                Text {
                    x: 18; y: 41
                    text: rowCard.poemDynasty ? rowCard.poemDynasty + " · " + rowCard.poemAuthor : rowCard.poemAuthor
                    color: Theme.secondary
                    font.family: "Microsoft YaHei UI"; font.pixelSize: 11
                }
                Text {
                    x: 18; y: 67; width: parent.width - 35
                    text: rowCard.poemExcerpt.replace(/\n/g, "  ")
                    color: Theme.text
                    font.family: "SimSun"; font.pixelSize: 13
                    elide: Text.ElideRight
                }
                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: catalog.selectPoem(rowCard.poemId)
                }
            }
            footer: Item {
                width: poemList.width
                height: catalog.hasMore ? 57 : 14
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 8; width: 154; height: 36; radius: 8
                    visible: catalog.hasMore
                    color: moreArea.containsMouse ? Theme.card : Theme.card
                    border.color: Theme.border
                    Text {
                        anchors.centerIn: parent
                        text: "载入更多诗词  ↓"
                        color: Theme.text
                        font.family: "Microsoft YaHei UI"; font.pixelSize: 12
                    }
                    MouseArea {
                        id: moreArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: catalog.loadNextPage()
                    }
                }
            }
        }

        Item {
            anchors.fill: poemList
            visible: catalog.resultCount === 0
            Rectangle { anchors.centerIn: parent; width: 62; height: 1; color: gold; opacity: .7 }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: -40
                text: catalog.errorMessage ? "典藏暂不可读" : "未寻得相合的诗词"
                color: Theme.text
                font.family: "SimSun"; font.pixelSize: 19
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: 35
                width: parent.width - 30
                text: catalog.errorMessage || "试试更换关键词或放宽筛选条件"
                color: catalog.errorMessage ? Theme.danger : Theme.secondary
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                font.family: "Microsoft YaHei UI"; font.pixelSize: 12
            }
        }
    }

    Rectangle {
        id: readerPanel
        x: archive.immersive ? 0 : listPanel.x + listPanel.width + 18
        y: archive.immersive ? 0 : 23
        width: archive.immersive ? archive.width : archive.width - x - 24
        height: archive.immersive ? archive.height : archive.height - 46
        radius: archive.immersive ? 0 : 15
        color: Theme.paper
        border.color: archive.immersive ? "transparent" : Theme.borderStrong
        border.width: 1
        clip: true
        z: archive.immersive ? 10 : 1
        Behavior on x { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
        Behavior on y { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
        Behavior on width { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
        Behavior on height { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }

        ArtBackground {
            anchors.fill: parent
            lightSource: "qrc:/picture/b420b20827e9cefed34f0277a69dd4dd.jpg"
            lightClip: Qt.rect(0, 0, 1440, 1940)
            darkSource: "qrc:/picture/e59fefa5d8c32ddd6ff3072783a69b3c.jpg"
            darkClip: Qt.rect(0, 0, 1440, 2090)
            lightVeil: "#55FFFCF5"
            darkVeil: "#DBF1EDE3"
        }
        Rectangle { x: 0; y: 0; width: 4; height: parent.height; color: Theme.goldWash; opacity: .65 }
        Rectangle { x: 0; y: 72; width: parent.width; height: 1; color: Theme.paperAlt }
        Text {
            x: archive.immersive ? Math.max(65, (readerPanel.width - 760) / 2) : 31
            y: 23
            text: archive.immersive ? "卷 一  ·  诗 词 典 藏" : "诗 词 典 藏"
            color: Theme.paperMuted
            font.family: "SimSun"; font.pixelSize: 15; font.letterSpacing: 2
        }

        Row {
            anchors.right: parent.right; anchors.rightMargin: archive.immersive ? 52 : 24
            y: 16; spacing: 9
            Rectangle {
                width: 84; height: 38; radius: 8
                opacity: catalog.selectedId > 0 ? 1 : .45
                color: aiMouse.containsMouse ? Theme.goldWash : Theme.paper
                border.color: Theme.border
                Text { anchors.centerIn: parent; text: "AI 解读 ↗"; color: paperInk; font.family: "Microsoft YaHei UI"; font.pixelSize: 12 }
                MouseArea { id: aiMouse; anchors.fill: parent; enabled: catalog.selectedId > 0; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: archive.openAi(catalog.selectedId) }
            }
            Rectangle {
                width: 78; height: 38; radius: 8
                opacity: catalog.selectedId > 0 ? 1 : .45
                color: favoriteMouse.containsMouse ? Theme.goldWash : Theme.paper
                border.color: catalog.selectedFavorite ? Theme.borderStrong : Theme.border
                Text {
                    anchors.centerIn: parent
                    text: catalog.selectedFavorite ? "◆ 已收藏" : "◇ 收藏"
                    color: catalog.selectedFavorite ? Theme.goldDark : paperInk
                    font.family: "Microsoft YaHei UI"; font.pixelSize: 12
                }
                MouseArea {
                    id: favoriteMouse
                    anchors.fill: parent
                    enabled: catalog.selectedId > 0
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: catalog.toggleFavorite()
                }
            }
            Rectangle {
                width: 74; height: 38; radius: 8
                opacity: catalog.selectedId > 0 ? 1 : .45
                color: noteMouse.containsMouse ? Theme.goldWash : Theme.paper
                border.color: Theme.border
                Text {
                    anchors.centerIn: parent
                    text: "✎ 笔记"
                    color: paperInk
                    font.family: "Microsoft YaHei UI"; font.pixelSize: 12
                }
                MouseArea {
                    id: noteMouse
                    anchors.fill: parent
                    enabled: catalog.selectedId > 0
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: noteDialog.open()
                }
            }
            Rectangle {
                width: archive.immersive ? 104 : 94; height: 38; radius: 8
                color: immersiveMouse.containsMouse ? Theme.card : Theme.card
                Text {
                    anchors.centerIn: parent
                    text: archive.immersive ? "↙ 退出沉浸" : "▣ 沉浸阅读"
                    color: Theme.text
                    font.family: "Microsoft YaHei UI"; font.pixelSize: 12
                }
                MouseArea {
                    id: immersiveMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: archive.immersive = !archive.immersive
                }
            }
        }

        Flickable {
            id: readingScroll
            x: archive.immersive ? Math.max(64, (readerPanel.width - 760) / 2) : 54
            y: 84
            width: archive.immersive ? Math.min(760, readerPanel.width - 128) : readerPanel.width - 108
            height: readerPanel.height - 103
            contentWidth: width
            contentHeight: paperFlow.implicitHeight + 50
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
                contentItem: Rectangle { implicitWidth: 3; radius: 2; color: Theme.goldWash; opacity: .55 }
            }

            Column {
                id: paperFlow
                width: readingScroll.width
                spacing: 0
                opacity: 0
                Text {
                    width: parent.width; topPadding: 22
                    text: catalog.selectedId ? catalog.selectedTitle : "请从左侧选择诗词"
                    color: paperInk
                    font.family: "SimSun"
                    font.pixelSize: archive.immersive ? 38 : 34
                    wrapMode: Text.Wrap
                    horizontalAlignment: Text.AlignHCenter
                }
                Text {
                    width: parent.width; topPadding: 17
                    text: catalog.selectedId
                          ? (catalog.selectedDynasty ? catalog.selectedDynasty + "  ·  " : "") + catalog.selectedAuthor
                          : ""
                    color: Theme.paperMuted
                    font.family: "Microsoft YaHei UI"; font.pixelSize: 13
                    horizontalAlignment: Text.AlignHCenter
                }
                Text {
                    width: parent.width; topPadding: 12
                    text: catalog.selectedId ? "第 " + ("0" + catalog.selectedId).slice(-2) + " 首" : ""
                    color: Theme.paperGold
                    font.family: "Microsoft YaHei UI"; font.pixelSize: 11
                    horizontalAlignment: Text.AlignHCenter
                }
                Item {
                    width: parent.width; height: 52
                    Rectangle { anchors.centerIn: parent; width: 82; height: 1; color: Theme.goldWash }
                    Rectangle { anchors.centerIn: parent; width: 5; height: 5; rotation: 45; color: Theme.goldWash }
                }

                Column {
                    width: parent.width; spacing: archive.immersive ? 18 : 13
                    Repeater {
                        model: catalog.selectedContent ? catalog.selectedContent.split(/\r?\n/) : []
                        delegate: Text {
                            required property string modelData
                            required property int index
                            width: parent.width
                            text: modelData
                            color: paperInk
                            font.family: "SimSun"
                            font.pixelSize: personal.readingFontSize + (archive.immersive ? 4 : 0)
                            lineHeight: 1.5
                            lineHeightMode: Text.ProportionalHeight
                            wrapMode: Text.Wrap
                            horizontalAlignment: Text.AlignHCenter
                            opacity: personal.animationsEnabled ? 0 : 1
                            SequentialAnimation on opacity {
                                running: personal.animationsEnabled
                                PauseAnimation { duration: Math.min(index * 95, 1400) }
                                NumberAnimation { from: 0; to: 1; duration: 390; easing.type: Easing.OutCubic }
                            }
                        }
                    }
                }

                Item { width: parent.width; height: 49 }
                Rectangle { width: parent.width; height: 1; color: Theme.paperAlt }
                Item {
                    width: parent.width; height: 61
                    Row {
                        anchors.centerIn: parent; spacing: 10
                        Repeater {
                            model: ["注释", "译文", "赏析"]
                            delegate: Rectangle {
                                required property string modelData
                                required property int index
                                width: 70; height: 33; radius: 7
                                color: archive.detailTab === index ? Theme.goldWash : "transparent"
                                Text {
                                    anchors.centerIn: parent
                                    text: modelData
                                    color: archive.detailTab === index ? Theme.text : Theme.paperMuted
                                    font.family: "Microsoft YaHei UI"; font.pixelSize: 13
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: archive.detailTab = index
                                }
                            }
                        }
                    }
                }
                Text {
                    width: parent.width
                    text: archive.detailTab === 0
                          ? (catalog.selectedAnnotation || "暂无注释资料")
                          : archive.detailTab === 1
                            ? (catalog.selectedTranslation || "暂无译文资料")
                            : (catalog.selectedAppreciation || "暂无赏析资料")
                    color: (archive.detailTab === 0 && !catalog.selectedAnnotation)
                           || (archive.detailTab === 1 && !catalog.selectedTranslation)
                           || (archive.detailTab === 2 && !catalog.selectedAppreciation)
                           ? Theme.paperMuted : Theme.paperInk
                    font.family: "Microsoft YaHei UI"; font.pixelSize: 14
                    lineHeight: 1.65
                    lineHeightMode: Text.ProportionalHeight
                    wrapMode: Text.Wrap
                    horizontalAlignment: Text.AlignHCenter
                }
                Item { width: parent.width; height: 45 }
                Rectangle { width: parent.width; height: 1; color: Theme.paperAlt }
                Text {
                    width: parent.width; topPadding: 25
                    text: catalog.selectedNote ? "我的札记" : "留一页给自己的感想"
                    color: Theme.paperGold
                    font.family: "SimSun"; font.pixelSize: 18
                }
                Text {
                    width: parent.width; topPadding: 13
                    text: catalog.selectedNote || "点击右上角「笔记」，记录读诗时的所思所感。"
                    color: catalog.selectedNote ? Theme.paperInk : Theme.paperMuted
                    font.family: "Microsoft YaHei UI"; font.pixelSize: 13
                    lineHeight: 1.6
                    lineHeightMode: Text.ProportionalHeight
                    wrapMode: Text.Wrap
                }
            }
            NumberAnimation {
                id: readerFade
                target: paperFlow; property: "opacity"
                from: 0; to: 1; duration: 390; easing.type: Easing.OutCubic
            }
            Connections {
                target: catalog
                function onSelectedChanged() {
                    readingScroll.contentY = 0
                    archive.detailTab = 0
                    readerFade.restart()
                }
            }
            Component.onCompleted: readerFade.start()
        }

        Text {
            anchors.right: parent.right; anchors.rightMargin: 18
            anchors.bottom: parent.bottom; anchors.bottomMargin: 10
            text: "YI JUAN SHAN HE  ·  POETRY ARCHIVE"
            color: Theme.paperMuted
            font.family: "Georgia"; font.pixelSize: 9; font.letterSpacing: 1
        }
    }

    Popup {
        id: noteDialog
        parent: Overlay.overlay
        modal: true; dim: true
        width: Math.min(560, parent.width - 50)
        height: Math.min(450, parent.height - 55)
        x: (parent.width - width) / 2
        y: (parent.height - height) / 2
        padding: 0
        closePolicy: Popup.CloseOnEscape
        onOpened: noteArea.text = catalog.selectedNote
        background: Rectangle {
            radius: 15; color: Theme.paper
            border.color: Theme.borderStrong; border.width: 1
        }
        contentItem: Item {
            Text {
                x: 30; y: 24
                text: "诗笺札记"
                color: Theme.paperInk
                font.family: "SimSun"; font.pixelSize: 27
            }
            Text {
                x: 32; y: 64; width: parent.width - 64
                text: catalog.selectedTitle + "  ·  " + catalog.selectedAuthor
                color: Theme.paperMuted
                font.family: "Microsoft YaHei UI"; font.pixelSize: 12
                elide: Text.ElideRight
            }
            Rectangle { x: 30; y: 93; width: parent.width - 60; height: 1; color: Theme.paperAlt }
            Rectangle {
                x: 30; y: 112; width: parent.width - 60; height: parent.height - 195
                radius: 8; color: Theme.paper; border.color: Theme.border
                Flickable {
                    id: noteScroll
                    anchors.fill: parent
                    anchors.margins: 8
                    contentWidth: width
                    contentHeight: noteArea.implicitHeight
                    clip: true
                    TextArea.flickable: TextArea {
                        id: noteArea
                        width: noteScroll.width
                        placeholderText: "写下此刻的读诗心得……"
                        placeholderTextColor: Theme.paperMuted
                        color: Theme.paperInk
                        font.family: "Microsoft YaHei UI"; font.pixelSize: 14
                        wrapMode: TextEdit.Wrap
                        background: Item {}
                    }
                }
            }
            Row {
                anchors.right: parent.right; anchors.rightMargin: 30
                anchors.bottom: parent.bottom; anchors.bottomMargin: 25
                spacing: 12
                Rectangle {
                    width: 78; height: 37; radius: 7
                    visible: catalog.selectedNote.length > 0
                    color: deleteMouse.containsMouse ? Theme.paper : Theme.paper
                    border.color: Theme.border
                    Text { anchors.centerIn: parent; text: "删除"; color: Theme.danger; font.pixelSize: 13 }
                    MouseArea {
                        id: deleteMouse; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { catalog.deleteNote(); if (!catalog.errorMessage) noteDialog.close() }
                    }
                }
                Rectangle {
                    width: 78; height: 37; radius: 7
                    color: cancelMouse.containsMouse ? Theme.paper : "transparent"
                    border.color: Theme.border
                    Text { anchors.centerIn: parent; text: "取消"; color: Theme.paperInk; font.pixelSize: 13 }
                    MouseArea {
                        id: cancelMouse; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: noteDialog.close()
                    }
                }
                Rectangle {
                    width: 104; height: 37; radius: 7
                    color: saveMouse.containsMouse ? Theme.cardAlt : Theme.card
                    Text { anchors.centerIn: parent; text: "保存笔记"; color: Theme.text; font.pixelSize: 13 }
                    MouseArea {
                        id: saveMouse; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { catalog.saveNote(noteArea.text); if (!catalog.errorMessage) noteDialog.close() }
                    }
                }
            }
        }
    }

    Connections {
        target: catalog
        function onNotice(message) { archive.notify(message) }
    }
}
