import QtQuick
import QtQuick.Controls
import YiJuanShanHe

ComboBox {
    id: control
    height: 37
    leftPadding: 11
    rightPadding: 28

    contentItem: Text {
        text: control.displayText
        color: Theme.text
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        font.pixelSize: 12
    }
    indicator: Text {
        x: control.width - width - 11
        anchors.verticalCenter: parent.verticalCenter
        text: "⌄"
        color: Theme.goldDark
        font.pixelSize: 17
    }
    background: Rectangle {
        radius: 6
        color: control.pressed ? Theme.hover : Theme.field
        border.color: control.activeFocus ? Theme.borderStrong : Theme.border
    }
    delegate: ItemDelegate {
        width: control.width - 8
        height: 34
        highlighted: control.highlightedIndex === index
        contentItem: Text {
            leftPadding: 9
            text: modelData
            color: highlighted ? Theme.goldDark : Theme.text
            verticalAlignment: Text.AlignVCenter
            font.pixelSize: 12
        }
        background: Rectangle { radius: 5; color: highlighted ? Theme.selected : Theme.card }
    }
    popup: Popup {
        y: control.height + 4
        width: control.width
        height: Math.min(230, contentItem.implicitHeight + 8)
        padding: 4
        background: Rectangle { radius: 8; color: Theme.card; border.color: Theme.borderStrong }
        contentItem: ListView {
            clip: true
            implicitHeight: contentHeight
            model: control.popup.visible ? control.delegateModel : null
            currentIndex: control.highlightedIndex
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
        }
    }
}
