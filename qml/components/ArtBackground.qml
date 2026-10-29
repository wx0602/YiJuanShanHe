import QtQuick
import YiJuanShanHe

Item {
    id: art
    property url lightSource: ""
    property url darkSource: ""
    // These bounds omit the source images' lower-right watermarks.
    property rect lightClip: Qt.rect(0, 0, 0, 0)
    property rect darkClip: Qt.rect(0, 0, 0, 0)
    property color lightVeil: "#B8FFFCF5"
    property color darkVeil: "#C9F1EDE3"

    clip: true
    Image {
        anchors.fill: parent
        source: art.lightSource
        sourceClipRect: art.lightClip
        fillMode: Image.PreserveAspectCrop
        verticalAlignment: Image.AlignBottom
        asynchronous: true
        opacity: Theme.light ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.motion ? 380 : 0 } }
    }
    Image {
        anchors.fill: parent
        source: art.darkSource
        sourceClipRect: art.darkClip
        fillMode: Image.PreserveAspectCrop
        verticalAlignment: Image.AlignBottom
        asynchronous: true
        opacity: Theme.light ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: Theme.motion ? 380 : 0 } }
    }
    Rectangle {
        anchors.fill: parent
        color: Theme.light ? art.lightVeil : art.darkVeil
        Behavior on color { ColorAnimation { duration: Theme.motion ? 380 : 0 } }
    }
}
