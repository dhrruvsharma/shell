pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import qs.colors
import qs.components
import qs.modules.lock
import qs.services as Services

// A colour picked by hand: a saturation/brightness square and a hue strip
// to drag in, the hex code to type, and swatches to start from (the
// wallpaper's own colours, and a few classics).
//
// `value` is the colour in use; `picked` says what the user chose, live
// while they drag. The picker keeps its own hue, so dragging into black or
// grey and back out doesn't lose it, and it takes `value` back whenever it
// differs from what the picker is showing (another swatch, a reset).
Item {
    id: root

    property color value: "#808080"
    // Room left free under the hue strip, for the caller's own line.
    property real footer: 0

    signal picked(color c)

    property real hue: 0
    property real sat: 0
    property real val: 0.5
    readonly property bool dragging: svArea.pressed || hueArea.pressed
    // The hex code is being typed (the panel's keys stand aside).
    readonly property bool typing: hexField.activeFocus
    readonly property color shown: Qt.hsva(root.hue, root.sat, root.val, 1)

    implicitHeight: 196

    function take(c) {
        const q = Qt.color(c);
        if (q.hsvHue >= 0 && q.hsvSaturation > 0)
            root.hue = q.hsvHue;
        root.sat = q.hsvSaturation;
        root.val = q.hsvValue;
    }

    function send() {
        root.picked(root.shown);
    }

    onValueChanged: {
        if (!root.dragging && Services.BarSettings.hex(root.value) !== Services.BarSettings.hex(root.shown))
            root.take(root.value);
    }
    Component.onCompleted: root.take(root.value)

    // ── Saturation (across) and brightness (up) at the current hue ──────────
    Rectangle {
        id: sv
        width: root.width - side.width - 18
        height: root.height - hueStrip.height - 12 - root.footer
        radius: Services.DesktopTheme.rad(14)
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: "white" }
            GradientStop { position: 1; color: Qt.hsva(root.hue, 1, 1, 1) }
        }

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            gradient: Gradient {
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 1; color: "black" }
            }
            border.width: 1
            border.color: Colors.withAlpha(Colors.outline_variant, 0.9)
        }

        Knob {
            x: root.sat * sv.width - width / 2
            y: (1 - root.val) * sv.height - height / 2
            fill: root.shown
        }

        MouseArea {
            id: svArea
            anchors.fill: parent
            anchors.margins: -6
            cursorShape: Qt.CrossCursor

            function pick(mouse) {
                root.sat = Math.max(0, Math.min(1, (mouse.x - 6) / sv.width));
                root.val = 1 - Math.max(0, Math.min(1, (mouse.y - 6) / sv.height));
                root.send();
            }

            onPressed: mouse => pick(mouse)
            onPositionChanged: mouse => pick(mouse)
        }
    }

    // ── Hue ──────────────────────────────────────────────────────────────────
    Rectangle {
        id: hueStrip
        anchors.top: sv.bottom
        anchors.topMargin: 12
        width: sv.width
        height: 16
        radius: Services.DesktopTheme.rad(8)
        border.width: 1
        border.color: Colors.withAlpha(Colors.outline_variant, 0.9)
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0 / 6; color: "#ff0000" }
            GradientStop { position: 1 / 6; color: "#ffff00" }
            GradientStop { position: 2 / 6; color: "#00ff00" }
            GradientStop { position: 3 / 6; color: "#00ffff" }
            GradientStop { position: 4 / 6; color: "#0000ff" }
            GradientStop { position: 5 / 6; color: "#ff00ff" }
            GradientStop { position: 6 / 6; color: "#ff0000" }
        }

        Knob {
            x: root.hue * hueStrip.width - width / 2
            anchors.verticalCenter: parent.verticalCenter
            fill: Qt.hsva(root.hue, 1, 1, 1)
        }

        MouseArea {
            id: hueArea
            anchors.fill: parent
            anchors.margins: -6
            cursorShape: Qt.PointingHandCursor

            function pick(mouse) {
                root.hue = Math.max(0, Math.min(0.999, (mouse.x - 6) / hueStrip.width));
                // A hue means nothing on a grey: give it some colour.
                if (root.sat < 0.05)
                    root.sat = 0.6;
                if (root.val < 0.08)
                    root.val = 0.5;
                root.send();
            }

            onPressed: mouse => pick(mouse)
            onPositionChanged: mouse => pick(mouse)
        }
    }

    // ── The colour, its code and the swatches ───────────────────────────────
    Column {
        id: side
        anchors.right: parent.right
        width: 196
        spacing: 12

        // The colour as it stands, and its hex code to type over.
        Rectangle {
            width: parent.width
            height: 46
            radius: Services.DesktopTheme.rad(12)
            color: Colors.surface_container
            border.width: hexField.activeFocus ? 2 : 1
            border.color: hexField.activeFocus ? Colors.primary : Colors.withAlpha(Colors.outline_variant, 0.9)

            Rectangle {
                id: well
                x: 7
                anchors.verticalCenter: parent.verticalCenter
                width: 32
                height: 32
                radius: Services.DesktopTheme.rad(9)
                color: root.shown
                border.width: 1
                border.color: Colors.withAlpha(Colors.on_surface, 0.18)
            }

            StyledText {
                id: hash
                anchors.left: well.right
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                text: "#"
                font.pixelSize: 16
                font.family: "monospace"
                color: Colors.on_surface_variant
            }

            TextField {
                id: hexField
                anchors.left: hash.right
                anchors.right: parent.right
                anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                leftPadding: 2
                background: null
                color: Colors.on_surface
                selectionColor: Colors.primary
                selectedTextColor: Colors.on_primary
                font.pixelSize: 16
                font.family: "monospace"
                font.capitalization: Font.AllUppercase
                maximumLength: 6
                validator: RegularExpressionValidator {
                    regularExpression: /[0-9a-fA-F]{0,6}/
                }
                // Follows the colour, except while it's being typed.
                text: Services.BarSettings.hex(root.shown).slice(1)
                onTextEdited: {
                    if (/^[0-9a-fA-F]{6}$/.test(text))
                        root.picked("#" + text);
                }
                onEditingFinished: text = Qt.binding(() => Services.BarSettings.hex(root.shown).slice(1))
            }
        }

        Swatches {
            label: "From your wallpaper"
            colors: [Colors.source_color, Colors.primary, Colors.secondary, Colors.tertiary, Colors.primary_container, Colors.surface_variant]
        }

        Swatches {
            label: "Classics"
            colors: ["#0e0e12", "#2a2c3a", "#f1ede4", "#d9616c", "#e2b35c", "#5f9fe0"]
        }
    }

    // A draggable handle: a ring in the colour it stands on.
    component Knob: Rectangle {
        property color fill

        width: 18
        height: 18
        radius: 9
        color: fill
        border.width: 3
        border.color: "white"

        Rectangle {
            anchors.fill: parent
            anchors.margins: -1
            radius: width / 2
            color: "transparent"
            border.width: 1
            border.color: Qt.rgba(0, 0, 0, 0.45)
        }
    }

    // A labelled row of colours to start from.
    component Swatches: Column {
        id: swatches

        property string label
        property var colors: []

        width: side.width
        spacing: 6

        StyledText {
            text: swatches.label
            font.pixelSize: 11
            font.weight: Font.Medium
            font.letterSpacing: 0.4
            color: Colors.on_surface_variant
        }

        Row {
            spacing: 6

            Repeater {
                model: swatches.colors

                ClickableRect {
                    id: dot

                    required property var modelData
                    readonly property bool current: Services.BarSettings.hex(modelData) === Services.BarSettings.hex(root.shown)

                    width: (side.width - 5 * 6) / 6
                    height: width
                    radius: width / 2
                    color: modelData
                    border.width: dot.current ? 2 : 1
                    border.color: dot.current ? Colors.primary : dot.hovered ? Colors.outline : Colors.withAlpha(Colors.on_surface, 0.16)
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.take(dot.modelData);
                        root.send();
                    }
                }
            }
        }
    }
}
