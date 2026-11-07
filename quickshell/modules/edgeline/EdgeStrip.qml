pragma ComponentBehavior: Bound
import QtQuick
import qs.colors
import qs.services as Services
import qs.modules.control

// The line opened out, along its border inside the popout: the workspaces
// and the time at its start, the tabs, and the launcher, the power menu
// and minimal mode at its far end. In a row along a border lying flat, a
// column up a standing one. Its bare stretch is the popout's grip (in
// EdgeLineView): a click there folds it up, a drag moves it.
Item {
    id: strip

    property bool vertical: false
    property color ink: Colors.on_surface
    property color accent: Colors.primary
    property int focusedWs: 1
    property int wsCount: 5
    property var occupied: n => false
    property date now: new Date()
    property var tabs: []
    property int activeTab: 0

    signal tip(Item item, string text)
    signal untip(Item item)
    signal chooseTab(int i)

    readonly property var line: Services.EdgeLine
    readonly property real gap: 10
    // How long it has to be for all of it.
    readonly property real naturalLength: strip.vertical
        ? lead.implicitHeight + tabCol.implicitHeight + tail.implicitHeight + 4 * strip.gap
        : lead.implicitWidth + tabRow.implicitWidth + tail.implicitWidth + 4 * strip.gap

    // The wheel over it steps through the tabs (a notch a tab).
    property real wheelSum: 0

    WheelHandler {
        onWheel: event => {
            strip.wheelSum += event.angleDelta.y + event.angleDelta.x;
            if (Math.abs(strip.wheelSum) < 120 || strip.tabs.length < 2)
                return;
            const d = strip.wheelSum > 0 ? -1 : 1;
            strip.wheelSum = 0;
            strip.chooseTab((strip.activeTab + d + strip.tabs.length) % strip.tabs.length);
        }
    }

    // The workspaces and the time.
    Grid {
        id: lead
        columns: strip.vertical ? 1 : 2
        spacing: 4
        horizontalItemAlignment: Grid.AlignHCenter
        verticalItemAlignment: Grid.AlignVCenter
        x: strip.vertical ? (strip.width - width) / 2 : 0
        y: strip.vertical ? 0 : (strip.height - height) / 2

        WorkspaceDots {
            vertical: strip.vertical
            focusedWs: strip.focusedWs
            wsCount: strip.wsCount
            occupied: strip.occupied
            ink: strip.ink
            accent: strip.accent
        }

        Item {
            implicitWidth: strip.vertical ? 34 : clockRow.implicitWidth + 12
            implicitHeight: strip.vertical ? clockColumn.implicitHeight + 6 : 34

            Row {
                id: clockRow
                visible: !strip.vertical
                anchors.centerIn: parent
                spacing: 3

                Text {
                    id: clockTime
                    text: Qt.formatDateTime(strip.now, "h:mm AP").split(" ")[0]
                    font.family: ControlStyle.display
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                    color: strip.ink
                }

                Text {
                    anchors.baseline: clockTime.baseline
                    text: Qt.formatDateTime(strip.now, "AP")
                    font.family: ControlStyle.body
                    font.pixelSize: 9
                    font.weight: Font.Bold
                    color: Colors.withAlpha(strip.ink, 0.6)
                }
            }

            Column {
                id: clockColumn
                visible: strip.vertical
                anchors.centerIn: parent
                spacing: -2

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDateTime(strip.now, "hh AP").split(" ")[0]
                    font.family: ControlStyle.display
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                    color: strip.ink
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDateTime(strip.now, "mm")
                    font.family: ControlStyle.display
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                    color: Colors.withAlpha(strip.ink, 0.75)
                }
            }
        }
    }

    // A hairline after the lead.
    Rectangle {
        x: strip.vertical ? (strip.width - width) / 2 : lead.x + lead.width + strip.gap - 1
        y: strip.vertical ? lead.y + lead.height + strip.gap - 1 : (strip.height - height) / 2
        width: strip.vertical ? 18 : 1
        height: strip.vertical ? 1 : 18
        color: Colors.withAlpha(strip.ink, 0.22)
    }

    // The tabs.
    Row {
        id: tabRow
        visible: !strip.vertical
        x: lead.x + lead.width + 2 * strip.gap
        y: (strip.height - height) / 2
        spacing: 2

        Repeater {
            model: strip.vertical ? [] : strip.tabs

            EdgeTab {
                required property var modelData
                required property int index
                icon: modelData.icon
                name: modelData.name
                current: index === strip.activeTab
                ink: strip.ink
                accent: strip.accent
                onClicked: strip.chooseTab(index)
            }
        }
    }

    Column {
        id: tabCol
        visible: strip.vertical
        x: (strip.width - width) / 2
        y: lead.y + lead.height + 2 * strip.gap
        spacing: 2

        Repeater {
            model: strip.vertical ? strip.tabs : []

            EdgeTab {
                required property var modelData
                required property int index
                vertical: true
                icon: modelData.icon
                name: modelData.name
                current: index === strip.activeTab
                ink: strip.ink
                accent: strip.accent
                onClicked: strip.chooseTab(index)
                onTip: (item, text) => strip.tip(item, text)
                onUntip: item => strip.untip(item)
            }
        }
    }

    // Arranging this tab's panels, the tabs' page in the customizer, the
    // launcher, the power menu and minimal mode, at the far end.
    Grid {
        id: tail
        columns: strip.vertical ? 1 : 5
        spacing: 2
        x: strip.vertical ? (strip.width - width) / 2 : strip.width - width
        y: strip.vertical ? strip.height - height : (strip.height - height) / 2

        SpineButton {
            vertical: strip.vertical
            ink: strip.ink
            accent: strip.accent
            icon: "dashboard_customize"
            name: strip.line.arranging ? "Done arranging" : "Arrange this tab's panels"
            on: strip.line.arranging
            onClicked: strip.line.setArranging(!strip.line.arranging)
            onTip: (item, text) => strip.tip(item, text)
            onUntip: item => strip.untip(item)
        }

        SpineButton {
            vertical: strip.vertical
            ink: strip.ink
            accent: strip.accent
            icon: "tune"
            name: "Arrange the tabs"
            onClicked: strip.line.request("customizer:edgeTabs")
            onTip: (item, text) => strip.tip(item, text)
            onUntip: item => strip.untip(item)
        }

        SpineButton {
            vertical: strip.vertical
            ink: strip.ink
            accent: strip.accent
            icon: "apps"
            name: "Apps"
            onClicked: strip.line.request("launcher")
            onTip: (item, text) => strip.tip(item, text)
            onUntip: item => strip.untip(item)
        }

        SpineButton {
            vertical: strip.vertical
            ink: strip.ink
            accent: strip.accent
            icon: "power_settings_new"
            name: "Power"
            onClicked: strip.line.request("power")
            onTip: (item, text) => strip.tip(item, text)
            onUntip: item => strip.untip(item)
        }

        SpineButton {
            vertical: strip.vertical
            ink: strip.ink
            accent: strip.accent
            icon: "horizontal_rule"
            name: strip.line.minimal ? "Minimal mode is on: bring the bar back" : "Minimal mode: only the line"
            on: strip.line.minimal
            onClicked: strip.line.toggleMinimal()
            onTip: (item, text) => strip.tip(item, text)
            onUntip: item => strip.untip(item)
        }
    }
}
