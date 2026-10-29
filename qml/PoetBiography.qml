import QtQuick
import QtQuick.Controls
import YiJuanShanHe

Item {
    id: page
    property bool compareMode: false
    property int compareTarget: 0
    property int activeStage: 0
    property int compareStage: 0
    property string expandedEventKey: ""
    property string expandedLeftKey: ""
    property string expandedRightKey: ""
    signal notify(string message)
    signal openJourney(string poetId)
    signal openAi(string name, string description)

    readonly property var leftProfile: poets.compareAProfile
    readonly property var rightProfile: poets.compareBProfile
    readonly property var actionProfile: compareMode ? (compareTarget === 0 ? leftProfile : rightProfile) : poets.selectedProfile
    readonly property string actionId: compareMode ? (compareTarget === 0 ? poets.compareAId : poets.compareBId) : poets.selectedId
    readonly property int overlapStart: Math.max(leftProfile.birthYear || 0, rightProfile.birthYear || 0)
    readonly property int overlapEnd: Math.min(leftProfile.deathYear || 0, rightProfile.deathYear || 0)
    readonly property bool overlap: overlapStart <= overlapEnd && overlapStart > 0

    function eventKey(e) { return (e.year || 0) + "/" + (e.title || "") }
    function eventsForStage(stageIndex, events, stages) {
        if (!stages || stageIndex >= stages.length || !events) return []
        const start = stages[stageIndex].start || 0
        const next = stageIndex + 1 < stages.length ? stages[stageIndex + 1].start : 10000
        let result = []
        for (let i = 0; i < events.length; ++i)
            if (events[i].year >= start && events[i].year < next) result.push(events[i])
        return result
    }
    function jumpStage(index) {
        activeStage = index
        const target = stageRepeater.itemAt(index)
        if (target) bookScroll.contentY = Math.max(0, Math.min(bookScroll.contentHeight - bookScroll.height, target.y - 13))
    }
    function openReference(url) { if (url) Qt.openUrlExternally(url) }

    Rectangle { anchors.fill: parent; color: Theme.background }

    Text {
        x: 25; y: 16; text: "诗人列传"
        color: Theme.text; font.family: "SimSun"; font.pixelSize: 30
    }
    Text {
        x: 26; y: 51; text: "以人生为卷，读诗人与时代"
        color: Theme.secondary; font.family: "Microsoft YaHei UI"; font.pixelSize: 12
    }
    Row {
        id: headerActions
        anchors.right: parent.right; anchors.rightMargin: 25; y: 23; spacing: 7
        Repeater {
            model: [{label:"生平长卷", compare:false}, {label:"双璧对照", compare:true}]
            delegate: Rectangle {
                required property var modelData
                width: 90; height: 35; radius: 7
                color: page.compareMode === modelData.compare ? Theme.selected : Theme.surface
                border.color: page.compareMode === modelData.compare ? Theme.borderStrong : Theme.border
                Behavior on color { ColorAnimation { duration: Theme.motion ? 170 : 0 } }
                Text {
                    anchors.centerIn: parent; text: modelData.label
                    color: Theme.text; font.family: "Microsoft YaHei UI"; font.pixelSize: 12
                }
                MouseArea {
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: page.compareMode = modelData.compare
                }
            }
        }
        Rectangle { width: 1; height: 24; anchors.verticalCenter: parent.verticalCenter; color: Theme.line }
        Repeater {
            model: [{label:"AI 解读 ↗", action:"ai", width:88}, {label:"行旅地图 ↗", action:"journey", width:98}]
            delegate: Rectangle {
                required property var modelData
                width: modelData.width; height: 35; radius: 7
                color: actionMouse.containsMouse ? Theme.hover : Theme.surface
                border.color: Theme.border
                Text {
                    anchors.centerIn: parent; text: modelData.label
                    color: Theme.gold; font.family: "Microsoft YaHei UI"; font.pixelSize: 12
                }
                MouseArea {
                    id: actionMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: modelData.action === "ai"
                               ? page.openAi(page.actionProfile.name || "", page.actionProfile.intro || "")
                               : page.openJourney(page.actionId)
                }
            }
        }
    }

    Rectangle {
        id: selector
        x: 24; y: 84; width: parent.width - 48; height: 66; radius: 10
        color: Theme.surface; border.color: Theme.border
        Rectangle {
            id: searchBox
            x: 12; y: 11; width: Math.min(216, selector.width * .24); height: 44; radius: 7
            color: Theme.field; border.color: searchInput.activeFocus ? Theme.borderStrong : Theme.border
            Text { x: 11; anchors.verticalCenter: parent.verticalCenter; text: "⌕"; color: Theme.gold; font.pixelSize: 21 }
            TextField {
                id: searchInput; x: 38; y: 1; width: parent.width - 45; height: parent.height - 2
                placeholderText: "查找诗人、朝代"; placeholderTextColor: Theme.subtle
                color: Theme.text; font.family: "Microsoft YaHei UI"; font.pixelSize: 12
                background: Item {}
                onTextChanged: searchDelay.restart()
                onAccepted: poets.search(text)
            }
            Timer { id: searchDelay; interval: 190; onTriggered: poets.search(searchInput.text) }
        }
        ListView {
            id: poetStrip
            x: searchBox.x + searchBox.width + 11; y: 8
            width: parent.width - x - 11; height: 50
            orientation: ListView.Horizontal; spacing: 7; clip: true
            boundsBehavior: Flickable.StopAtBounds; model: poets
            delegate: Rectangle {
                id: poetChoice
                required property string poetId
                required property string poetName
                required property string poetDynasty
                required property string poetEpithet
                readonly property bool singleSelected: poets.selectedId === poetId
                readonly property bool leftSelected: poets.compareAId === poetId
                readonly property bool rightSelected: poets.compareBId === poetId
                readonly property bool marked: page.compareMode ? (leftSelected || rightSelected) : singleSelected
                width: Math.max(155, Math.min(184, (poetStrip.width - 14) / 3)); height: 49; radius: 7
                color: marked ? Theme.selected : (choiceMouse.containsMouse ? Theme.hover : Theme.card)
                border.color: marked ? Theme.borderStrong : Theme.border
                Behavior on color { ColorAnimation { duration: Theme.motion ? 180 : 0 } }
                Rectangle {
                    x: 8; y: 8; width: 32; height: 32; radius: 16
                    color: Theme.light ? "#F7EAD0" : "#426462"
                    Text { anchors.centerIn: parent; text: poetChoice.poetName.slice(0, 1); color: Theme.gold; font.family: "SimSun"; font.pixelSize: 20 }
                }
                Text { x: 48; y: 6; text: poetName; color: Theme.text; font.family: "SimSun"; font.pixelSize: 17 }
                Text { x: 48; y: 30; text: poetDynasty + "  ·  " + poetEpithet; color: Theme.secondary; font.pixelSize: 10 }
                Text {
                    anchors.right: parent.right; anchors.rightMargin: 9; y: 7
                    text: page.compareMode ? (leftSelected ? "左" : rightSelected ? "右" : "") : (singleSelected ? "●" : "")
                    color: Theme.gold; font.family: "SimSun"; font.pixelSize: 11
                }
                MouseArea {
                    id: choiceMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (page.compareMode) {
                            if (!poets.setComparison(page.compareTarget, poetChoice.poetId))
                                page.notify("双璧对照需要两位不同的诗人")
                        } else poets.selectPoet(poetChoice.poetId)
                    }
                }
            }
        }
        Text {
            visible: poets.resultCount === 0
            anchors.centerIn: poetStrip
            text: poets.errorMessage || "没有找到相符人物"
            color: Theme.secondary; font.family: "Microsoft YaHei UI"; font.pixelSize: 12
        }
    }

    Rectangle {
        id: folio
        x: 24; y: 162; width: parent.width - 48; height: parent.height - 180
        radius: 13; clip: true
        color: Theme.light ? "#F4EFE5" : "#17373C"
        border.color: Theme.borderStrong
        Behavior on color { ColorAnimation { duration: Theme.motion ? 300 : 0 } }

        Item {
            anchors.fill: parent; visible: !page.compareMode
            Rectangle {
                id: stageNav
                x: 0; y: 0; width: parent.width; height: 56
                color: Theme.light ? "#EAE2D2" : "#214247"
                Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.line }
                Text {
                    x: 25; anchors.verticalCenter: parent.verticalCenter
                    text: "生平长卷  /  " + (page.activeStage + 1) + " · " + poets.selectedStages.length
                    color: Theme.gold; font.family: "SimSun"; font.pixelSize: 15
                }
                Row {
                    anchors.right: parent.right; anchors.rightMargin: 17
                    anchors.verticalCenter: parent.verticalCenter; spacing: 5
                    Repeater {
                        model: poets.selectedStages
                        delegate: Rectangle {
                            required property var modelData
                            required property int index
                            width: Math.max(100, Math.min(138, (stageNav.width - 285) / Math.max(1, poets.selectedStages.length))); height: 34; radius: 6
                            color: page.activeStage === index ? Theme.selected : "transparent"
                            border.color: page.activeStage === index ? Theme.borderStrong : "transparent"
                            Text {
                                anchors.centerIn: parent
                                text: (index + 1) + "  " + modelData.name
                                color: page.activeStage === index ? Theme.text : Theme.secondary
                                font.family: "Microsoft YaHei UI"; font.pixelSize: 11
                            }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: page.jumpStage(index) }
                        }
                    }
                }
            }
            Flickable {
                id: bookScroll
                x: 0; y: 57; width: parent.width; height: parent.height - 57
                contentWidth: width; contentHeight: bookColumn.implicitHeight + 26
                clip: true; boundsBehavior: Flickable.StopAtBounds
                onContentYChanged: {
                    for (let i = 0; i < stageRepeater.count; ++i) {
                        const item = stageRepeater.itemAt(i)
                        if (item && contentY + 110 >= item.y) page.activeStage = i
                    }
                }
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded; contentItem: Rectangle { implicitWidth: 4; radius: 2; color: Theme.borderStrong } }
                Column {
                    id: bookColumn
                    x: 25; width: bookScroll.width - 50; spacing: 0
                    Item { width: 1; height: 24 }
                    LifePortrait {
                        id: hero
                        width: bookColumn.width; height: implicitHeight
                        profile: poets.selectedProfile
                    }
                    Item { width: 1; height: 24 }
                    Row {
                        width: parent.width; height: 40; spacing: 22
                        Text { text: "四时流转，山河为证"; color: Theme.text; font.family: "SimSun"; font.pixelSize: 23 }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "CHRONICLE   /   按人生阶段展卷"
                            color: Theme.gold; font.family: "Georgia"; font.pixelSize: 10; font.letterSpacing: 1
                        }
                    }
                    Item { width: 1; height: 10 }
                    Repeater {
                        id: stageRepeater
                        model: poets.selectedStages
                        delegate: Column {
                            id: stageSection
                            required property var modelData
                            required property int index
                            readonly property int stageNumber: index
                            width: bookColumn.width; spacing: 0
                            Item {
                                id: stageHeading
                                width: parent.width; height: Math.max(137, stageSummary.implicitHeight + 82)
                                Rectangle {
                                    x: 5; y: 16; width: 54; height: 54; radius: 27
                                    color: Theme.light ? "#EFE1C4" : "#325354"
                                    border.color: Theme.borderStrong
                                    Text { anchors.centerIn: parent; text: "0" + (stageSection.index + 1); color: Theme.gold; font.family: "Georgia"; font.pixelSize: 18 }
                                }
                                Text {
                                    x: 78; y: 12
                                    text: stageSection.modelData.name
                                    color: Theme.text; font.family: "SimSun"; font.pixelSize: 28
                                }
                                Text {
                                    x: 80; y: 48
                                    text: stageSection.modelData.period + (stageSection.modelData.uncertain ? "  ·  年代约略" : "")
                                    color: Theme.gold; font.family: "Georgia"; font.pixelSize: 13
                                }
                                Text {
                                    id: stageSummary
                                    x: 80; y: 74; width: Math.min(parent.width - 265, 670)
                                    text: stageSection.modelData.summary
                                    color: Theme.secondary; font.family: "Microsoft YaHei UI"; font.pixelSize: 13
                                    lineHeight: 1.5; wrapMode: Text.Wrap
                                }
                                Canvas {
                                    id: sketch
                                    x: parent.width - 165; y: 25; width: 150; height: 95
                                    opacity: Theme.light ? .21 : .19
                                    onWidthChanged: requestPaint()
                                    Connections { target: Theme; function onNameChanged() { sketch.requestPaint() } }
                                    onPaint: {
                                        const c = getContext("2d")
                                        c.clearRect(0,0,width,height)
                                        c.fillStyle = Theme.gold
                                        c.beginPath(); c.moveTo(0,92)
                                        c.quadraticCurveTo(31,76,54,37)
                                        c.quadraticCurveTo(73,78,88,61)
                                        c.quadraticCurveTo(110,26,150,72)
                                        c.lineTo(150,95); c.closePath(); c.fill()
                                    }
                                }
                                Rectangle { anchors.bottom: parent.bottom; x: 78; width: parent.width - 78; height: 1; color: Theme.line }
                            }
                            Item {
                                id: eventTrack
                                width: parent.width; height: Math.max(76, eventColumn.implicitHeight + 15)
                                Rectangle {
                                    x: 118; y: 0; width: 1
                                    height: Math.max(0, eventColumn.implicitHeight - 2)
                                    color: Theme.line
                                }
                                Column {
                                    id: eventColumn; x: 20; width: parent.width - 25; spacing: 5
                                    Repeater {
                                        model: page.eventsForStage(stageSection.stageNumber, poets.selectedEvents, poets.selectedStages)
                                        delegate: LifeChronicleNode {
                                            id: chronicleNode
                                            required property var modelData
                                            width: eventColumn.width; height: implicitHeight
                                            eventData: modelData
                                            expanded: page.expandedEventKey === page.eventKey(modelData)
                                            current: expanded
                                            opacity: bookScroll.contentY + bookScroll.height > stageSection.y + eventTrack.y + y + 24 ? 1 : .15
                                            Behavior on opacity { NumberAnimation { duration: Theme.motion ? 330 : 0 } }
                                            onActivated: page.expandedEventKey = expanded ? "" : page.eventKey(modelData)
                                        }
                                    }
                                }
                                Text {
                                    visible: eventColumn.children.length === 0
                                    x: 145; y: 18; text: "此阶段暂无单列纪事"
                                    color: Theme.secondary; font.pixelSize: 12
                                }
                            }
                            Item { width: 1; height: 20 }
                        }
                    }
                    Rectangle { width: parent.width; height: 1; color: Theme.line }
                    Item { width: 1; height: 17 }
                    Row {
                        spacing: 20
                        Text { text: "史料索引"; color: Theme.text; font.family: "SimSun"; font.pixelSize: 18 }
                        Repeater {
                            model: poets.selectedProfile.sources || []
                            delegate: Text {
                                required property var modelData
                                text: "↗ " + modelData.label
                                color: Theme.gold; font.family: "Microsoft YaHei UI"; font.pixelSize: 11
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: page.openReference(modelData.url) }
                            }
                        }
                    }
                    Item { width: 1; height: 25 }
                }
            }
        }

        Item {
            anchors.fill: parent; visible: page.compareMode
            Flickable {
                id: compareScroll
                anchors.fill: parent; clip: true
                contentWidth: width; contentHeight: compareColumn.implicitHeight + 28
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded; contentItem: Rectangle { implicitWidth: 4; radius: 2; color: Theme.borderStrong } }
                Column {
                    id: compareColumn
                    x: 25; width: compareScroll.width - 50; spacing: 15
                    Item { width: 1; height: 8 }
                    Row {
                        width: parent.width; height: 47
                        Text { text: "双璧对照"; color: Theme.text; font.family: "SimSun"; font.pixelSize: 27 }
                        Text {
                            x: 142; anchors.verticalCenter: parent.verticalCenter
                            text: "以各自的人生阶段相望，年表保留原有纪年"
                            color: Theme.secondary; font.family: "Microsoft YaHei UI"; font.pixelSize: 12
                        }
                        Row {
                            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; spacing: 5
                            Repeater {
                                model: [{label:"选左卷", slot:0}, {label:"选右卷", slot:1}]
                                delegate: Rectangle {
                                    required property var modelData
                                    width: 72; height: 31; radius: 6
                                    color: page.compareTarget === modelData.slot ? Theme.selected : Theme.surface
                                    border.color: page.compareTarget === modelData.slot ? Theme.borderStrong : Theme.border
                                    Text { anchors.centerIn: parent; text: modelData.label; color: Theme.text; font.pixelSize: 11 }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: page.compareTarget = modelData.slot }
                                }
                            }
                        }
                    }
                    Item {
                        width: parent.width
                        height: Math.max(leftPortrait.implicitHeight, rightPortrait.implicitHeight)
                        LifePortrait {
                            id: leftPortrait
                            x: 0; width: (parent.width - 14) / 2; height: parent.height
                            compact: true; profile: page.leftProfile
                        }
                        LifePortrait {
                            id: rightPortrait
                            anchors.right: parent.right; width: (parent.width - 14) / 2; height: parent.height
                            compact: true; profile: page.rightProfile
                        }
                    }
                    Rectangle {
                        width: parent.width; height: 42; radius: 7
                        color: Theme.light ? "#E8DDC9" : "#284A4C"
                        Rectangle { x: 18; y: 20; width: parent.width - 36; height: 1; color: Theme.borderStrong }
                        Rectangle {
                            anchors.centerIn: parent; width: bridgeText.implicitWidth + 24; height: 29; radius: 14
                            color: Theme.light ? "#E8DDC9" : "#284A4C"
                            Text {
                                id: bridgeText; anchors.centerIn: parent
                                text: page.overlap ? "共同生活的年代  ·  " + page.overlapStart + "—" + page.overlapEnd
                                                   : "不同时代  ·  按人生阶段对读"
                                color: Theme.gold; font.family: "SimSun"; font.pixelSize: 12
                            }
                        }
                    }
                    Text { text: "四境对读"; color: Theme.text; font.family: "SimSun"; font.pixelSize: 21 }
                    Repeater {
                        model: Math.min(poets.compareAStages.length, poets.compareBStages.length)
                        delegate: Rectangle {
                            id: pairedStage
                            required property int index
                            readonly property var a: poets.compareAStages[index] || ({})
                            readonly property var b: poets.compareBStages[index] || ({})
                            readonly property bool selected: page.compareStage === index
                            width: compareColumn.width
                            height: selected ? Math.max(111, Math.max(leftSummary.implicitHeight, rightSummary.implicitHeight) + 73) : 60
                            radius: 8; color: selected ? (Theme.light ? "#EDE2CA" : "#2A4D4E") : (Theme.light ? "#F8F4EA" : "#204147")
                            border.color: selected ? Theme.borderStrong : Theme.border
                            Behavior on height { NumberAnimation { duration: Theme.motion ? 240 : 0; easing.type: Easing.OutCubic } }
                            Behavior on color { ColorAnimation { duration: Theme.motion ? 200 : 0 } }
                            Rectangle { x: parent.width / 2; y: 10; width: 1; height: parent.height - 20; color: Theme.line }
                            Rectangle {
                                x: parent.width / 2 - 14; y: 14; width: 29; height: 29; radius: 15
                                color: Theme.light ? "#F7F0E2" : "#355A58"; border.color: Theme.borderStrong
                                Text { anchors.centerIn: parent; text: pairedStage.index + 1; color: Theme.gold; font.family: "Georgia"; font.pixelSize: 12 }
                            }
                            Text { x: 17; y: 10; text: a.name || ""; color: Theme.text; font.family: "SimSun"; font.pixelSize: 18 }
                            Text { x: 18; y: 37; text: a.period || ""; color: Theme.gold; font.pixelSize: 11 }
                            Text { x: parent.width / 2 + 34; y: 10; text: b.name || ""; color: Theme.text; font.family: "SimSun"; font.pixelSize: 18 }
                            Text { x: parent.width / 2 + 35; y: 37; text: b.period || ""; color: Theme.gold; font.pixelSize: 11 }
                            Text {
                                id: leftSummary; visible: selected
                                x: 18; y: 68; width: parent.width / 2 - 50
                                text: a.summary || ""; color: Theme.secondary; font.family: "Microsoft YaHei UI"
                                font.pixelSize: 12; wrapMode: Text.Wrap; lineHeight: 1.4
                            }
                            Text {
                                id: rightSummary; visible: selected
                                x: parent.width / 2 + 35; y: 68; width: parent.width / 2 - 50
                                text: b.summary || ""; color: Theme.secondary; font.family: "Microsoft YaHei UI"
                                font.pixelSize: 12; wrapMode: Text.Wrap; lineHeight: 1.4
                            }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: page.compareStage = pairedStage.index
                            }
                        }
                    }
                    Text {
                        text: "本境纪事  /  " + (page.compareStage + 1)
                        color: Theme.text; font.family: "SimSun"; font.pixelSize: 21
                        topPadding: 8
                    }
                    Item {
                        width: parent.width; height: Math.max(leftEventsColumn.implicitHeight, rightEventsColumn.implicitHeight) + 10
                        Column {
                            id: leftEventsColumn; x: 0; width: (parent.width - 14) / 2; spacing: 4
                            Text { text: page.leftProfile.name + "  /  " + ((poets.compareAStages[page.compareStage] || {}).period || ""); color: Theme.gold; font.family: "SimSun"; font.pixelSize: 13; bottomPadding: 7 }
                            Repeater {
                                model: page.eventsForStage(page.compareStage, poets.compareAEvents, poets.compareAStages)
                                delegate: LifeChronicleNode {
                                    required property var modelData
                                    width: leftEventsColumn.width; height: implicitHeight; compact: true
                                    eventData: modelData
                                    expanded: page.expandedLeftKey === page.eventKey(modelData)
                                    current: expanded
                                    onActivated: page.expandedLeftKey = expanded ? "" : page.eventKey(modelData)
                                }
                            }
                        }
                        Rectangle { x: parent.width / 2; y: 2; width: 1; height: parent.height - 6; color: Theme.line }
                        Column {
                            id: rightEventsColumn; anchors.right: parent.right
                            width: (parent.width - 14) / 2; spacing: 4
                            Text { text: page.rightProfile.name + "  /  " + ((poets.compareBStages[page.compareStage] || {}).period || ""); color: Theme.gold; font.family: "SimSun"; font.pixelSize: 13; bottomPadding: 7 }
                            Repeater {
                                model: page.eventsForStage(page.compareStage, poets.compareBEvents, poets.compareBStages)
                                delegate: LifeChronicleNode {
                                    required property var modelData
                                    width: rightEventsColumn.width; height: implicitHeight; compact: true
                                    eventData: modelData
                                    expanded: page.expandedRightKey === page.eventKey(modelData)
                                    current: expanded
                                    onActivated: page.expandedRightKey = expanded ? "" : page.eventKey(modelData)
                                }
                            }
                        }
                    }
                    Item { width: 1; height: 17 }
                }
            }
        }
    }

    Connections {
        target: poets
        function onSelectionChanged() {
            page.activeStage = 0
            page.expandedEventKey = poets.selectedEvents.length ? page.eventKey(poets.selectedEvents[0]) : ""
            bookScroll.contentY = 0
        }
        function onComparisonChanged() {
            page.expandedLeftKey = ""
            page.expandedRightKey = ""
            compareScroll.contentY = 0
        }
    }
    Component.onCompleted: expandedEventKey = poets.selectedEvents.length ? eventKey(poets.selectedEvents[0]) : ""
    onCompareModeChanged: {
        if (compareMode) compareScroll.contentY = 0
        else bookScroll.contentY = 0
    }
}
