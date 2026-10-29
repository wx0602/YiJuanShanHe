import QtQuick
import QtQuick.Controls
import YiJuanShanHe

Item {
    id: stage
    property int turnNumber: interaction.questionNumber
    readonly property bool answering: interaction.phase === "asking"
    readonly property bool correct: interaction.roundResults.length > 0 && interaction.roundResults[interaction.roundResults.length-1].correct
    onTurnNumberChanged: verseInput.text = ""
    onVisibleChanged: if (visible && answering) Qt.callLater(function() { verseInput.forceActiveFocus() })
    Rectangle { anchors.fill: parent; radius: 13; color: Theme.light ? "#F5EFE3" : "#1B3C41" }
    Image {
        anchors.fill: parent
        source: Theme.light ? "qrc:/picture/feihua_bg2.jpg" : "qrc:/picture/feihua_bg1.jpg"
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        smooth: true
    }
    Rectangle {
        anchors.fill: parent; radius: 13
        color: Theme.light ? "#99F8F2E7" : "#BA123439"
        border.color: Theme.borderStrong
        Behavior on color { ColorAnimation { duration: Theme.motion ? 260 : 0 } }
    }
    Rectangle {
        anchors.centerIn: commandSeal; width: commandSeal.width + 42; height: width; radius: width/2
        color: "transparent"; border.color: Theme.gold; opacity: correct && !answering ? .46 : .13
        Behavior on opacity { NumberAnimation { duration: Theme.motion ? 300 : 0 } }
    }
    Rectangle {
        id: commandSeal
        anchors.horizontalCenter: parent.horizontalCenter; y: 26
        width: Math.min(132, parent.height*.29); height: width; radius: width/2
        color: Theme.light ? "#EBDDBF" : "#31575A"; border.color: Theme.borderStrong; border.width: 2
        scale: correct && !answering ? 1.045 : 1
        Behavior on scale { NumberAnimation { duration: Theme.motion ? 270 : 0; easing.type: Easing.OutCubic } }
        Text { anchors.centerIn: parent; text: interaction.question.command || "令"; color: Theme.gold; font.family: "SimSun"; font.pixelSize: Math.min(65, parent.width*.52) }
    }
    Text {
        anchors.horizontalCenter: parent.horizontalCenter; y: commandSeal.y + commandSeal.height + 15
        text: "以 字 为 令   ·   一 句 相 和"; color: Theme.gold; font.family: "SimSun"; font.pixelSize: 13
    }
    Text {
        x: 24; y: commandSeal.y + commandSeal.height + 41; width: parent.width-48
        text: interaction.question.subtitle || ""
        color: Theme.secondary; font.family: "Microsoft YaHei UI"; font.pixelSize: 12
        horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap
    }
    Rectangle {
        x: 24; y: parent.height*.48; width: parent.width-48; height: 1; color: Theme.line
    }
    Text {
        x: 31; y: parent.height*.505
        text: interaction.question.computerLine ? "对方先行" : "轮到你了"
        color: Theme.gold; font.family: "SimSun"; font.pixelSize: 12
    }
    Text {
        x: 31; y: parent.height*.57; width: parent.width-62
        text: interaction.question.computerLine || "请接出符合令字的诗句"
        color: Theme.text; font.family: "SimSun"; font.pixelSize: Math.min(22, Math.max(17,parent.width*.022))
        wrapMode: Text.Wrap; horizontalAlignment: Text.AlignHCenter
    }
    Text {
        anchors.right: parent.right; anchors.rightMargin: 30; y: parent.height*.69
        text: interaction.question.computerSource || "已用 " + (interaction.question.usedCount || 0) + " 句"
        color: Theme.secondary; font.family: "Microsoft YaHei UI"; font.pixelSize: 11
    }
    Rectangle {
        x: 26; y: parent.height-65; width: parent.width-52; height: 44; radius: 7
        visible: stage.answering
        color: Theme.field; border.color: verseInput.activeFocus ? Theme.borderStrong : Theme.border
        TextField {
            id: verseInput; anchors.fill: parent; anchors.leftMargin: 13; anchors.rightMargin: 12
            placeholderText: "写下一句含令字的诗，按 Enter 交卷"; placeholderTextColor: Theme.subtle
            color: Theme.text; font.family: "SimSun"; font.pixelSize: 17
            background: Item {}
            onAccepted: interaction.submit(text)
        }
    }
    Rectangle {
        x: 26; y: parent.height-78; width: parent.width-52; height: 60; radius: 7
        visible: !stage.answering
        color: stage.correct ? (Theme.light ? "#ECE2C9" : "#365850") : (Theme.light ? "#EFE8DE" : "#315056")
        border.color: Theme.borderStrong
        Text { x: 14; y: 7; width: parent.width-28; text: interaction.feedback; color: Theme.text; font.family: "SimSun"; font.pixelSize: 15; wrapMode: Text.Wrap }
        Text { x: 14; y: 34; width: parent.width-28; text: (stage.correct ? "本回合接句  ·  " : "参考诗句  ·  ") + interaction.correctAnswer; color: Theme.gold; font.family: "SimSun"; font.pixelSize: 12; elide: Text.ElideRight }
    }
    Rectangle {
        id: successStamp
        anchors.right: parent.right; anchors.rightMargin: 48; y: 20
        width: 59; height: 59; radius: 30; rotation: -13
        visible: !stage.answering && stage.correct
        color: "transparent"; border.color: Theme.gold; border.width: 2
        Text { anchors.centerIn: parent; text: interaction.streak >= 3 ? "连珠" : "令成"; color: Theme.gold; font.family: "SimSun"; font.pixelSize: 17 }
        NumberAnimation on scale { from: 1.6; to: 1; duration: Theme.motion ? 430 : 0; easing.type: Easing.OutBack; running: successStamp.visible }
    }
    function submitCurrent() { interaction.submit(verseInput.text) }
}
