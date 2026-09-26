pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.modules.lock
import qs.services as Services

// Full-screen demo of a lock theme, launched by the theme picker:
//   QS_LOCK_THEME=xianxia quickshell -p ~/.config/quickshell/LockPreview.qml
//
// This never locks the session: the theme runs in an overlay window with a
// LockContext in preview mode (PAM is never touched, nothing is saved). Any
// passcode "unlocks", "wrong" plays a failure, Esc on an empty field leaves.
ShellRoot {
    id: root

    readonly property string themeId: {
        const requested = Quickshell.env("QS_LOCK_THEME");
        return requested && Services.LockScreen.has(requested) ? requested : Services.LockScreen.current;
    }
    readonly property var theme: Services.LockScreen.theme(themeId)
    property bool started: false

    function start() {
        if (started)
            return;
        previewCtx.configure(theme);
        previewCtx.begin();
        started = true;
    }

    ScreenCapture {
        id: capture
        onFinished: root.start()
    }

    LockContext {
        id: previewCtx
        preview: true
        onReleased: Qt.quit()
        onPreviewExit: Qt.quit()
    }

    Variants {
        model: root.started ? Quickshell.screens : []

        PanelWindow {
            id: window

            required property ShellScreen modelData

            screen: modelData
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "quickshell:lock-preview"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            exclusionMode: ExclusionMode.Ignore
            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true
            color: "black"

            ThemeHost {
                anchors.fill: parent
                ctx: previewCtx
                themeId: root.themeId
                shot: capture.urlFor(window.modelData)
            }

            // What this is and how to leave it; fades back after a few seconds.
            Rectangle {
                id: banner

                anchors.horizontalCenter: parent.horizontalCenter
                y: 14
                width: bannerRow.implicitWidth + 28
                height: 34
                radius: 17
                color: Qt.rgba(0.06, 0.06, 0.08, 0.82)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.14)
                opacity: bannerHover.containsMouse || bannerHold.running ? 1 : 0.35

                Behavior on opacity {
                    NumberAnimation { duration: 400 }
                }

                Timer {
                    id: bannerHold
                    interval: 4500
                    running: true
                }

                Row {
                    id: bannerRow
                    anchors.centerIn: parent
                    spacing: 10

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "PREVIEW · " + root.theme.name
                        font.family: "Rubik"
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        color: "#ffffff"
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "any passcode unlocks · “wrong” fails · Esc exits"
                        font.family: "Rubik"
                        font.pixelSize: 12
                        color: Qt.rgba(1, 1, 1, 0.65)
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "✕"
                        font.pixelSize: 13
                        color: closeArea.containsMouse ? "#ffffff" : Qt.rgba(1, 1, 1, 0.65)

                        MouseArea {
                            id: closeArea
                            anchors.fill: parent
                            anchors.margins: -8
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Qt.quit()
                        }
                    }
                }

                MouseArea {
                    id: bannerHover
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                    z: -1
                }
            }
        }
    }
}
