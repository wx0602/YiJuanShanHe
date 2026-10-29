import QtQuick
import QtQuick.Controls
import YiJuanShanHe

ApplicationWindow {
    id: window
    width: 1440
    height: 900
    minimumWidth: 1180
    minimumHeight: 760
    visible: true
    title: "一卷山河 · 古典诗词探索"
    color: Theme.background
    palette.window: Theme.background
    palette.windowText: Theme.text
    palette.base: Theme.field
    palette.text: Theme.paperInk
    palette.button: Theme.card
    palette.buttonText: Theme.text
    palette.highlight: Theme.goldLight
    palette.highlightedText: Theme.paperInk

    readonly property color ink: Theme.background
    readonly property color moonWhite: Theme.text
    readonly property color muted: Theme.secondary
    readonly property color paleGold: Theme.gold
    property string toastText: ""
    property string currentPage: startPage
    readonly property int activeIndex: currentPage === "ai" ? 7 : currentPage === "personal" ? 6 : currentPage === "interaction" ? 5 : currentPage === "imagery" ? 4 : currentPage === "journey" ? 3 : currentPage === "lives" ? 2 : currentPage === "poetry" ? 1 : 0
    readonly property color shellColor: Theme.topbar
    readonly property color railColor: Theme.sidebar

    Binding { target: Theme; property: "name"; value: personal.theme }
    Binding { target: Theme; property: "motion"; value: personal.animationsEnabled }

    function showToast(message) {
        toastText = message
        toast.opacity = 1
        toastTimer.restart()
    }

    function showPending(name) {
        showToast(name + "将在后续阶段逐页开放")
    }

    Rectangle {
        id: sidebar
        width: archive.immersive ? 0 : 220
        visible: width > 0
        Behavior on width { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        color: window.railColor
        border.color: Theme.border
        border.width: 1

        Item {
            id: brand
            x: 28; y: 29; width: 170; height: 77
            Rectangle {
                x: 0; y: 7; width: 37; height: 37
                color: "transparent"; border.color: paleGold; border.width: 1
                radius: 3
                Text {
                    anchors.centerIn: parent
                    text: "山"
                    color: paleGold
                    font.family: "SimSun"; font.pixelSize: 23
                }
            }
            Text {
                x: 47; y: 2
                text: "一卷山河"
                color: moonWhite
                font.family: "SimSun"; font.pixelSize: 22
                font.letterSpacing: 1
            }
            Text {
                x: 48; y: 35
                text: "YI JUAN SHAN HE"
                color: Theme.secondary
                font.family: "Georgia"; font.pixelSize: 9; font.letterSpacing: 1.4
            }
            Rectangle {
                y: 73; width: 164; height: 1
                color: Theme.card
            }
        }

        Text {
            x: 31; y: 134
            text: "探  索"
            color: Theme.secondary
            font.family: "Microsoft YaHei UI"; font.pixelSize: 10
            font.letterSpacing: 2
        }

        Column {
            x: 16; y: 169; width: 188; spacing: 7
            Repeater {
                model: [
                    { name: "山河首页", mark: "⌂" },
                    { name: "诗词典藏", mark: "诗" },
                    { name: "诗人生平", mark: "人" },
                    { name: "诗人行旅", mark: "行" },
                    { name: "意象探索", mark: "象" },
                    { name: "诗词互动", mark: "学" },
                    { name: "个人空间", mark: "我" },
                    { name: "诗心问墨", mark: "墨" }
                ]
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    width: 188; height: 48; radius: 8
                    color: index === window.activeIndex ? Theme.selected : (navMouse.containsMouse ? Theme.hover : "transparent")
                    border.color: index === window.activeIndex ? Theme.borderStrong : "transparent"
                    Behavior on color { ColorAnimation { duration: 160 } }
                    Rectangle {
                        width: 2; height: 24; x: 0
                        anchors.verticalCenter: parent.verticalCenter
                        radius: 1
                        color: paleGold
                        visible: index === window.activeIndex
                    }
                    Text {
                        x: 18; anchors.verticalCenter: parent.verticalCenter
                        width: 24
                        text: modelData.mark
                        color: index === window.activeIndex ? paleGold : Theme.secondary
                        font.family: "SimSun"; font.pixelSize: 19
                    }
                    Text {
                        x: 54; anchors.verticalCenter: parent.verticalCenter
                        text: modelData.name
                        color: index === window.activeIndex ? (Theme.light ? Theme.paperInk : Theme.text) : Theme.secondary
                        font.family: "Microsoft YaHei UI"; font.pixelSize: 14
                    }
                    MouseArea {
                        id: navMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: index === window.activeIndex ? Qt.ArrowCursor : Qt.PointingHandCursor
                        onClicked: {
                            if (index === 0) window.currentPage = "home"
                            else if (index === 1) window.currentPage = "poetry"
                            else if (index === 2) window.currentPage = "lives"
                            else if (index === 3) window.currentPage = "journey"
                            else if (index === 4) window.currentPage = "imagery"
                            else if (index === 5) window.currentPage = "interaction"
                            else if (index === 6) window.currentPage = "personal"
                            else if (index === 7) window.currentPage = "ai"
                            else window.showPending(modelData.name)
                        }
                    }
                }
            }
        }

        Item {
            anchors.left: parent.left; anchors.right: parent.right
            anchors.bottom: parent.bottom; height: 118
            Rectangle {
                x: 28; width: 164; height: 1; color: Theme.card
            }
            Text {
                x: 29; y: 24
                text: "诗以载道，山河为卷。"
                color: Theme.secondary
                font.family: "SimSun"; font.pixelSize: 14
            }
        }
    }

    Item {
        anchors.left: sidebar.right
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom

        Rectangle {
            id: topbar
            anchors.left: parent.left; anchors.right: parent.right
            height: archive.immersive ? 0 : 76
            visible: height > 0
            Behavior on height { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
            color: window.shellColor
            Behavior on color { ColorAnimation { duration: personal.animationsEnabled ? 320 : 0 } }
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.card }
            Text {
                x: 32; anchors.verticalCenter: parent.verticalCenter
                text: window.currentPage === "home" ? "山河首页" : window.currentPage === "poetry" ? "诗词典藏" : window.currentPage === "lives" ? "诗人生平" : window.currentPage === "imagery" ? "意象探索" : window.currentPage === "interaction" ? "诗词雅集" : window.currentPage === "personal" ? "山河手记" : window.currentPage === "ai" ? "诗心问墨" : "诗人行旅"
                color: moonWhite
                font.family: "SimSun"; font.pixelSize: 25
            }
            Text {
                x: 161; anchors.verticalCenter: parent.verticalCenter
                text: window.currentPage === "home" ? "HOME  /  001" : window.currentPage === "poetry" ? "ARCHIVE  /  002" : window.currentPage === "lives" ? "LIVES  /  003" : window.currentPage === "imagery" ? "IMAGERY  /  005" : window.currentPage === "interaction" ? "INTERACT  /  006" : window.currentPage === "personal" ? "PERSONAL  /  007" : window.currentPage === "ai" ? "AI ASSISTANT  /  008" : "JOURNEY  /  004"
                color: Theme.secondary
                font.family: "Georgia"; font.pixelSize: 10; font.letterSpacing: 1.4
            }
            Row {
                anchors.right: parent.right; anchors.rightMargin: 36
                anchors.verticalCenter: parent.verticalCenter
                spacing: 13
                Rectangle {
                    width: 107; height: 34; radius: 17
                    color: themeMouse.containsMouse ? Theme.hover : Theme.card
                    border.color: Theme.borderStrong
                    Behavior on color { ColorAnimation { duration: 200 } }
                    Text {
                        anchors.centerIn: parent
                        text: Theme.light ? "☾  烟青" : "☀  月白"
                        color: Theme.goldDark
                        font.family: "Microsoft YaHei UI"; font.pixelSize: 12
                    }
                    MouseArea {
                        id: themeMouse; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (!personal.setTheme(Theme.light ? "烟青" : "月白"))
                                window.showToast(personal.errorMessage)
                        }
                    }
                }
                Text {
                    text: Qt.formatDate(new Date(), "yyyy.MM.dd")
                    color: paleGold
                    font.family: "Georgia"; font.pixelSize: 12; font.letterSpacing: 1
                }
            }
        }

        Flickable {
            id: scroller
            objectName: "homeScroller"
            anchors.left: parent.left; anchors.right: parent.right
            anchors.top: topbar.bottom; anchors.bottom: parent.bottom
            contentWidth: width
            contentHeight: contentColumn.height + 52
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            opacity: window.currentPage === "home" ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: personal.animationsEnabled ? 260 : 0 } }

            NumberAnimation {
                id: calendarJump
                target: scroller; property: "contentY"
                duration: 520; easing.type: Easing.InOutCubic
            }

            Column {
                id: contentColumn
                x: 32; y: 28
                width: scroller.width - 64
                spacing: 23

                Rectangle {
                    id: hero
                    width: parent.width; height: 390; radius: 19
                    color: Theme.card
                    clip: true
                    border.color: Theme.border; border.width: 1

                    MountainScene { anchors.fill: parent; motionEnabled: window.visible && window.currentPage === "home" && personal.animationsEnabled }

                    Item {
                        id: heroWords
                        x: 49; y: 42; width: 490; height: 245
                        opacity: 0
                        NumberAnimation on opacity {
                            from: 0; to: 1; duration: 1000
                            easing.type: Easing.OutCubic
                        }
                        Row {
                            y: 0; spacing: 12
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 24; height: 1; color: paleGold
                            }
                            Text {
                                text: "山河作序  ·  诗意入卷"
                                color: Theme.goldDark
                                font.family: "Microsoft YaHei UI"; font.pixelSize: 12; font.letterSpacing: 2
                            }
                        }
                        Text {
                            y: 47
                            text: "一卷山河"
                            color: moonWhite
                            font.family: "SimSun"; font.pixelSize: 59; font.letterSpacing: 5
                            style: Text.Raised; styleColor: Theme.border
                        }
                        Rectangle { x: 2; y: 132; width: 95; height: 2; color: paleGold }
                        Text {
                            y: 160
                            text: "循诗入境，阅尽山河"
                            color: Theme.text
                            font.family: "SimSun"; font.pixelSize: 24; font.letterSpacing: 3
                        }
                        Text {
                            y: 207
                            text: "以诗词为舟，溯千年文脉；以山河为卷，见天地襟怀。"
                            color: Theme.text
                            font.family: "Microsoft YaHei UI"; font.pixelSize: 12
                        }
                    }

                    Rectangle {
                        x: 49; y: 323; width: 132; height: 1
                        color: Theme.paperAlt; opacity: .55
                    }
                    Text {
                        x: 49; y: 337
                        text: "READ  ·  DISCOVER  ·  WANDER"
                        color: Theme.text
                        font.family: "Georgia"; font.pixelSize: 10; font.letterSpacing: 1.6
                    }

                    Rectangle {
                        id: dailyCard
                        width: 348; height: 302
                        anchors.right: parent.right; anchors.rightMargin: 35
                        anchors.verticalCenter: parent.verticalCenter
                        radius: 13
                        color: Theme.light ? Theme.paper : Theme.cardAlt
                        border.color: previewMouse.containsMouse ? Theme.borderStrong : Theme.border
                        border.width: 1
                        Behavior on border.color { ColorAnimation { duration: 220 } }
                        Rectangle { x: 26; y: 27; width: 4; height: 17; radius: 2; color: paleGold }
                        Text {
                            x: 40; y: 22; text: "诗词日历"
                            color: Theme.goldDark; font.family: "SimSun"; font.pixelSize: 18
                        }
                        Text {
                            anchors.right: parent.right; anchors.rightMargin: 26; y: 29
                            text: "POETRY CALENDAR"
                            color: Theme.secondary; font.family: "Georgia"; font.pixelSize: 9
                            font.letterSpacing: 1
                        }
                        Rectangle { x: 26; y: 61; width: parent.width - 52; height: 1; color: Theme.cardAlt }
                        Text {
                            x: 26; y: 73
                            text: ("0" + shiciCalendar.selectedDay).slice(-2)
                            color: Theme.goldDark; font.family: "Georgia"; font.pixelSize: 55
                        }
                        Text {
                            x: 111; y: 88
                            text: shiciCalendar.selectedDateLabel
                            color: Theme.text; font.family: "Microsoft YaHei UI"; font.pixelSize: 12
                        }
                        Text {
                            x: 111; y: 112
                            text: shiciCalendar.showingToday && shiciCalendar.selectedDay === shiciCalendar.todayDay
                                  ? "今  日  诗  笺" : "循  日  阅  诗"
                            color: paleGold; font.family: "SimSun"; font.pixelSize: 13
                        }
                        Rectangle { x: 26; y: 153; width: parent.width - 52; height: 1; color: Theme.cardAlt }
                        Text {
                            x: 26; y: 168; width: parent.width - 52
                            text: shiciCalendar.title || "诗词暂不可用"
                            color: moonWhite; font.family: "SimSun"; font.pixelSize: 24
                            elide: Text.ElideRight
                        }
                        Text {
                            x: 27; y: 204; width: parent.width - 54
                            text: shiciCalendar.errorMessage || shiciCalendar.preview
                            color: shiciCalendar.errorMessage ? Theme.danger : Theme.text
                            font.family: "SimSun"; font.pixelSize: 14
                            elide: Text.ElideRight
                        }
                        Rectangle { x: 26; y: 247; width: parent.width - 52; height: 1; color: Theme.cardAlt }
                        Text {
                            x: 27; y: 265
                            text: "翻阅日历  ·  查看全文"
                            color: Theme.goldDark; font.family: "Microsoft YaHei UI"; font.pixelSize: 12
                        }
                        Text {
                            anchors.right: parent.right; anchors.rightMargin: 27; y: 260
                            text: "↘"; color: paleGold; font.pixelSize: 20
                        }
                        MouseArea {
                            id: previewMouse; anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                calendarJump.from = scroller.contentY
                                calendarJump.to = calendarSection.y - 18
                                calendarJump.restart()
                            }
                        }
                    }
                }

                PoetryCalendarView {
                    id: calendarSection
                    width: parent.width
                }

                Item {
                    width: parent.width; height: 47
                    Text {
                        x: 0; y: 0
                        text: "循迹 · 探索山河"
                        color: moonWhite
                        font.family: "SimSun"; font.pixelSize: 26
                    }
                    Text {
                        x: 226; y: 9
                        text: "从文字出发，走进诗人与天地之间。"
                        color: muted
                        font.family: "Microsoft YaHei UI"; font.pixelSize: 12
                    }
                    Rectangle {
                        anchors.right: parent.right; y: 23
                        width: 100; height: 1; color: Theme.selected
                    }
                }

                Row {
                    id: cards
                    width: parent.width; spacing: 17
                    FeatureCard {
                        width: (cards.width - 34) / 3
                        index: "01"; title: "诗词典藏"; subtitle: "于一字一句间，见千年风雅"
                        glyph: "诗"; tint: Theme.gold
                        footerText: "进入典藏  ·  即刻阅诗"
                        onActivated: window.currentPage = "poetry"
                    }
                    FeatureCard {
                        width: (cards.width - 34) / 3
                        index: "02"; title: "诗人行旅"; subtitle: "循诗人足迹，览万里山河"
                        glyph: "山"; tint: Theme.secondary
                        footerText: "展开地图  ·  循迹山河"
                        onActivated: window.currentPage = "journey"
                    }
                    FeatureCard {
                        width: (cards.width - 34) / 3
                        index: "03"; title: "意象探索"; subtitle: "让月与山水，织成诗意星图"
                        glyph: "月"; tint: Theme.secondary
                        onActivated: window.currentPage = "imagery"
                    }
                }

                Item {
                    width: parent.width; height: 56
                    Rectangle { y: 0; width: parent.width; height: 1; color: Theme.card }
                    Text {
                        y: 21
                        text: "一卷山河  ·  中国古典诗词探索"
                        color: Theme.secondary
                        font.family: "Microsoft YaHei UI"; font.pixelSize: 11
                    }
                    Text {
                        anchors.right: parent.right; y: 21
                        text: "以诗为入口  /  以人为线索  /  以山河为坐标"
                        color: Theme.secondary
                        font.family: "Microsoft YaHei UI"; font.pixelSize: 11
                    }
                }
            }
        }

        ImageryExplore {
            id: imageryPage
            anchors.left: parent.left; anchors.right: parent.right
            anchors.top: topbar.bottom; anchors.bottom: parent.bottom
            opacity: window.currentPage === "imagery" ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: personal.animationsEnabled ? 270 : 0 } }
            onOpenPoem: function(poemId) {
                catalog.selectPoem(poemId)
                window.currentPage = "poetry"
            }
            onOpenAi: function(name, description) {
                ai.openWithImagery(name, description)
                window.currentPage = "ai"
            }
        }

        PoetryArchive {
            id: archive
            objectName: "poetryArchive"
            anchors.left: parent.left; anchors.right: parent.right
            anchors.top: topbar.bottom; anchors.bottom: parent.bottom
            opacity: window.currentPage === "poetry" ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: personal.animationsEnabled ? 270 : 0 } }
            onNotify: function(message) { window.showToast(message) }
            onOpenAi: function(poemId) {
                if (ai.openWithPoem(poemId)) window.currentPage = "ai"
                else window.showToast(ai.errorMessage)
            }
        }

        PoetBiography {
            id: livesPage
            objectName: "poetBiography"
            anchors.left: parent.left; anchors.right: parent.right
            anchors.top: topbar.bottom; anchors.bottom: parent.bottom
            opacity: window.currentPage === "lives" ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: personal.animationsEnabled ? 270 : 0 } }
            onNotify: function(message) { window.showToast(message) }
            onOpenJourney: function(poetId) {
                journey.selectPoet(poetId)
                window.currentPage = "journey"
            }
            onOpenAi: function(name, description) {
                ai.openWithPoet(name, description)
                window.currentPage = "ai"
            }
        }

        PoetJourney {
            id: journeyPage
            objectName: "poetJourney"
            anchors.left: parent.left; anchors.right: parent.right
            anchors.top: topbar.bottom; anchors.bottom: parent.bottom
            opacity: window.currentPage === "journey" ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: personal.animationsEnabled ? 270 : 0 } }
            onOpenAi: function(name, description) {
                ai.openWithPoet(name, description)
                window.currentPage = "ai"
            }
            onOpenPoem: function(poemId) {
                catalog.selectPoem(poemId)
                window.currentPage = "poetry"
            }
            onOpenArchive: window.currentPage = "poetry"
        }

        PoetryInteraction {
            id: interactionPage
            objectName: "poetryInteraction"
            anchors.left: parent.left; anchors.right: parent.right
            anchors.top: topbar.bottom; anchors.bottom: parent.bottom
            opacity: window.currentPage === "interaction" ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: personal.animationsEnabled ? 270 : 0 } }
        }

        PersonalSpace {
            id: personalPage
            objectName: "personalSpace"
            anchors.left: parent.left; anchors.right: parent.right
            anchors.top: topbar.bottom; anchors.bottom: parent.bottom
            opacity: window.currentPage === "personal" ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: personal.animationsEnabled ? 270 : 0 } }
            onOpenPoem: function(poemId) {
                catalog.selectPoem(poemId)
                window.currentPage = "poetry"
            }
            onOpenArchive: window.currentPage = "poetry"
            onOpenMistakes: {
                window.currentPage = "interaction"
                interactionPage.showMistakes = true
            }
            onNotify: function(message) { window.showToast(message) }
        }

        AiAssistantPage {
            id: aiPage
            anchors.left: parent.left; anchors.right: parent.right
            anchors.top: topbar.bottom; anchors.bottom: parent.bottom
            opacity: window.currentPage === "ai" ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: personal.animationsEnabled ? 270 : 0 } }
        }
    }

    Rectangle {
        id: toast
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom; anchors.bottomMargin: 29
        width: toastLabel.implicitWidth + 42
        height: 43; radius: 21
        color: Theme.paper
        border.color: paleGold
        opacity: 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 240 } }
        Text {
            id: toastLabel
            anchors.centerIn: parent
            text: window.toastText
            color: Theme.paperInk
            font.family: "Microsoft YaHei UI"; font.pixelSize: 13
        }
        Timer {
            id: toastTimer
            interval: 2700
            onTriggered: toast.opacity = 0
        }
    }
}
