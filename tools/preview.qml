import QtQuick
import QtQuick.Window
import "../package/contents/ui" as Notch

// Renders README screenshots from the real Island.qml / StatsCard.qml with mock data,
// without touching anyone's screen.  Usage (see tools/render-screenshots.sh):
//   QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qml tools/preview.qml -- <idle|music|mic|card|hidden> out.png
Window {
    id: win
    readonly property var args: Qt.application.arguments
    readonly property string scene: args.length >= 2 ? args[args.length - 2] : "idle"
    readonly property string out: args.length >= 1 ? args[args.length - 1] : "preview.png"

    width: 720
    height: scene === "card" ? 340 : 72
    visible: true
    color: "#0b0b12"

    // ---- fake desktop: browser-ish tab strip under the notch, so you can see what it overlaps
    Rectangle {
        id: bar
        width: parent.width; height: 40
        color: "#1b1b24"
        Row {
            x: 10; y: 6; spacing: 6
            Repeater {
                model: ["GitHub", "Docs · Plasma", "YouTube", "KDE Store", "Arch Wiki", "Reddit", "News"]
                Rectangle {
                    required property string modelData
                    required property int index
                    width: 92; height: 28; radius: 7
                    color: index === 2 ? "#2c2c3a" : "#23232e"
                    Text {
                        anchors.centerIn: parent; text: parent.modelData
                        color: "#b9b6cc"; font.pixelSize: 11; font.family: "Inter"
                    }
                }
            }
        }
    }
    Rectangle {
        y: bar.height; width: parent.width; height: parent.height - bar.height
        gradient: Gradient {
            GradientStop { position: 0; color: "#151522" }
            GradientStop { position: 1; color: "#0b0b12" }
        }
    }

    // ---- mock of the PlasmoidItem state the visuals read
    QtObject {
        id: mock
        readonly property color cBg: "#000000"
        readonly property color cText: "#e0d4ff"
        readonly property color cDim: "#6c6c80"
        readonly property color cAccent: "#c77dff"
        readonly property color cPink: "#ff8fd8"
        readonly property color cCyan: "#5cf2ff"
        readonly property color cMic: "#ff9f43"
        readonly property color cGood: "#5cffa0"
        readonly property color cWarn: "#ffd75c"
        readonly property color cHot: "#ff5c8a"
        readonly property string monoFont: "GeistMono Nerd Font"
        readonly property int notchW: 250
        readonly property int notchH: 32
        readonly property int cardW: 380
        readonly property int fillet: 10

        readonly property var micApps: win.scene === "mic" ? ["Discord"] : []
        readonly property bool micActive: micApps.length > 0
        readonly property bool open: win.scene === "card"
        readonly property bool hidden: win.scene === "hidden"
        readonly property bool playing: win.scene === "music" || win.scene === "card"
        readonly property var player: null
        readonly property string trackTitle: playing ? "Midnight City" : ""
        readonly property string trackArtist: playing ? "M83" : ""

        readonly property bool hasGpu: true
        readonly property bool hasBattery: true
        readonly property bool hasFan: true
        readonly property bool hasSsd: true
        readonly property bool weatherOk: true
        readonly property real weatherTemp: 28
        readonly property string weatherIcon: "weather-few-clouds"
        readonly property real v_cpuTemp: 58
        readonly property real v_cpuUse: 23
        readonly property real v_gpuTemp: 47
        readonly property real v_gpuUse: 12
        readonly property real v_ramUsed: 3.4 * 1073741824
        readonly property real v_ramPct: 44
        readonly property real v_batPct: 81
        readonly property real v_batRate: 0
        readonly property real v_fan: 2400
        readonly property real v_ssdTemp: 41
        readonly property real v_uptime: 3 * 3600 + 42 * 60
        function tempColor(t) { return t >= 80 ? cHot : t >= 62 ? cWarn : cGood; }
        function loadColor(p) { return p >= 85 ? cHot : p >= 60 ? cWarn : cAccent; }
    }

    Notch.Island {
        id: island
        n: mock
        anchors.horizontalCenter: parent.horizontalCenter
    }

    // let animations settle, then save and quit
    Timer {
        interval: 1500; running: true
        onTriggered: win.contentItem.grabToImage(function (r) {
            r.saveToFile(win.out);
            console.log("saved", win.out);
            Qt.quit();
        })
    }
}
