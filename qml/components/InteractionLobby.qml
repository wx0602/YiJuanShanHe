import QtQuick
import QtQuick.Controls
import YiJuanShanHe

Item {
    id: lobby
    property int roundLength: 10
    property bool showMistakes: false
    signal chooseLength(int count)
    signal begin(string mode)
    signal retry()
    readonly property var modes: [
        {key:"feihua", number:"壹", title:"飞花令", subtitle:"诗会擂台", image:"qrc:/picture/feihua1.png", desc:"以一字为令，与诗海轮流接句。每轮有倒计时，诗句不可重用。"},
        {key:"chain", number:"贰", title:"诗词接龙", subtitle:"展卷续诗", image:"qrc:/picture/jielong1.png", desc:"一行已起，下一句由你续写。循诗意前行，找回诗篇原貌。"},
        {key:"puzzle", number:"叁", title:"残卷修复", subtitle:"诗句归位", image:"qrc:/picture/canjuan1.png", desc:"拾起散落的诗句，轻拖纸笺，让一首古诗重新成卷。"}
    ]
    Rectangle { anchors.fill: parent; color: Theme.background }
    Flickable {
        id: scroll
        anchors.fill: parent; contentWidth: width; contentHeight: content.implicitHeight + 34
        clip: true; boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded; contentItem: Rectangle { implicitWidth: 4; radius: 2; color: Theme.borderStrong } }
        Column {
            id: content; x: 25; width: scroll.width - 50; spacing: 16
            Item { width: 1; height: 9 }
            Rectangle {
                width: parent.width; height: 174; radius: 14; clip: true
                color: Theme.surface
                border.color: Theme.borderStrong
                Image {
                    anchors.fill: parent
                    source: "qrc:/picture/yaji1.png"
                    fillMode: Image.PreserveAspectCrop
                    verticalAlignment: Image.AlignBottom
                    asynchronous: true
                    smooth: true
                }
                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: Theme.light ? "#F3FFFCF5" : "#E6163439" }
                        GradientStop { position: .48; color: Theme.light ? "#C2F8F3E9" : "#A81A3A3F" }
                        GradientStop { position: 1; color: Theme.light ? "#18FFFCF5" : "#321A383C" }
                    }
                }
                Text { x: 28; y: 24; text: "YI JUAN SHAN HE  /  POETRY SALON"; color: Theme.gold; font.family: "Georgia"; font.pixelSize: 11; font.letterSpacing: 1.5 }
                Text { x: 27; y: 54; text: "诗词雅集"; color: Theme.text; font.family: "SimSun"; font.pixelSize: 42; font.letterSpacing: 4 }
                Text { x: 30; y: 119; width: parent.width*.65; text: "一字起令，一句相和，一卷待修。择一席入座，与诗词再相逢。"; color: Theme.secondary; font.family: "Microsoft YaHei UI"; font.pixelSize: 13; wrapMode: Text.Wrap }
                Rectangle { anchors.right: parent.right; anchors.rightMargin: 22; y: 23; width: 70; height: 27; radius: 14; color: Theme.light ? "#F8F1E5" : "#31575B"; border.color: Theme.borderStrong
                    Text { anchors.centerIn: parent; text: "雅集入席"; color: Theme.light ? Theme.gold : Theme.accentText; font.family: "SimSun"; font.pixelSize: 11 }
                }
            }
            Row {
                width: parent.width; height: 35; spacing: 16
                Text { text: "择一席，开始今日诗会"; color: Theme.text; font.family: "SimSun"; font.pixelSize: 21 }
                Text { anchors.verticalCenter: parent.verticalCenter; text: "每轮题数"; color: Theme.secondary; font.pixelSize: 11 }
                Repeater {
                    model: [5,10,15]
                    delegate: Rectangle {
                        required property int modelData
                        width: 46; height: 29; radius: 15
                        color: lobby.roundLength === modelData ? Theme.selected : Theme.surface
                        border.color: lobby.roundLength === modelData ? Theme.borderStrong : Theme.border
                        Text { anchors.centerIn: parent; text: modelData; color: Theme.text; font.family: "Georgia"; font.pixelSize: 12 }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: lobby.chooseLength(modelData) }
                    }
                }
            }
            Row {
                width: parent.width; spacing: 12
                Repeater {
                    model: lobby.modes
                    delegate: Rectangle {
                        id: modeCard
                        required property var modelData
                        width: (content.width - 24) / 3; height: 298; radius: 11
                        color: Theme.light ? "#FFFCF5" : "#25494C"
                        border.color: cardMouse.containsMouse ? Theme.borderStrong : Theme.border
                        clip: true
                        scale: cardMouse.containsMouse && Theme.motion ? 1.014 : 1
                        Behavior on scale { NumberAnimation { duration: 170; easing.type: Easing.OutCubic } }
                        Image {
                            anchors.fill: parent
                            source: modeCard.modelData.image
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            smooth: true
                        }
                        Rectangle {
                            anchors.fill: parent
                            gradient: Gradient {
                                GradientStop { position: 0; color: Theme.light ? "#22FFFCF5" : "#7A15353A" }
                                GradientStop { position: .45; color: Theme.light ? "#C9FFFCF5" : "#C91B3B3F" }
                                GradientStop { position: 1; color: Theme.light ? "#F7FFFCF5" : "#F1214145" }
                            }
                        }
                        Rectangle {
                            x: 13; y: 10; width: 151; height: 28; radius: 5
                            color: Theme.light ? "#DCFFFCF5" : "#DB16353A"
                            border.color: Theme.border
                        }
                        Text { x: 22; y: 16; text: modelData.number + "  /  " + modelData.subtitle; color: Theme.gold; font.family: "SimSun"; font.pixelSize: 12 }
                        Text { x: 19; y: 150; text: modelData.title; color: Theme.text; font.family: "SimSun"; font.pixelSize: 25 }
                        Text { x: 20; y: 189; width: parent.width - 42; text: modelData.desc; color: Theme.light ? "#425B56" : "#E0E8E3"; font.family: "Microsoft YaHei UI"; font.pixelSize: 12; wrapMode: Text.Wrap; lineHeight: 1.45 }
                        Rectangle { x: 19; y: parent.height - 45; width: parent.width - 38; height: 30; radius: 5; color: Theme.light ? "#F4EAD8" : "#3C605E"; border.color: Theme.borderStrong
                            Text { anchors.centerIn: parent; text: "入席挑战  →"; color: Theme.light ? Theme.gold : Theme.accentText; font.family: "SimSun"; font.pixelSize: 12 }
                        }
                        MouseArea { id: cardMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: lobby.begin(modeCard.modelData.key) }
                    }
                }
            }
            Text {
                visible: !!interaction.errorMessage
                width: parent.width; text: interaction.errorMessage
                color: Theme.danger; font.family: "Microsoft YaHei UI"; font.pixelSize: 12; wrapMode: Text.Wrap
            }
            Rectangle {
                width: parent.width; height: 62; radius: 9
                color: Theme.surface; border.color: Theme.border
                Text { x: 18; y: 12; text: "错题温习"; color: Theme.text; font.family: "SimSun"; font.pixelSize: 16 }
                Text {
                    x: 18; y: 37
                    text: interaction.mistakes.length > 0 ? (interaction.mistakes.length + " 道诗题待重新作答") : "当前没有待温习的错题"
                    color: Theme.secondary; font.pixelSize: 11
                }
                Rectangle {
                    anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter
                    width: 132; height: 34; radius: 6
                    enabled: interaction.mistakes.length > 0
                    opacity: enabled ? 1 : .55
                    color: retryMouse.containsMouse ? Theme.accentHover : Theme.accent
                    border.color: Theme.borderStrong
                    Text { anchors.centerIn: parent; text: "重练错题  →"; color: Theme.accentText; font.family: "SimSun"; font.pixelSize: 12 }
                    MouseArea { id: retryMouse; anchors.fill: parent; enabled: parent.enabled; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: lobby.retry() }
                }
            }
            Item { width: 1; height: 10 }
        }
    }
}
