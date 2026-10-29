import QtQuick
import YiJuanShanHe

Item {
    id: scene
    property bool motionEnabled: true
    clip: true

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.heroSkyTop }
            GradientStop { position: 0.58; color: Theme.heroSkyMiddle }
            GradientStop { position: 1.0; color: Theme.heroSkyBottom }
        }
    }

    Rectangle {
        id: halo
        width: 190; height: 190; radius: 95
        x: parent.width * 0.67; y: 20
        color: Theme.heroMoon; opacity: Theme.light ? 0.19 : 0.075
        scale: 1
        SequentialAnimation on scale {
            running: scene.motionEnabled; loops: Animation.Infinite
            NumberAnimation { to: 1.11; duration: 5200; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1.0; duration: 5200; easing.type: Easing.InOutSine }
        }
    }
    Rectangle {
        width: 82; height: 82; radius: 41
        x: parent.width * 0.67 + 54; y: 74
        color: Theme.heroMoon; opacity: Theme.light ? 0.88 : 0.82
    }

    Canvas {
        id: mountains
        anchors.fill: parent
        opacity: 0
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Connections { target: Theme; function onNameChanged() { mountains.requestPaint() } }
        NumberAnimation on opacity {
            from: 0; to: 1; duration: 1400
            easing.type: Easing.OutCubic
        }
        onPaint: {
            const ctx = getContext("2d")
            const w = width, h = height
            ctx.clearRect(0, 0, w, h)

            function ridge(fill, points) {
                ctx.beginPath()
                ctx.moveTo(0, h)
                ctx.lineTo(0, points[0][1] * h)
                for (let i = 1; i < points.length; ++i) {
                    const p = points[i]
                    ctx.bezierCurveTo(p[0] * w, p[1] * h,
                                      p[2] * w, p[3] * h,
                                      p[4] * w, p[5] * h)
                }
                ctx.lineTo(w, h)
                ctx.closePath()
                ctx.fillStyle = fill
                ctx.fill()
            }

            ridge(Theme.heroFar, [[0, .66], [.10, .58, .16, .43, .25, .48],
                  [.37, .54, .42, .36, .52, .45], [.63, .52, .69, .35, .77, .48],
                  [.87, .58, .93, .49, 1, .50]])
            ridge(Theme.heroMiddle, [[0, .73], [.11, .67, .18, .55, .27, .60],
                  [.37, .67, .44, .51, .53, .59], [.63, .69, .69, .54, .78, .60],
                  [.87, .69, .94, .61, 1, .66]])
            ridge(Theme.heroNear, [[0, .81], [.13, .68, .20, .67, .29, .72],
                  [.39, .78, .47, .63, .57, .68], [.70, .79, .78, .67, .87, .69],
                  [.94, .73, .97, .70, 1, .72]])
            ridge(Theme.heroFront, [[0, .88], [.13, .80, .22, .75, .34, .81],
                  [.46, .89, .56, .78, .67, .81], [.79, .90, .88, .76, 1, .83]])

            const water = ctx.createLinearGradient(0, h * .83, 0, h)
            water.addColorStop(0, Theme.heroWaterStart)
            water.addColorStop(1, Theme.heroWaterEnd)
            ctx.fillStyle = water
            ctx.fillRect(0, h * .81, w, h * .19)

            // Sparse ink lines give the landscape texture without busy detail.
            ctx.strokeStyle = Theme.heroTexture
            ctx.lineWidth = 1
            for (let i = 0; i < 10; ++i) {
                const y = h * (.83 + i * .018)
                ctx.beginPath()
                ctx.moveTo(w * (.10 + (i % 3) * .09), y)
                ctx.quadraticCurveTo(w * .47, y - 5, w * (.68 + (i % 4) * .05), y)
                ctx.stroke()
            }
        }
    }

    ArtBackground {
        anchors.fill: parent
        lightSource: "qrc:/picture/b420b20827e9cefed34f0277a69dd4dd.jpg"
        lightClip: Qt.rect(0, 1230, 1440, 700)
        darkSource: "qrc:/picture/e59fefa5d8c32ddd6ff3072783a69b3c.jpg"
        darkClip: Qt.rect(0, 450, 1440, 1200)
        lightVeil: "#36FFFCF5"
        darkVeil: "#9A1A3B40"
        opacity: Theme.light ? .78 : .47
        Behavior on opacity { NumberAnimation { duration: Theme.motion ? 380 : 0 } }
    }

    Canvas {
        id: mist
        width: 560; height: 130
        x: -180; y: parent.height * .62
        opacity: .75
        Connections { target: Theme; function onNameChanged() { mist.requestPaint() } }
        onPaint: {
            const ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            const glow = ctx.createRadialGradient(width / 2, height / 2, 0,
                                                  width / 2, height / 2, width / 2)
            glow.addColorStop(0, Theme.heroMistStart)
            glow.addColorStop(1, Theme.heroMistEnd)
            ctx.fillStyle = glow
            ctx.fillRect(0, 0, width, height)
        }
        NumberAnimation on x {
            running: scene.motionEnabled; from: -220; to: scene.width + 100
            duration: 45000; loops: Animation.Infinite
        }
    }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: Theme.heroVeilLeft }
            GradientStop { position: 0.48; color: Theme.heroVeilMiddle }
            GradientStop { position: 1.0; color: Theme.heroVeilRight }
        }
    }
}
