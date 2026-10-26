pragma ComponentBehavior: Bound
import QtQuick
import qs.colors
import qs.modules.desktopwidgets

// A value along a ruled track: the theme's own meter as the track (a
// sword drawn from its scabbard, prayer beads, a vernier, the posture
// gauge…; a rail and a knob without a theme), graduated under it, with the
// figure set beside it. Drag or click it, or turn the wheel over it.
// `mark` puts a small hollow tick where the theme (or the config) would
// have it, when the value is one set here.
Item {
    id: slider

    property real from: 0
    property real to: 100
    property real stepSize: 1
    property real value: 0
    property string unit: ""
    property int decimals: 0
    property real mark: NaN
    // How the figure reads; the value with its unit by default.
    property var format: v => v.toFixed(slider.decimals) + (slider.unit ? " " + slider.unit : "")
    property real readoutWidth: 70

    // While it's dragged, and as it's let go.
    signal moved(real value)
    signal released

    readonly property bool dragging: lane.pressed
    property real dragValue: 0
    readonly property real shown: slider.dragging ? slider.dragValue : slider.value
    readonly property real frac: Math.max(0, Math.min(1, (slider.shown - slider.from) / Math.max(1e-9, slider.to - slider.from)))
    readonly property bool themed: BookStyle.themeId !== "" && BookStyle.themeId !== "zen"

    implicitWidth: 300
    implicitHeight: 36

    function snap(v) {
        const s = slider.stepSize > 0 ? Math.round((v - slider.from) / slider.stepSize) * slider.stepSize + slider.from : v;
        return Math.max(slider.from, Math.min(slider.to, Number(s.toFixed(4))));
    }

    Item {
        id: track
        anchors.left: parent.left
        anchors.right: readout.left
        anchors.rightMargin: 16
        height: parent.height

        Loader {
            id: meter
            anchors.left: parent.left
            anchors.right: parent.right
            y: 8
            sourceComponent: slider.themed ? themedTrack : plainTrack
        }

        // The graduations: a tick for each step (or a sensible share of
        // them), longer every fifth.
        Repeater {
            id: ticks

            readonly property int steps: {
                const steps = Math.round((slider.to - slider.from) / Math.max(1e-9, slider.stepSize));
                let n = steps;
                while (n > 24)
                    n = n % 2 === 0 ? n / 2 : n % 5 === 0 ? n / 5 : Math.ceil(n / 2);
                return Math.max(1, n);
            }

            model: ticks.steps + 1

            Rectangle {
                required property int index
                x: Math.round(track.width * index / ticks.steps)
                y: 24
                width: 1
                height: index % 5 === 0 || index === ticks.steps ? 6 : 3
                color: BookStyle.inkFaint
            }
        }

        // Where the theme would have it.
        Rectangle {
            visible: !isNaN(slider.mark)
            readonly property real f: Math.max(0, Math.min(1, (slider.mark - slider.from) / Math.max(1e-9, slider.to - slider.from)))
            x: Math.round(track.width * f) - 4
            y: 23
            width: 9
            height: 9
            rotation: 45
            color: BookStyle.paper
            border.width: 1
            border.color: BookStyle.accent
        }

        MouseArea {
            id: lane
            anchors.fill: parent
            anchors.topMargin: -4
            anchors.bottomMargin: -4
            preventStealing: true
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            function at(x) {
                return slider.snap(slider.from + Math.max(0, Math.min(1, x / track.width)) * (slider.to - slider.from));
            }

            onPressed: mouse => {
                slider.dragValue = lane.at(mouse.x);
                slider.moved(slider.dragValue);
            }
            onPositionChanged: mouse => {
                if (!pressed)
                    return;
                const v = lane.at(mouse.x);
                if (v === slider.dragValue)
                    return;
                slider.dragValue = v;
                slider.moved(v);
            }
            onReleased: slider.released()
            onWheel: wheel => {
                const d = (wheel.angleDelta.y || -wheel.angleDelta.x) > 0 ? 1 : -1;
                const v = slider.snap(slider.value + d * slider.stepSize);
                if (v !== slider.value) {
                    slider.moved(v);
                    slider.released();
                }
            }
        }
    }

    BookText {
        id: readout
        anchors.right: parent.right
        y: 1
        width: slider.readoutWidth
        horizontalAlignment: Text.AlignRight
        text: slider.format(slider.shown)
        font.family: BookStyle.ui
        font.pixelSize: 15
        font.features: ({ "tnum": 1, "lnum": 1 })
        color: slider.dragging ? BookStyle.accent : BookStyle.ink
    }

    Component {
        id: themedTrack

        WidgetBar {
            themeId: BookStyle.themeId
            value: slider.frac
            fromStart: true
            ink: BookStyle.ink
            accent: BookStyle.accent
        }
    }

    // A fine rail filled to the value, and a knob.
    Component {
        id: plainTrack

        Item {
            height: 12

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: 2
                radius: 1
                color: BookStyle.line

                Rectangle {
                    width: parent.width * slider.frac
                    height: parent.height
                    radius: 1
                    color: BookStyle.accent
                }
            }

            Rectangle {
                x: parent.width * slider.frac - width / 2
                anchors.verticalCenter: parent.verticalCenter
                width: 13
                height: 13
                radius: 6.5
                color: BookStyle.accent
                border.width: 2
                border.color: BookStyle.paper
                scale: lane.pressed ? 1.25 : lane.containsMouse ? 1.1 : 1

                Behavior on scale {
                    NumberAnimation {
                        duration: 120
                    }
                }
            }
        }
    }
}
