import QtQuick
import QtQuick.Window
import QtQuick.Shapes
import "../package/contents/ui" as Notch

// Scripted demo for the README GIF: renders the real Island.qml while a fake cursor
// goes for a browser tab under the notch, opens the stats card, and a mic turns on.
// Frames are written to <outDir>/frame-NNNN.png; tools/render-demo-gif.sh stitches them.
//   QT_QPA_PLATFORM=offscreen ... qml tools/demo.qml -- <outDir>
Window {
    id: win
    readonly property string outDir: Qt.application.arguments[Qt.application.arguments.length - 1]
    readonly property int duration: 12500
    readonly property int fps: 25

    width: 720; height: 330
    visible: true
    color: "#0b0b12"

    // ------------------------------------------------------------------ timeline
    property real t: 0
    NumberAnimation on t { from: 0; to: win.duration; duration: win.duration; running: true }

    // cursor keyframes: [time ms, x, y]
    readonly property var keys: [
        [0, 600, 250], [700, 600, 250],
        [1700, 340, 22], [3300, 340, 22],          // onto the "KDE Store" tab under the notch (click at 2500)
        [4100, 330, 215], [4600, 330, 215],         // away -> notch comes back
        [5300, 360, 0], [6400, 360, 0],             // push to top edge -> card opens
        [7100, 395, 170], [8300, 395, 170],         // read the card
        [9100, 640, 270], [win.duration, 640, 270]  // leave -> collapses; mic turns on at 9800
    ]
    function ease(p) { return p < 0.5 ? 4 * p * p * p : 1 - Math.pow(-2 * p + 2, 3) / 2; }
    function at(time) {
        for (let i = 1; i < keys.length; i++) {
            const a = keys[i - 1], b = keys[i];
            if (time <= b[0]) {
                const p = b[0] === a[0] ? 1 : ease((time - a[0]) / (b[0] - a[0]));
                return Qt.point(a[1] + (b[1] - a[1]) * p, a[2] + (b[2] - a[2]) * p);
            }
        }
        const l = keys[keys.length - 1]; return Qt.point(l[1], l[2]);
    }
    readonly property point cur: at(t)

    // same zones as kwin-script/contents/code/main.js
    property int level: 0
    onCurChanged: {
        const dx = Math.abs(cur.x - width / 2), dy = cur.y;
        let now = 0;
        if (dy <= 1 && dx <= 130) now = 3;
        else if ((level === 3 || level === 2) && dy <= 470 && dx <= 195) now = 2;
        else if (dy <= 48 && dx <= 160) now = 1;
        if (now !== level) {
            level = now;
            if (now === 3) { if (!mock.open) dwell.restart(); }
            else if (now === 2) dwell.stop();
            else { dwell.stop(); mock.open = false; }
        }
    }
    Timer { id: dwell; interval: 600; onTriggered: if (win.level === 3) mock.open = true }

    property int activeTab: 2
    onTChanged: {
        if (t >= 2500 && activeTab === 2) { activeTab = 3; ripple.go(); }
        mock.micApps = (t >= 9800 && t < 12200) ? ["Discord"] : [];
    }

    // ------------------------------------------------------------------ fake desktop
    Rectangle {
        id: bar
        width: parent.width; height: 40
        color: "#1b1b24"
        Row {
            x: 10; y: 6; spacing: 6
            Repeater {
                model: ["GitHub", "Docs · Plasma", "YouTube", "KDE Store", "Arch Wiki", "Reddit", "News"]
                Rectangle {
                    id: tab
                    required property string modelData
                    required property int index
                    readonly property bool hovered: win.cur.y < 40 && win.cur.x >= tab.x + 10 && win.cur.x < tab.x + 10 + width
                    width: 92; height: 28; radius: 7
                    color: index === win.activeTab ? "#34344a" : (hovered ? "#2a2a38" : "#23232e")
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Text {
                        anchors.centerIn: parent; text: parent.modelData
                        color: tab.index === win.activeTab ? "#ffffff" : "#b9b6cc"
                        font.pixelSize: 11; font.family: "Inter"
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
        Text {
            anchors { left: parent.left; bottom: parent.bottom; margins: 14 }
            color: "#8a87a3"; font.pixelSize: 12; font.family: "Inter"
            text: win.t < 4300 ? "mouse near the notch → it slides away, tabs stay clickable"
                 : win.t < 9000 ? "push to the top edge → stats card"
                 : "mic in use → orange + app name"
        }
    }

    // ------------------------------------------------------------------ the notch (real code)
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

        property var micApps: []
        readonly property bool micActive: micApps.length > 0
        property bool open: false
        readonly property bool hidden: win.level === 1 && !open
        readonly property bool playing: false
        readonly property var player: null
        readonly property string trackTitle: ""
        readonly property string trackArtist: ""

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
    Notch.Island { n: mock; anchors.horizontalCenter: parent.horizontalCenter }

    // ------------------------------------------------------------------ fake cursor
    Rectangle {
        id: ripple
        property real s: 0
        function go() { rip.restart(); }
        x: win.cur.x - width / 2; y: win.cur.y - height / 2
        width: 34 * s; height: width; radius: width / 2
        color: "transparent"; border.color: "#ffffff"; border.width: 2
        opacity: 1 - s
        NumberAnimation on s { id: rip; from: 0; to: 1; duration: 450; running: false }
    }
    Shape {
        x: win.cur.x; y: win.cur.y
        width: 14; height: 21
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: "#ffffff"; strokeColor: "#000000"; strokeWidth: 1.2
            joinStyle: ShapePath.RoundJoin
            startX: 0; startY: 0
            PathLine { x: 0; y: 17 }
            PathLine { x: 4.2; y: 13.2 }
            PathLine { x: 7; y: 19.5 }
            PathLine { x: 9.6; y: 18.4 }
            PathLine { x: 6.9; y: 12.3 }
            PathLine { x: 12.4; y: 12.3 }
            PathLine { x: 0; y: 0 }
        }
    }

    // ------------------------------------------------------------------ frame capture
    property int frame: 0
    property int pending: 0
    Timer {
        interval: 1000 / win.fps; repeat: true; running: true
        onTriggered: {
            if (win.t >= win.duration) { running = false; if (win.pending === 0) Qt.quit(); return; }
            const name = win.outDir + "/frame-" + String(win.frame++).padStart(4, "0") + ".png";
            win.pending++;
            win.contentItem.grabToImage(function (r) {
                r.saveToFile(name);
                if (--win.pending === 0 && win.t >= win.duration) Qt.quit();
            });
        }
    }
}
