import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Item {
    id: card
    property var n                    // the notch PlasmoidItem

    implicitWidth: Kirigami.Units.gridUnit * 20
    implicitHeight: col.implicitHeight + Kirigami.Units.largeSpacing * 3
    Layout.preferredWidth: implicitWidth
    Layout.preferredHeight: implicitHeight
    Layout.minimumWidth: implicitWidth
    Layout.minimumHeight: implicitHeight

    function fmtUptime(sec) {
        sec = Math.floor(sec);
        const d = Math.floor(sec / 86400), h = Math.floor(sec % 86400 / 3600), m = Math.floor(sec % 3600 / 60);
        return (d ? d + "d " : "") + h + "h " + m + "m";
    }

    Timer {
        id: clock
        property date now: new Date()
        interval: 1000; repeat: true; triggeredOnStart: true
        running: card.visible
        onTriggered: now = new Date()
    }

    ColumnLayout {
        id: col
        anchors { fill: parent; margins: Kirigami.Units.largeSpacing * 1.5 }
        spacing: Kirigami.Units.mediumSpacing

        RowLayout {
            Layout.fillWidth: true
            ColumnLayout {
                spacing: 0
                Text { text: Qt.formatTime(clock.now, "hh:mm"); color: card.n.cText; font.family: card.n.monoFont; font.pixelSize: 26; font.weight: Font.DemiBold }
                Text { text: Qt.formatDate(clock.now, "dddd, d MMMM"); color: card.n.cDim; font.pixelSize: 11 }
            }
            Item { Layout.fillWidth: true }
            Rectangle {
                radius: height / 2
                color: card.n.micActive ? Qt.rgba(1, 0.62, 0.26, 0.15) : "#14141c"
                implicitHeight: micRow.implicitHeight + 8
                implicitWidth: micRow.implicitWidth + 16
                Row {
                    id: micRow
                    anchors.centerIn: parent
                    spacing: 6
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 7; height: 7; radius: 3.5
                        color: card.n.micActive ? card.n.cMic : card.n.cDim
                    }
                    Text {
                        text: card.n.micActive ? "Mic: " + card.n.micApps.join(", ") : "Mic off"
                        color: card.n.micActive ? card.n.cMic : card.n.cDim
                        font.pixelSize: 11; font.family: card.n.monoFont
                        elide: Text.ElideRight
                        width: Math.min(implicitWidth, Kirigami.Units.gridUnit * 8)
                    }
                }
            }
        }

        // now playing
        RowLayout {
            Layout.fillWidth: true
            visible: card.n.trackTitle !== ""
            spacing: Kirigami.Units.largeSpacing
            Rectangle {
                Layout.preferredWidth: 34; Layout.preferredHeight: 34; radius: 8; color: "#14141c"; clip: true
                Image {
                    anchors.fill: parent
                    source: card.n.player && card.n.player.artUrl ? card.n.player.artUrl : ""
                    fillMode: Image.PreserveAspectCrop; asynchronous: true
                    sourceSize.width: 68; sourceSize.height: 68
                }
                Kirigami.Icon {
                    anchors.centerIn: parent; width: 16; height: 16
                    visible: !(card.n.player && card.n.player.artUrl)
                    source: "media-playback-start-symbolic"; color: card.n.cAccent; isMask: true
                }
            }
            ColumnLayout {
                Layout.fillWidth: true; spacing: 0
                Text { Layout.fillWidth: true; text: card.n.trackTitle; color: card.n.cText; font.pixelSize: 12; font.weight: Font.DemiBold; elide: Text.ElideRight }
                Text { Layout.fillWidth: true; text: card.n.trackArtist; color: card.n.cDim; font.pixelSize: 11; elide: Text.ElideRight; visible: text !== "" }
            }
            Equalizer { n: card.n; active: card.n.playing && card.visible; opacity: card.n.playing ? 1 : 0.3 }
        }

        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: "#1a1a24" }

        StatRow { n: card.n; icon: "cpu-symbolic"; label: "CPU temp"
            value: Math.round(card.n.v_cpuTemp) + " °C"; fraction: card.n.v_cpuTemp / 100; tint: card.n.tempColor(card.n.v_cpuTemp) }
        StatRow { n: card.n; icon: "cpu-symbolic"; label: "CPU load"
            value: Math.round(card.n.v_cpuUse) + " %"; fraction: card.n.v_cpuUse / 100; tint: card.n.loadColor(card.n.v_cpuUse) }
        StatRow { n: card.n; icon: "video-display-symbolic"; label: "GPU temp"; visible: card.n.hasGpu
            value: card.n.v_gpuTemp > 0 ? Math.round(card.n.v_gpuTemp) + " °C" : "sleeping"
            fraction: card.n.v_gpuTemp / 100; tint: card.n.tempColor(card.n.v_gpuTemp) }
        StatRow { n: card.n; icon: "video-display-symbolic"; label: "GPU load"; visible: card.n.hasGpu
            value: Math.round(card.n.v_gpuUse) + " %"; fraction: card.n.v_gpuUse / 100; tint: card.n.loadColor(card.n.v_gpuUse) }
        StatRow { n: card.n; icon: "memory-symbolic"; label: "RAM"
            value: (card.n.v_ramUsed / 1073741824).toFixed(1) + " GB"; fraction: card.n.v_ramPct / 100; tint: card.n.loadColor(card.n.v_ramPct) }
        StatRow { n: card.n; icon: "drive-harddisk-symbolic"; label: "SSD temp"; visible: card.n.hasSsd
            value: Math.round(card.n.v_ssdTemp) + " °C"; fraction: card.n.v_ssdTemp / 90; tint: card.n.tempColor(card.n.v_ssdTemp + 10) }
        StatRow { n: card.n; icon: "battery-symbolic"; label: "Battery"; visible: card.n.hasBattery
            value: Math.round(card.n.v_batPct) + " %" + (card.n.v_batRate > 0.5 ? " ⚡" : "")
            fraction: card.n.v_batPct / 100; tint: card.n.v_batPct < 20 ? card.n.cHot : card.n.cGood }
        StatRow { n: card.n; icon: "speedometer-symbolic"; label: "Fan"; visible: card.n.hasFan
            value: Math.round(card.n.v_fan) + " rpm"; fraction: card.n.v_fan / 6000; tint: card.n.cAccent }
        StatRow { n: card.n; icon: "clock-symbolic"; label: "Uptime"
            value: card.fmtUptime(card.n.v_uptime) }
    }
}
