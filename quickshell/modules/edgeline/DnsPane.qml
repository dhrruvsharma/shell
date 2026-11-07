pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.colors
import qs.services as Services
import qs.modules.lock
import qs.modules.control

// Who answers the lookups on the connection in use (services/Dns): the
// network's own servers, a provider's, or a server of your own typed under
// them (a name like dns.adguard.com, or addresses). A click tries it first
// and only then uses it; one that can't be reached says why under the list
// (and in a notification), and what was set stays. Each network keeps its
// own. Encrypted (DNS over TLS) when NetworkManager can; a network that
// answers DNS itself is called out, with the setup encrypted DNS needs.
PaneSection {
    id: pane

    title: EdgeWords.word("dns")
    preferredWidth: 304

    readonly property var dns: Services.Dns
    readonly property bool usable: pane.dns.ready && pane.dns.offline === ""
    property bool copied: false

    Component.onCompleted: pane.dns.look()

    function inUse(id) {
        return pane.dns.current === id && pane.dns.trying === "";
    }

    // The line under the one in use: how it answered last.
    function inUseLine() {
        const d = pane.dns;
        if (d.health === "fail")
            return "In use · not answering";
        if (d.health === "intercepted")
            return "Set, but the network answers instead";
        const how = d.encrypted ? "encrypted" : d.canEncrypt && d.current !== "auto" ? "unencrypted" : "";
        const ms = d.health === "ok" && d.healthMs >= 0 ? d.healthMs + " ms" : "";
        return ["In use", how, ms].filter(s => s !== "").join(" · ");
    }

    function use() {
        const t = field.text.trim();
        if (t !== "")
            pane.dns.useCustom(t);
    }

    Connections {
        target: pane.dns

        function onSwitched(id) {
            if (id === "custom")
                field.text = "";
        }
    }

    trailing: [
        PaneChip {
            icon: "refresh"
            spinning: pane.dns.checking
            onClicked: pane.dns.recheck()
        }
    ]

    // Which connection it's for.
    Text {
        width: parent.width
        elide: Text.ElideRight
        text: !pane.dns.ready ? "Looking…" : pane.dns.offline !== "" ? pane.dns.offline : "For “" + pane.dns.connection + "” · each network keeps its own"
        font.family: ControlStyle.body
        font.pixelSize: 11
        color: Colors.withAlpha(ControlStyle.ink, 0.6)
    }

    // The choices: the network's own, the providers, and one of your own
    // while it's in use (or being tried).
    Column {
        width: parent.width
        spacing: 4
        enabled: pane.usable

        PaneRow {
            width: parent.width
            icon: "router"
            title: "Automatic"
            subtitle: pane.dns.trying === "auto" ? pane.dns.step
                : pane.inUse("auto") ? pane.inUseLine() + (pane.dns.servers.length > 0 ? " · " + pane.dns.servers.slice(0, 2).join(", ") : "")
                : "what the network hands out"
            on: pane.inUse("auto")
            busy: pane.dns.trying === "auto"
            onClicked: pane.dns.automatic()
        }

        Repeater {
            model: pane.dns.providers

            PaneRow {
                id: choice
                required property var modelData
                width: parent.width
                icon: choice.modelData.icon
                title: choice.modelData.name
                subtitle: pane.dns.trying === choice.modelData.id ? pane.dns.step
                    : pane.inUse(choice.modelData.id) ? pane.inUseLine()
                    : choice.modelData.blurb
                figure: pane.inUse(choice.modelData.id) && pane.dns.encrypted ? "TLS" : ""
                on: pane.inUse(choice.modelData.id)
                busy: pane.dns.trying === choice.modelData.id
                onClicked: pane.dns.use(choice.modelData.id)
            }
        }

        PaneRow {
            visible: pane.dns.trying === "custom" || pane.inUse("custom")
            width: parent.width
            icon: "dns"
            title: pane.dns.trying === "custom" ? pane.dns.tryingName : pane.dns.currentName
            subtitle: pane.dns.trying === "custom" ? pane.dns.step : pane.inUseLine()
            figure: pane.inUse("custom") && pane.dns.encrypted ? "TLS" : ""
            on: pane.inUse("custom")
            busy: pane.dns.trying === "custom"
            onClicked: pane.dns.recheck()
        }
    }

    // A server of your own.
    Item {
        width: parent.width
        height: 40
        enabled: pane.usable && !pane.dns.busy
        opacity: enabled ? 1 : 0.6

        Rectangle {
            anchors.fill: parent
            radius: ControlStyle.radius(12)
            color: ControlStyle.well
            border.width: 1
            border.color: field.activeFocus ? ControlStyle.accent : ControlStyle.line
        }

        Glyph {
            id: mark
            x: 10
            anchors.verticalCenter: parent.verticalCenter
            text: "edit"
            font.pixelSize: 17
            color: field.activeFocus ? ControlStyle.accent : Colors.withAlpha(ControlStyle.ink, 0.6)
        }

        TextInput {
            id: field
            anchors.left: mark.right
            anchors.leftMargin: 8
            anchors.right: go.left
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            clip: true
            inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhUrlCharactersOnly
            font.family: ControlStyle.body
            font.pixelSize: 13
            color: ControlStyle.ink
            selectionColor: Colors.withAlpha(ControlStyle.accent, 0.4)
            onAccepted: pane.use()
            Keys.onEscapePressed: event => {
                if (field.text !== "") {
                    field.text = "";
                    event.accepted = true;
                } else {
                    event.accepted = false;
                }
            }

            Text {
                visible: field.text.length === 0
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                elide: Text.ElideRight
                text: "Your own: dns.adguard.com"
                font: field.font
                color: Colors.withAlpha(ControlStyle.ink, 0.45)
            }
        }

        PaneChip {
            id: go
            anchors.right: parent.right
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            text: "Use"
            onClicked: pane.use()
        }
    }

    // Why the last switch didn't happen.
    Item {
        visible: pane.dns.failureTitle !== ""
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
                text: pane.dns.failureTitle
                font.family: ControlStyle.body
                font.pixelSize: 12
                font.weight: Font.DemiBold
                color: ControlStyle.danger
            }

            Text {
                width: parent.width
                wrapMode: Text.Wrap
                text: pane.dns.failure
                font.family: ControlStyle.body
                font.pixelSize: 11
                color: Colors.withAlpha(ControlStyle.ink, 0.75)
            }
        }

        PaneChip {
            id: dismiss
            anchors.right: parent.right
            icon: "close"
            onClicked: pane.dns.dismiss()
        }
    }

    // DNS set here that isn't working now.
    Text {
        visible: pane.dns.failureTitle === "" && pane.dns.own && (pane.dns.health === "fail" || pane.dns.health === "intercepted") && pane.dns.trying === ""
        width: parent.width
        wrapMode: Text.Wrap
        text: {
            const d = pane.dns;
            if (d.health === "intercepted")
                return d.healthWhy;
            const why = d.healthWhy.replace(/\.$/, "");
            return d.currentName + " isn't answering (" + why.charAt(0).toLowerCase() + why.slice(1) + ")." + (d.encrypted ? " Lookups fail until it does, or until another is picked." : "");
        }
        font.family: ControlStyle.body
        font.pixelSize: 11
        color: ControlStyle.danger
    }

    // A network that answers DNS itself, and what would get past it.
    Column {
        visible: pane.dns.interceptedHere && !pane.dns.canEncrypt && (pane.dns.tlsGetsThrough || !(pane.dns.failureIntercepted && pane.dns.failureTitle !== ""))
        width: parent.width
        spacing: 4

        Text {
            width: parent.width
            wrapMode: Text.Wrap
            // (the first half's said already when it's why a switch failed)
            text: (pane.dns.failureIntercepted && pane.dns.failureTitle !== "" ? "" : "This network answers every plain DNS question itself, so no other provider can be reached that way. ")
                + (pane.dns.tlsGetsThrough ? "Encrypted DNS does get through; it needs systemd-resolved to handle lookups, set up once as root." : "")
            font.family: ControlStyle.body
            font.pixelSize: 11
            color: Colors.withAlpha(ControlStyle.ink, 0.65)
        }

        Item {
            visible: pane.dns.tlsGetsThrough
            width: parent.width
            height: 26

            PaneChip {
                anchors.right: parent.right
                icon: pane.copied ? "check" : "content_copy"
                text: pane.copied ? "Copied" : "Copy the setup"
                onClicked: {
                    pane.dns.copySetup();
                    pane.copied = true;
                    copiedTimer.restart();
                }
            }

            Timer {
                id: copiedTimer
                interval: 2200
                onTriggered: pane.copied = false
            }
        }
    }

    // Encrypted, while it can be.
    Text {
        visible: pane.dns.canEncrypt && pane.usable
        width: parent.width
        wrapMode: Text.Wrap
        text: pane.dns.encrypted ? "Lookups go encrypted (DNS over TLS), and nowhere else if it can't be reached." : "Providers are used encrypted (DNS over TLS)."
        font.family: ControlStyle.body
        font.pixelSize: 11
        color: Colors.withAlpha(ControlStyle.ink, 0.6)
    }
}
