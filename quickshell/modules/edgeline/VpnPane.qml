pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.colors
import qs.services as Services
import qs.modules.lock
import qs.modules.control

// VPN tunnels (services/Vpn): WireGuard ones, imported from the .conf a
// provider gives you (Import, or drop the file on the pane), and any other
// kind NetworkManager has a plugin for. A click connects one (one at a
// time: another goes down first) or disconnects it; a spinner turns while
// it does. Its end button removes one that isn't up (asked first). What
// went wrong (couldn't connect, nothing comes back through it) shows under
// the list, and in a notification.
PaneSection {
    id: pane

    title: EdgeWords.word("vpn")
    preferredWidth: 304

    readonly property var vpn: Services.Vpn
    // A tunnel asked to be removed, waiting for yes or no (its uuid).
    property string confirming: ""
    readonly property var confirmed: pane.vpn.profiles.find(p => p.uuid === pane.confirming) ?? null

    Component.onCompleted: pane.vpn.refresh()

    function kind(p) {
        return p.type === "wireguard" ? "WireGuard" : "VPN";
    }

    function line(p) {
        const work = pane.vpn.busy[p.uuid] ?? "";
        if (work === "connecting" || p.state === "activating")
            return "Connecting…";
        if (work === "disconnecting" || p.state === "deactivating")
            return "Disconnecting…";
        if (work === "removing")
            return "Removing…";
        if (p.active) {
            const heard = pane.vpn.answers[p.uuid] ?? "";
            return "Connected" + (p.address ? " · " + p.address : "") + (heard === "silent" ? " · no answer through it" : "");
        }
        return pane.kind(p);
    }

    // (one at a time: the one up goes down before another comes up)
    function choose(p) {
        pane.confirming = "";
        const up = pane.vpn.current;
        if (up && up.uuid !== p.uuid && !p.active)
            pane.vpn.disconnect(up);
        pane.vpn.toggle(p);
    }

    trailing: [
        PaneChip {
            icon: "upload_file"
            text: "Import"
            spinning: pane.vpn.importing
            onClicked: pane.vpn.browse()
        }
    ]

    // The tunnels, or how to get one; a WireGuard file dropped here goes in.
    DropArea {
        id: drop

        readonly property bool wanted: drop.containsDrag

        width: parent.width
        height: rows.implicitHeight

        onEntered: event => {
            event.accepted = event.hasUrls;
        }
        onDropped: event => {
            for (const u of event.urls) {
                const path = decodeURIComponent(String(u).replace(/^file:\/\//, ""));
                if (path !== "") {
                    pane.vpn.importFile(path);
                    break;
                }
            }
        }

        Column {
            id: rows
            width: parent.width
            spacing: 4

            Repeater {
                model: ScriptModel {
                    values: pane.vpn.profiles
                }

                PaneRow {
                    id: tunnel
                    required property var modelData
                    readonly property string work: pane.vpn.busy[tunnel.modelData.uuid] ?? ""
                    width: parent.width
                    icon: tunnel.modelData.active ? "vpn_lock" : "vpn_key"
                    title: tunnel.modelData.name
                    subtitle: pane.line(tunnel.modelData)
                    figure: tunnel.modelData.type === "wireguard" ? "WG" : ""
                    on: tunnel.modelData.active
                    busy: tunnel.work !== "" || tunnel.modelData.state === "activating" || tunnel.modelData.state === "deactivating"
                    action: tunnel.modelData.active ? "" : "delete"
                    onClicked: pane.choose(tunnel.modelData)
                    onActionClicked: pane.confirming = tunnel.modelData.uuid
                }
            }

            // None yet: where one comes from.
            MouseArea {
                id: empty
                visible: pane.vpn.ready && pane.vpn.profiles.length === 0
                width: parent.width
                height: 92
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: pane.vpn.browse()

                Rectangle {
                    anchors.fill: parent
                    radius: ControlStyle.radius(12)
                    color: empty.containsMouse ? ControlStyle.wellHover : ControlStyle.well
                    border.width: 1
                    border.color: empty.containsMouse || drop.wanted ? ControlStyle.accent : ControlStyle.line
                }

                Column {
                    anchors.centerIn: parent
                    width: parent.width - 24
                    spacing: 4

                    Glyph {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "vpn_key"
                        font.pixelSize: 22
                        color: ControlStyle.accent
                    }

                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                        text: "No VPN yet. Import the WireGuard file (.conf) your provider gives you, or drop it here."
                        font.family: ControlStyle.body
                        font.pixelSize: 11
                        color: Colors.withAlpha(ControlStyle.ink, 0.7)
                    }
                }
            }
        }

        // A file over it.
        Rectangle {
            visible: drop.wanted
            anchors.fill: parent
            radius: ControlStyle.radius(12)
            color: Colors.withAlpha(ControlStyle.accent, 0.16)
            border.width: 2
            border.color: ControlStyle.accent

            Text {
                anchors.centerIn: parent
                text: "Drop to import"
                font.family: ControlStyle.ui
                font.pixelSize: 13
                font.weight: Font.DemiBold
                color: ControlStyle.accent
            }
        }
    }

    // Removing one: asked first.
    Item {
        visible: pane.confirmed !== null
        width: parent.width
        height: 30

        Text {
            anchors.left: parent.left
            anchors.right: keep.left
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            text: "Remove “" + (pane.confirmed?.name ?? "") + "”?"
            font.family: ControlStyle.body
            font.pixelSize: 12
            color: ControlStyle.ink
        }

        PaneChip {
            id: keep
            anchors.right: gone.left
            anchors.verticalCenter: parent.verticalCenter
            text: "Keep"
            onClicked: pane.confirming = ""
        }

        PaneChip {
            id: gone
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            icon: "delete"
            text: "Remove"
            onClicked: {
                if (pane.confirmed)
                    pane.vpn.remove(pane.confirmed);
                pane.confirming = "";
            }
        }
    }

    // What went wrong.
    Item {
        visible: pane.vpn.failureTitle !== ""
        width: parent.width
        height: failureText.implicitHeight

        Glyph {
            id: failureGlyph
            y: 1
            text: "error"
            font.pixelSize: 16
            color: ControlStyle.danger
        }

        Column {
            id: failureText
            anchors.left: failureGlyph.right
            anchors.leftMargin: 6
            anchors.right: dismiss.left
            anchors.rightMargin: 4
            spacing: 2

            Text {
                width: parent.width
                wrapMode: Text.Wrap
                text: pane.vpn.failureTitle
                font.family: ControlStyle.body
                font.pixelSize: 12
                font.weight: Font.DemiBold
                color: ControlStyle.danger
            }

            Text {
                visible: text !== ""
                width: parent.width
                wrapMode: Text.Wrap
                text: pane.vpn.failure
                font.family: ControlStyle.body
                font.pixelSize: 11
                color: Colors.withAlpha(ControlStyle.ink, 0.75)
            }
        }

        PaneChip {
            id: dismiss
            anchors.right: parent.right
            icon: "close"
            onClicked: pane.vpn.dismiss()
        }
    }
}
