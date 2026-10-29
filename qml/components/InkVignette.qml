import QtQuick
import YiJuanShanHe

Item {
    id: art
    property string scene: "flower"
    property real reveal: 1
    Canvas {
        id: canvas
        anchors.fill: parent
        opacity: art.reveal
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Connections { target: Theme; function onNameChanged() { canvas.requestPaint() } }
        onPaint: {
            const c = getContext("2d"), w = width, h = height
            c.clearRect(0, 0, w, h)
            const ink = Theme.light ? "#56736C" : "#A9C7BD"
            const soft = Theme.light ? "#A8B7A8" : "#557E79"
            const gold = Theme.light ? "#B99357" : "#D6B982"
            function line(x1,y1,x2,y2,color,lw) {
                c.strokeStyle=color; c.lineWidth=lw; c.beginPath(); c.moveTo(x1,y1); c.lineTo(x2,y2); c.stroke()
            }
            if (art.scene === "flower") {
                const cx=w*.56, cy=h*.52, r=Math.min(w,h)*.31
                c.fillStyle=Theme.light ? "#EFE1C4" : "#3E5E5C"
                c.beginPath(); c.arc(cx,cy,r,0,Math.PI*2); c.fill()
                c.strokeStyle=gold; c.lineWidth=1.2
                c.beginPath(); c.arc(cx,cy,r*.83,0,Math.PI*2); c.stroke()
                c.font="bold " + Math.round(r*.95) + "px SimSun"
                c.fillStyle=ink; c.textAlign="center"; c.textBaseline="middle"; c.fillText("花",cx,cy+3)
                for (let i=0;i<8;i++) {
                    const a=(i*43-16)*Math.PI/180, px=cx+Math.cos(a)*r*1.38, py=cy+Math.sin(a)*r*.95
                    c.fillStyle=gold; c.globalAlpha=.46
                    c.beginPath(); c.ellipse(px,py,3+i%3,7+i%4,a,0,Math.PI*2); c.fill()
                }
                c.globalAlpha=1
                line(w*.09,h*.82,w*.27,h*.35,ink,1.4)
                line(w*.27,h*.35,w*.19,h*.19,ink,1.1)
                line(w*.21,h*.49,w*.34,h*.35,ink,1.1)
            } else if (art.scene === "chain") {
                c.strokeStyle=gold; c.lineWidth=1.2
                for (let i=0;i<4;i++) {
                    const x=w*(.16+i*.17), y=h*(.27+(i%2)*.10)
                    c.beginPath(); c.moveTo(x,y)
                    c.bezierCurveTo(x+30,y-12,x+58,y+18,x+68,y+57)
                    c.stroke()
                    c.fillStyle=ink; c.globalAlpha=.85-i*.13
                    c.font="bold " + Math.round(Math.min(w,h)*.17) + "px SimSun"
                    c.fillText(["山","河","诗","行"][i],x+8,y+29)
                }
                c.globalAlpha=1
                c.strokeStyle=soft; c.lineWidth=1
                for(let j=0;j<3;j++) {
                    c.beginPath(); c.moveTo(w*.09,h*(.66+j*.07))
                    c.quadraticCurveTo(w*.50,h*(.60+j*.07),w*.91,h*(.66+j*.07)); c.stroke()
                }
            } else {
                for(let i=0;i<4;i++) {
                    const x=w*(.18+(i%2)*.33), y=h*(.23+Math.floor(i/2)*.33)
                    c.save(); c.translate(x,y); c.rotate((i%2 ? 1:-1)*.06)
                    c.fillStyle=Theme.light ? "#F7EEDC" : "#355A57"
                    c.fillRect(0,0,w*.29,h*.23)
                    c.strokeStyle=gold; c.lineWidth=1.4; c.strokeRect(0,0,w*.29,h*.23)
                    c.fillStyle=ink; c.font="bold " + Math.round(h*.13) + "px SimSun"
                    c.textAlign="center"; c.fillText(["春","江","月","夜"][i],w*.145,h*.16)
                    c.restore()
                }
                line(w*.49,h*.31,w*.53,h*.68,soft,1.1)
            }
        }
    }
}
