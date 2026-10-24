pragma ComponentBehavior: Bound
import QtQuick
import qs.colors
import qs.modules.lock
import qs.services as Services

// An app riding the launcher's wheel (LauncherDial): its icon on the rim,
// swelling as it nears the pointer; its name beside it once it's well off
// the pointer (the one at the pointer has its name set large); a terminal's
// prompt on an app that runs in one; and, while nothing is searched, the
// first letter of each run of names on the band inside the rim, like the
// letters round an index dial.
Item {
    id: item

    required property var modelData
    required property int index
    required property LauncherDial dial
    property bool hovered: false

    readonly property real angle: dial.angleOf(index)
    readonly property real away: Math.abs(angle)
    readonly property real rad: angle * Math.PI / 180
    // 1 at the pointer, 0 a couple of apps off.
    readonly property real near: Math.max(0, 1 - away / (dial.step * 1.7))
    readonly property real size: 36 + 40 * near

    readonly property string initial: String(modelData.name[0] ?? "").toUpperCase()
    readonly property bool leads: dial.query.length === 0 && (index === 0 || String(dial.results[index - 1].name[0] ?? "").toUpperCase() !== initial)

    visible: away < 96
    x: dial.cx + dial.track * Math.cos(rad) - size / 2
    y: dial.cy + dial.track * Math.sin(rad) - size / 2
    width: size
    height: size
    z: near
    // Fading out towards the ends of the arc.
    opacity: Math.max(0, Math.min(1, (94 - away) / 34)) * dial.settled

    Image {
        anchors.fill: parent
        source: Services.AppRegistry.iconForDesktopIcon(item.modelData.icon)
        sourceSize: Qt.size(128, 128)
        asynchronous: true
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
        scale: item.hovered && item.index !== item.dial.current ? 1.18 : 1

        Behavior on scale {
            NumberAnimation {
                duration: 140
                easing.type: Easing.OutCubic
            }
        }
    }

    // Runs in a terminal.
    Rectangle {
        visible: item.modelData.terminal
        x: item.width - width * 0.8
        y: item.height - height * 0.8
        width: Math.round(12 + 6 * item.near)
        height: width
        radius: width * 0.3
        color: Colors.surface_container_highest
        border.width: 1
        border.color: item.dial.accent

        Glyph {
            anchors.centerIn: parent
            text: "terminal"
            font.pixelSize: Math.round(parent.width * 0.68)
            color: item.dial.accent
        }
    }

    // Its name, beside it.
    Text {
        x: item.width + 12
        anchors.verticalCenter: parent.verticalCenter
        opacity: Math.max(0, Math.min(1, (item.away - 19) / 12)) * (item.hovered ? 1 : 0.72)
        visible: opacity > 0
        text: item.modelData.name
        font.family: item.dial.bodyFont
        font.pixelSize: 14
        color: item.dial.light
    }

    // The letter a run of names starts with, on the band inside the rim.
    Text {
        readonly property real r: item.dial.radius + 22
        visible: item.leads
        x: item.dial.cx + r * Math.cos(item.rad) - item.x - width / 2
        y: item.dial.cy + r * Math.sin(item.rad) - item.y - height / 2
        text: item.initial
        font.family: item.dial.uiFont
        font.pixelSize: 12
        font.weight: Font.DemiBold
        color: Colors.withAlpha(item.dial.accent, 0.9)
    }
}
