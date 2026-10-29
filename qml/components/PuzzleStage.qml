import QtQuick
import QtQuick.Controls
import YiJuanShanHe

Item {
    id: stage
    property int turnNumber: interaction.questionNumber
    property int selectedTile: -1
    property bool draggingTile: false
    readonly property bool answering: interaction.phase === "asking"
    readonly property bool correct: interaction.roundResults.length > 0 && interaction.roundResults[interaction.roundResults.length-1].correct
    onTurnNumberChanged: selectedTile = -1
    function tileText(tileId) {
        const tiles = interaction.question.tiles || []
        for (let i=0;i<tiles.length;i++) if (tiles[i].id === tileId) return tiles[i].text
        return ""
    }
    Rectangle { anchors.fill: parent; radius: 12; color: Theme.light ? "#EDE3D0" : "#1D3D41" }
    Image {
        anchors.fill: parent
        source: Theme.light ? "qrc:/picture/canjuan_bg2.jpg" : "qrc:/picture/canjuan_bg1.jpg"
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        smooth: true
    }
    Rectangle {
        anchors.fill: parent; radius: 12
        color: Theme.light ? "#99F8F2E7" : "#C01A383B"
        border.color: Theme.borderStrong
        Behavior on color { ColorAnimation { duration: Theme.motion ? 260 : 0 } }
    }
    Text { x: 26; y: 18; text: stage.answering ? "诗句归位  /  将散句放回原卷" : "残卷复原  /  原诗已展开"; color: Theme.gold; font.family: "SimSun"; font.pixelSize: 16 }
    Text { anchors.right: parent.right; anchors.rightMargin: 26; y: 23; text: stage.answering ? "可拖动，也可先点纸笺再点卷位" : ""; color: Theme.secondary; font.pixelSize: 11 }
    Rectangle { x: 25; y: 51; width: parent.width-50; height: 1; color: Theme.line }

    Item {
        id: workbench
        x: 20; y: 64; width: parent.width-40; height: parent.height-81
        opacity: stage.answering ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: Theme.motion ? 280 : 0; easing.type: Easing.OutCubic } }
        Text { x: 8; y: 0; text: "散  句  匣"; color: Theme.gold; font.family: "SimSun"; font.pixelSize: 13 }
        Text { x: parent.width/2+17; y: 0; text: "待  复  原  卷"; color: Theme.gold; font.family: "SimSun"; font.pixelSize: 13 }
        Rectangle { x: parent.width/2; y: 3; width: 1; height: parent.height-3; color: Theme.line }
        Flickable {
            id: bank
            x: 0; y: 28; width: parent.width/2-12; height: parent.height-29
            clip: !stage.draggingTile; z: stage.draggingTile ? 5 : 0
            contentWidth: width; contentHeight: bankColumn.implicitHeight+8
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded; contentItem: Rectangle { implicitWidth: 3; radius: 2; color: Theme.borderStrong } }
            Column {
                id: bankColumn; width: parent.width-6; spacing: 7
                Repeater {
                    model: interaction.question.tiles || []
                    delegate: Rectangle {
                        id: piece
                        required property var modelData
                        property int tileId: modelData.id
                        visible: (interaction.question.slots || []).indexOf(tileId) < 0
                        width: bankColumn.width; height: Math.max(52, pieceText.implicitHeight+18)
                        radius: 5
                        color: stage.selectedTile === tileId ? (Theme.light ? "#E8D8B4" : "#486964")
                              : (pieceMouse.containsMouse ? (Theme.light ? "#FFFDF7" : "#365B58")
                                                         : (Theme.light ? "#F7F0E2" : "#2C5150"))
                        border.color: stage.selectedTile === tileId ? Theme.borderStrong : Theme.border
                        z: pieceMouse.drag.active ? 20 : 0
                        scale: pieceMouse.drag.active ? 1.035 : 1
                        Behavior on scale { NumberAnimation { duration: Theme.motion ? 150 : 0 } }
                        Drag.active: pieceMouse.drag.active
                        Drag.source: piece
                        Drag.keys: ["versePiece"]
                        Drag.hotSpot.x: width/2; Drag.hotSpot.y: height/2
                        Text {
                            id: pieceText; x: 13; y: 9; width: parent.width-26
                            text: piece.modelData.text; color: Theme.text; font.family: "SimSun"
                            font.pixelSize: 15; wrapMode: Text.Wrap; lineHeight: 1.25
                        }
                        MouseArea {
                            id: pieceMouse; anchors.fill: parent; hoverEnabled: true
                            drag.target: piece; preventStealing: true; cursorShape: Qt.OpenHandCursor
                            onPressed: stage.draggingTile = true
                            onClicked: stage.selectedTile = piece.tileId
                            onReleased: Qt.callLater(function() { piece.x=0; piece.y=0; stage.draggingTile=false })
                            onCanceled: { piece.x=0; piece.y=0; stage.draggingTile=false }
                        }
                    }
                }
            }
        }
        Flickable {
            x: parent.width/2+15; y: 28; width: parent.width/2-15; height: parent.height-29
            clip: true; contentWidth: width; contentHeight: slotColumn.implicitHeight+8
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded; contentItem: Rectangle { implicitWidth: 3; radius: 2; color: Theme.borderStrong } }
            Column {
                id: slotColumn; width: parent.width-5; spacing: 7
                Repeater {
                    model: interaction.question.slotCount || 0
                    delegate: Rectangle {
                        id: target
                        required property int index
                        property int placedId: (interaction.question.slots || [])[index]
                        width: slotColumn.width; height: Math.max(52, slotText.implicitHeight+19)
                        radius: 5
                        color: slotDrop.containsDrag ? (Theme.light ? "#E8D8B4" : "#496B64")
                             : placedId >= 0 ? (Theme.light ? "#FFFCF5" : "#315451")
                                             : (Theme.light ? "#EDE4D2" : "#2A4948")
                        border.color: slotDrop.containsDrag ? Theme.gold : Theme.border
                        border.width: slotDrop.containsDrag ? 2 : 1
                        Behavior on color { ColorAnimation { duration: Theme.motion ? 180 : 0 } }
                        Text { x: 12; y: 16; text: String(target.index+1).padStart(2,"0"); color: Theme.gold; font.family: "Georgia"; font.pixelSize: 11 }
                        Text {
                            id: slotText; x: 43; y: 10; width: parent.width-53
                            text: stage.tileText(target.placedId) || "轻点或拖入诗句"
                            color: target.placedId >= 0 ? Theme.text : Theme.secondary
                            font.family: "SimSun"; font.pixelSize: 15; wrapMode: Text.Wrap; lineHeight: 1.25
                        }
                        DropArea {
                            id: slotDrop; anchors.fill: parent; keys: ["versePiece"]
                            onDropped: function(drop) {
                                if (drop.source) {
                                    interaction.placePiece(drop.source.tileId, target.index)
                                    stage.selectedTile = -1
                                }
                            }
                        }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (stage.selectedTile >= 0) {
                                    interaction.placePiece(stage.selectedTile,target.index)
                                    stage.selectedTile=-1
                                } else if (target.placedId >= 0) interaction.removePiece(target.index)
                            }
                        }
                    }
                }
            }
        }
    }
    Flickable {
        x: 42; y: 65; width: parent.width-84; height: parent.height-83
        opacity: stage.answering ? 0 : 1
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: Theme.motion ? 360 : 0; easing.type: Easing.OutCubic } }
        contentWidth: width; contentHeight: restored.implicitHeight+22
        clip: true; boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded; contentItem: Rectangle { implicitWidth: 3; radius: 2; color: Theme.borderStrong } }
        Column {
            id: restored; width: parent.width; spacing: 12
            Text { width: parent.width; text: interaction.feedback; color: Theme.gold; font.family: "SimSun"; font.pixelSize: 19; wrapMode: Text.Wrap }
            Text { width: parent.width; text: "《"+(interaction.question.poemTitle||"")+"》"; color: Theme.text; font.family: "SimSun"; font.pixelSize: 24; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap }
            Rectangle { width: parent.width; height: poemText.implicitHeight+34; radius: 6; color: Theme.light ? "#FFFCF5" : "#2A4B4D"; border.color: Theme.borderStrong
                Text { id: poemText; x: 18; y: 16; width: parent.width-36; text: interaction.question.fullPoem || ""; color: Theme.text; font.family: "SimSun"; font.pixelSize: 17; lineHeight: 1.55; wrapMode: Text.Wrap; horizontalAlignment: Text.AlignHCenter }
            }
            Rectangle { width: parent.width; height: 1; color: Theme.line }
            Text { text: interaction.question.backgroundLabel || "资料"; color: Theme.gold; font.family: "SimSun"; font.pixelSize: 13 }
            Text { width: parent.width; text: interaction.question.background || "现有资料未收录这首诗的背景介绍。"; color: Theme.secondary; font.family: "Microsoft YaHei UI"; font.pixelSize: 12; wrapMode: Text.Wrap; lineHeight: 1.45 }
        }
    }
    function submitCurrent() { interaction.submitPuzzle() }
}
