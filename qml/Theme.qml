pragma Singleton
import QtQuick

QtObject {
    id: palette
    property string name: "月白"
    property bool motion: true
    readonly property bool light: name === "月白"

    // Shared surfaces and typography for every page.
    property color background: light ? "#EEE9DD" : "#112F34"
    property color sidebar: light ? "#E5DDCE" : "#0C272D"
    property color topbar: light ? "#F8F3E8" : "#1B3D41"
    property color surface: light ? "#F8F4EB" : "#1D4146"
    property color card: light ? "#FFFCF5" : "#31575A"
    property color cardAlt: light ? "#EBE2D3" : "#25494D"
    property color field: light ? "#FFFDF8" : "#214449"
    property color paper: light ? "#FFFCF6" : "#F2EEE5"
    property color paperAlt: light ? "#F0E8D9" : "#E6DFD2"
    property color text: light ? "#354747" : "#F2F0E7"
    property color secondary: light ? "#586C66" : "#C4D2CD"
    property color subtle: light ? "#62716A" : "#B4CAC2"
    property color paperInk: "#354747"
    property color paperMuted: "#536761"
    property color paperGold: "#76572F"
    property color gold: light ? "#8E6833" : "#CDB487"
    property color goldDark: light ? "#76572F" : "#B99D6B"
    property color goldLight: light ? "#E8D6B2" : "#DECA9F"
    property color goldWash: light ? "#F3E9D4" : "#4B5047"
    property color border: light ? "#D9CBB4" : "#56767A"
    property color borderStrong: light ? "#D5BC8C" : "#A48D68"
    property color line: light ? "#DFD0B5" : "#587579"
    property color selected: light ? "#E9D9BB" : "#406366"
    property color hover: light ? "#F0E5CF" : "#3A6062"
    property color accent: light ? "#375B5A" : "#3E6564"
    property color accentHover: light ? "#4D6D69" : "#517774"
    property color accentText: "#F9F5EC"
    property color danger: light ? "#A35F50" : "#DF9A8E"
    property color success: light ? "#517B6D" : "#A9CBB7"
    readonly property color previewSmoke: "#25494C"
    readonly property color previewMoon: "#FFFCF5"

    // The home landscape has its own two painted palettes.
    property color heroSkyTop: light ? "#F6F1E6" : "#24474C"
    property color heroSkyMiddle: light ? "#E6ECE3" : "#31575B"
    property color heroSkyBottom: light ? "#C8D6CF" : "#18383D"
    property color heroFar: light ? "#B8C9BE" : "#648582"
    property color heroMiddle: light ? "#91ACA4" : "#436A6C"
    property color heroNear: light ? "#668E87" : "#31575B"
    property color heroFront: light ? "#426C69" : "#1D4147"
    property color heroMoon: light ? "#F7E9CB" : "#F2EBDC"
    property color heroMist: light ? "#EDEFE4" : "#D7E1D6"
    property color heroVeilLeft: light ? "#DDF8F4EA" : "#C11B3D43"
    property color heroVeilMiddle: light ? "#33F2EDE0" : "#40153740"
    property color heroVeilRight: light ? "#00F3EDE0" : "#0613262B"
    readonly property string heroWaterStart: light ? "rgba(72,106,97,0)" : "rgba(22,55,64,0)"
    readonly property string heroWaterEnd: light ? "rgba(42,81,77,.34)" : "rgba(4,24,33,.66)"
    readonly property string heroTexture: light ? "rgba(250,246,235,.32)" : "rgba(193,211,200,.10)"
    readonly property string heroMistStart: light ? "rgba(255,252,241,.44)" : "rgba(218,230,218,.24)"
    readonly property string heroMistEnd: light ? "rgba(255,252,241,0)" : "rgba(218,230,218,0)"
    readonly property string imageryLinkActive: light ? "rgba(155,117,61,0.88)" : "rgba(231,199,135,0.88)"
    readonly property string imageryLink: light ? "rgba(155,117,61,0.46)" : "rgba(196,172,123,0.39)"
    readonly property string imageryNode: light ? "rgba(155,117,61,0.8)" : "rgba(230,199,137,0.75)"

    Behavior on background { ColorAnimation { duration: palette.motion ? 320 : 0 } }
    Behavior on sidebar { ColorAnimation { duration: palette.motion ? 320 : 0 } }
    Behavior on topbar { ColorAnimation { duration: palette.motion ? 320 : 0 } }
    Behavior on card { ColorAnimation { duration: palette.motion ? 320 : 0 } }
    Behavior on surface { ColorAnimation { duration: palette.motion ? 320 : 0 } }
    Behavior on cardAlt { ColorAnimation { duration: palette.motion ? 320 : 0 } }
    Behavior on field { ColorAnimation { duration: palette.motion ? 320 : 0 } }
    Behavior on paper { ColorAnimation { duration: palette.motion ? 320 : 0 } }
    Behavior on paperAlt { ColorAnimation { duration: palette.motion ? 320 : 0 } }
    Behavior on text { ColorAnimation { duration: palette.motion ? 320 : 0 } }
    Behavior on secondary { ColorAnimation { duration: palette.motion ? 320 : 0 } }
    Behavior on gold { ColorAnimation { duration: palette.motion ? 320 : 0 } }
    Behavior on border { ColorAnimation { duration: palette.motion ? 320 : 0 } }
    Behavior on selected { ColorAnimation { duration: palette.motion ? 320 : 0 } }
    Behavior on heroSkyTop { ColorAnimation { duration: palette.motion ? 500 : 0 } }
    Behavior on heroSkyMiddle { ColorAnimation { duration: palette.motion ? 500 : 0 } }
    Behavior on heroSkyBottom { ColorAnimation { duration: palette.motion ? 500 : 0 } }
}
