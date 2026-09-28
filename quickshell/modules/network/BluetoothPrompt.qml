import QtQuick
import QtQuick.Layouts
import qs.services as Services
import qs.colors
import qs.components

// What bluetoothd is waiting on (Services.Bluetooth.request): a code to
// compare or type, or a device asking to pair or connect.
Card {
    id: prompt

    required property var request

    readonly property int requestId: request?.id ?? -1
    readonly property string kind: request?.kind ?? ""
    readonly property string name: Services.Bluetooth.nameOf(request?.device ?? "")
    readonly property bool typing: kind === "pin" || kind === "passkey"
    readonly property bool showing: kind === "show-pin" || kind === "show-passkey"
    readonly property string code: kind === "show-pin" ? (request?.pincode ?? "") : (request?.passkey ?? "")
    // show-passkey: digits already typed on the device
    readonly property int entered: request?.entered ?? 0
    readonly property bool valid: kind === "pin" ? field.text.length > 0 : /^\d{1,6}$/.test(field.text)

    // Profile UUIDs (their 16-bit part) a device asks to use, in words.
    readonly property var services: ({
        "1101": "Serial port",
        "1105": "File transfer", "1106": "File transfer",
        "1108": "Headset audio", "1112": "Headset audio",
        "110a": "Audio streaming", "110b": "Audio streaming", "110d": "Audio streaming",
        "110c": "Media controls", "110e": "Media controls", "110f": "Media controls",
        "1115": "Network sharing", "1116": "Network sharing", "1117": "Network sharing",
        "111e": "Hands-free audio", "111f": "Hands-free audio",
        "1124": "Input", "1812": "Input",
        "112f": "Contacts", "1130": "Contacts",
        "1132": "Messages", "1133": "Messages", "1134": "Messages",
        "184e": "LE audio", "184f": "LE audio", "1850": "LE audio", "1853": "LE audio"
    })
    readonly property string service: {
        const short = /^0000([0-9a-f]{4})-0000-1000-8000-00805f9b34fb$/.exec((request?.uuid ?? "").toLowerCase())
        return (short && services[short[1]]) || "A Bluetooth service"
    }

    function submit() {
        if (typing && !valid)
            return
        Services.Bluetooth.respond(true, typing ? field.text : "", false)
    }

    // A new question: clear the field, and put the cursor in it when it's
    // needed (kind, not `typing`, which may not have caught up yet).
    onRequestIdChanged: {
        field.text = ""
        if (request?.kind === "pin" || request?.kind === "passkey")
            field.forceActiveFocus()
    }
    Component.onCompleted: if (typing) field.forceActiveFocus()

    implicitHeight: body.implicitHeight + 28
    radius: Services.DesktopTheme.rad(18)
    color: Colors.primary_container

    ColumnLayout {
        id: body
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: 14
        }
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Rectangle {
                Layout.preferredWidth: 38
                Layout.preferredHeight: 38
                Layout.alignment: Qt.AlignTop
                radius: Services.DesktopTheme.rad(19)
                color: Colors.withAlpha(Colors.on_primary_container, 0.12)

                MaterialIcon {
                    anchors.centerIn: parent
                    text: prompt.typing ? "󰌋"
                        : prompt.showing ? "󰌌"
                        : prompt.kind === "service" ? "󰦝"
                        : "󰂱"
                    font.pixelSize: 19
                    color: Colors.on_primary_container
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                StyledText {
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    text: {
                        switch (prompt.kind) {
                        case "confirm": return "Pair with " + prompt.name + "?"
                        case "authorize": return prompt.name + " wants to pair"
                        case "service": return prompt.name + " wants to connect"
                        case "pin": return "Enter the PIN for " + prompt.name
                        case "passkey": return "Enter the passkey for " + prompt.name
                        default: return "Type this code on " + prompt.name
                        }
                    }
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    color: Colors.on_primary_container
                }
                StyledText {
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    text: {
                        switch (prompt.kind) {
                        case "confirm": return "Only if it shows the same code."
                        case "authorize": return "Only if you started pairing on it."
                        case "service": return prompt.service + " · not trusted yet"
                        case "pin": return "Headsets often use 0000 or 1234."
                        case "passkey": return "The number " + prompt.name + " shows."
                        default: return "Then press Enter on it."
                        }
                    }
                    font.pixelSize: 12
                    color: Colors.withAlpha(Colors.on_primary_container, 0.75)
                }
            }
        }

        // the code, digits already typed dimmed
        Row {
            Layout.alignment: Qt.AlignHCenter
            visible: prompt.code !== "" && !prompt.typing
            spacing: 3

            Repeater {
                model: prompt.code.length

                StyledText {
                    required property int index
                    text: prompt.code.charAt(index)
                    rightPadding: index === 2 ? 12 : 0
                    font.pixelSize: 28
                    font.weight: Font.DemiBold
                    color: index < prompt.entered
                        ? Colors.withAlpha(Colors.on_primary_container, 0.35)
                        : Colors.on_primary_container
                }
            }
        }

        StyledTextField {
            id: field
            Layout.fillWidth: true
            Layout.preferredHeight: 38
            visible: prompt.typing
            leftPadding: 12
            placeholderText: prompt.kind === "pin" ? "PIN" : "Passkey"
            maximumLength: prompt.kind === "pin" ? 16 : 6
            inputMethodHints: prompt.kind === "passkey" ? Qt.ImhDigitsOnly : Qt.ImhNone
            validator: RegularExpressionValidator {
                regularExpression: prompt.kind === "passkey" ? /[0-9]*/ : /[\x20-\x7e]*/
            }
            font.pixelSize: 14
            font.letterSpacing: 2
            backgroundColor: Colors.surface_container_highest
            focusBorderColor: Colors.primary
            onAccepted: prompt.submit()
            Keys.onEscapePressed: Services.Bluetooth.respond(false, "", false)
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Item { Layout.fillWidth: true }

            PromptButton {
                text: prompt.kind === "service" || prompt.kind === "authorize" ? "Deny" : "Cancel"
                onClicked: Services.Bluetooth.respond(false, "", false)
            }
            PromptButton {
                visible: prompt.kind === "service"
                text: "Allow"
                onClicked: Services.Bluetooth.respond(true, "", false)
            }
            PromptButton {
                visible: !prompt.showing
                enabled: !prompt.typing || prompt.valid
                filled: true
                text: prompt.kind === "service" ? "Always allow" : "Pair"
                onClicked: {
                    if (prompt.kind === "service")
                        Services.Bluetooth.respond(true, "", true)
                    else
                        prompt.submit()
                }
            }
        }
    }

    component PromptButton: ClickableRect {
        id: button

        property alias text: label.text
        property bool filled: false

        Layout.preferredWidth: label.implicitWidth + 28
        Layout.preferredHeight: 34
        radius: Services.DesktopTheme.rad(17)
        opacity: enabled ? 1 : 0.45
        color: filled
            ? (hovered ? Colors.withAlpha(Colors.primary, 0.85) : Colors.primary)
            : (hovered ? Colors.withAlpha(Colors.on_primary_container, 0.1) : "transparent")
        border.width: filled ? 0 : 1
        border.color: Colors.withAlpha(Colors.on_primary_container, 0.35)
        cursorShape: Qt.PointingHandCursor

        StyledText {
            id: label
            anchors.centerIn: parent
            font.pixelSize: 12
            font.weight: Font.Medium
            color: button.filled ? Colors.on_primary : Colors.on_primary_container
        }
    }
}
