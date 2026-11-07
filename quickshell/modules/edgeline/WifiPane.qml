pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.colors
import qs.services as Services
import qs.modules.lock
import qs.modules.control

// Wi-Fi and the wired and tethered links: the radio's switch, what's in
// use, and the networks around (the one in use first, then the saved ones,
// then by signal). A click joins one: straight away when it's saved or
// open, after a password asked for under the list when it's neither. Its
// end button takes the one in use down, or forgets a saved one. The whole
// fan of networks is in the network panel ("All networks").
PaneSection {
    id: pane

    title: EdgeWords.word("network")
    preferredWidth: 304

    readonly property var net: Services.Network
    // The network a password is being typed for ("" none).
    property string asking: ""

    readonly property var wifis: pane.net.connections.filter(c => c.type === "wifi" && c.name !== "").sort((a, b) => (b.active - a.active) || (b.saved - a.saved) || (b.strength - a.strength))
    readonly property var links: pane.net.wiredLinks.filter(c => c.active || c.available)

    Component.onCompleted: pane.net.refresh()

    function strengthGlyph(s) {
        return s >= 75 ? "signal_wifi_4_bar" : s >= 50 ? "network_wifi_3_bar" : s >= 25 ? "network_wifi_2_bar" : "network_wifi_1_bar";
    }

    function linkGlyph(kind) {
        return kind === "usb" ? "usb" : kind === "bluetooth" ? "bluetooth_connected" : kind === "mobile" ? "signal_cellular_alt" : "lan";
    }

    function choose(c) {
        if (c.active || pane.net.connecting)
            return;
        if (c.saved || !c.isSecure) {
            pane.asking = "";
            pane.net.connect(c, "", "");
        } else {
            pane.asking = c.name;
            password.text = "";
            password.forceActiveFocus();
        }
    }

    function join() {
        const c = pane.wifis.find(w => w.name === pane.asking);
        if (c && password.text.length > 0)
            pane.net.connect(c, password.text, "");
        pane.asking = "";
        password.text = "";
    }

    trailing: [
        PaneChip {
            visible: pane.net.wifiEnabled
            icon: "refresh"
            spinning: pane.net.scanning
            onClicked: pane.net.rescan()
        },
        PaneSwitch {
            checked: pane.net.wifiEnabled
            onToggled: pane.net.toggleWifi()
        }
    ]

    // Wired and tethered links.
    Column {
        visible: pane.links.length > 0
        width: parent.width
        spacing: 4

        Repeater {
            model: ScriptModel {
                values: pane.links
            }

            PaneRow {
                id: link
                required property var modelData
                width: parent.width
                icon: pane.linkGlyph(link.modelData.kind)
                title: link.modelData.title
                subtitle: link.modelData.active ? "Connected" : "Available"
                on: link.modelData.active
                busy: pane.net.linking && pane.net.lastNetworkAttempt === link.modelData.name
                action: link.modelData.active ? "link_off" : ""
                onClicked: if (!link.modelData.active) pane.net.connect(link.modelData, "", "")
                onActionClicked: pane.net.disconnect(link.modelData)
            }
        }
    }

    // The networks around.
    Column {
        visible: pane.net.wifiEnabled
        width: parent.width
        spacing: 4

        Repeater {
            model: ScriptModel {
                values: pane.wifis.slice(0, 6)
            }

            PaneRow {
                id: wifi
                required property var modelData
                readonly property bool joining: pane.net.connecting && pane.net.lastNetworkAttempt === wifi.modelData.name
                width: parent.width
                icon: pane.strengthGlyph(wifi.modelData.strength)
                title: wifi.modelData.name
                subtitle: wifi.joining ? "Connecting…"
                    : wifi.modelData.active ? "Connected" + (pane.net.ipAddress ? " · " + pane.net.ipAddress.split("/")[0] : "")
                    : wifi.modelData.saved ? "Saved" : wifi.modelData.isSecure ? "Secured" : "Open"
                figure: wifi.modelData.band ? wifi.modelData.band + " GHz" : ""
                on: wifi.modelData.active
                busy: wifi.joining
                action: wifi.modelData.active ? "link_off" : wifi.modelData.saved ? "delete" : ""
                onClicked: pane.choose(wifi.modelData)
                onActionClicked: {
                    if (wifi.modelData.active)
                        pane.net.disconnect(wifi.modelData);
                    else
                        pane.net.forget(wifi.modelData.name);
                }
            }
        }

        Text {
            visible: pane.wifis.length === 0
            width: parent.width
            topPadding: 6
            bottomPadding: 6
            horizontalAlignment: Text.AlignHCenter
            text: pane.net.scanning ? "Looking for networks…" : "No networks in reach"
            font.family: ControlStyle.body
            font.pixelSize: 12
            color: Colors.withAlpha(ControlStyle.ink, 0.6)
        }
    }

    Text {
        visible: !pane.net.wifiEnabled
        width: parent.width
        topPadding: 4
        bottomPadding: 4
        horizontalAlignment: Text.AlignHCenter
        text: "Wi-Fi is off"
        font.family: ControlStyle.body
        font.pixelSize: 12
        color: Colors.withAlpha(ControlStyle.ink, 0.6)
    }

    // The password for a network that wants one.
    Item {
        visible: pane.asking !== ""
        width: parent.width
        height: 40

        Rectangle {
            anchors.fill: parent
            radius: ControlStyle.radius(12)
            color: ControlStyle.well
            border.width: 1
            border.color: password.activeFocus ? ControlStyle.accent : ControlStyle.line
        }

        Glyph {
            id: lock
            x: 10
            anchors.verticalCenter: parent.verticalCenter
            text: "lock"
            font.pixelSize: 17
            color: ControlStyle.accent
        }

        TextInput {
            id: password
            anchors.left: lock.right
            anchors.leftMargin: 8
            anchors.right: go.left
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            echoMode: TextInput.Password
            clip: true
            font.family: ControlStyle.body
            font.pixelSize: 13
            color: ControlStyle.ink
            selectionColor: Colors.withAlpha(ControlStyle.accent, 0.4)
            onAccepted: pane.join()
            Keys.onEscapePressed: event => {
                pane.asking = "";
                event.accepted = true;
            }

            Text {
                visible: password.text.length === 0
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                elide: Text.ElideRight
                text: "Password for " + pane.asking
                font: password.font
                color: Colors.withAlpha(ControlStyle.ink, 0.45)
            }
        }

        PaneChip {
            id: go
            anchors.right: parent.right
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            text: "Join"
            onClicked: pane.join()
        }
    }

    // Why the last attempt failed (a notification says so too, for when
    // the popout has folded by then).
    Item {
        visible: pane.net.lastErrorMessage !== "" && !pane.net.connecting && !pane.net.linking
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
                text: "Couldn't connect" + (pane.net.lastNetworkAttempt !== "" ? " to " + pane.net.lastNetworkAttempt : "")
                font.family: ControlStyle.body
                font.pixelSize: 12
                font.weight: Font.DemiBold
                color: ControlStyle.danger
            }

            Text {
                visible: pane.net.lastErrorMessage !== "Couldn't connect"
                width: parent.width
                wrapMode: Text.Wrap
                text: pane.net.lastErrorMessage
                font.family: ControlStyle.body
                font.pixelSize: 11
                color: Colors.withAlpha(ControlStyle.ink, 0.75)
            }
        }

        PaneChip {
            id: dismiss
            anchors.right: parent.right
            icon: "close"
            onClicked: pane.net.lastErrorMessage = ""
        }
    }

    Item {
        width: parent.width
        height: 26

        PaneChip {
            anchors.right: parent.right
            icon: "open_in_new"
            text: "All networks"
            onClicked: Services.EdgeLine.request("network")
        }
    }
}
