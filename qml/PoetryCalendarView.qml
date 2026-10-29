import QtQuick
import YiJuanShanHe
import QtQuick.Controls

Rectangle {
    id: calendarPage
    width: parent ? parent.width : 1000
    height: 456
    radius: 17
    color: Theme.surface
    border.color: Theme.border
    clip: true

    readonly property color gold: Theme.gold
    readonly property color moon: Theme.text
    readonly property color ink: Theme.paperInk

    Rectangle {
        id: calendarSide
        x: 1; y: 1
        width: Math.min(414, Math.max(358, parent.width * .405))
        height: parent.height - 2
        color: Theme.card

        Text {
            x: 26; y: 21
            text: "诗  词  日  历"
            color: moon; font.family: "SimSun"; font.pixelSize: 24
        }
        Text {
            anchors.right: parent.right; anchors.rightMargin: 25; y: 29
            text: "POETRY  /  CALENDAR"
            color: Theme.secondary; font.family: "Georgia"; font.pixelSize: 10
            font.letterSpacing: 1
        }
        Rectangle { x: 26; y: 65; width: parent.width - 52; height: 1; color: Theme.cardAlt }

        Text {
            x: 27; y: 84
            text: shiciCalendar.monthLabel
            color: moon; font.family: "SimSun"; font.pixelSize: 22
        }
        Row {
            anchors.right: parent.right; anchors.rightMargin: 25
            y: 79; spacing: 7
            Repeater {
                model: [{label:"‹", delta:-1}, {label:"今", delta:0}, {label:"›", delta:1}]
                delegate: Rectangle {
                    id: monthButton
                    required property var modelData
                    width: 32; height: 32; radius: 7
                    color: monthMouse.containsMouse ? Theme.cardAlt : Theme.card
                    border.color: Theme.border
                    Text {
                        anchors.centerIn: parent
                        text: monthButton.modelData.label
                        color: gold; font.family: "SimSun"; font.pixelSize: 19
                    }
                    MouseArea {
                        id: monthMouse; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: monthButton.modelData.delta === 0
                                   ? shiciCalendar.goToday()
                                   : shiciCalendar.shiftMonth(monthButton.modelData.delta)
                    }
                }
            }
        }

        Row {
            x: 26; y: 130; width: parent.width - 52
            Repeater {
                model: ["一", "二", "三", "四", "五", "六", "日"]
                delegate: Text {
                    required property string modelData
                    width: (calendarSide.width - 52) / 7
                    text: modelData
                    horizontalAlignment: Text.AlignHCenter
                    color: Theme.secondary; font.family: "SimSun"; font.pixelSize: 14
                }
            }
        }

        Grid {
            id: dayGrid
            x: 26; y: 162
            width: parent.width - 52
            columns: 7; rowSpacing: 4; columnSpacing: 0
            Repeater {
                model: shiciCalendar.days
                delegate: Item {
                    id: dayCell
                    required property var modelData
                    readonly property int day: Number(modelData)
                    readonly property bool chosen: day > 0 && day === shiciCalendar.selectedDay
                    readonly property bool today: day > 0 && shiciCalendar.showingToday
                                                  && day === shiciCalendar.todayDay
                    width: dayGrid.width / 7; height: 34
                    Rectangle {
                        anchors.centerIn: parent
                        width: 36; height: 31; radius: 8
                        visible: dayCell.day > 0
                        color: dayCell.chosen ? Theme.goldWash : (dayMouse.containsMouse ? Theme.card : "transparent")
                        border.color: dayCell.today ? gold : "transparent"
                        border.width: dayCell.today ? 1.5 : 0
                        Behavior on color { ColorAnimation { duration: 190 } }
                    }
                    Text {
                        anchors.centerIn: parent
                        text: dayCell.day > 0 ? dayCell.day : ""
                        color: dayCell.chosen ? Theme.text : (dayCell.today ? Theme.goldDark : Theme.text)
                        font.family: "Georgia"; font.pixelSize: 16
                    }
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom; anchors.bottomMargin: 3
                        width: 3; height: 3; radius: 2
                        visible: dayCell.today && !dayCell.chosen
                        color: gold
                    }
                    MouseArea {
                        id: dayMouse; anchors.fill: parent
                        enabled: dayCell.day > 0 && shiciCalendar.poemCount >= 31
                        hoverEnabled: true
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: shiciCalendar.selectDay(dayCell.day)
                    }
                }
            }
        }
        NumberAnimation {
            id: gridFade
            target: dayGrid; property: "opacity"
            from: .25; to: 1; duration: 350; easing.type: Easing.OutCubic
        }
        Connections {
            target: shiciCalendar
            function onMonthChanged() { gridFade.restart() }
        }

        Rectangle {
            x: 26; anchors.bottom: parent.bottom; anchors.bottomMargin: 63
            width: parent.width - 52; height: 1; color: Theme.cardAlt
        }
        Text {
            x: 27; anchors.bottom: parent.bottom; anchors.bottomMargin: 32
            text: "每日一诗"
            color: Theme.goldDark; font.family: "SimSun"; font.pixelSize: 15
        }
    }

    Rectangle {
        id: reader
        x: calendarSide.width; y: 1
        width: parent.width - x - 1; height: parent.height - 2
        color: Theme.paper
        Rectangle { width: 1; height: parent.height; color: Theme.goldWash }

        Text {
            x: 34; y: 21
            text: "卷  ·  " + shiciCalendar.selectedDateLabel
            color: Theme.paperGold; font.family: "SimSun"; font.pixelSize: 13
            font.letterSpacing: 2
        }
        Text {
            anchors.right: parent.right; anchors.rightMargin: 34; y: 22
            text: "DAY  " + ("0" + shiciCalendar.selectedDay).slice(-2) + "  /  31"
            color: Theme.paperGold; font.family: "Georgia"; font.pixelSize: 11
        }
        Rectangle { x: 34; y: 52; width: parent.width - 68; height: 1; color: Theme.goldWash }

        Flickable {
            id: poemScroll
            objectName: "calendarPoemScroll"
            x: 34; y: 72
            width: parent.width - 68; height: parent.height - 95
            contentWidth: width
            contentHeight: Math.max(height, poemColumn.implicitHeight + 20)
            clip: true; boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
                contentItem: Rectangle { implicitWidth: 3; radius: 2; color: Theme.goldWash }
            }
            Column {
                id: poemColumn
                width: poemScroll.width; spacing: 0
                Text {
                    width: parent.width
                    text: shiciCalendar.title || "诗词暂不可用"
                    color: ink; font.family: "SimSun"; font.pixelSize: 31
                    wrapMode: Text.Wrap
                }
                Item { width: 1; height: 11 }
                Text {
                    text: shiciCalendar.attribution
                    color: Theme.paperGold; font.family: "Microsoft YaHei UI"; font.pixelSize: 13
                }
                Item { width: 1; height: 19 }
                Rectangle { width: 95; height: 1; color: Theme.goldWash }
                Item { width: 1; height: 22 }
                Text {
                    width: parent.width
                    text: shiciCalendar.errorMessage || shiciCalendar.content
                    color: shiciCalendar.errorMessage ? Theme.danger : ink
                    font.family: "SimSun"; font.pixelSize: Math.max(18, personal.readingFontSize - 4)
                    lineHeight: 1.6; lineHeightMode: Text.ProportionalHeight
                    wrapMode: Text.Wrap
                }
                Item { width: 1; height: 19 }
                Text {
                    text: shiciCalendar.errorMessage ? "数据读取失败，请检查数据路径。" : "——  原文全文"
                    color: Theme.paperGold; font.family: "Microsoft YaHei UI"; font.pixelSize: 10
                }
            }
            NumberAnimation {
                id: readerFade
                target: poemColumn; property: "opacity"
                from: .08; to: 1; duration: 430; easing.type: Easing.OutCubic
            }
            Connections {
                target: shiciCalendar
                function onSelectionChanged() {
                    poemScroll.contentY = 0
                    readerFade.restart()
                }
            }
        }
        Text {
            anchors.right: parent.right; anchors.rightMargin: 34
            anchors.bottom: parent.bottom; anchors.bottomMargin: 8
            text: "SCROLL TO READ  ↓"
            visible: poemScroll.contentHeight > poemScroll.height + 8
                     && poemScroll.contentY < poemScroll.contentHeight - poemScroll.height - 8
            color: Theme.paperGold; font.family: "Georgia"; font.pixelSize: 9
            font.letterSpacing: 1
        }
    }
}
