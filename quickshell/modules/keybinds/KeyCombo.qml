pragma ComponentBehavior: Bound
import QtQuick
import qs.colors
import qs.components
import qs.services as Services

// A shortcut written as keycaps: Super  Shift  Q.
Row {
    id: combo

    property var mods: []
    property string key: ""
    // shown in place of the key, e.g. a loop's "1 … 0"
    property string keyText: ""
    // the caps' type size; everything else scales with it
    property int size: 12
    property color fill: Colors.surface_container_highest
    property color ink: Colors.on_surface
    // a cap for a key that isn't chosen yet
    property bool placeholder: false

    spacing: Math.max(3, Math.round(size * 0.3))

    readonly property var caps: {
        const out = KeyData.sortMods(mods).map(m => KeyData.modLabel(m));
        if (keyText || key)
            out.push(keyText || KeyData.keyLabel(key));
        else if (placeholder)
            out.push("…");
        return out;
    }

    Repeater {
        model: combo.caps.length

        delegate: Rectangle {
            id: cap
            required property int index
            readonly property string label: combo.caps[index] ?? ""
            readonly property bool last: index === combo.caps.length - 1
            readonly property int lip: Math.max(2, Math.round(combo.size * 0.17))

            height: Math.round(combo.size * 1.95) + lip
            width: Math.max(height - lip, capLabel.implicitWidth + Math.round(combo.size * 1.15))
            radius: Services.DesktopTheme.rad(Math.round(combo.size * 0.42))
            color: Qt.darker(combo.fill, 1.45)

            Rectangle {
                anchors.fill: parent
                anchors.bottomMargin: cap.lip
                radius: parent.radius
                color: combo.placeholder && cap.last && !combo.key ? "transparent" : combo.fill
                border.width: 1
                border.color: combo.placeholder && cap.last && !combo.key ? Colors.withAlpha(combo.ink, 0.35) : Colors.withAlpha(Colors.outline, 0.35)

                StyledText {
                    id: capLabel
                    anchors.centerIn: parent
                    text: cap.label
                    font.pixelSize: combo.size
                    font.weight: Font.DemiBold
                    color: combo.ink
                    opacity: combo.placeholder && cap.last && !combo.key ? 0.5 : 1
                }
            }
        }
    }
}
