import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import org.kde.kirigami as Kirigami

// The visible notch: collapsed pill + expanded stats card.
// Pure visuals; all state comes from `n` (the PlasmoidItem in main.qml, or a mock in tools/preview.qml).
Item {
    id: island
    property var n
    // slides up out of sight while the mouse is near it, so tabs underneath are visible
    y: n.hidden ? -(height + 24) : 0
    opacity: n.hidden ? 0 : 1
    Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: 180 } }
    width: n.open ? n.cardW : n.notchW + (n.micActive ? 30 : 0)
    height: n.open ? cardContent.implicitHeight : n.notchH
    Behavior on width  { NumberAnimation { duration: 420; easing.type: Easing.OutBack; easing.overshoot: 0.9 } }
    Behavior on height { NumberAnimation { duration: 420; easing.type: Easing.OutBack; easing.overshoot: 0.9 } }

    // look of the edge: violet idle, pink with music, pulsing orange with mic
    property real r: n.open ? 26 : 14
    Behavior on r { NumberAnimation { duration: 300 } }
    readonly property color rimColor: Qt.lighter(n.micActive ? n.cMic : (n.playing ? n.cPink : n.cAccent), 1.25)
    readonly property real rimAlpha: n.micActive ? (0.45 + 0.55 * pulse.v) : (n.playing ? 0.95 : 0.85)

    // one continuous shape: concave shoulders + body, black fill, even accent rim, soft glow
    Shape {
        id: outline
        readonly property real f: n.fillet
        readonly property real w: island.width
        readonly property real h: island.height
        readonly property real rr: Math.min(island.r, island.height - n.fillet)
        x: -f; y: 0
        width: w + 2 * f; height: h + 2
        preferredRendererType: Shape.CurveRenderer
        layer.enabled: true
        layer.samples: 4
        layer.effect: MultiEffect {
            autoPaddingEnabled: true
            shadowEnabled: true
            shadowColor: island.rimColor
            shadowBlur: 0.5
            shadowOpacity: 0.35 * island.rimAlpha
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 0
        }
        ShapePath {
            fillColor: n.cBg
            strokeColor: Qt.rgba(island.rimColor.r, island.rimColor.g, island.rimColor.b, island.rimAlpha)
            strokeWidth: 1
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            startX: 0; startY: 0
            PathArc  { x: outline.f; y: outline.f; radiusX: outline.f; radiusY: outline.f; direction: PathArc.Clockwise }
            PathLine { x: outline.f; y: outline.h - outline.rr }
            PathArc  { x: outline.f + outline.rr; y: outline.h; radiusX: outline.rr; radiusY: outline.rr; direction: PathArc.Counterclockwise }
            PathLine { x: outline.f + outline.w - outline.rr; y: outline.h }
            PathArc  { x: outline.f + outline.w; y: outline.h - outline.rr; radiusX: outline.rr; radiusY: outline.rr; direction: PathArc.Counterclockwise }
            PathLine { x: outline.f + outline.w; y: outline.f }
            PathArc  { x: outline.w + 2 * outline.f; y: 0; radiusX: outline.f; radiusY: outline.f; direction: PathArc.Clockwise }
            // left open along the top edge, so no line is drawn against the screen edge
        }
    }

    // content container (clips content to the rounded body)
    Rectangle {
        anchors.fill: parent
        color: "transparent"
        topLeftRadius: 0; topRightRadius: 0
        bottomLeftRadius: island.r
        bottomRightRadius: island.r
        clip: true

        // ------------- collapsed content -------------
        Item {
            id: collapsed
            anchors.fill: parent
            opacity: n.open ? 0 : 1
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 180 } }

            // camera lens
            Rectangle {
                anchors.centerIn: parent
                width: 10; height: 10; radius: 5
                color: "#06060b"; border.color: "#161624"; border.width: 1
                Rectangle { x: 2.5; y: 2.5; width: 3; height: 3; radius: 1.5; color: "#2b3c70" }
            }

            // left: clock, or mic indicator
            Item {
                anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter }
                width: parent.width / 2 - 26; height: parent.height
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Qt.formatTime(clock.now, "hh:mm")
                    color: n.cText; font.family: n.monoFont; font.pixelSize: 12; font.weight: Font.Medium
                    opacity: n.micActive ? 0 : 1
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                }
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6
                    opacity: n.micActive ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                    Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 7; height: 7; radius: 3.5; color: n.cMic; opacity: pulse.v }
                    Kirigami.Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 16; height: 16
                        source: "audio-input-microphone-symbolic"; color: n.cMic; isMask: true
                    }
                }
            }

            // right: mic app / equalizer / weather (or CPU temp)
            Item {
                anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
                width: parent.width / 2 - 26; height: parent.height

                Text {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    width: parent.width; horizontalAlignment: Text.AlignRight; elide: Text.ElideRight
                    text: n.micApps.length > 1 ? n.micApps.length + " apps" : (n.micApps[0] || "")
                    color: n.cMic; font.family: n.monoFont; font.pixelSize: 11
                    opacity: n.micActive ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                }
                Equalizer {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    n: island.n; active: n.playing && !n.micActive && !n.open
                    opacity: n.playing && !n.micActive ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                }
                // weather: icon + temperature for the configured city
                Row {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    spacing: 5
                    opacity: !n.playing && !n.micActive && n.weatherOk ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                    Kirigami.Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 16; height: 16
                        source: n.weatherIcon || ""
                    }
                    Text {
                        text: n.weatherOk ? Math.round(n.weatherTemp) + "°" : ""
                        color: n.cText; font.family: n.monoFont; font.pixelSize: 12; font.weight: Font.Medium
                    }
                }
                // fallback when no city is set (or weather is unreachable): CPU temperature
                Row {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    spacing: 5
                    opacity: !n.playing && !n.micActive && !n.weatherOk ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                    Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 6; height: 6; radius: 3; color: n.tempColor(n.v_cpuTemp) }
                    Text {
                        text: n.v_cpuTemp > 0 ? Math.round(n.v_cpuTemp) + "°" : "--°"
                        color: n.cText; font.family: n.monoFont; font.pixelSize: 12; font.weight: Font.Medium
                    }
                }
            }
        }

        // ------------- expanded card -------------
        StatsCard {
            id: cardContent
            n: island.n
            width: n.cardW
            anchors.horizontalCenter: parent.horizontalCenter
            y: 0
            opacity: n.open ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 260 } }
        }
    }

    // ---------- clock ----------
    Timer {
        id: clock
        property date now: new Date()
        interval: n.open ? 1000 : 10000; repeat: true; running: true; triggeredOnStart: true
        onTriggered: now = new Date()
    }

    // shared pulse for mic dot + glow
    QtObject {
        id: pulse
        property real v: 1
        property SequentialAnimation anim: SequentialAnimation {
            running: n.micActive
            loops: Animation.Infinite
            NumberAnimation { target: pulse; property: "v"; from: 1; to: 0.35; duration: 900; easing.type: Easing.InOutSine }
            NumberAnimation { target: pulse; property: "v"; from: 0.35; to: 1; duration: 900; easing.type: Easing.InOutSine }
            onStopped: pulse.v = 1
        }
    }
}
