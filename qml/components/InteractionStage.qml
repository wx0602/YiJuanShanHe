import QtQuick
import YiJuanShanHe

Item {
    id: stage
    signal back()
    signal advanceRequested()
    readonly property string mode: interaction.question.mode || interaction.mode
    readonly property string title: mode === "feihua" ? "飞花令  ·  诗会擂台"
                                   : mode === "chain" ? "诗词接龙  ·  展卷续诗" : "残卷修复  ·  诗句归位"
    readonly property bool answering: interaction.phase === "asking"
    Rectangle { anchors.fill: parent; color: Theme.background }
    Rectangle {
        x: 24; y: 20; width: parent.width-48; height: 82; radius: 11
        color: Theme.light ? "#EEE3D0" : "#214348"; border.color: Theme.border
        Rectangle {
            x: 12; y: 15; width: 113; height: 38; radius: 6
            color: backMouse.containsMouse ? Theme.hover : Theme.surface; border.color: Theme.border
            Text { anchors.centerIn: parent; text: "←  返回雅集"; color: Theme.text; font.family: "SimSun"; font.pixelSize: 13 }
            MouseArea { id: backMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: stage.back() }
        }
        Text { x: 141; y: 13; width: parent.width-405; text: stage.title; color: Theme.text; font.family: "SimSun"; font.pixelSize: 23; elide: Text.ElideRight }
        Text { x: 144; y: 50; text: "第 " + interaction.questionNumber + " / " + interaction.questionCount + " 题"; color: Theme.gold; font.family: "Georgia"; font.pixelSize: 12 }
        Text {
            anchors.right: parent.right; anchors.rightMargin: 19; y: 15
            text: interaction.score + " 分" + (interaction.streak > 1 ? "  ·  连对 " + interaction.streak : "")
            color: Theme.gold; font.family: "Georgia"; font.pixelSize: 18
        }
        Text {
            anchors.right: parent.right; anchors.rightMargin: 20; y: 52
            text: stage.mode === "feihua" && stage.answering ? "沙漏  " + interaction.timeLeft + " 秒" : "以诗相和"
            color: stage.mode === "feihua" && interaction.timeLeft <= 5 ? Theme.danger : Theme.secondary
            font.family: "SimSun"; font.pixelSize: 12
        }
        Rectangle { x: 142; y: 75; width: parent.width-161; height: 2; radius: 1; color: Theme.line }
        Rectangle {
            x: 142; y: 75; height: 2; radius: 1
            width: (parent.width-161)*interaction.questionNumber/Math.max(1,interaction.questionCount)
            color: Theme.gold
            Behavior on width { NumberAnimation { duration: Theme.motion ? 350 : 0; easing.type: Easing.OutCubic } }
        }
    }
    Item {
        id: arena
        x: 24; y: 115; width: parent.width-48; height: parent.height-204
        FeihuaStage { id: feihua; anchors.fill: parent; visible: stage.mode === "feihua" }
        ChainStage { id: chain; anchors.fill: parent; visible: stage.mode === "chain" }
        PuzzleStage { id: puzzle; anchors.fill: parent; visible: stage.mode === "puzzle" }
    }
    Text {
        x: 31; y: parent.height-83; width: parent.width-62
        text: interaction.errorMessage || interaction.statusMessage || interaction.hintText
        color: interaction.errorMessage ? Theme.danger : Theme.gold
        font.family: "Microsoft YaHei UI"; font.pixelSize: 11
        elide: Text.ElideRight
    }
    Row {
        x: 25; y: parent.height-59; spacing: 9
        visible: stage.answering
        Repeater {
            model: [{label:"交卷评判", action:"submit", wide:true}, {label:"提示", action:"hint"},
                    {label:"跳过", action:"skip"}, {label:"看答案", action:"reveal"}]
            delegate: Rectangle {
                id: control
                required property var modelData
                width: modelData.wide ? 145 : 92; height: 41; radius: 7
                color: modelData.wide ? (buttonMouse.containsMouse ? Theme.accentHover : Theme.accent)
                                     : (buttonMouse.containsMouse ? Theme.hover : Theme.surface)
                border.color: modelData.wide ? Theme.borderStrong : Theme.border
                Text { anchors.centerIn: parent; text: modelData.label; color: modelData.wide ? Theme.accentText : Theme.text; font.family: "SimSun"; font.pixelSize: 14 }
                MouseArea {
                    id: buttonMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (control.modelData.action === "submit") {
                            if (stage.mode === "feihua") feihua.submitCurrent()
                            else if (stage.mode === "chain") chain.submitCurrent()
                            else puzzle.submitCurrent()
                        } else if (control.modelData.action === "hint") interaction.hint()
                        else if (control.modelData.action === "skip") interaction.skip()
                        else interaction.showAnswer()
                    }
                }
            }
        }
    }
    Rectangle {
        x: 25; y: parent.height-59; width: 242; height: 41; radius: 7
        visible: !stage.answering
        color: nextMouse.containsMouse ? Theme.accentHover : Theme.accent
        border.color: Theme.borderStrong
        Text { anchors.centerIn: parent; text: interaction.questionNumber === interaction.questionCount ? "查看本轮成绩  →" : "续下一题  →"; color: Theme.accentText; font.family: "SimSun"; font.pixelSize: 15 }
        MouseArea { id: nextMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: stage.advanceRequested() }
    }
    Text {
        x: 289; y: parent.height-48; visible: !stage.answering
        text: interaction.correctCount + " 题已答对  ·  " + (interaction.questionCount-interaction.questionNumber) + " 题未开始"
        color: Theme.secondary; font.family: "Microsoft YaHei UI"; font.pixelSize: 11
    }
}
