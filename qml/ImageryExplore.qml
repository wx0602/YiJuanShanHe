import QtQuick
import QtQuick.Controls
import YiJuanShanHe

Item {
    id: page
    objectName: "imageryExplore"
    signal openPoem(int poemId)
    signal openAi(string name, string description)
    property bool notebookOpen: false
    readonly property real noteWidth: Math.max(365, stage.width * .43)
    readonly property color ink: Theme.paperInk
    readonly property color accent: Theme.paperGold

    function openNote(key) {
        imagery.setCenter(key)
        notebookOpen = true
        forceActiveFocus()
        Qt.callLater(function() { field.focusOn(key, true) })
    }
    function closeNote() {
        notebookOpen = false
        imagery.clearPair()
        field.resetView()
    }
    function clearFilters() {
        searchInput.text = ""
        categoryBox.currentIndex = 0
        dynastyBox.currentIndex = 0
        imagery.setQuery("")
        imagery.setCategory("全部意象")
        imagery.setDynasty("全部朝代")
        field.resetView()
    }
    focus: true
    Keys.onEscapePressed: function(event) {
        if (notebookOpen) closeNote()
        else if (searchInput.activeFocus) { searchInput.focus = false; forceActiveFocus() }
        event.accepted = true
    }
    Shortcut { sequence: "Escape"; enabled: page.notebookOpen; onActivated: page.closeNote() }
    onVisibleChanged: if (visible) imagery.refresh()
    onNotebookOpenChanged: notebookOpen ? field.focusOn(imagery.center, true) : field.resetView()
    Connections {
        target: imagery
        function onChanged() {
            if (page.notebookOpen) Qt.callLater(function() { field.focusOn(imagery.center, true) })
        }
    }

    Rectangle { anchors.fill: parent; color: Theme.background }
    Item {
        x: 26; y: 16; width: parent.width - 52; height: 58
        Rectangle { x: 0; y: 10; width: 23; height: 1; color: Theme.gold }
        Text { x: 34; y: 1; text: "诗中万象  /  CONSTELLATION"; color: Theme.gold; font.family: "Georgia"; font.pixelSize: 11; font.letterSpacing: 1.5 }
        Text { x: 0; y: 24; text: "宋式星野图"; color: Theme.text; font.family: "SimSun"; font.pixelSize: 30; font.letterSpacing: 2 }
        Text { x: 180; y: 37; text: "循意象入诗，观万象共现"; color: Theme.secondary; font.family: "SimSun"; font.pixelSize: 12 }
        Text {
            anchors.right: parent.right; y: 30
            text: imagery.corpusCount + " 首诗词  ·  " + imagery.items.length + " 枚意象"
            color: Theme.secondary; font.family: "Georgia"; font.pixelSize: 12
        }
    }

    Rectangle {
        id: stage
        x: 24; y: 86; width: parent.width - 48; height: parent.height - 108
        radius: 17; color: Theme.surface; border.color: Theme.borderStrong
        clip: true

        SkyChart {
            id: field
            anchors.fill: parent
            entries: imagery.items
            connections: imagery.skyEdges
            selectedKey: page.notebookOpen ? imagery.center : ""
            pairKey: imagery.pair
            notebookOpen: page.notebookOpen
            onNodeSelected: function(key) { page.openNote(key) }
        }

        Rectangle {
            id: toolbar
            x: 17; y: 15
            width: Math.min(parent.width - 34, page.notebookOpen ? parent.width - page.noteWidth - 25 : 580)
            height: 48; radius: 9
            color: Theme.light ? "#EEF8F4EB" : "#E9214146"
            border.color: Theme.border
            Behavior on width { NumberAnimation { duration: Theme.motion ? 340 : 0; easing.type: Easing.OutCubic } }
            Row {
                anchors.fill: parent; anchors.leftMargin: 7; anchors.rightMargin: 7
                anchors.topMargin: 6; anchors.bottomMargin: 6; spacing: 6
                Rectangle {
                    width: Math.max(138, toolbar.width - 307); height: 36; radius: 6
                    color: Theme.field; border.color: searchInput.activeFocus ? Theme.borderStrong : Theme.border
                    TextField {
                        id: searchInput
                        anchors.fill: parent; leftPadding: 11; rightPadding: 7
                        placeholderText: "寻一枚意象"; placeholderTextColor: Theme.subtle
                        color: Theme.text; font.family: "Microsoft YaHei UI"; font.pixelSize: 12
                        background: Item {}
                        onTextChanged: queryDelay.restart()
                        onAccepted: imagery.setQuery(text)
                    }
                    Timer { id: queryDelay; interval: 220; onTriggered: imagery.setQuery(searchInput.text) }
                }
                ThemeComboBox {
                    id: categoryBox
                    width: 112; height: 36
                    model: imagery.categories
                    onActivated: imagery.setCategory(currentText)
                }
                ThemeComboBox {
                    id: dynastyBox
                    width: 112; height: 36
                    model: imagery.dynasties
                    onActivated: imagery.setDynasty(currentText)
                }
                Rectangle {
                    width: 45; height: 36; radius: 6
                    color: resetMouse.containsMouse ? Theme.hover : Theme.field
                    border.color: Theme.border
                    Text { anchors.centerIn: parent; text: "复位"; color: Theme.text; font.family: "SimSun"; font.pixelSize: 12 }
                    MouseArea { id: resetMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: page.clearFilters() }
                }
            }
        }

        Text {
            x: 26; y: 77
            text: imagery.error || (imagery.items.length ? "轻点星名展开手札  ·  拖拽移图  ·  滚轮缩放" : "当前条件下没有意象，试试放宽筛选。")
            color: imagery.error ? Theme.danger : Theme.secondary
            font.family: "SimSun"; font.pixelSize: 11
        }
        Row {
            x: 25; anchors.bottom: parent.bottom; anchors.bottomMargin: 17; spacing: 9
            Text { text: "✦"; color: Theme.gold; font.pixelSize: 10 }
            Text { text: "星名大小示出现频次"; color: Theme.secondary; font.family: "SimSun"; font.pixelSize: 10 }
            Text { text: "·"; color: Theme.gold }
            Text { text: "曲线深浅示诗中共现"; color: Theme.secondary; font.family: "SimSun"; font.pixelSize: 10 }
        }
        Row {
            anchors.right: parent.right; anchors.rightMargin: page.notebookOpen ? page.noteWidth + 18 : 18
            anchors.bottom: parent.bottom; anchors.bottomMargin: 13; spacing: 5
            Behavior on anchors.rightMargin { NumberAnimation { duration: Theme.motion ? 340 : 0 } }
            Repeater {
                model: [{label:"−", value:-1}, {label:"+", value:1}, {label:"归位", value:0}]
                delegate: Rectangle {
                    required property var modelData
                    width: modelData.value === 0 ? 48 : 31; height: 31; radius: 6
                    color: controlMouse.containsMouse ? Theme.hover : Theme.surface
                    border.color: Theme.border
                    Text { anchors.centerIn: parent; text: modelData.label; color: Theme.text; font.pixelSize: modelData.value === 0 ? 11 : 18 }
                    MouseArea {
                        id: controlMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: modelData.value === 0 ? field.resetView() : field.zoomBy(modelData.value > 0 ? 1.14 : .88)
                    }
                }
            }
        }

        Rectangle {
            id: notebook
            x: page.notebookOpen ? stage.width - width : stage.width + 8
            y: 0; width: page.noteWidth; height: stage.height
            opacity: page.notebookOpen ? 1 : 0
            visible: opacity > 0
            color: Theme.paper
            border.color: Theme.borderStrong
            Behavior on x { NumberAnimation { duration: Theme.motion ? 430 : 0; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: Theme.motion ? 340 : 0 } }

            Rectangle { x: 0; width: 3; height: parent.height; color: Theme.gold }
            Rectangle { x: 25; y: 25; width: 26; height: 1; color: Theme.paperGold }
            Text { x: 61; y: 15; text: "意 象 手 札  /  FIELD NOTES"; color: Theme.paperGold; font.family: "Georgia"; font.pixelSize: 11; font.letterSpacing: 1 }
            Rectangle {
                anchors.right: parent.right; anchors.rightMargin: 18; y: 12
                width: 33; height: 33; radius: 6
                color: closeMouse.containsMouse ? Theme.paperAlt : "transparent"
                Text { anchors.centerIn: parent; text: "×"; color: Theme.paperInk; font.pixelSize: 23 }
                MouseArea { id: closeMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: page.closeNote() }
            }
            Rectangle { x: 24; y: 54; width: parent.width - 48; height: 1; color: Theme.line }

            ListView {
                id: noteList
                x: 23; y: 69; width: parent.width - 43; height: parent.height - 84
                clip: true; spacing: 9; model: imagery.poems
                boundsBehavior: Flickable.StopAtBounds
                onModelChanged: positionViewAtBeginning()
                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                    contentItem: Rectangle { implicitWidth: 3; radius: 2; color: Theme.borderStrong }
                }
                header: Item {
                    width: noteList.width; height: introColumn.implicitHeight + 18
                    Column {
                        id: introColumn; width: parent.width - 12; spacing: 14
                        Text { text: imagery.center; color: page.ink; font.family: "SimSun"; font.pixelSize: 48; topPadding: 7 }
                        Text { text: imagery.centerCount + " 首诗词  /  共 " + imagery.corpusCount + " 首"; color: page.accent; font.family: "Georgia"; font.pixelSize: 14 }
                        Rectangle { width: parent.width; height: 1; color: Theme.line }
                        Text {
                            width: parent.width; text: imagery.description || "暂无意象释义"
                            color: page.ink; font.family: "SimSun"; font.pixelSize: 16
                            lineHeight: 1.48; wrapMode: Text.Wrap
                        }
                        Text { text: "共 现 意 象"; color: page.accent; font.family: "SimSun"; font.pixelSize: 14; topPadding: 8 }
                        Flow {
                            width: parent.width; spacing: 7
                            Repeater {
                                model: imagery.items.filter(function(item) { return item.key !== imagery.center && item.linkCount > 0 }).slice(0, 9)
                                delegate: Rectangle {
                                    required property var modelData
                                    width: relatedText.implicitWidth + 25; height: 33; radius: 6
                                    color: imagery.pair === modelData.key ? Theme.goldLight : Theme.paperAlt
                                    border.color: imagery.pair === modelData.key ? Theme.borderStrong : Theme.border
                                    Text { id: relatedText; anchors.centerIn: parent; text: modelData.key + "  " + modelData.linkCount; color: Theme.paperInk; font.family: "SimSun"; font.pixelSize: 12 }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: imagery.pair === modelData.key ? imagery.clearPair() : imagery.selectPair(modelData.key) }
                                }
                            }
                        }
                        Text {
                            width: parent.width; wrapMode: Text.Wrap
                            text: imagery.pair ? "「" + imagery.center + "」与「" + imagery.pair + "」同现于 " + imagery.pairCount + " 首诗。" : "选择相关意象，可追寻它们同现的诗句。"
                            color: Theme.paperMuted; font.family: "SimSun"; font.pixelSize: 12
                        }
                        Row {
                            spacing: 10
                            Rectangle {
                                width: 101; height: 34; radius: 6
                                color: Theme.goldLight
                                border.color: Theme.borderStrong
                                Text { anchors.centerIn: parent; text: "AI 解读  ↗"; color: Theme.paperGold; font.family: "SimSun"; font.pixelSize: 12 }
                                MouseArea { id: aiMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: page.openAi(imagery.center, imagery.description + (imagery.pair ? "\n关联意象：" + imagery.pair : "")) }
                            }
                            Text { anchors.verticalCenter: parent.verticalCenter; text: "相关诗词  /  " + imagery.poems.length; color: page.accent; font.family: "SimSun"; font.pixelSize: 14 }
                        }
                        Text { visible: imagery.error !== ""; width: parent.width; wrapMode: Text.Wrap; text: imagery.error; color: Theme.danger; font.pixelSize: 12 }
                    }
                }
                delegate: Rectangle {
                    id: poemCard
                    required property var modelData
                    width: noteList.width - 9
                    height: poemContent.implicitHeight + 24; radius: 8
                    color: poemMouse.containsMouse ? Theme.paperAlt : Theme.paper
                    border.color: poemMouse.containsMouse ? Theme.borderStrong : Theme.border
                    Behavior on color { ColorAnimation { duration: Theme.motion ? 170 : 0 } }
                    Column {
                        id: poemContent; x: 14; y: 12; width: parent.width - 28; spacing: 8
                        Text { width: parent.width; text: "《" + modelData.title + "》"; color: page.ink; font.family: "SimSun"; font.pixelSize: 18; wrapMode: Text.Wrap }
                        Text { text: modelData.dynasty + " · " + modelData.author; color: Theme.paperGold; font.family: "Microsoft YaHei UI"; font.pixelSize: 11 }
                        Text { width: parent.width; text: modelData.excerpt; textFormat: Text.RichText; wrapMode: Text.Wrap; color: Theme.paperInk; font.family: "SimSun"; font.pixelSize: 13; lineHeight: 1.42 }
                    }
                    MouseArea { id: poemMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: page.openPoem(modelData.id) }
                }
                footer: Text {
                    width: noteList.width; height: imagery.poems.length ? 35 : 74
                    text: imagery.poems.length ? "卷末  ·  点击诗卡阅览全文" : "当前条件下暂无关联诗词。"
                    color: Theme.paperMuted; font.family: "SimSun"; font.pixelSize: 12
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                }
            }
        }
    }
}
