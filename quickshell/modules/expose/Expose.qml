import Quickshell
import QtQuick
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick.Shapes
import QtQuick.Effects
import qs.services as Svc
import qs.colors

// Expose / workspace overview window. Slides up from the bottom on
// `qs ipc call expose toggle`. Ported from Nebula's WorkspaceOverview.
PanelWindow {
    id: root
    implicitWidth: (5 * 300) + 40 + 60   // grid width + wrapper padding
    implicitHeight: (2 * 200) + 10 + 60  // grid height + wrapper padding

    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Ignore
    focusable: true
    visible: false
    color: "transparent"

    anchors { bottom: true }

    property bool shouldOpen: Svc.ExposeState.open
    onShouldOpenChanged: shouldOpen ? root.openOverview() : root.closeOverview()

    function openOverview() {
        hideTimer.stop()
        root.visible = true
        Hyprland.refreshToplevels()
        closeAnimation.stop()
        openAnimation.start()
    }

    function closeOverview() {
        openAnimation.stop()
        closeAnimation.start()
    }

    Timer {
        id: hideTimer
        interval: 100
        onTriggered: root.visible = false
    }

    // Keep previews live while the overview is open.
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (!root.visible) return
            if (event.name === "movewindow" || event.name === "resizewindow" ||
                event.name === "fullscreen" || event.name === "activewindow" ||
                event.name === "openwindow" || event.name === "closewindow" ||
                event.name === "changefloatingmode") {
                Hyprland.refreshToplevels()
            }
        }
    }

    SequentialAnimation {
        id: openAnimation
        ParallelAnimation {
            NumberAnimation { target: wrapper; property: "height"; from: 0; to: 30; duration: 400; easing.type: Easing.OutQuad }
            NumberAnimation { target: shapeScale; property: "yScale"; from: 0; to: 1.0; duration: 400; easing.type: Easing.OutQuad }
        }
        NumberAnimation { target: wrapper; property: "height"; from: 30; to: 470; duration: 200; easing.type: Easing.OutQuad }
    }

    SequentialAnimation {
        id: closeAnimation
        NumberAnimation { target: wrapper; property: "height"; from: 470; to: 30; duration: 200; easing.type: Easing.InQuad }
        ParallelAnimation {
            NumberAnimation { target: shapeScale; property: "yScale"; from: 1.0; to: 0; duration: 400; easing.type: Easing.InQuad }
            NumberAnimation { target: wrapper; property: "height"; from: 30; to: 0; duration: 400; easing.type: Easing.InQuad }
        }
        onFinished: hideTimer.start()
    }

    Item {
        id: wrapper
        width: parent.width
        height: 0
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter

        layer.enabled: wrapper.width > 100
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowBlur: 0.4
            shadowOpacity: 1.0
            shadowColor: Qt.alpha(Colors.shadow, 1)
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 0
        }

        Shape {
            id: shapeElement
            preferredRendererType: Shape.CurveRenderer
            transform: Scale {
                id: shapeScale
                origin.x: wrapper.width / 2
                origin.y: wrapper.height
                yScale: 0
            }
            ShapePath {
                fillColor: Colors.surface_container
                strokeWidth: 0
                startX: wrapper.x
                startY: wrapper.height
                PathArc { relativeX: 20; relativeY: -20; radiusY: 15; radiusX: 20; direction: PathArc.Counterclockwise }
                PathLine { relativeX: wrapper.width - 40; relativeY: 0 }
                PathArc { relativeX: 20; relativeY: 20; radiusX: 20; radiusY: 15; direction: PathArc.Counterclockwise }
            }
        }

        Rectangle {
            id: workspaceOverview
            width: parent.width - 40
            height: parent.height
            color: Colors.surface_container
            topLeftRadius: 20
            topRightRadius: 20
            clip: true
            anchors.verticalCenter: parent.verticalCenter
            anchors.horizontalCenter: parent.horizontalCenter

            ExposeContent {
                id: content
                anchors.fill: parent
                visible: wrapper.height === 470

                focus: root.visible
                Keys.onEscapePressed: Svc.ExposeState.open = false
            }
        }
    }
}
