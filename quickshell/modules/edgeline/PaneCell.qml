pragma ComponentBehavior: Bound
import QtQuick
import qs.services as Services
import qs.modules.control

// One cell of the popout's collage: a well of the theme's ink with one
// pane in it, built while its tab is showing. It sits where the collage
// puts it and slides there when the panes around it change size; what its
// pane measures goes back to the collage (services/EdgeLine.panelSizes).
Item {
    id: cell

    required property string modelData
    required property var host

    readonly property string paneId: cell.modelData
    readonly property rect r: cell.host.cellRects[cell.paneId] ?? Qt.rect(0, 0, 0, 0)
    readonly property real pad: cell.host.cellPad
    // Placed once: from then on it slides.
    property bool placed: false

    x: cell.r.x
    y: cell.r.y
    width: cell.r.width
    height: cell.r.height

    Component.onCompleted: Qt.callLater(() => cell.placed = true)

    Behavior on x {
        enabled: cell.placed
        NumberAnimation {
            duration: 260
            easing.type: Easing.OutCubic
        }
    }
    Behavior on y {
        enabled: cell.placed
        NumberAnimation {
            duration: 260
            easing.type: Easing.OutCubic
        }
    }
    Behavior on width {
        enabled: cell.placed
        NumberAnimation {
            duration: 260
            easing.type: Easing.OutCubic
        }
    }
    Behavior on height {
        enabled: cell.placed
        NumberAnimation {
            duration: 260
            easing.type: Easing.OutCubic
        }
    }

    Rectangle {
        anchors.fill: parent
        topLeftRadius: ControlStyle.corner(14, 0)
        topRightRadius: ControlStyle.corner(14, 1)
        bottomRightRadius: ControlStyle.corner(14, 2)
        bottomLeftRadius: ControlStyle.corner(14, 3)
        color: ControlStyle.well
    }

    Loader {
        id: loader
        x: cell.pad
        y: cell.pad
        width: Math.max(0, cell.width - 2 * cell.pad)
        height: Math.max(0, cell.height - 2 * cell.pad)
        sourceComponent: ({
                workspaces: workspacesPane,
                calendar: calendarPane,
                media: mediaPane,
                wifi: wifiPane,
                bluetooth: bluetoothPane,
                dns: dnsPane,
                vpn: vpnPane,
                sound: soundPane,
                system: systemPane,
                notes: notesPane,
                notifications: notificationsPane,
                tray: trayPane,
                commands: commandsPane
            })[cell.paneId] ?? null
    }

    readonly property real natW: loader.item ? loader.item.implicitWidth : 0
    readonly property real natH: loader.item ? loader.item.implicitHeight : 0

    function report() {
        if (cell.natW > 0 && cell.natH > 0)
            Services.EdgeLine.reportSize(cell.paneId, Math.ceil(cell.natW), Math.ceil(cell.natH));
    }

    onNatWChanged: cell.report()
    onNatHChanged: cell.report()

    Component {
        id: workspacesPane
        WorkspacesPane {}
    }
    Component {
        id: calendarPane
        CalendarPane {}
    }
    Component {
        id: mediaPane
        MediaPane {}
    }
    Component {
        id: wifiPane
        WifiPane {}
    }
    Component {
        id: bluetoothPane
        BluetoothPane {}
    }
    Component {
        id: dnsPane
        DnsPane {}
    }
    Component {
        id: vpnPane
        VpnPane {}
    }
    Component {
        id: soundPane
        SoundPane {}
    }
    Component {
        id: systemPane
        SystemPane {}
    }
    Component {
        id: notesPane
        NotesPane {}
    }
    Component {
        id: notificationsPane
        NotificationsPane {}
    }
    Component {
        id: trayPane
        TrayPane {}
    }
    Component {
        id: commandsPane
        CommandsPane {}
    }
}
