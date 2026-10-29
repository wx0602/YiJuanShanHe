import QtQuick
import YiJuanShanHe

Item {
    id: card
    property string index: "01"
    property string title: ""
    property string subtitle: ""
    property string glyph: "山"
    property color tint: Theme.gold
    property string footerText: "逐页开放  ·  敬请期待"
    signal activated()

    height: 174
    scale: mouse.containsMouse ? 1.018 : 1.0
    y: mouse.containsMouse ? -4 : 0
    Behavior on scale { NumberAnimation { duration: 190; easing.type: Easing.OutCubic } }
    Behavior on y { NumberAnimation { duration: 190; easing.type: Easing.OutCubic } }

    Rectangle {
        anchors.fill: parent
        radius: 15
        color: mouse.containsMouse ? Theme.card : Theme.surface
        border.color: mouse.containsMouse ? Theme.borderStrong : Theme.border
        border.width: 1
        Behavior on color { ColorAnimation { duration: 180 } }
        Behavior on border.color { ColorAnimation { duration: 180 } }
    }


    Rectangle {
        x: 22; y: 24; width: 33; height: 1
        color: card.tint; opacity: .9
    }
    Text {
        x: 64; y: 16
        text: card.index
        color: Theme.secondary
        font.family: "Georgia"; font.pixelSize: 13; font.letterSpacing: 2
    }
    Text {
        x: 23; y: 55
        text: card.title
        color: Theme.text
        font.family: "SimSun"; font.pixelSize: 27
    }
    Text {
        x: 25; y: 104
        text: card.subtitle
        color: Theme.secondary
        font.family: "Microsoft YaHei UI"; font.pixelSize: 13
    }
    Text {
        x: 25
        anchors.bottom: parent.bottom; anchors.bottomMargin: 19
        text: card.footerText
        color: Theme.secondary
        font.family: "Microsoft YaHei UI"; font.pixelSize: 11
    }
    Text {
        anchors.right: parent.right; anchors.rightMargin: 26
        anchors.verticalCenter: parent.verticalCenter
        text: card.glyph
        color: card.tint
        opacity: .28
        font.family: "SimSun"; font.pixelSize: 91
    }
    Text {
        anchors.right: parent.right; anchors.rightMargin: 22
        anchors.bottom: parent.bottom; anchors.bottomMargin: 18
        text: "↗"
        color: mouse.containsMouse ? Theme.goldDark : Theme.secondary
        font.pixelSize: 20
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: card.activated()
    }
}
