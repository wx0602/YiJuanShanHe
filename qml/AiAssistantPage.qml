import QtQuick
import QtQuick.Controls
import YiJuanShanHe

Item {
    id: page
    objectName: "aiAssistantPage"

    property bool historyCollapsed: false
    property bool contextOpen: false
    property string pendingDelete: ""
    readonly property real outerMargin: 16
    readonly property real railWidth: historyCollapsed ? 54 : 184
    readonly property real drawerWidth: contextOpen ? Math.min(332, Math.max(268, width * .245)) : 0
    readonly property bool hasContext: !!(ai.context.label || (ai.context.poems && ai.context.poems.length))
    readonly property bool welcome: ai.messages.length === 0 && !ai.busy
    readonly property color panel: Theme.light ? "#EAF8F3E9" : "#E81A3B40"
    readonly property color panelStrong: Theme.light ? "#F4FFFCF6" : "#F21B3E43"
    readonly property color panelSoft: Theme.light ? "#DDF2EBDD" : "#DD25494D"
    readonly property var modes: [
        {key:"chat", mark:"问", title:"自由问答", note:"谈诗人、意象与山河掌故", prompt:"王维诗中的空山意境为何如此动人？"},
        {key:"analysis", mark:"赏", title:"诗词鉴赏", note:"从意境、情感与修辞细读", prompt:""},
        {key:"recommend", mark:"寻", title:"寻诗推荐", note:"说出心境，为你从诗海寻篇", prompt:"想读一首适合秋夜独行的诗。"},
        {key:"compare", mark:"照", title:"双诗对照", note:"并读两卷，辨情思与意象", prompt:""}
    ]
    readonly property var promptSeeds: [
        "为什么古诗常借月亮表达思念？",
        "推荐几首写雨后山林的诗词",
        "苏轼词中的旷达是怎样形成的？"
    ]

    function sendCurrent() {
        const content = composer.text
        if (ai.send(content)) composer.text = ""
    }
    function modeTitle(mode) {
        return mode === "analysis" ? "诗词鉴赏" : mode === "recommend" ? "寻诗推荐"
             : mode === "compare" ? "双诗对照" : "自由问答"
    }
    function contextHint() {
        if (ai.mode === "analysis") return hasContext ? "围绕随卷诗笺，写下想细读的角度" : "请先从随卷诗笺选择一首诗词"
        if (ai.mode === "compare") return "选择两首诗词，再写下希望比较的角度"
        if (ai.mode === "recommend") return "描述此刻的心境、风景，或想读的诗"
        return "写下你关于诗词、诗人、意象或历史的问题"
    }
    function sessionGroup(dateText) {
        const today = Qt.formatDate(new Date(), "yyyy-MM-dd")
        const day = new Date(); day.setDate(day.getDate() - 1)
        const yesterday = Qt.formatDate(day, "yyyy-MM-dd")
        return dateText === today ? "今天" : dateText === yesterday ? "昨天" : "更早"
    }
    function chooseMode(key, prompt) {
        if (ai.mode !== key || ai.sessionId === "") ai.newChat(key)
        if (key === "analysis" || key === "compare") contextOpen = true
        if (prompt) composer.text = prompt
        Qt.callLater(function() { composer.forceActiveFocus() })
    }

    Connections {
        target: ai
        function onMessagesChanged() { Qt.callLater(function() { conversationList.positionViewAtEnd() }) }
        function onLiveChanged() { Qt.callLater(function() { conversationList.positionViewAtEnd() }) }
        function onContextChanged() { if (page.hasContext) page.contextOpen = true }
    }
    Component.onCompleted: if (hasContext) contextOpen = true

    Rectangle { anchors.fill: parent; color: Theme.background }

    Rectangle {
        id: historyRail
        x: page.outerMargin; y: 14; width: page.railWidth; height: parent.height - 28
        radius: 12; color: page.panel; border.color: Theme.borderStrong; clip: true
        Behavior on width { NumberAnimation { duration: Theme.motion ? 290 : 0; easing.type: Easing.OutCubic } }
        Rectangle {
            x: 10; y: 10; width: 34; height: 34; radius: 17
            color: collapseMouse.containsMouse ? Theme.hover : Theme.cardAlt; border.color: Theme.border
            Text { anchors.centerIn: parent; text: page.historyCollapsed ? "卷" : "收"; color: Theme.gold; font.family: "SimSun"; font.pixelSize: 13 }
            MouseArea { id: collapseMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: page.historyCollapsed = !page.historyCollapsed }
        }
        Text { x: 55; y: 12; visible: !page.historyCollapsed; text: "问墨旧卷"; color: Theme.text; font.family: "SimSun"; font.pixelSize: 19 }
        Text { x: 56; y: 36; visible: !page.historyCollapsed; text: "SESSIONS"; color: Theme.gold; font.family: "Georgia"; font.pixelSize: 9; font.letterSpacing: 1.4 }
        Rectangle {
            x: 10; y: 58; width: parent.width - 20; height: 38; radius: 7
            color: newMouse.containsMouse ? Theme.accentHover : Theme.accent; border.color: Theme.borderStrong
            Text { anchors.centerIn: parent; text: page.historyCollapsed ? "＋" : "＋  新卷"; color: Theme.accentText; font.family: "SimSun"; font.pixelSize: 13 }
            MouseArea { id: newMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: ai.newChat("chat") }
        }
        Rectangle { x: 12; y: 108; width: parent.width - 24; height: 1; color: Theme.line; visible: !page.historyCollapsed }
        ListView {
            id: sessionList
            x: 7; y: 120; width: parent.width - 14; height: parent.height - 177
            visible: !page.historyCollapsed; clip: true; spacing: 4; model: ai.sessions
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded; contentItem: Rectangle { implicitWidth: 3; radius: 2; color: Theme.borderStrong } }
            delegate: Item {
                id: sessionRow
                required property var modelData
                required property int index
                readonly property string groupName: page.sessionGroup(modelData.date)
                readonly property bool firstInGroup: index === 0 || page.sessionGroup(ai.sessions[index - 1].date) !== groupName
                width: sessionList.width - 4; height: (firstInGroup ? 22 : 0) + 58
                Text { x: 8; y: 1; visible: sessionRow.firstInGroup; text: sessionRow.groupName; color: Theme.gold; font.family: "SimSun"; font.pixelSize: 10 }
                Rectangle {
                    id: sessionCard
                    x: 0; y: sessionRow.firstInGroup ? 20 : 0; width: parent.width; height: 56; radius: 7
                    color: ai.sessionId === sessionRow.modelData.id ? Theme.selected : (sessionMouse.containsMouse ? Theme.hover : "transparent")
                    border.color: ai.sessionId === sessionRow.modelData.id ? Theme.borderStrong : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.motion ? 150 : 0 } }
                    Rectangle { x: 8; y: 10; width: 3; height: 35; radius: 2; color: ai.sessionId === sessionRow.modelData.id ? Theme.gold : Theme.line }
                    Text { x: 18; y: 8; width: parent.width - 40; text: sessionRow.modelData.title || "未题名"; color: Theme.text; font.family: "SimSun"; font.pixelSize: 12; elide: Text.ElideRight }
                    Text { x: 18; y: 34; text: page.modeTitle(sessionRow.modelData.mode); color: Theme.secondary; font.pixelSize: 9 }
                    Text { anchors.right: parent.right; anchors.rightMargin: 9; y: 30; text: "×"; color: Theme.danger; font.pixelSize: 15
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { page.pendingDelete = sessionRow.modelData.id; deletePopup.open() } } }
                    MouseArea { id: sessionMouse; x: 0; y: 0; width: parent.width; height: 29; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: ai.selectSession(sessionRow.modelData.id) }
                }
            }
            Text { anchors.centerIn: parent; visible: parent.count === 0; text: "尚无旧卷"; color: Theme.secondary; font.family: "SimSun"; font.pixelSize: 12 }
        }
        Text { x: 13; y: parent.height - 45; width: parent.width - 26; visible: !page.historyCollapsed; text: "会话仅保存在本机"; color: Theme.secondary; font.pixelSize: 9; horizontalAlignment: Text.AlignHCenter }
    }

    Rectangle {
        id: study
        x: historyRail.x + historyRail.width + 12; y: 14
        width: parent.width - x - page.outerMargin - page.drawerWidth - (page.contextOpen ? 12 : 0)
        height: parent.height - 28; radius: 13; color: page.panelStrong; border.color: Theme.borderStrong; clip: true
        Behavior on x { NumberAnimation { duration: Theme.motion ? 290 : 0; easing.type: Easing.OutCubic } }
        Behavior on width { NumberAnimation { duration: Theme.motion ? 320 : 0; easing.type: Easing.OutCubic } }
        Image {
            anchors.fill: parent
            source: Theme.light ? "qrc:/picture/ai_bg2.jpg" : "qrc:/picture/ai_bg1.jpg"
            fillMode: Image.PreserveAspectCrop
            horizontalAlignment: Image.AlignHCenter
            verticalAlignment: Image.AlignVCenter
            asynchronous: true
            smooth: true
        }
        Rectangle {
            anchors.fill: parent
            color: Theme.light ? "#A8FFFCF5" : "#B51A3B40"
            Behavior on color { ColorAnimation { duration: Theme.motion ? 330 : 0 } }
        }
        Rectangle { x: 0; y: 0; width: parent.width; height: 73; color: Theme.light ? "#E8F8F2E6" : "#D91A3B40" }
        Rectangle { x: 0; y: 72; width: parent.width; height: 1; color: Theme.line }
        Text { x: 22; y: 14; text: "诗 心 问 墨"; color: Theme.text; font.family: "SimSun"; font.pixelSize: 23; font.letterSpacing: 2 }
        Text { x: 24; y: 45; text: "AI POETRY STUDY  /  " + page.modeTitle(ai.mode); color: Theme.gold; font.family: "Georgia"; font.pixelSize: 9; font.letterSpacing: 1.2 }
        Row {
            id: compactModes; anchors.right: contextButton.left; anchors.rightMargin: 8; y: 18; spacing: 4
            Repeater {
                model: page.modes
                delegate: Rectangle {
                    id: modeChip
                    required property var modelData
                    width: study.width < 720 ? 38 : 64; height: 34; radius: 7
                    color: ai.mode === modelData.key ? Theme.selected : (modeMouse.containsMouse ? Theme.hover : "transparent")
                    border.color: ai.mode === modelData.key ? Theme.borderStrong : Theme.border
                    Text { anchors.centerIn: parent; text: study.width < 720 ? modeChip.modelData.mark : modeChip.modelData.title; color: Theme.text; font.family: "SimSun"; font.pixelSize: 11 }
                    MouseArea { id: modeMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: page.chooseMode(modeChip.modelData.key, "") }
                }
            }
        }
        Rectangle {
            id: contextButton
            anchors.right: parent.right; anchors.rightMargin: 16; y: 18; width: 92; height: 34; radius: 7
            color: page.contextOpen ? Theme.selected : (contextMouse.containsMouse ? Theme.hover : Theme.surface)
            border.color: page.contextOpen ? Theme.borderStrong : Theme.border
            Text { anchors.centerIn: parent; text: "随卷诗笺  " + (page.contextOpen ? "›" : "‹"); color: Theme.text; font.family: "SimSun"; font.pixelSize: 11 }
            MouseArea { id: contextMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: page.contextOpen = !page.contextOpen }
        }
        Rectangle {
            id: contextTag
            x: 22; y: 82; width: Math.min(parent.width - 44, contextLabel.implicitWidth + 66); height: 31; radius: 16
            visible: page.hasContext; color: Theme.light ? "#F1E4CC" : "#35595B"; border.color: Theme.borderStrong
            Text { x: 13; anchors.verticalCenter: parent.verticalCenter; text: "随卷"; color: Theme.gold; font.family: "SimSun"; font.pixelSize: 10 }
            Text { id: contextLabel; x: 46; anchors.verticalCenter: parent.verticalCenter; text: ai.context.label || "已携带诗词上下文"; color: Theme.text; font.family: "SimSun"; font.pixelSize: 11; elide: Text.ElideRight; width: Math.min(360, implicitWidth) }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: page.contextOpen = true }
        }

        Item {
            id: conversationArea
            x: 0; y: page.hasContext ? 122 : 76; width: parent.width; height: parent.height - y - 101
            Behavior on y { NumberAnimation { duration: Theme.motion ? 210 : 0 } }
            Flickable {
                id: welcomeView
                anchors.fill: parent; visible: page.welcome; contentWidth: width; contentHeight: welcomeColumn.implicitHeight + 48
                clip: true; boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                Column {
                    id: welcomeColumn
                    x: Math.max(24, (welcomeView.width - width) / 2); width: Math.min(850, welcomeView.width - 48); spacing: 16
                    Item { width: 1; height: 18 }
                    Text { width: parent.width; text: "入座，且与诗心相问"; color: Theme.text; font.family: "SimSun"; font.pixelSize: 31; horizontalAlignment: Text.AlignHCenter }
                    Text { width: parent.width; text: "一卷可赏，一念可寻。问墨会结合你的问题与随卷诗笺作答。"; color: Theme.secondary; font.pixelSize: 12; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap }
                    Item { width: 1; height: 3 }
                    Grid {
                        id: modeGrid; width: parent.width; columns: 2; columnSpacing: 10; rowSpacing: 10
                        Repeater {
                            model: page.modes
                            delegate: Rectangle {
                                id: modeCard
                                required property var modelData
                                width: (modeGrid.width - 10) / 2; height: 112; radius: 10
                                color: modeCardMouse.containsMouse ? Theme.hover : page.panelSoft
                                border.color: ai.mode === modelData.key ? Theme.borderStrong : Theme.border
                                scale: modeCardMouse.containsMouse && Theme.motion ? 1.012 : 1
                                Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                                Rectangle { x: 16; y: 17; width: 43; height: 43; radius: 22; color: Theme.light ? "#F0E1C2" : "#365B5B"; border.color: Theme.borderStrong
                                    Text { anchors.centerIn: parent; text: modeCard.modelData.mark; color: Theme.gold; font.family: "SimSun"; font.pixelSize: 21 } }
                                Text { x: 73; y: 19; text: modeCard.modelData.title; color: Theme.text; font.family: "SimSun"; font.pixelSize: 18 }
                                Text { x: 73; y: 48; width: parent.width - 90; text: modeCard.modelData.note; color: Theme.secondary; font.pixelSize: 11; wrapMode: Text.Wrap }
                                Text { x: 17; y: 87; text: "展开此卷  →"; color: Theme.gold; font.family: "SimSun"; font.pixelSize: 11 }
                                MouseArea { id: modeCardMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: page.chooseMode(modeCard.modelData.key, modeCard.modelData.prompt) }
                            }
                        }
                    }
                    Text { text: "可从这些问题起笔"; color: Theme.gold; font.family: "SimSun"; font.pixelSize: 12; topPadding: 2 }
                    Flow {
                        width: parent.width; spacing: 7
                        Repeater {
                            model: page.promptSeeds
                            delegate: Rectangle {
                                id: seed
                                required property string modelData
                                width: seedText.implicitWidth + 26; height: 31; radius: 16
                                color: seedMouse.containsMouse ? Theme.hover : Theme.surface; border.color: Theme.border
                                Text { id: seedText; anchors.centerIn: parent; text: seed.modelData; color: Theme.text; font.family: "SimSun"; font.pixelSize: 10 }
                                MouseArea { id: seedMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { composer.text = seed.modelData; composer.forceActiveFocus() } }
                            }
                        }
                    }
                }
                NumberAnimation on opacity { from: 0; to: 1; duration: Theme.motion ? 420 : 0; running: visible }
            }

            ListView {
                id: conversationList
                anchors.fill: parent; visible: !page.welcome; model: ai.messages; clip: true; spacing: 13
                boundsBehavior: Flickable.StopAtBounds; topMargin: 12; bottomMargin: 12
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded; contentItem: Rectangle { implicitWidth: 4; radius: 2; color: Theme.borderStrong } }
                delegate: Item {
                    id: messageRow
                    required property var modelData
                    required property int index
                    width: conversationList.width; height: bubble.height + 4
                    readonly property bool fromUser: modelData.role === "user"
                    readonly property real readingWidth: Math.min(820, parent.width - 44)
                    Rectangle {
                        id: bubble
                        x: (parent.width - messageRow.readingWidth) / 2 + (messageRow.fromUser ? messageRow.readingWidth - width : 0)
                        width: messageRow.fromUser ? Math.min(messageRow.readingWidth * .72, Math.max(230, messageText.implicitWidth + 34)) : messageRow.readingWidth
                        height: messageText.implicitHeight + (messageRow.fromUser ? 38 : 61); radius: 9
                        color: messageRow.fromUser ? Theme.selected : page.panelSoft
                        border.color: messageRow.fromUser ? Theme.borderStrong : Theme.border
                        Text { x: 15; y: 11; text: messageRow.fromUser ? "你  ·  " + messageRow.modelData.time : "问墨  /  AI"; color: Theme.gold; font.family: "SimSun"; font.pixelSize: 10 }
                        Text { id: messageText; x: 16; y: 32; width: bubble.width - 32; text: messageRow.modelData.content; textFormat: messageRow.fromUser ? Text.PlainText : Text.MarkdownText; wrapMode: Text.Wrap; color: Theme.text; font.pixelSize: 13; lineHeight: 1.55 }
                        Row {
                            x: 15; y: bubble.height - 23; spacing: 15; visible: !messageRow.fromUser
                            Text { text: "复制"; color: Theme.secondary; font.pixelSize: 10
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: ai.copyText(messageRow.modelData.content) } }
                            Text { visible: messageRow.index === ai.messages.length - 1; text: "重新生成"; color: Theme.gold; font.pixelSize: 10
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: ai.regenerate() } }
                            Text { visible: messageRow.index === ai.messages.length - 1; text: "继续生成"; color: Theme.gold; font.pixelSize: 10
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: ai.continueAnswer() } }
                        }
                        NumberAnimation on opacity { from: 0; to: 1; duration: Theme.motion ? 280 : 0; running: messageRow.visible }
                    }
                }
                footer: Item {
                    width: conversationList.width; height: ai.busy ? liveBubble.height + 12 : 5
                    Rectangle {
                        id: liveBubble
                        x: (parent.width - width) / 2; width: Math.min(820, parent.width - 44); height: Math.max(82, liveContent.implicitHeight + 54)
                        visible: ai.busy; radius: 9; color: page.panelSoft; border.color: Theme.borderStrong
                        Text { x: 16; y: 11; text: "问墨正在落笔  · · ·"; color: Theme.gold; font.family: "SimSun"; font.pixelSize: 11 }
                        Text { id: liveContent; x: 16; y: 33; width: parent.width - 32; text: ai.liveText || "正在整理诗意，请稍候。"; textFormat: Text.MarkdownText; wrapMode: Text.Wrap; color: Theme.text; font.pixelSize: 13; lineHeight: 1.55 }
                    }
                }
            }
        }
        Text { x: Math.max(22, (parent.width - width) / 2); y: parent.height - 96; width: Math.min(860, parent.width - 44); height: 17; text: ai.errorMessage || ai.statusMessage; color: ai.errorMessage ? Theme.danger : Theme.gold; font.pixelSize: 10; elide: Text.ElideRight }
        Rectangle {
            id: composerFrame
            x: Math.max(20, (parent.width - width) / 2); y: parent.height - 76; width: Math.min(860, parent.width - 40); height: 58; radius: 9
            color: page.panelStrong; border.color: composer.activeFocus ? Theme.borderStrong : Theme.border
            TextArea {
                id: composer; x: 11; y: 4; width: parent.width - 118; height: parent.height - 8
                placeholderText: page.contextHint(); placeholderTextColor: Theme.subtle; wrapMode: TextArea.Wrap; color: Theme.text; font.pixelSize: 13; background: Item {}
                Keys.onPressed: function(event) { if (event.key === Qt.Key_Return && (event.modifiers & Qt.ControlModifier)) { page.sendCurrent(); event.accepted = true } }
            }
            Rectangle {
                anchors.right: parent.right; anchors.rightMargin: 7; y: 8; width: 91; height: 42; radius: 7
                color: sendMouse.containsMouse ? Theme.accentHover : Theme.accent; border.color: Theme.borderStrong
                Text { anchors.centerIn: parent; text: ai.busy ? "停止生成" : "发送  ↗"; color: Theme.accentText; font.family: "SimSun"; font.pixelSize: 12 }
                MouseArea { id: sendMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: ai.busy ? ai.cancel() : page.sendCurrent() }
            }
        }
    }

    Rectangle {
        id: contextDrawer
        x: parent.width - page.outerMargin - width; y: 14; width: page.drawerWidth; height: parent.height - 28; radius: 12
        visible: width > 1; opacity: page.contextOpen ? 1 : 0; color: page.panel; border.color: Theme.borderStrong; clip: true
        Behavior on width { NumberAnimation { duration: Theme.motion ? 320 : 0; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: Theme.motion ? 220 : 0 } }
        Text { x: 19; y: 16; text: "随 卷 诗 笺"; color: Theme.text; font.family: "SimSun"; font.pixelSize: 19; font.letterSpacing: 1.5 }
        Text { x: 20; y: 45; text: "LOCAL POETRY CONTEXT"; color: Theme.gold; font.family: "Georgia"; font.pixelSize: 9; font.letterSpacing: 1 }
        Text { anchors.right: parent.right; anchors.rightMargin: 17; y: 18; text: "×"; color: Theme.text; font.pixelSize: 20
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: page.contextOpen = false } }
        Rectangle { x: 17; y: 70; width: parent.width - 34; height: 1; color: Theme.line }
        Text { x: 18; y: 84; text: ai.mode === "compare" ? "择两卷并读" : "从本地诗海择一卷"; color: Theme.secondary; font.family: "SimSun"; font.pixelSize: 11 }
        Rectangle {
            x: 16; y: 107; width: parent.width - 32; height: 37; radius: 7; color: Theme.field; border.color: poemSearch.activeFocus ? Theme.borderStrong : Theme.border
            Text { x: 10; anchors.verticalCenter: parent.verticalCenter; text: "⌕"; color: Theme.gold; font.pixelSize: 17 }
            TextField { id: poemSearch; x: 34; y: 0; width: parent.width - 42; height: parent.height; placeholderText: "检索篇名或作者"; placeholderTextColor: Theme.subtle; color: Theme.text; font.pixelSize: 11; background: Item {} onTextChanged: poemSearchDelay.restart() }
            Timer { id: poemSearchDelay; interval: 220; onTriggered: ai.searchPoems(poemSearch.text) }
        }
        ListView {
            id: poemList; x: 13; y: 153; width: parent.width - 26; height: Math.min(205, parent.height * .29)
            clip: true; spacing: 5; model: ai.poemChoices; boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded; contentItem: Rectangle { implicitWidth: 3; radius: 2; color: Theme.borderStrong } }
            delegate: Rectangle {
                id: choice
                required property var modelData
                width: poemList.width - 4; height: 46; radius: 6; color: choiceMouse.containsMouse ? Theme.hover : page.panelSoft; border.color: Theme.border
                Text { x: 10; y: 6; width: parent.width - 20; text: modelData.title; color: Theme.text; font.family: "SimSun"; font.pixelSize: 12; elide: Text.ElideRight }
                Text { x: 10; y: 28; text: modelData.dynasty + " · " + modelData.author; color: Theme.secondary; font.pixelSize: 9 }
                MouseArea { id: choiceMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: ai.mode === "compare" ? ai.addComparePoem(choice.modelData.id) : ai.usePoem(choice.modelData.id) }
            }
        }
        Rectangle { x: 17; y: poemList.y + poemList.height + 12; width: parent.width - 34; height: 1; color: Theme.line }
        Text { x: 18; y: poemList.y + poemList.height + 25; text: "此 刻 所 读"; color: Theme.gold; font.family: "SimSun"; font.pixelSize: 12 }
        Flickable {
            x: 15; y: poemList.y + poemList.height + 51; width: parent.width - 30; height: parent.height - y - 17
            clip: true; contentWidth: width; contentHeight: contextColumn.implicitHeight + 12; boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded; contentItem: Rectangle { implicitWidth: 3; radius: 2; color: Theme.borderStrong } }
            Column {
                id: contextColumn; width: parent.width; spacing: 9
                Text { visible: !(ai.context.poems && ai.context.poems.length) && !ai.context.description; width: parent.width; text: "尚未夹入诗笺。选择诗词后，问墨会连同原文一起阅读。"; color: Theme.secondary; font.family: "SimSun"; font.pixelSize: 11; wrapMode: Text.Wrap; lineHeight: 1.5 }
                Text { visible: !!ai.context.description; width: parent.width; text: ai.context.label || "随卷资料"; color: Theme.text; font.family: "SimSun"; font.pixelSize: 17; wrapMode: Text.Wrap }
                Text { visible: !!ai.context.description; width: parent.width; text: ai.context.description || ""; color: Theme.secondary; font.pixelSize: 11; wrapMode: Text.Wrap; lineHeight: 1.5 }
                Repeater {
                    model: ai.context.poems || []
                    delegate: Rectangle {
                        required property var modelData
                        width: contextColumn.width; height: poemContext.implicitHeight + 24; radius: 8
                        color: Theme.light ? "#F8F1E4" : "#294E50"; border.color: Theme.borderStrong
                        Column {
                            id: poemContext; x: 12; y: 11; width: parent.width - 24; spacing: 7
                            Text { width: parent.width; text: "《" + modelData.title + "》"; color: Theme.text; font.family: "SimSun"; font.pixelSize: 16; wrapMode: Text.Wrap }
                            Text { text: modelData.dynasty + " · " + modelData.author; color: Theme.gold; font.pixelSize: 10 }
                            Rectangle { width: parent.width; height: 1; color: Theme.line }
                            Text { width: parent.width; text: modelData.content; color: Theme.text; font.family: "SimSun"; font.pixelSize: 12; lineHeight: 1.5; wrapMode: Text.Wrap }
                        }
                    }
                }
            }
        }
    }

    Popup {
        id: deletePopup
        anchors.centerIn: Overlay.overlay; width: 318; height: 164; modal: true; focus: true
        background: Rectangle { radius: 11; color: page.panelStrong; border.color: Theme.borderStrong }
        contentItem: Item {
            Text { x: 21; y: 19; text: "删除这卷对话？"; color: Theme.text; font.family: "SimSun"; font.pixelSize: 20 }
            Text { x: 22; y: 55; width: parent.width - 44; text: "对话内容会从本机永久删除。"; color: Theme.secondary; font.pixelSize: 11; wrapMode: Text.Wrap }
            Row {
                anchors.right: parent.right; anchors.rightMargin: 20; y: 103; spacing: 8
                Rectangle { width: 80; height: 35; radius: 6; color: Theme.surface; border.color: Theme.border
                    Text { anchors.centerIn: parent; text: "取消"; color: Theme.text; font.pixelSize: 12 }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: deletePopup.close() } }
                Rectangle { width: 88; height: 35; radius: 6; color: Theme.danger
                    Text { anchors.centerIn: parent; text: "确认删除"; color: "#FFF9F1"; font.pixelSize: 12 }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { ai.deleteSession(page.pendingDelete); page.pendingDelete = ""; deletePopup.close() } } }
            }
        }
    }
}
