import QtQuick
import YiJuanShanHe

Item {
    id: map
    property bool drawerOpen: false
    property bool overview: false
    property real zoom: 1
    property real panX: 0
    property real panY: 0
    property bool dragging: false
    property int hoveredStop: -1
    signal stopChosen(int index)

    function applyCamera(focusIndex) {
        var camera = journey.cameraFor(width, height, overview,
                                       drawerOpen ? .62 : 1, focusIndex)
        if (!camera.zoom) return
        zoom = camera.zoom
        panX = camera.panX
        panY = camera.panY
    }
    function zoomAt(factor, px, py) {
        var next = Math.max(.62, Math.min(5.6, zoom * factor))
        var originX = world.x
        var originY = world.y
        var targetOriginX = px - (px - originX) * next / zoom
        var targetOriginY = py - (py - originY) * next / zoom
        zoom = next
        panX = targetOriginX - (width - 700 * next) / 2
        panY = targetOriginY - (height - 400 * next) / 2
        constrainPan()
    }
    function constrainPan() {
        var visibleWidth = drawerOpen ? width * .62 : width
        var scaledWidth = 700 * zoom, scaledHeight = 400 * zoom
        var baseX = (width - scaledWidth) / 2
        var baseY = (height - scaledHeight) / 2
        var originX = baseX + panX, originY = baseY + panY
        originX = scaledWidth >= visibleWidth
                ? Math.max(visibleWidth - scaledWidth, Math.min(0, originX))
                : (visibleWidth - scaledWidth) / 2
        originY = scaledHeight >= height
                ? Math.max(height - scaledHeight, Math.min(0, originY))
                : (height - scaledHeight) / 2
        panX = originX - baseX
        panY = originY - baseY
    }
    onZoomChanged: routes.requestPaint()
    onWidthChanged: if (width > 0) Qt.callLater(function() { map.applyCamera(drawerOpen ? journey.currentIndex : -1) })
    onHeightChanged: if (height > 0) Qt.callLater(function() { map.applyCamera(drawerOpen ? journey.currentIndex : -1) })
    clip: true

    Rectangle { anchors.fill: parent; color: Theme.light ? "#F4EDE0" : "#102D32" }
    MouseArea {
        id: panArea
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        property real lastX: 0
        property real lastY: 0
        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        onPressed: function(mouse) { map.dragging = true; lastX = mouse.x; lastY = mouse.y }
        onReleased: map.dragging = false
        onCanceled: map.dragging = false
        onPositionChanged: function(mouse) {
            if (!pressed) return
            map.panX += mouse.x - lastX
            map.panY += mouse.y - lastY
            map.constrainPan()
            lastX = mouse.x; lastY = mouse.y
        }
        onWheel: function(wheel) {
            map.zoomAt(wheel.angleDelta.y > 0 ? 1.14 : .88, wheel.x, wheel.y)
            wheel.accepted = true
        }
    }

    Item {
        id: world
        width: 700; height: 400
        x: (map.width - width * map.zoom) / 2 + map.panX
        y: (map.height - height * map.zoom) / 2 + map.panY
        scale: map.zoom
        transformOrigin: Item.TopLeft
        Behavior on x { enabled: !map.dragging; NumberAnimation { duration: Theme.motion ? 660 : 0; easing.type: Easing.InOutCubic } }
        Behavior on y { enabled: !map.dragging; NumberAnimation { duration: Theme.motion ? 660 : 0; easing.type: Easing.InOutCubic } }
        Behavior on scale { NumberAnimation { duration: Theme.motion ? 600 : 0; easing.type: Easing.InOutCubic } }

        Image {
            anchors.fill: parent
            source: "qrc:/picture/xinglv1.png"
            fillMode: Image.PreserveAspectCrop
            asynchronous: true; smooth: true
            opacity: Theme.light ? .66 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.motion ? 400 : 0 } }
        }
        Image {
            anchors.fill: parent
            source: "qrc:/picture/xinglv2.png"
            fillMode: Image.PreserveAspectCrop
            asynchronous: true; smooth: true
            opacity: Theme.light ? 0 : .72
            Behavior on opacity { NumberAnimation { duration: Theme.motion ? 400 : 0 } }
        }
        Rectangle {
            anchors.fill: parent
            color: Theme.light ? "#27FFF9ED" : "#20091F24"
            Behavior on color { ColorAnimation { duration: Theme.motion ? 350 : 0 } }
        }

        // The artwork is atmospheric; this independent Natural Earth outline
        // and the longitude/latitude projection locate the actual stations.
        Image {
            anchors.fill: parent
            source: "qrc:/data/china-outline-overlay.svg"
            fillMode: Image.Stretch
            opacity: Theme.light ? .98 : .94
            smooth: true
        }

        Canvas {
            id: routes
            anchors.fill: parent
            property real progress: journey.currentIndex
            onProgressChanged: requestPaint()
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            Behavior on progress { NumberAnimation { duration: Theme.motion ? 760 : 0; easing.type: Easing.InOutCubic } }
            Connections { target: journey; function onPoetChanged() { routes.requestPaint() } }
            Connections { target: Theme; function onNameChanged() { routes.requestPaint() } }
            onPaint: {
                var c = getContext("2d"), stops = journey.stops
                c.clearRect(0, 0, width, height)
                for (var i = 0; i < stops.length - 1; ++i) {
                    var from = stops[i], to = stops[i+1]
                    var x1 = (from.lon-70)*10, y1 = (56-from.lat)*10
                    var x2 = (to.lon-70)*10, y2 = (56-to.lat)*10
                    var dx = x2-x1, dy = y2-y1, length = Math.max(1, Math.hypot(dx,dy))
                    var bend = Math.min(13, length*.12) * (i%2 ? 1 : -1)
                    var cx = (x1+x2)/2 - dy/length*bend
                    var cy = (y1+y2)/2 + dx/length*bend
                    function segment(t) {
                        c.beginPath(); c.moveTo(x1,y1)
                        for (var step = 1; step <= 32; ++step) {
                            var v = t*step/32, u = 1-v
                            c.lineTo(u*u*x1+2*u*v*cx+v*v*x2,
                                     u*u*y1+2*u*v*cy+v*v*y2)
                        }
                        c.stroke()
                    }
                    c.lineCap = "round"
                    c.strokeStyle = Theme.light ? "rgba(139,101,48,.36)" : "rgba(227,194,131,.34)"
                    c.lineWidth = 1.15/map.zoom
                    segment(1)
                    var visible = Math.max(0, Math.min(1, progress-i))
                    if (visible > 0) {
                        c.strokeStyle = Theme.light ? "rgba(155,104,38,.94)" : "rgba(245,203,128,.96)"
                        c.lineWidth = 2.4/map.zoom
                        segment(visible)
                    }
                }
            }
        }

        Repeater {
            model: journey.stops
            delegate: Item {
                id: station
                required property var modelData
                required property int index
                readonly property bool active: journey.currentIndex === index
                readonly property bool reached: index <= journey.currentIndex
                width: 30; height: 30
                x: (modelData.lon-70)*10 - width/2
                y: (56-modelData.lat)*10 - height/2
                scale: 1/map.zoom
                transformOrigin: Item.Center
                opacity: reached ? 1 : .68
                Behavior on opacity { NumberAnimation { duration: Theme.motion ? 350 : 0 } }
                Rectangle {
                    anchors.centerIn: parent
                    width: station.active ? 42 : 29; height: width; radius: width/2
                    color: Theme.light ? "#A8DDBB79" : "#93D7B36B"
                    opacity: station.active ? .68 : .31
                    Behavior on width { NumberAnimation { duration: Theme.motion ? 340 : 0 } }
                }
                Rectangle {
                    anchors.centerIn: parent
                    width: station.active ? 22 : 15; height: width; radius: width/2
                    color: Theme.light ? "#FFF9E8" : "#345859"
                    border.color: Theme.light ? "#A6773F" : "#E2C58D"
                    border.width: station.active ? 2 : 1.4
                    Behavior on width { NumberAnimation { duration: Theme.motion ? 330 : 0 } }
                }
                Rectangle {
                    anchors.centerIn: parent
                    width: 6; height: 6; radius: 3
                    color: Theme.light ? "#A7783E" : "#F4D69B"
                }
                Rectangle {
                    id: stationTag
                    width: tagText.implicitWidth + 17; height: 26; radius: 5
                    x: station.index%2 ? 25 : -width-9
                    y: station.index === 2 ? -29 : (station.index%3 === 0 ? -24 : 24)
                    readonly property real projectedX: world.x + (station.x + 15) * map.zoom + x - 15
                    visible: (station.active || stationMouse.containsMouse || station.index%2 === 0)
                             && projectedX >= 8
                             && projectedX + width <= (map.drawerOpen ? map.width*.62 : map.width) - 8
                    color: Theme.light ? "#EAFDF9F0" : "#DA17373A"
                    border.color: station.active ? Theme.borderStrong : Theme.border
                    Text {
                        id: tagText; anchors.centerIn: parent
                        text: station.modelData.place
                        color: Theme.light ? Theme.paperInk : Theme.text
                        font.family: "SimSun"; font.pixelSize: 12
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: map.stopChosen(station.index)
                    }
                }
                MouseArea {
                    id: stationMouse
                    anchors.centerIn: parent
                    width: 30; height: 30
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: map.hoveredStop = station.index
                    onExited: if (map.hoveredStop === station.index) map.hoveredStop = -1
                    onClicked: map.stopChosen(station.index)
                    onWheel: function(wheel) {
                        var at = station.mapToItem(map, wheel.x, wheel.y)
                        map.zoomAt(wheel.angleDelta.y > 0 ? 1.14 : .88, at.x, at.y)
                        wheel.accepted = true
                    }
                }
            }
        }
    }

    Rectangle {
        x: 18; y: 15; width: 197; height: 27; radius: 5
        color: Theme.light ? "#D9FFF9EF" : "#C216393C"
        Text {
            anchors.centerIn: parent; text: "山  河  行  卷    /    ATLAS"
            color: Theme.light ? Theme.paperGold : Theme.goldLight
            font.family: "SimSun"; font.pixelSize: 11; font.letterSpacing: 1
        }
    }
    Rectangle {
        anchors.left: parent.left; anchors.leftMargin: 17
        anchors.bottom: parent.bottom; anchors.bottomMargin: 15
        width: 272; height: 26; radius: 5
        color: Theme.light ? "#DEFFF9EF" : "#D0153438"
        Text {
            anchors.centerIn: parent
            text: "现代经纬度定位  ·  曲线仅示事件先后"
            color: Theme.light ? Theme.paperInk : Theme.text
            font.family: "Microsoft YaHei UI"; font.pixelSize: 10
        }
    }
    Row {
        anchors.right: parent.right
        anchors.rightMargin: map.drawerOpen ? map.width*.38 + 16 : 18
        anchors.bottom: parent.bottom; anchors.bottomMargin: 14
        spacing: 5
        Behavior on anchors.rightMargin { NumberAnimation { duration: Theme.motion ? 360 : 0 } }
        Repeater {
            model: [{label:"＋", factor:1}, {label:"－", factor:-1}, {label:"归位", factor:0}]
            delegate: Rectangle {
                required property var modelData
                width: modelData.factor === 0 ? 48 : 33; height: 33; radius: 6
                color: zoomMouse.containsMouse ? Theme.hover : Theme.surface
                border.color: Theme.borderStrong
                Text { anchors.centerIn: parent; text: modelData.label; color: Theme.text; font.pixelSize: modelData.factor === 0 ? 11 : 18 }
                MouseArea {
                    id: zoomMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: modelData.factor === 0 ? map.applyCamera(map.drawerOpen ? journey.currentIndex : -1)
                               : map.zoomAt(modelData.factor > 0 ? 1.17 : .85, map.width*.5, map.height*.5)
                }
            }
        }
    }
}
