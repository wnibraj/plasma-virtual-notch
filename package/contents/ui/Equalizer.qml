import QtQuick

// Small animated equalizer shown while music is playing. Only animates when `active`.
Row {
    id: eq
    property var n
    property bool active: false
    property int bars: 5
    spacing: 3
    height: 16

    Repeater {
        model: eq.bars
        Rectangle {
            required property int index
            property real level: 0.3
            anchors.verticalCenter: parent.verticalCenter
            width: 3
            radius: 1.5
            height: Math.max(3, eq.height * level)
            color: [eq.n.cAccent, eq.n.cPink, eq.n.cCyan, eq.n.cPink, eq.n.cAccent][index % 5]
            Behavior on height { NumberAnimation { duration: 160; easing.type: Easing.OutQuad } }
            Timer {
                interval: 170 + index * 23
                repeat: true
                running: eq.active && eq.visible
                onTriggered: parent.level = 0.2 + Math.random() * 0.8
                onRunningChanged: if (!running) parent.level = 0.3
            }
        }
    }
}
