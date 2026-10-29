import QtQuick
import QtQuick.Controls
import YiJuanShanHe

Item {
    id: page
    objectName: "poetJourney"
    signal openAi(string name, string description)
    signal openPoem(int poemId)
    signal openArchive()
    property bool noteOpen: false
    property bool overview: false
    property bool ready: false
    property string arrival: ""
    property bool poemExpanded: false
    readonly property var reading: journey.stagePoem
    readonly property real noteWidth: atlas.width * .38
    readonly property color noteSurface: Theme.light ? Theme.paper : "#173A3D"
    readonly property color noteCard: Theme.light ? Theme.paperAlt : "#244A4C"
    readonly property color noteInk: Theme.light ? Theme.paperInk : Theme.text
    readonly property color noteMuted: Theme.light ? Theme.paperMuted : Theme.secondary
    readonly property color noteGold: Theme.light ? Theme.paperGold : Theme.goldLight
    readonly property color noteHighlight: Theme.light ? Theme.goldLight : Theme.selected

    function selectPoet(id) {
        if (journey.selectPoet(id)) {
            noteOpen = false
            overview = false
            arrival = ""
            Qt.callLater(function() { mapStage.applyCamera(-1) })
        }
    }
    function selectStop(index, showNote) {
        journey.pause()
        journey.seek(index)
        if (showNote) {
            noteOpen = true
            noteScroll.contentY = 0
        }
        poemExpanded = false
        mapStage.applyCamera(index)
    }
    function togglePlayback() {
        if (journey.playing) { journey.pause(); return }
        if (journey.currentIndex >= journey.stopCount - 1) journey.seek(0)
        mapStage.applyCamera(journey.currentIndex)
        journey.play()
    }
    function closeNote() {
        noteOpen = false
        mapStage.applyCamera(-1)
    }
    function revealSelectedPoet() {
        const options = journey.poetOptions || []
        for (let i = 0; i < options.length; ++i) {
            if (options[i].id === journey.selectedPoetId) {
                journeyPoetStrip.positionViewAtIndex(i, ListView.Contain)
                break
            }
        }
    }
    focus: true
    Shortcut { sequence: "Escape"; enabled: page.noteOpen; onActivated: page.closeNote() }
    onNoteOpenChanged: Qt.callLater(function() { mapStage.applyCamera(noteOpen ? journey.currentIndex : -1) })
    onOverviewChanged: Qt.callLater(function() { mapStage.applyCamera(noteOpen ? journey.currentIndex : -1) })
    onVisibleChanged: {
        if (visible) {
            journey.pause()
            Qt.callLater(function() { page.ready = true; mapStage.applyCamera(-1) })
        } else journey.pause()
    }
    Component.onCompleted: Qt.callLater(function() {
        page.revealSelectedPoet()
        if (page.visible) { journey.pause(); page.ready = true; mapStage.applyCamera(-1) }
    })
    Connections {
        target: journey
        function onPoetChanged() {
            page.noteOpen = false
            page.arrival = ""
            Qt.callLater(function() { page.revealSelectedPoet(); mapStage.applyCamera(-1) })
        }
        function onPositionChanged() {
            timeSlider.value = journey.currentIndex
            page.poemExpanded = false
            if (!page.ready || !page.visible) return
            mapStage.applyCamera(journey.currentIndex)
            var stop = journey.currentStop
            page.arrival = stop.place ? (stop.date + "  ·  " + stop.event) : ""
            arrivalTimer.restart()
        }
    }
    Timer { id: arrivalTimer; interval: 2450; onTriggered: page.arrival = "" }

    Rectangle { anchors.fill: parent; color: Theme.background }
    Text {
        x: 27; y: 10; text: "循迹山河"
        color: Theme.text; font.family: "SimSun"; font.pixelSize: 29
    }
    Text {
        x: 29; y: 51; text: "以诗人的人生次序，读山川万里   /   JOURNEY NOTES"
        color: Theme.secondary; font.family: "Microsoft YaHei UI"; font.pixelSize: 11
    }
    Row {
        anchors.right: parent.right; anchors.rightMargin: 24
        y: 20; spacing: 7
        Rectangle {
            width: 83; height: 38; radius: 7
            color: aiHover.containsMouse ? Theme.hover : Theme.surface
            border.color: Theme.border
            Text { anchors.centerIn: parent; text: "AI 解读 ↗"; color: Theme.text; font.family: "SimSun"; font.pixelSize: 12 }
            MouseArea {
                id: aiHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: page.openAi(journey.selectedPoet.name,
                                       journey.selectedPoet.intro + "\n当前站点：" + journey.currentStop.place + "，" + journey.currentStop.detail)
            }
        }
        Repeater {
            model: [{label:"聚焦行旅", overview:false}, {label:"纵览山河", overview:true}]
            delegate: Rectangle {
                id: viewChoice
                required property var modelData
                width: 82; height: 38; radius: 7
                color: page.overview === modelData.overview ? Theme.selected : Theme.surface
                border.color: page.overview === modelData.overview ? Theme.borderStrong : Theme.border
                Text { anchors.centerIn: parent; text: viewChoice.modelData.label; color: Theme.text; font.family: "SimSun"; font.pixelSize: 11 }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: { page.overview = viewChoice.modelData.overview; mapStage.overview = page.overview; mapStage.applyCamera(page.noteOpen ? journey.currentIndex : -1) }
                }
            }
        }
        Rectangle { width: 1; height: 26; anchors.verticalCenter: parent.verticalCenter; color: Theme.borderStrong }
        Item {
            width: Math.min(420, Math.max(255, page.width - 720)); height: 38
            ListView {
                id: journeyPoetStrip
                anchors.fill: parent; orientation: ListView.Horizontal
                spacing: 6; clip: true; boundsBehavior: Flickable.StopAtBounds
                model: journey.poetOptions
                delegate: Rectangle {
                    id: poetChoice
                    required property var modelData
                    width: 82; height: 38; radius: 7
                    color: journey.selectedPoetId === modelData.id ? Theme.selected : (poetHover.containsMouse ? Theme.hover : Theme.surface)
                    border.color: journey.selectedPoetId === modelData.id ? Theme.borderStrong : Theme.border
                    Text { anchors.centerIn: parent; text: poetChoice.modelData.name; color: Theme.text; font.family: "SimSun"; font.pixelSize: 13 }
                    MouseArea {
                        id: poetHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            page.selectPoet(poetChoice.modelData.id)
                            journeyPoetStrip.positionViewAtIndex(index, ListView.Contain)
                        }
                    }
                }
                ScrollBar.horizontal: ScrollBar {
                    policy: journeyPoetStrip.contentWidth > journeyPoetStrip.width ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
                    contentItem: Rectangle { implicitHeight: 2; radius: 1; color: Theme.borderStrong }
                }
            }
        }
    }

    Rectangle {
        id: atlas
        x: 23; y: 82; width: parent.width - 46
        height: Math.max(360, parent.height - y - timeline.height - 26)
        radius: 13; clip: true
        color: Theme.surface; border.color: Theme.borderStrong

        JourneyMap {
            id: mapStage
            anchors.fill: parent
            drawerOpen: page.noteOpen
            overview: page.overview
            onStopChosen: function(index) {
                var target = index
                // Repeated events at one coordinate remain individually selectable.
                if (page.noteOpen && journey.currentIndex === index && journey.placeEvents.length > 1) {
                    var group = journey.placeEvents
                    for (var i = 0; i < group.length; ++i)
                        if (group[i].index === index) { target = group[(i+1)%group.length].index; break }
                }
                page.selectStop(target, true)
            }
        }

        Rectangle {
            x: page.noteOpen ? atlas.width - page.noteWidth - width - 13 : atlas.width - width - 17
            y: 15; width: Math.min(260, atlas.width*.27); height: 46; radius: 7
            visible: page.arrival !== "" && !page.noteOpen
            opacity: page.arrival !== "" && !page.noteOpen ? 1 : 0
            color: Theme.light ? "#E8FFFAF2" : "#DE18393B"
            border.color: Theme.borderStrong
            Behavior on opacity { NumberAnimation { duration: Theme.motion ? 250 : 0 } }
            Text {
                anchors.centerIn: parent; width: parent.width - 20
                text: page.arrival; elide: Text.ElideRight
                color: Theme.text; font.family: "SimSun"; font.pixelSize: 12
            }
        }

        Rectangle {
            id: note
            x: page.noteOpen ? atlas.width - width : atlas.width + 7
            y: 0; width: page.noteWidth; height: atlas.height
            visible: opacity > 0; opacity: page.noteOpen ? 1 : 0
            color: page.noteSurface; border.color: Theme.borderStrong
            Behavior on x { NumberAnimation { duration: Theme.motion ? 410 : 0; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: Theme.motion ? 340 : 0 } }
            Rectangle { x: 0; width: 3; height: parent.height; color: Theme.gold }
            Text { x: 25; y: 19; text: "行 旅 手 札   /   FIELD NOTES"; color: page.noteGold; font.family: "SimSun"; font.pixelSize: 12; font.letterSpacing: 1 }
            Text {
                anchors.right: parent.right; anchors.rightMargin: 64; y: 20
                text: noteScroll.contentY >= eventDirectoryTitle.y - 60 ? "返回详述  ↑" : "沿途事件  ↓"
                color: page.noteGold; font.family: "SimSun"; font.pixelSize: 12
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        eventJump.stop()
                        eventJump.to = noteScroll.contentY >= eventDirectoryTitle.y - 60
                                       ? 0 : Math.min(noteScroll.contentHeight - noteScroll.height, eventDirectoryTitle.y)
                        eventJump.start()
                    }
                }
            }
            Rectangle {
                anchors.right: parent.right; anchors.rightMargin: 16; y: 10
                width: 34; height: 34; radius: 6
                color: closeHover.containsMouse ? page.noteCard : "transparent"
                Text { anchors.centerIn: parent; text: "×"; color: page.noteInk; font.pixelSize: 23 }
                MouseArea { id: closeHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: page.closeNote() }
            }
            Rectangle { x: 24; y: 53; width: parent.width - 48; height: 1; color: Theme.line }
            Flickable {
                id: noteScroll
                x: 23; y: 67; width: parent.width - 42; height: parent.height - 81
                clip: true; contentWidth: width; contentHeight: noteContent.implicitHeight + 18
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                    contentItem: Rectangle { implicitWidth: 3; radius: 2; color: Theme.borderStrong }
                }
                Column {
                    id: noteContent; width: parent.width - 12; spacing: 12
                    Text { text: "JOURNEY / " + ("0" + (journey.currentIndex+1)).slice(-2); color: page.noteGold; font.family: "Georgia"; font.pixelSize: 11; font.letterSpacing: 1.5 }
                    Text { width: parent.width; text: journey.currentStop.place || "站点资料不可用"; color: page.noteInk; font.family: "SimSun"; font.pixelSize: 34; wrapMode: Text.Wrap }
                    Text { text: journey.currentStop.date || ""; color: page.noteGold; font.family: "SimSun"; font.pixelSize: 15 }
                    Text {
                        width: parent.width; wrapMode: Text.Wrap
                        text: journey.selectedPoet.name + "  /  " + (journey.stages[journey.activeStage] ? journey.stages[journey.activeStage].name : "")
                        color: page.noteMuted; font.family: "Microsoft YaHei UI"; font.pixelSize: 12
                    }
                    Text {
                        width: parent.width; wrapMode: Text.Wrap
                        text: journey.stages[journey.activeStage] ? journey.stages[journey.activeStage].summary : ""
                        color: page.noteMuted; font.family: "Microsoft YaHei UI"; font.pixelSize: 12
                        lineHeight: 1.4
                    }
                    Rectangle { width: parent.width; height: 1; color: Theme.line }
                    Text { width: parent.width; text: "此站经历  /  " + (journey.currentStop.event || ""); color: page.noteInk; font.family: "SimSun"; font.pixelSize: 21; wrapMode: Text.Wrap }
                    Text {
                        width: parent.width; text: journey.currentStop.detail || journey.errorMessage
                        color: page.noteInk; font.family: "Microsoft YaHei UI"; font.pixelSize: 13
                        lineHeight: 1.5; wrapMode: Text.Wrap
                    }
                    Rectangle {
                        visible: !!page.reading.content
                        width: parent.width; height: readingContent.implicitHeight + 24
                        radius: 8; color: page.noteCard; border.color: Theme.borderStrong
                        Column {
                            id: readingContent
                            x: 13; y: 12; width: parent.width - 26; spacing: 8
                            Text {
                                width: parent.width
                                text: "此 站 诗 笺  /  " + (page.reading.period || journey.currentStop.date || "")
                                color: page.noteGold; font.family: "SimSun"; font.pixelSize: 13
                                font.letterSpacing: 1
                            }
                            Text {
                                width: parent.width; wrapMode: Text.Wrap
                                text: "《" + (page.reading.title || "") + "》"
                                color: page.noteInk; font.family: "SimSun"; font.pixelSize: 20
                            }
                            Text {
                                width: parent.width; wrapMode: Text.Wrap
                                text: page.reading.context || ""
                                color: page.noteMuted; font.family: "Microsoft YaHei UI"; font.pixelSize: 11
                                lineHeight: 1.45
                            }
                            Rectangle { width: parent.width; height: 1; color: Theme.line }
                            Text {
                                width: parent.width; wrapMode: Text.Wrap
                                text: page.reading.content || ""
                                maximumLineCount: page.poemExpanded ? 999 : 5
                                elide: page.poemExpanded ? Text.ElideNone : Text.ElideRight
                                color: page.noteInk; font.family: "SimSun"; font.pixelSize: 15
                                lineHeight: 1.55
                            }
                            Row {
                                spacing: 18
                                Text {
                                    visible: (page.reading.content || "").length > 64
                                    text: page.poemExpanded ? "收起诗文  ↑" : "展开全文  ↓"
                                    color: page.noteGold; font.family: "SimSun"; font.pixelSize: 12
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: page.poemExpanded = !page.poemExpanded }
                                }
                                Text {
                                    visible: !!page.reading.textSource
                                    text: "诗文原文  ↗"; color: page.noteGold
                                    font.family: "SimSun"; font.pixelSize: 12
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Qt.openUrlExternally(page.reading.textSource) }
                                }
                                Text {
                                    visible: !!page.reading.dateSource
                                    text: "年代考据  ↗"; color: page.noteGold
                                    font.family: "SimSun"; font.pixelSize: 12
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Qt.openUrlExternally(page.reading.dateSource) }
                                }
                            }
                        }
                    }
                    Text {
                        visible: !page.reading.content
                        width: parent.width; wrapMode: Text.Wrap
                        text: "此站暂无完成网络考据的同年代诗作。"
                        color: page.noteMuted; font.family: "Microsoft YaHei UI"; font.pixelSize: 12
                    }
                    Text { text: "地名与位置"; color: page.noteGold; font.family: "SimSun"; font.pixelSize: 16; topPadding: 8 }
                    Text {
                        width: parent.width; text: journey.currentStop.context || ""
                        color: page.noteMuted; font.family: "Microsoft YaHei UI"; font.pixelSize: 12
                        lineHeight: 1.42; wrapMode: Text.Wrap
                    }
                    Text {
                        visible: journey.currentStop.uncertain === true
                        width: parent.width; wrapMode: Text.Wrap
                        text: "≈  此站的时间或地点为约略记述"
                        color: page.noteGold; font.family: "Microsoft YaHei UI"; font.pixelSize: 11
                    }
                    Text {
                        text: "资料来源  ↗"; color: page.noteGold
                        font.family: "Microsoft YaHei UI"; font.pixelSize: 12
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (journey.currentStop.source) Qt.openUrlExternally(journey.currentStop.source) }
                    }
                    Column {
                        visible: journey.placeEvents.length > 1
                        width: parent.width; spacing: 7
                        Text { text: "同地事件"; color: page.noteGold; font.family: "SimSun"; font.pixelSize: 15 }
                        Repeater {
                            model: journey.placeEvents
                            delegate: Rectangle {
                                required property var modelData
                                width: noteContent.width; height: 32; radius: 5
                                color: modelData.index === journey.currentIndex ? page.noteHighlight : page.noteCard
                                Text { anchors.centerIn: parent; width: parent.width - 18; elide: Text.ElideRight
                                    text: modelData.date + " · " + modelData.event; color: page.noteInk; font.pixelSize: 11 }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: page.selectStop(modelData.index, true) }
                            }
                        }
                    }
                    Rectangle { width: parent.width; height: 1; color: Theme.line }
                    Text {
                        id: eventDirectoryTitle
                        width: parent.width; text: "沿途事件  /  " + journey.stopCount + " 站"
                        color: page.noteGold; font.family: "SimSun"; font.pixelSize: 16
                    }
                    Text {
                        width: parent.width; wrapMode: Text.Wrap
                        text: "按史料所载的人生次序排列；点击任一事件，地图与时间轴会同步定位。"
                        color: page.noteMuted; font.family: "Microsoft YaHei UI"; font.pixelSize: 11
                    }
                    Repeater {
                        model: journey.stops
                        delegate: Rectangle {
                            id: eventCard
                            required property var modelData
                            required property int index
                            width: noteContent.width
                            height: eventText.implicitHeight + 22
                            radius: 7
                            color: journey.currentIndex === index ? page.noteHighlight : page.noteCard
                            border.color: journey.currentIndex === index ? Theme.borderStrong : Theme.border
                            Column {
                                id: eventText
                                x: 12; y: 11; width: parent.width - 24; spacing: 5
                                Text {
                                    width: parent.width; wrapMode: Text.Wrap
                                    text: (eventCard.index + 1) + "  /  " + eventCard.modelData.date + "  ·  " + eventCard.modelData.place
                                    color: Theme.light && journey.currentIndex === eventCard.index ? Theme.paperGold : page.noteGold
                                    font.family: "SimSun"; font.pixelSize: 12
                                }
                                Text {
                                    width: parent.width; wrapMode: Text.Wrap
                                    text: eventCard.modelData.event
                                    color: page.noteInk; font.family: "SimSun"; font.pixelSize: 16
                                }
                                Text {
                                    width: parent.width; wrapMode: Text.Wrap
                                    text: eventCard.modelData.detail
                                    color: page.noteMuted; font.family: "Microsoft YaHei UI"; font.pixelSize: 12
                                    lineHeight: 1.45
                                }
                                Text {
                                    visible: eventCard.modelData.uncertain === true
                                    text: "约略记述"; color: page.noteGold
                                    font.family: "Microsoft YaHei UI"; font.pixelSize: 10
                                }
                            }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: page.selectStop(eventCard.index, true)
                            }
                        }
                    }
                    Rectangle { width: parent.width; height: 1; color: Theme.line }
                    Text { text: "本地典藏 · 诗中同名地点"; color: page.noteGold; font.family: "SimSun"; font.pixelSize: 16 }
                    Text {
                        visible: journey.relatedPoems.length === 0
                        width: parent.width; wrapMode: Text.Wrap
                        text: "本地诗词库暂无该诗人写及此地的作品。"
                        color: page.noteMuted; font.family: "Microsoft YaHei UI"; font.pixelSize: 12
                    }
                    Repeater {
                        model: journey.relatedPoems
                        delegate: Rectangle {
                            required property var modelData
                            width: noteContent.width; height: 55; radius: 7
                            color: poemHover.containsMouse ? page.noteCard : page.noteSurface
                            border.color: Theme.border
                            Text { x: 12; y: 8; text: "《" + modelData.title + "》"; color: page.noteInk; font.family: "SimSun"; font.pixelSize: 15 }
                            Text { x: 13; y: 34; text: modelData.dynasty + " · " + modelData.author; color: page.noteGold; font.pixelSize: 10 }
                            MouseArea { id: poemHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: page.openPoem(modelData.id) }
                        }
                    }
                    Row {
                        spacing: 8; topPadding: 5
                        Repeater {
                            model: [{label:"打开诗词典藏", action:"archive", width:122}, {label:"AI 解读 ↗", action:"ai", width:90}]
                            delegate: Rectangle {
                                id: action
                                required property var modelData
                                width: modelData.width; height: 35; radius: 6
                                color: actionHover.containsMouse ? (Theme.light ? page.noteHighlight : Theme.hover) : page.noteCard
                                border.color: Theme.borderStrong
                                Text { anchors.centerIn: parent; text: action.modelData.label; color: page.noteGold; font.family: "SimSun"; font.pixelSize: 12 }
                                MouseArea {
                                    id: actionHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: action.modelData.action === "archive" ? page.openArchive()
                                               : page.openAi(journey.selectedPoet.name, journey.currentStop.detail)
                                }
                            }
                        }
                    }
                    Item { width: 1; height: 16 }
                }
            }
            NumberAnimation {
                id: eventJump; target: noteScroll; property: "contentY"
                duration: Theme.motion ? 430 : 0; easing.type: Easing.OutCubic
            }
        }
    }

    Rectangle {
        id: timeline
        x: 23; y: atlas.y + atlas.height + 11
        width: parent.width - 46; height: 164
        radius: 12; color: Theme.surface; border.color: Theme.border
        Text { x: 18; y: 9; text: "行旅时间轴"; color: Theme.text; font.family: "SimSun"; font.pixelSize: 19 }
        Text { x: 139; y: 17; text: "按人生阶段，丈量诗人的山河"; color: Theme.secondary; font.family: "SimSun"; font.pixelSize: 11 }
        Text {
            anchors.right: parent.right; anchors.rightMargin: 18; y: 15
            text: journey.selectedPoet.name + "  ·  " + journey.currentStop.place + "   /   " + (journey.currentIndex+1) + " · " + journey.stopCount + " 站"
            color: Theme.gold; font.family: "Microsoft YaHei UI"; font.pixelSize: 11
        }
        Slider {
            id: timeSlider
            x: 18; y: 37; width: parent.width - 36; height: 24
            from: 0; to: Math.max(1, journey.stopCount-1); stepSize: 1
            value: journey.currentIndex; enabled: journey.stopCount > 1
            onMoved: page.selectStop(Math.round(value), false)
            background: Rectangle {
                x: 0; y: timeSlider.availableHeight/2 - 2
                width: timeSlider.availableWidth; height: 3; radius: 2
                color: Theme.border
                Rectangle { width: timeSlider.visualPosition*parent.width; height: parent.height; radius: 2; color: Theme.gold }
            }
            handle: Rectangle {
                x: timeSlider.leftPadding + timeSlider.visualPosition*(timeSlider.availableWidth-width)
                y: timeSlider.topPadding + timeSlider.availableHeight/2-height/2
                width: 16; height: 16; radius: 8
                color: Theme.goldLight; border.color: Theme.gold; border.width: 2
            }
        }
        Row {
            x: 18; y: 64; width: parent.width - 36; spacing: 7
            Repeater {
                model: journey.stages
                delegate: Rectangle {
                    id: stageCard
                    required property var modelData
                    required property int index
                    width: (timeline.width - 36 - 7 * Math.max(0, journey.stages.length - 1))
                           / Math.max(1, journey.stages.length)
                    height: 57; radius: 7
                    color: journey.activeStage === index ? Theme.selected : Theme.card
                    border.color: journey.activeStage === index ? Theme.borderStrong : Theme.border
                    clip: true
                    Canvas {
                        anchors.right: parent.right; anchors.bottom: parent.bottom
                        width: 91; height: 32; opacity: Theme.light ? .20 : .12
                        onPaint: {
                            var c = getContext("2d")
                            c.clearRect(0,0,width,height)
                            c.fillStyle = Theme.light ? "#8B9D92" : "#BCD0C3"
                            c.beginPath(); c.moveTo(0,height)
                            c.lineTo(29,8); c.lineTo(44,23); c.lineTo(63,2); c.lineTo(width,height)
                            c.closePath(); c.fill()
                        }
                    }
                    Text { x: 13; y: 8; width: parent.width-22; text: stageCard.modelData.name; color: Theme.text; font.family: "SimSun"; font.pixelSize: 15; elide: Text.ElideRight }
                    Text { x: 13; y: 36; width: parent.width-22; text: stageCard.modelData.period; color: Theme.secondary; font.family: "Georgia"; font.pixelSize: 10; elide: Text.ElideRight }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { journey.pause(); journey.seekStage(stageCard.index) } }
                }
            }
        }
        Row {
            x: 18; y: 129; spacing: 7
            Repeater {
                model: [{label:"上一站", action:"previous", width:70},
                        {label:journey.playing ? "暂停" : "开始行旅", action:"toggle", width:87},
                        {label:"下一站", action:"next", width:70},
                        {label:"从头重看", action:"restart", width:82}]
                delegate: Rectangle {
                    id: control
                    required property var modelData
                    width: modelData.width; height: 28; radius: 6
                    color: modelData.action === "toggle" ? Theme.selected : Theme.card
                    border.color: modelData.action === "toggle" ? Theme.borderStrong : Theme.border
                    Text { anchors.centerIn: parent; text: control.modelData.label; color: Theme.text; font.family: "SimSun"; font.pixelSize: 11 }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (control.modelData.action === "previous") { journey.pause(); journey.previous() }
                            else if (control.modelData.action === "next") { journey.pause(); journey.next() }
                            else if (control.modelData.action === "restart") { journey.restart(); mapStage.applyCamera(0) }
                            else page.togglePlayback()
                        }
                    }
                }
            }
        }
        Row {
            anchors.right: parent.right; anchors.rightMargin: 18; y: 129; spacing: 7
            Rectangle {
                width: 93; height: 28; radius: 6; color: Theme.card; border.color: Theme.border
                Text { anchors.centerIn: parent; text: "速度 " + journey.speed.toFixed(1) + "×"; color: Theme.text; font.family: "SimSun"; font.pixelSize: 11 }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: journey.setSpeed(journey.speed >= 2 ? .5 : journey.speed+.5) }
            }
            Rectangle {
                width: 80; height: 28; radius: 6; color: Theme.card; border.color: Theme.border
                Text { anchors.centerIn: parent; text: "复位视角"; color: Theme.text; font.family: "SimSun"; font.pixelSize: 11 }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: mapStage.applyCamera(page.noteOpen ? journey.currentIndex : -1) }
            }
        }
    }
}
