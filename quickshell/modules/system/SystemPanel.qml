import QtQuick
import Quickshell
import qs.components
import Quickshell.Io
import Quickshell.Wayland
import qs.modules.screentools
import qs.services as Services

Item {
    id: systemPanel
    property bool opened: false
    property int currentTab: 0
    focus: true
    // It unfolds out of the bar (shell.qml hangs it from the middle of the
    // bar): down from a top bar, up from a bottom one, sideways from a
    // standing one. `unfold` runs 0 (folded away) to 1 (open), so moving the
    // bar to another edge doesn't play the animation.
    readonly property bool vertical: Services.BarLayout.vertical
    property real unfold: opened ? 1 : 0
    // Hanging down it's wide and shallow, the gauges in a row. Beside a
    // standing bar it stands too: the gauges stack under the tabs and the
    // panel fits round them, a little clear of the bar, a little more in
    // from the outer side (the theme's corner mark, the bubble's rounded
    // corners), and inside the bubble's body, which is inset by the radius
    // at both ends there.
    readonly property real barPad: Services.BarLayout.size + 14
    readonly property real outerPad: 28
    readonly property real endPad: popout.radius + 14
    implicitWidth: vertical ? (barPad + content.implicitWidth + outerPad) * unfold : 550
    implicitHeight: vertical ? content.implicitHeight + 2 * endPad : 200 * unfold
    visible: opened || unfold > 0

    Behavior on unfold {
        NumberAnimation {
            duration: 260
            easing.type: Easing.OutCubic
        }
    }

    // Standing, the panel follows its tab's height; only once it is out, as
    // the graphs load on opening and the panel would grow while unfolding.
    Behavior on implicitHeight {
        enabled: systemPanel.vertical && systemPanel.opened && systemPanel.unfold === 1
        NumberAnimation {
            duration: 220
            easing.type: Easing.OutCubic
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"

        MouseArea {
            anchors.fill: parent
            onClicked: systemPanel.opened = false
        }
    }

    FocusScope {
        anchors.fill: parent
        focus: systemPanel.opened

        Keys.onEscapePressed: systemPanel.opened = false

        Popout {
            id: popout
            anchors.fill: parent
            alignment: Services.BarLayout.middleAlignment
            leftPadding: !systemPanel.vertical ? radius : Services.BarLayout.atLeft ? systemPanel.barPad : systemPanel.outerPad
            rightPadding: !systemPanel.vertical ? radius : Services.BarLayout.atRight ? systemPanel.barPad : systemPanel.outerPad
            topPadding: systemPanel.vertical ? systemPanel.endPad : radius
            bottomPadding: systemPanel.vertical ? systemPanel.endPad : radius

            Column {
                id: content
                anchors.fill: parent
                spacing: systemPanel.vertical ? 12 : 8

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 8

                    TabButton {
                        text: "System"
                        active: currentTab === 0
                        onClicked: currentTab = 0
                    }

                    TabButton {
                        text: "Screen"
                        active: currentTab === 1
                        onClicked: currentTab = 1
                    }
                }

                // The graphs only while the panel shows: they otherwise went
                // on redrawing every stats poll behind the closed panel. The
                // Screen tab stays, as its screenshot process outlives the
                // panel (it closes the panel before grimblast runs).
                Loader {
                    anchors.horizontalCenter: parent.horizontalCenter
                    active: systemPanel.visible || systemPanel.currentTab !== 0
                    sourceComponent: currentTab === 0 ? systemTab : screenTab
                }
            }
        }
    }

    Component {
        id: systemTab
        SystemGraphs {
            vertical: systemPanel.vertical
        }
    }

    Component {
        id: screenTab
        ScreenTools {
            vertical: systemPanel.vertical
        }
    }

    // A peek (opened on hover) stays while it's in use.
    PeekWatch {
        target: "system"
    }

    IpcHandler {
        target: "systemPanel"
        function toggle(): void {
            systemPanel.opened = !systemPanel.opened
        }
    }
}
