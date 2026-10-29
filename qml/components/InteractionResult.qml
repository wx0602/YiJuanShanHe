import QtQuick
import QtQuick.Controls
import YiJuanShanHe

Item {
    id: result
    property int durationSeconds: 0
    signal replayRequested()
    signal lobbyRequested()
    Rectangle { anchors.fill: parent; color: Theme.background }
    Flickable {
        anchors.fill: parent; contentWidth: width; contentHeight: contents.implicitHeight+36
        clip: true; boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded; contentItem: Rectangle { implicitWidth: 4; radius: 2; color: Theme.borderStrong } }
        Column {
            id: contents; x: 25; width: parent.width-50; spacing: 14
            Item { width: 1; height: 12 }
            Rectangle {
                id: finisher
                width: parent.width; height: 225; radius: 13
                color: Theme.light ? "#F4E9D4" : "#214348"; border.color: Theme.borderStrong
                InkVignette { x: parent.width*.73; y: -8; width: parent.width*.25; height: 218; scene: "chain"; opacity: .35 }
                Text { x: 28; y: 23; text: "诗  会  收  卷    /    FINISHED"; color: Theme.gold; font.family: "Georgia"; font.pixelSize: 12; font.letterSpacing: 1.3 }
                Text { x: 28; y: 54; text: "此卷已毕，诗意未尽。"; color: Theme.text; font.family: "SimSun"; font.pixelSize: 31 }
                Text { x: 31; y: 111; text: interaction.score + " 分"; color: Theme.gold; font.family: "Georgia"; font.pixelSize: 44 }
                Text {
                    x: 32; y: 177
                    text: "答对 " + interaction.correctCount + " / " + interaction.questionCount + " 题   ·   正确率 "
                          + Math.round(100*interaction.correctCount/Math.max(1,interaction.questionCount)) + "%"
                          + (result.durationSeconds > 0 ? "   ·   本轮用时 " + Math.floor(result.durationSeconds/60) + "分" + result.durationSeconds%60 + "秒" : "")
                    color: Theme.secondary; font.family: "Microsoft YaHei UI"; font.pixelSize: 13
                }
                Rectangle {
                    anchors.right: parent.right; anchors.rightMargin: 34; y: 33
                    width: 68; height: 68; radius: 34; rotation: -12
                    color: "transparent"; border.color: Theme.gold; border.width: 2
                    Text { anchors.centerIn: parent; text: "留印"; color: Theme.gold; font.family: "SimSun"; font.pixelSize: 20 }
                    NumberAnimation on scale { from: 1.4; to: 1; duration: Theme.motion ? 470 : 0; running: result.visible }
                }
            }
            Row {
                width: parent.width; height: 42; spacing: 10
                Rectangle { width: 159; height: 37; radius: 6; color: againMouse.containsMouse ? Theme.accentHover : Theme.accent; border.color: Theme.borderStrong
                    Text { anchors.centerIn: parent; text: "再来一轮  →"; color: Theme.accentText; font.family: "SimSun"; font.pixelSize: 14 }
                    MouseArea { id: againMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: result.replayRequested() }
                }
                Rectangle { width: 159; height: 37; radius: 6; color: backMouse.containsMouse ? Theme.hover : Theme.surface; border.color: Theme.border
                    Text { anchors.centerIn: parent; text: "返回雅集"; color: Theme.text; font.family: "SimSun"; font.pixelSize: 14 }
                    MouseArea { id: backMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: result.lobbyRequested() }
                }
            }
            Rectangle { width: parent.width; height: 1; color: Theme.line }
            Text { text: "本轮回顾  /  错题可在雅集大厅重练"; color: Theme.text; font.family: "SimSun"; font.pixelSize: 19 }
            Repeater {
                model: interaction.roundResults
                delegate: Rectangle {
                    id: answerRecord
                    required property var modelData
                    required property int index
                    width: contents.width; height: recordBody.implicitHeight+25; radius: 7
                    color: Theme.light ? "#FFFCF5" : "#27494D"
                    border.color: modelData.correct ? Theme.border : Theme.borderStrong
                    Column {
                        id: recordBody; x: 16; y: 11; width: parent.width-32; spacing: 5
                        Text { width: parent.width; text: String(answerRecord.index+1).padStart(2,"0") + "  /  " + (answerRecord.modelData.correct ? "答对" : "待温习") + (answerRecord.modelData.poemTitle ? "  ·  《" + answerRecord.modelData.poemTitle + "》" : ""); color: answerRecord.modelData.correct ? Theme.gold : Theme.danger; font.family: "SimSun"; font.pixelSize: 12; wrapMode: Text.Wrap }
                        Text { width: parent.width; text: (answerRecord.modelData.prompt || "").replace("\n","  "); color: Theme.text; font.family: "SimSun"; font.pixelSize: 15; wrapMode: Text.Wrap }
                        Text { width: parent.width; text: "正解  ·  " + answerRecord.modelData.answer; color: Theme.secondary; font.family: "Microsoft YaHei UI"; font.pixelSize: 12; wrapMode: Text.Wrap }
                    }
                }
            }
            Item { width: 1; height: 18 }
        }
    }
}
