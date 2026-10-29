import QtQuick
import YiJuanShanHe

Rectangle {
    id: portrait
    property var profile: ({})
    property bool compact: false
    readonly property color textInk: Theme.light ? "#304846" : "#F3F0E6"
    readonly property color mutedInk: Theme.light ? "#5B6C65" : "#C1D2CC"
    readonly property color portraitGold: Theme.light ? "#886633" : "#D9BE8B"
    readonly property int marginSize: compact ? 24 : 38

    implicitHeight: compact ? Math.max(195, profileIntro.implicitHeight + 142)
                            : Math.max(260, profileIntro.implicitHeight + 203)
    radius: compact ? 10 : 14
    clip: true
    color: Theme.light ? "#F7F2E7" : "#1A3B40"
    border.color: Theme.light ? "#C9AD76" : "#607B77"
    Behavior on color { ColorAnimation { duration: Theme.motion ? 300 : 0 } }

    Rectangle {
        anchors.right: parent.right; anchors.rightMargin: compact ? -62 : 10
        anchors.bottom: parent.bottom; anchors.bottomMargin: compact ? -103 : -153
        width: compact ? 264 : 370; height: width; radius: width / 2
        color: "transparent"; border.width: 1
        border.color: Theme.light ? "#3CA88A55" : "#45DBC28E"
    }
    Rectangle {
        anchors.right: parent.right; anchors.rightMargin: compact ? 32 : 78
        anchors.top: parent.top; anchors.topMargin: compact ? 17 : 24
        width: compact ? 76 : 118; height: width; radius: width / 2
        color: Theme.light ? "#E9D7AE" : "#D7BC87"
        opacity: Theme.light ? .42 : .18
    }
    Canvas {
        id: mountain
        x: parent.width * .70; width: parent.width * .30
        anchors.bottom: parent.bottom; height: compact ? 105 : 160
        opacity: Theme.light ? .40 : .37
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Connections { target: Theme; function onNameChanged() { mountain.requestPaint() } }
        onPaint: {
            const c = getContext("2d")
            c.clearRect(0, 0, width, height)
            c.fillStyle = Theme.light ? "#8CA49B" : "#83A49E"
            c.beginPath(); c.moveTo(0, height)
            c.bezierCurveTo(width*.08,height*.68,width*.18,height*.65,width*.26,height*.78)
            c.bezierCurveTo(width*.37,height*.90,width*.45,height*.27,width*.55,height*.36)
            c.bezierCurveTo(width*.64,height*.42,width*.69,height*.80,width*.77,height*.62)
            c.bezierCurveTo(width*.84,height*.51,width*.91,height*.61,width,height*.48)
            c.lineTo(width,height); c.closePath(); c.fill()
            c.globalAlpha = .43
            c.fillStyle = Theme.light ? "#647D75" : "#608D87"
            c.beginPath(); c.moveTo(width*.13,height)
            c.bezierCurveTo(width*.37,height*.87,width*.49,height*.54,width*.59,height*.73)
            c.bezierCurveTo(width*.76,height*.54,width*.82,height*.73,width,height*.64)
            c.lineTo(width,height); c.closePath(); c.fill()
        }
    }
    Rectangle { x: 0; y: 0; width: 4; height: parent.height; color: portraitGold }
    Text {
        x: marginSize; y: compact ? 17 : 25
        text: compact ? "人物小传  /  BIOGRAPHY" : "人  物  列  传     /     BIOGRAPHY"
        color: portraitGold; font.family: "Georgia"; font.pixelSize: compact ? 10 : 11
        font.letterSpacing: 1.4
    }
    Text {
        id: poetName
        x: marginSize; y: compact ? 40 : 53
        text: profile.name || ""
        color: textInk; font.family: "SimSun"; font.pixelSize: compact ? 35 : 54
        font.letterSpacing: compact ? 2 : 5
    }
    Text {
        x: poetName.x + poetName.implicitWidth + (compact ? 12 : 19); y: compact ? 55 : 77
        width: Math.max(80, parent.width - x - 125)
        text: (profile.dynasty || "") + "  ·  " + (profile.years || "")
        color: portraitGold; font.family: "Microsoft YaHei UI"
        font.pixelSize: compact ? 11 : 14; elide: Text.ElideRight
    }
    Text {
        x: marginSize; y: compact ? 88 : 122
        width: parent.width * (compact ? .79 : .70)
        text: profile.courtesy || ""
        color: mutedInk; font.family: "Microsoft YaHei UI"; font.pixelSize: compact ? 11 : 13
        wrapMode: Text.Wrap
    }
    Text {
        id: profileIntro
        x: marginSize; y: compact ? 117 : 151
        width: parent.width * (compact ? .66 : .61) - marginSize
        text: profile.intro || ""
        color: textInk; font.family: "Microsoft YaHei UI"
        font.pixelSize: compact ? 11 : 14; lineHeight: 1.55; wrapMode: Text.Wrap
    }
    Text {
        visible: !compact
        x: marginSize; anchors.bottom: parent.bottom; anchors.bottomMargin: 17
        width: parent.width * .67 - marginSize
        text: profile.motto ? "“" + profile.motto + "”" : ""
        color: portraitGold; font.family: "SimSun"; font.pixelSize: 15
        elide: Text.ElideRight
    }
    Rectangle {
        anchors.right: parent.right; anchors.rightMargin: compact ? 19 : 33
        anchors.top: parent.top; anchors.topMargin: compact ? 18 : 28
        width: compact ? 38 : 55; height: width; radius: width / 2
        color: Theme.light ? "#F8F1E4" : "#24484B"
        border.color: portraitGold
        Text {
            anchors.centerIn: parent; text: portrait.profile.epithet || ""
            color: portraitGold; font.family: "SimSun"; font.pixelSize: compact ? 11 : 15
        }
    }
}
