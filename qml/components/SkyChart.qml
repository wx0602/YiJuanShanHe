import QtQuick
import YiJuanShanHe

Item {
    id: sky
    property var entries: []
    property var connections: []
    property string selectedKey: ""
    property string pairKey: ""
    property string hoverKey: ""
    property bool notebookOpen: false
    property real zoom: 1
    property real panX: 0
    property real panY: 0
    property bool dragging: false
    signal nodeSelected(string key)

    // Positions are stable across searches, focus changes, and launches.
    readonly property var places: ({"星":[.20,.22], "月":[.51,.25], "日":[.80,.22],
        "雁":[.65,.14], "云":[.71,.39], "雨":[.88,.48], "风":[.40,.43], "雪":[.17,.43],
        "山":[.25,.65], "水":[.56,.61], "花":[.44,.78], "柳":[.75,.75],
        "秋":[.17,.56], "春":[.85,.63], "舟":[.63,.84], "酒":[.11,.79]})

    function pointFor(key) {
        if (places[key]) return Qt.point(places[key][0], places[key][1])
        var hash = 0
        for (var i = 0; i < key.length; ++i) hash = (hash * 31 + key.charCodeAt(i)) >>> 0
        return Qt.point(.15 + (hash % 650) / 1000, .20 + ((hash >>> 9) % 610) / 1000)
    }
    function resetView() {
        zoom = 1; panX = 0; panY = 0
    }
    function focusOn(key, showNotebook) {
        var p = pointFor(key)
        var targetX = showNotebook ? width * .29 : width * .50
        var targetY = height * .51
        panX = targetX - p.x * width * zoom
        panY = targetY - p.y * height * zoom
    }
    function zoomBy(factor) {
        var next = Math.max(.78, Math.min(1.62, zoom * factor))
        var midpointX = notebookOpen ? width * .32 : width * .50
        var midpointY = height * .50
        panX = midpointX - (midpointX - panX) * next / zoom
        panY = midpointY - (midpointY - panY) * next / zoom
        zoom = next
    }

    clip: true
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: Theme.light ? "#FDFBF5" : "#24474A" }
            GradientStop { position: .63; color: Theme.light ? "#F6F2E7" : "#1D3C42" }
            GradientStop { position: 1; color: Theme.light ? "#EDEAE0" : "#173238" }
        }
    }
    Image {
        anchors.fill: parent
        source: "qrc:/picture/xingyun1.jpg"
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        smooth: true
        opacity: Theme.light ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.motion ? 420 : 0 } }
    }
    Image {
        anchors.fill: parent
        source: "qrc:/picture/xingyun2.jpg"
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        smooth: true
        opacity: Theme.light ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: Theme.motion ? 420 : 0 } }
    }
    Rectangle {
        anchors.fill: parent
        color: Theme.light ? "#89FFFDF8" : "#8C10272D"
        Behavior on color { ColorAnimation { duration: Theme.motion ? 320 : 0 } }
    }
    Canvas {
        id: atmosphere
        anchors.fill: parent
        opacity: .12
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Connections { target: Theme; function onNameChanged() { atmosphere.requestPaint() } }
        onPaint: {
            var c = getContext("2d"), w = width, h = height
            c.clearRect(0, 0, w, h)
            for (var i = 0; i < 79; ++i) {
                var x = (((i * 97 + 43) % 101) / 101) * w
                var y = (((i * 53 + 11) % 89) / 89) * h
                var radius = i % 9 === 0 ? 1.6 : .8
                c.beginPath(); c.arc(x, y, radius, 0, Math.PI * 2)
                c.fillStyle = Theme.light ? "rgba(139,107,57,.24)" : "rgba(227,203,151,.30)"
                c.fill()
            }
            var wash = c.createLinearGradient(0, h * .72, 0, h)
            wash.addColorStop(0, Theme.light ? "rgba(158,181,166,0)" : "rgba(87,126,126,0)")
            wash.addColorStop(1, Theme.light ? "rgba(142,174,159,.16)" : "rgba(95,132,127,.20)")
            c.fillStyle = wash
            c.beginPath(); c.moveTo(0, h)
            c.lineTo(0, h * .91)
            c.bezierCurveTo(w*.18,h*.78,w*.26,h*.94,w*.43,h*.87)
            c.bezierCurveTo(w*.61,h*.75,w*.73,h*.93,w,h*.80)
            c.lineTo(w,h); c.closePath(); c.fill()
            c.strokeStyle = Theme.light ? "rgba(139,107,57,.12)" : "rgba(211,189,143,.12)"
            c.lineWidth = 1
            c.beginPath(); c.moveTo(w*.08,h*.90)
            c.bezierCurveTo(w*.37,h*.82,w*.49,h*.94,w*.88,h*.84)
            c.stroke()
        }
    }
    Repeater {
        model: [
            {label:"天  象", x:.08, y:.15}, {label:"山  水", x:.10, y:.55},
            {label:"草  木", x:.73, y:.70}, {label:"人  间", x:.48, y:.87}
        ]
        delegate: Text {
            required property var modelData
            x: sky.width * modelData.x; y: sky.height * modelData.y
            text: modelData.label
            color: Theme.gold; opacity: Theme.light ? .42 : .50
            font.family: "SimSun"; font.pixelSize: 13; font.letterSpacing: 3
        }
    }

    MouseArea {
        id: panArea
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        property real previousX: 0
        property real previousY: 0
        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        onPressed: function(mouse) { sky.dragging = true; previousX = mouse.x; previousY = mouse.y }
        onReleased: sky.dragging = false
        onCanceled: sky.dragging = false
        onPositionChanged: function(mouse) {
            if (!pressed) return
            sky.panX += mouse.x - previousX
            sky.panY += mouse.y - previousY
            previousX = mouse.x; previousY = mouse.y
        }
    }

    Item {
        id: world
        x: sky.panX; y: sky.panY
        width: sky.width; height: sky.height
        scale: sky.zoom
        transformOrigin: Item.TopLeft
        Behavior on x { enabled: !sky.dragging; NumberAnimation { duration: Theme.motion ? 530 : 0; easing.type: Easing.InOutCubic } }
        Behavior on y { enabled: !sky.dragging; NumberAnimation { duration: Theme.motion ? 530 : 0; easing.type: Easing.InOutCubic } }
        Behavior on scale { NumberAnimation { duration: Theme.motion ? 350 : 0; easing.type: Easing.OutCubic } }

        Canvas {
            id: threadLayer
            anchors.fill: parent
            property real reveal: 0
            onRevealChanged: requestPaint()
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            Connections { target: sky; function onConnectionsChanged() { threadLayer.requestPaint() }
                function onSelectedKeyChanged() { threadLayer.requestPaint() }
                function onHoverKeyChanged() { threadLayer.requestPaint() } }
            Connections { target: Theme; function onNameChanged() { threadLayer.requestPaint() } }
            NumberAnimation on reveal { from: 0; to: 1; duration: Theme.motion ? 950 : 0; easing.type: Easing.OutCubic }
            onPaint: {
                var c = getContext("2d")
                c.clearRect(0, 0, width, height)
                var all = sky.connections || []
                var highest = all.length ? Math.max(1, all[0].count) : 1
                for (var i = all.length - 1; i >= 0; --i) {
                    var link = all[i]
                    var a = sky.pointFor(link.from), b = sky.pointFor(link.to)
                    var x1 = a.x * width, y1 = a.y * height
                    var x2 = b.x * width, y2 = b.y * height
                    var dx = x2-x1, dy = y2-y1
                    var bend = Math.min(38, Math.hypot(dx,dy)*.12) * ((i%2) ? 1 : -1)
                    var length = Math.max(1, Math.hypot(dx,dy))
                    var cx = (x1+x2)/2 - dy/length*bend
                    var cy = (y1+y2)/2 + dx/length*bend
                    var active = link.from === sky.selectedKey || link.to === sky.selectedKey
                                 || link.from === sky.hoverKey || link.to === sky.hoverKey
                    c.beginPath(); c.moveTo(x1,y1)
                    for (var step = 1; step <= 24; ++step) {
                        var t = (step/24) * reveal, u = 1-t
                        c.lineTo(u*u*x1 + 2*u*t*cx + t*t*x2,
                                 u*u*y1 + 2*u*t*cy + t*t*y2)
                    }
                    c.globalAlpha = active ? .68 : (.11 + .21 * Math.sqrt(link.count/highest))
                    c.strokeStyle = active ? Theme.imageryLinkActive : Theme.imageryLink
                    c.lineWidth = .65 + Math.min(1.6, Math.sqrt(link.count) * .20)
                    c.stroke()
                }
                c.globalAlpha = 1
            }
        }

        Repeater {
            model: sky.entries
            delegate: Item {
                id: star
                required property var modelData
                required property int index
                readonly property point place: sky.pointFor(modelData.key)
                readonly property bool chosen: modelData.key === sky.selectedKey
                readonly property bool prominent: chosen || index < 4
                width: prominent ? 104 : 76
                height: prominent ? 94 : 66
                x: place.x * world.width - width/2
                y: place.y * world.height - height/2
                opacity: 0
                SequentialAnimation on opacity {
                    running: true
                    PauseAnimation { duration: Math.min(star.index * 55, 700) }
                    NumberAnimation { from: 0; to: 1; duration: Theme.motion ? 460 : 0; easing.type: Easing.OutCubic }
                }
                Rectangle {
                    anchors.centerIn: moonDisc
                    width: moonDisc.width + 31; height: width; radius: width/2
                    visible: star.prominent
                    color: Theme.light ? "#DFD8C4" : "#D5C294"
                    opacity: star.chosen ? .32 : .16
                }
                Rectangle {
                    id: moonDisc
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: star.prominent ? 8 : 15
                    width: star.prominent ? (star.chosen ? 69 : 54) : 34
                    height: width; radius: width/2
                    color: star.prominent ? (Theme.light ? "#F5E9CF" : "#596F6A") : "transparent"
                    border.color: star.prominent ? Theme.borderStrong : "transparent"
                    border.width: star.prominent ? 1 : 0
                    opacity: star.prominent ? 1 : .5
                    Behavior on width { NumberAnimation { duration: Theme.motion ? 260 : 0 } }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: star.prominent ? 20 : 17
                    text: star.modelData.key
                    color: star.chosen ? (Theme.light ? Theme.paperGold : Theme.text) : Theme.text
                    font.family: "SimSun"; font.pixelSize: star.chosen ? 31 : star.prominent ? 25 : 21
                    font.bold: star.chosen
                    horizontalAlignment: Text.AlignHCenter
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: star.prominent ? 72 : 48
                    text: star.modelData.count + " 首"
                    color: Theme.secondary
                    font.family: "Georgia"; font.pixelSize: 10
                    opacity: star.prominent || nodeArea.containsMouse ? 1 : .66
                }
                MouseArea {
                    id: nodeArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: sky.hoverKey = star.modelData.key
                    onExited: if (sky.hoverKey === star.modelData.key) sky.hoverKey = ""
                    onClicked: sky.nodeSelected(star.modelData.key)
                }
                scale: nodeArea.containsMouse ? 1.08 : 1
                Behavior on scale { NumberAnimation { duration: Theme.motion ? 170 : 0; easing.type: Easing.OutCubic } }
            }
        }
    }
    WheelHandler { onWheel: function(event) { sky.zoomBy(event.angleDelta.y > 0 ? 1.11 : .90) } }
}
