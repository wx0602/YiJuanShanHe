import QtQuick
import YiJuanShanHe
import QtQuick.Controls

Item {
    id: control
    property string label: "筛选"
    property var options: ["全部"]
    property string selected: "全部"
    signal picked(string value)
    height: 38

    Rectangle {
        anchors.fill: parent
        radius: 8
        color: area.containsMouse || menu.opened ? Theme.card : Theme.card
        border.color: menu.opened ? Theme.borderStrong : Theme.border
        Behavior on color { ColorAnimation { duration: 150 } }
    }
    Text {
        x: 12; anchors.verticalCenter: parent.verticalCenter
        width: parent.width - 34
        text: control.selected === "全部" ? control.label : control.selected
        color: control.selected === "全部" ? Theme.text : Theme.text
        font.family: "Microsoft YaHei UI"; font.pixelSize: 12
        elide: Text.ElideRight
    }
    Text {
        anchors.right: parent.right; anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        text: "⌄"
        color: Theme.goldDark; font.pixelSize: 16
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: menu.opened ? menu.close() : menu.open()
    }

    Popup {
        id: menu
        x: 0; y: control.height + 5
        width: control.width
        height: Math.min(224, control.options.length * 36 + 8)
        padding: 4
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        background: Rectangle {
            radius: 9; color: Theme.background
            border.color: Theme.border; border.width: 1
        }
        contentItem: ListView {
            clip: true
            model: control.options
            boundsBehavior: Flickable.StopAtBounds
            delegate: Rectangle {
                required property string modelData
                width: ListView.view.width
                height: 36; radius: 5
                color: optionArea.containsMouse ? Theme.card : "transparent"
                Text {
                    x: 10; anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 20
                    text: modelData
                    color: modelData === control.selected ? Theme.goldDark : Theme.text
                    font.family: "Microsoft YaHei UI"; font.pixelSize: 12
                    elide: Text.ElideRight
                }
                MouseArea {
                    id: optionArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        control.selected = modelData
                        control.picked(modelData)
                        menu.close()
                    }
                }
            }
            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
                contentItem: Rectangle { implicitWidth: 3; radius: 2; color: Theme.selected }
            }
        }
    }
}
