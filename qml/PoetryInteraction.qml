import QtQuick
import YiJuanShanHe

Item {
    id: page
    property bool showMistakes: false
    property int roundLength: 10
    property double startedAt: 0
    property int durationSeconds: 0
    property string lastMode: "chain"

    function begin(mode) {
        const started = mode === "puzzle" ? interaction.startPuzzle("simple", roundLength)
                                          : interaction.start(mode, roundLength)
        if (started) {
            startedAt = Date.now()
            durationSeconds = 0
            lastMode = mode
            showMistakes = false
        }
    }
    function beginRetry() {
        if (interaction.startRetry()) {
            startedAt = Date.now()
            durationSeconds = 0
            lastMode = "retry"
            showMistakes = false
        }
    }
    function advanceRound() { interaction.advance() }
    function returnLobby() { interaction.abort() }
    function again() {
        const replayMode = lastMode
        interaction.abort()
        if (replayMode === "retry") beginRetry()
        else begin(replayMode)
    }
    onShowMistakesChanged: if (showMistakes && interaction.phase !== "idle") interaction.abort()
    Connections {
        target: interaction
        function onStateChanged() {
            if (interaction.phase === "asking" && page.startedAt === 0) page.startedAt = Date.now()
            if (interaction.phase === "finished" && page.startedAt > 0)
                page.durationSeconds = Math.max(1,Math.round((Date.now()-page.startedAt)/1000))
            if (interaction.phase === "idle") page.startedAt = 0
        }
    }
    Component.onCompleted: {
        if (interaction.phase === "asking" || interaction.phase === "feedback") startedAt = Date.now()
    }

    InteractionLobby {
        anchors.fill: parent
        roundLength: page.roundLength
        showMistakes: page.showMistakes
        opacity: interaction.phase === "idle" ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: Theme.motion ? 260 : 0 } }
        onChooseLength: function(count) { page.roundLength = count }
        onBegin: function(mode) { page.begin(mode) }
        onRetry: page.beginRetry()
    }
    InteractionStage {
        anchors.fill: parent
        opacity: interaction.phase === "asking" || interaction.phase === "feedback" ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: Theme.motion ? 260 : 0 } }
        onBack: page.returnLobby()
        onAdvanceRequested: page.advanceRound()
    }
    InteractionResult {
        anchors.fill: parent
        durationSeconds: page.durationSeconds
        opacity: interaction.phase === "finished" ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: Theme.motion ? 320 : 0 } }
        onReplayRequested: page.again()
        onLobbyRequested: page.returnLobby()
    }
}
