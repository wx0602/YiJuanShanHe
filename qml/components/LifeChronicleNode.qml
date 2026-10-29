import QtQuick
import YiJuanShanHe

Item {
    id: node
    property var eventData: ({})
    property bool expanded: false
    property bool compact: false
    property bool current: false
    signal activated()

    implicitHeight: headerRow.height + (expanded ? detailArea.implicitHeight + 15 : 0) + 12
    Behavior on implicitHeight { NumberAnimation { duration: Theme.motion ? 230 : 0; easing.type: Easing.OutCubic } }

    readonly property int axisX: compact ? 58 : 98
    Rectangle {
        x: axisX - 4; y: 16; width: 9; height: 9; radius: 5
        color: current ? Theme.gold : (Theme.light ? "#F8F4EA" : "#25484C")
        border.color: Theme.gold; border.width: 1
    }
    Text {
        x: 0; y: 12; width: axisX - 13
        text: eventData.date || ""
        color: Theme.gold; font.family: "Georgia"; font.pixelSize: compact ? 10 : 12
        horizontalAlignment: Text.AlignRight; wrapMode: Text.Wrap
    }
    Item {
        id: headerRow
        x: axisX + 23; width: parent.width - x; height: Math.max(53, titleText.implicitHeight + 32)
        Text {
            id: titleText
            x: 0; y: 4; width: parent.width - 30
            text: node.eventData.title || ""
            color: Theme.text; font.family: "SimSun"; font.pixelSize: compact ? 15 : 19
            wrapMode: Text.Wrap
        }
        Text {
            x: 1; y: titleText.y + titleText.implicitHeight + 3
            width: parent.width - 28
            text: (node.eventData.place || "") + (node.eventData.uncertain ? "  ·  约略" : "")
            color: Theme.secondary; font.family: "Microsoft YaHei UI"; font.pixelSize: compact ? 10 : 12
            elide: Text.ElideRight
        }
        Text {
            anchors.right: parent.right; y: 4
            text: node.expanded ? "−" : "+"; color: Theme.gold
            font.family: "SimSun"; font.pixelSize: 19
        }
        MouseArea {
            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: node.activated()
        }
    }
    Column {
        id: detailArea
        x: axisX + 23; y: headerRow.height + 2
        width: parent.width - x - 16; spacing: 8
        visible: expanded
        Rectangle { width: parent.width; height: 1; color: Theme.line }
        Text {
            width: parent.width; text: node.eventData.detail || ""
            color: Theme.text; font.family: "Microsoft YaHei UI"
            font.pixelSize: compact ? 11 : 13; lineHeight: 1.55; wrapMode: Text.Wrap
        }
        Text {
            visible: !!node.eventData.source
            text: "史料出处  ↗"; color: Theme.gold
            font.family: "Microsoft YaHei UI"; font.pixelSize: 11
            MouseArea {
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: Qt.openUrlExternally(node.eventData.source)
            }
        }
    }
}
