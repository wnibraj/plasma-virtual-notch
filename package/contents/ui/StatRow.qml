import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

RowLayout {
    id: row
    property var n                    // the notch PlasmoidItem (palette)
    property string icon
    property string label
    property string value
    property real fraction: -1        // 0..1 → bar; <0 → no bar
    property color tint: n.cAccent

    spacing: Kirigami.Units.largeSpacing
    Layout.fillWidth: true

    Kirigami.Icon {
        source: row.icon; color: row.tint; isMask: true
        Layout.preferredWidth: Kirigami.Units.iconSizes.small
        Layout.preferredHeight: Kirigami.Units.iconSizes.small
    }
    Text {
        text: row.label; color: row.n.cDim; font.pixelSize: 12
        Layout.preferredWidth: Kirigami.Units.gridUnit * 4.5
    }
    Item {
        Layout.fillWidth: true
        Layout.preferredHeight: 4
        opacity: row.fraction >= 0 ? 1 : 0
        Rectangle { anchors.fill: parent; radius: 2; color: "#1a1a24" }
        Rectangle {
            width: parent.width * Math.max(0, Math.min(1, row.fraction))
            height: parent.height; radius: 2; color: row.tint
            Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
        }
    }
    Text {
        text: row.value; color: row.n.cText
        font.family: row.n.monoFont; font.pixelSize: 12
        horizontalAlignment: Text.AlignRight
        Layout.preferredWidth: Kirigami.Units.gridUnit * 4.5
    }
}
