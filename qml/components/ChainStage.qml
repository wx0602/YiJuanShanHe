import QtQuick
import QtQuick.Controls
import YiJuanShanHe

Item {
    id: stage
    property int turnNumber: interaction.questionNumber
    readonly property bool answering: interaction.phase === "asking"
    readonly property bool correct: interaction.roundResults.length > 0 && interaction.roundResults[interaction.roundResults.length-1].correct
    onTurnNumberChanged: nextLine.text = ""
    onVisibleChanged: if (visible && answering) Qt.callLater(function() { nextLine.forceActiveFocus() })
    Rectangle { anchors.fill: parent; radius: 12; color: Theme.light ? "#E9DFCB" : "#214247" }
    Image {
        anchors.fill: parent
        source: Theme.light ? "qrc:/picture/jielong_bg2.jpg" : "qrc:/picture/jielong_bg1.jpg"
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        smooth: true
    }
    Rectangle {
        anchors.fill: parent; radius: 12
        color: Theme.light ? "#80F8F2E7" : "#B519373B"
        border.color: Theme.borderStrong
        Behavior on color { ColorAnimation { duration: Theme.motion ? 260 : 0 } }
    }
    Rectangle {
        x: 26; y: 13; width: parent.width-52; height: parent.height-26; radius: 8
        color: Theme.light ? "#B8FFFCF4" : "#902A4B4D"; border.color: Theme.border
        Behavior on height { NumberAnimation { duration: Theme.motion ? 300 : 0 } }
    }
    Rectangle { x: 39; y: 23; width: 3; height: parent.height-46; color: Theme.gold; opacity: .58 }
    Rectangle { x: parent.width-42; y: 23; width: 3; height: parent.height-46; color: Theme.gold; opacity: .58 }
    Text {
        x: 58; y: 37; text: "展  卷  续  诗"
        color: Theme.gold; font.family: "SimSun"; font.pixelSize: 13; font.letterSpacing: 2
    }
    Text {
        x: 60; y: 65; width: parent.width-120
        text: interaction.question.subtitle || "循上一句，续写下一句"
        color: Theme.secondary; font.family: "Microsoft YaHei UI"; font.pixelSize: 12; wrapMode: Text.Wrap
    }
    Flickable {
        x: 59; y: 110; width: parent.width-118; height: Math.max(75,parent.height*.27)
        contentWidth: width; contentHeight: promptText.implicitHeight+10
        clip: true; boundsBehavior: Flickable.StopAtBounds
        Text {
            id: promptText; width: parent.width
            text: interaction.question.prompt || ""
            color: Theme.text; font.family: "SimSun"; font.pixelSize: Math.max(19,Math.min(31,parent.width*.034))
            lineHeight: 1.65; wrapMode: Text.Wrap; horizontalAlignment: Text.AlignHCenter
            opacity: 1
            NumberAnimation on opacity { from: 0; to: 1; duration: Theme.motion ? 380 : 0; running: stage.visible && stage.answering }
        }
    }
    Rectangle { x: 60; y: parent.height*.49; width: parent.width-120; height: 1; color: Theme.line }
    Text { x: 63; y: parent.height*.52; text: "下一句  /  YOUR VERSE"; color: Theme.gold; font.family: "SimSun"; font.pixelSize: 12 }
    Rectangle {
        x: 60; y: parent.height-73; width: parent.width-120; height: 49; radius: 5
        visible: stage.answering
        color: Theme.field; border.color: nextLine.activeFocus ? Theme.borderStrong : Theme.border
        TextField {
            id: nextLine; anchors.fill: parent; anchors.leftMargin: 15; anchors.rightMargin: 14
            placeholderText: "写下下一句诗，按 Enter 交卷"; placeholderTextColor: Theme.subtle
            color: Theme.text; font.family: "SimSun"; font.pixelSize: 19
            background: Item {}
            onAccepted: interaction.submit(text)
        }
    }
    Column {
        x: 61; y: parent.height-94; width: parent.width-122; spacing: 6
        visible: !stage.answering
        Text { width: parent.width; text: interaction.feedback; color: stage.correct ? Theme.gold : Theme.text; font.family: "SimSun"; font.pixelSize: 17; wrapMode: Text.Wrap }
        Text { width: parent.width; text: interaction.correctAnswer; color: Theme.text; font.family: "SimSun"; font.pixelSize: 19; wrapMode: Text.Wrap }
    }
    function submitCurrent() { interaction.submit(nextLine.text) }
}
