import QtQuick
import YiJuanShanHe

Rectangle {
    id: card
    property string stageName: ""
    property string period: ""
    property string scene: "春山"
    property string summary: ""
    property bool uncertain: false
    property bool selected: false
    signal activated()

    radius: 10
    color: selected ? Theme.paperAlt : Theme.paper
    border.color: selected ? Theme.borderStrong : Theme.border
    border.width: 1
    clip: true
    Behavior on color { ColorAnimation { duration: 200 } }

    Canvas {
        id: landscape
        anchors.right: parent.right
        anchors.top: parent.top
        width: 105; height: 80
        opacity: .55
        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            var shade = scene === "春山" ? Theme.selected : scene === "远江" ? Theme.paperAlt
                        : scene === "秋阙" ? Theme.goldWash : scene === "寒山" ? Theme.selected : Theme.selected
            ctx.fillStyle = shade
            ctx.beginPath(); ctx.moveTo(0, 73); ctx.lineTo(22, 52); ctx.lineTo(38, 64)
            ctx.lineTo(63, 29); ctx.lineTo(92, 64); ctx.lineTo(105, 55)
            ctx.lineTo(105, 80); ctx.lineTo(0, 80); ctx.closePath(); ctx.fill()
            ctx.globalAlpha = .42
            ctx.beginPath(); ctx.moveTo(0, 79); ctx.lineTo(38, 57); ctx.lineTo(71, 73)
            ctx.lineTo(95, 50); ctx.lineTo(105, 62); ctx.lineTo(105, 80); ctx.closePath(); ctx.fill()
        }
    }

    Text {
        x: 15; y: 12
        text: stageName
        color: Theme.paperInk
        font.family: "SimSun"; font.pixelSize: 18
    }
    Text {
        x: 15; y: 41
        text: period + (uncertain ? "  ≈" : "")
        color: Theme.paperGold
        font.family: "Georgia"; font.pixelSize: 11
    }
    Text {
        x: 15; y: 76; width: parent.width - 28
        text: summary
        color: Theme.paperInk
        font.family: "Microsoft YaHei UI"; font.pixelSize: 12
        wrapMode: Text.Wrap
        lineHeight: 1.28
        maximumLineCount: 4
        elide: Text.ElideRight
    }
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: card.activated()
    }
}
