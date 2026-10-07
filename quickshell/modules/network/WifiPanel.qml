pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Shapes
import qs.services as Services
import qs.colors
import qs.components

// The Wi-Fi tab: the networks round this computer on the opened-out Wi-Fi
// sign (WifiFan.qml), the connection with its address and the last minute
// of traffic, and the networks in range. The row under the pointer is lit
// on the fan and the network under the pointer in the list.
//
// A network on more than one band has a chip per band (with its signal
// there): a chip joins on that band, the rest of the row on whichever band
// NetworkManager likes, and clicking it on the fan joins on the band it's
// on there. The connection's chips show the band in use; the other chip
// moves it over.
Item {
    id: wifiRoot

    property string expandedSsid: ""
    // the band the password being typed is for ("" for whichever)
    property string chosenBand: ""
    // the row under the pointer, and a band chip ({ ssid, band }) under it
    property string hoveredSsid: ""
    property var hoveredChip: null

    readonly property color accent: Services.DesktopTheme.accent
    readonly property color accent2: Services.DesktopTheme.accent2
    readonly property bool on: Services.Network.wifiEnabled
    // the connection: Wi-Fi's, else a wired one
    readonly property var link: Services.Network.connections.find(c => c.active && c.type === "wifi") ?? Services.Network.active
    readonly property bool wired: link !== null && link.type !== "wifi"
    // the bands the connection's network is on
    readonly property var linkReach: link && !wired ? Services.Network.reachOf(link.name) : []
    readonly property var networks: Services.Network.connections
        .filter(c => c.type === "wifi" && !c.active)
        .sort((a, b) => b.strength - a.strength)

    onVisibleChanged: {
        if (visible)
            return
        expandedSsid = ""
        chosenBand = ""
    }

    // The traffic is sampled only while it's on screen. (Set by hand: a
    // Binding doesn't give the value back when it's destroyed.)
    readonly property bool showsTraffic: visible && link !== null && !wired
    onShowsTrafficChanged: Services.Network.watchTraffic = showsTraffic
    Component.onCompleted: Services.Network.watchTraffic = showsTraffic
    Component.onDestruction: Services.Network.watchTraffic = false

    // A network clicked on the fan, on the band it was clicked on.
    function pick(ssid, band) {
        if (link && !wired && link.name === ssid) {
            activate(link, band)
            return
        }
        const i = networks.findIndex(c => c.name === ssid)
        if (i < 0)
            return
        list.positionViewAtIndex(i, ListView.Contain)
        activate(networks[i], band)
    }

    // Joins `network` on `band` ("" for whichever band NetworkManager
    // likes), asking for the password first if it needs one. A band chip of
    // a network whose password is being asked for chooses the band instead
    // (again: whichever).
    function activate(network, band) {
        if (Services.Network.connecting && Services.Network.lastNetworkAttempt === network.name)
            return
        // already there
        if (network.active && (band === "" || Services.Network.reachOf(network.name).some(r => r.active && r.band === band)))
            return
        if (network.isSecure && !network.saved) {
            if (expandedSsid === network.name && band !== "") {
                chosenBand = chosenBand === band ? "" : band
                return
            }
            expandedSsid = expandedSsid === network.name ? "" : network.name
            chosenBand = band
            return
        }
        Services.Network.connect(network, "", band)
    }

    function rateText(bytes) {
        if (bytes >= 1e6)
            return (bytes / 1e6).toFixed(bytes >= 1e7 ? 0 : 1) + " MB/s"
        if (bytes >= 1e3)
            return Math.round(bytes / 1e3) + " kB/s"
        return Math.round(bytes) + " B/s"
    }

    function chipEntered(ssid, band) {
        hoveredChip = { ssid: ssid, band: band }
    }

    function chipExited(ssid, band) {
        if (hoveredChip && hoveredChip.ssid === ssid && hoveredChip.band === band)
            hoveredChip = null
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        // ── The air ──
        Card {
            id: airCard
            Layout.fillWidth: true
            Layout.preferredHeight: 214
            radius: Services.DesktopTheme.rad(18)
            color: Colors.surface_container_low

            WifiFan {
                id: wifiFan
                anchors.fill: parent
                anchors.margins: 12
                anchors.topMargin: 10
                anchors.bottomMargin: 6
                ground: airCard.color
                live: wifiRoot.on
                scanning: Services.Network.scanning
                highlight: wifiRoot.hoveredChip?.ssid ?? wifiRoot.hoveredSsid
                highlightBand: wifiRoot.hoveredChip?.band ?? ""
                joining: Services.Network.connecting ? Services.Network.lastNetworkAttempt : ""
                joiningBand: Services.Network.connecting ? Services.Network.lastBandAttempt : ""
                onPicked: (ssid, band) => wifiRoot.pick(ssid, band)
            }

            StyledText {
                anchors.left: parent.left
                anchors.leftMargin: 14
                y: 6 + (28 - height) / 2
                visible: wifiRoot.on
                text: Services.Network.scanning ? "Listening…"
                    : wifiFan.points.length === 1 ? "1 network in the air"
                    : wifiFan.points.length + " networks in the air"
                font.pixelSize: 12
                font.weight: Font.Medium
                color: Services.Network.scanning ? wifiRoot.accent2 : Colors.withAlpha(Colors.on_surface_variant, 0.75)
            }

            Row {
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.top: parent.top
                anchors.topMargin: 6
                spacing: 4

                ClickableRect {
                    id: scanRect
                    width: 28
                    height: 28
                    radius: Services.DesktopTheme.rad(14)
                    enabled: wifiRoot.on
                    opacity: enabled ? 1 : 0.4
                    color: scanRect.hovered ? Colors.surface_container_high : "transparent"
                    MaterialIcon {
                        anchors.centerIn: parent
                        text: "󰑐"
                        font.pixelSize: 15
                        color: Services.Network.scanning ? wifiRoot.accent2 : Colors.on_surface_variant
                        RotationAnimator on rotation {
                            from: 0; to: 360; duration: 900; loops: Animation.Infinite
                            running: Services.Network.scanning
                        }
                    }
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Services.Network.rescan()
                }
            }

            // nothing on the fan
            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                y: wifiFan.y + wifiFan.sy - wifiFan.rMax * 0.62 - height / 2
                spacing: 3
                visible: opacity > 0
                opacity: !wifiRoot.on || wifiFan.points.length === 0 ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 240 } }

                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: !wifiRoot.on ? "Wi-Fi is off"
                        : Services.Network.scanning ? "Listening…"
                        : "No networks in range"
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    color: Colors.on_surface_variant
                }
                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: !wifiRoot.on ? "Switch it on to hear the networks round you"
                        : Services.Network.scanning ? "" : "Scan again in a moment"
                    font.pixelSize: 11
                    color: Colors.withAlpha(Colors.on_surface_variant, 0.65)
                }
                Item { width: 1; height: 6; visible: !wifiRoot.on }
                ClickableRect {
                    id: wifiOn
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: !wifiRoot.on
                    width: wifiOnText.implicitWidth + 28
                    height: 28
                    radius: Services.DesktopTheme.rad(14)
                    color: wifiOn.hovered ? wifiRoot.accent : "transparent"
                    border.width: 1
                    border.color: Colors.withAlpha(wifiRoot.accent, 0.7)
                    StyledText {
                        id: wifiOnText
                        anchors.centerIn: parent
                        text: "Turn on Wi-Fi"
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        color: wifiOn.hovered ? Colors.on_primary : wifiRoot.accent
                    }
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Services.Network.enableWifi(true)
                }
            }
        }

        // ── The connection ──
        Card {
            id: linkCard
            Layout.fillWidth: true
            Layout.preferredHeight: wifiRoot.wired ? 62 : 100
            visible: wifiRoot.link !== null && wifiRoot.on || wifiRoot.wired
            radius: Services.DesktopTheme.rad(16)
            color: Qt.tint(Colors.surface_container, Colors.withAlpha(wifiRoot.accent, 0.07))
            border.color: Colors.withAlpha(wifiRoot.accent, 0.3)
            clip: true

            readonly property var history: Services.Network.rxHistory
            readonly property var sent: Services.Network.txHistory
            readonly property real peak: Math.max(40e3, ...history, ...sent)

            // the last minute of traffic along the foot: down filled, up a line
            Shape {
                id: traffic
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 1
                height: 24
                visible: !wifiRoot.wired && linkCard.history.length > 1
                preferredRendererType: Shape.CurveRenderer

                function points(samples, closed) {
                    const n = 60
                    const pts = []
                    const off = n - samples.length
                    for (let i = 0; i < samples.length; i++)
                        pts.push(Qt.point((off + i) / (n - 1) * width, height - 1 - Math.sqrt(samples[i] / linkCard.peak) * (height - 4)))
                    if (closed && pts.length > 0) {
                        pts.push(Qt.point(pts[pts.length - 1].x, height))
                        pts.push(Qt.point(pts[0].x, height))
                    }
                    return pts
                }

                ShapePath {
                    strokeColor: "transparent"
                    fillGradient: LinearGradient {
                        x1: 0; y1: 0; x2: 0; y2: traffic.height
                        GradientStop { position: 0; color: Colors.withAlpha(wifiRoot.accent, 0.2) }
                        GradientStop { position: 1; color: Colors.withAlpha(wifiRoot.accent, 0.02) }
                    }
                    PathPolyline { path: traffic.points(linkCard.history, true) }
                }
                ShapePath {
                    strokeColor: Colors.withAlpha(wifiRoot.accent, 0.55)
                    strokeWidth: 1
                    fillColor: "transparent"
                    joinStyle: ShapePath.RoundJoin
                    PathPolyline { path: traffic.points(linkCard.history, false) }
                }
                ShapePath {
                    strokeColor: Colors.withAlpha(wifiRoot.accent2, 0.5)
                    strokeWidth: 1
                    fillColor: "transparent"
                    joinStyle: ShapePath.RoundJoin
                    PathPolyline { path: traffic.points(linkCard.sent, false) }
                }
            }

            MouseArea {
                id: linkMouse
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
            }

            SignalFan {
                id: linkSign
                x: 14
                anchors.verticalCenter: linkActions.verticalCenter
                width: 30
                height: 24
                visible: !wifiRoot.wired
                level: (wifiRoot.link?.strength ?? 0) / 100
                tone: wifiRoot.accent
                lit: true
            }
            MaterialIcon {
                anchors.centerIn: linkSign
                visible: wifiRoot.wired
                text: "󰈀"
                font.pixelSize: 22
                color: wifiRoot.accent
            }

            Row {
                id: linkActions
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.top: parent.top
                anchors.topMargin: 9
                spacing: 6

                // forget it too (while the pointer's over the card; it keeps
                // its room meanwhile, so the name doesn't shift)
                ClickableRect {
                    id: forgetLink
                    readonly property bool shown: linkMouse.containsMouse || forgetLink.hovered || dcRect.hovered
                    width: 26
                    height: 26
                    visible: !wifiRoot.wired
                    opacity: shown ? 1 : 0
                    interactive: shown
                    Behavior on opacity { NumberAnimation { duration: 120 } }
                    radius: Services.DesktopTheme.rad(13)
                    color: forgetLink.hovered ? Colors.error_container : "transparent"
                    MaterialIcon {
                        anchors.centerIn: parent
                        text: "󰺝"
                        font.pixelSize: 14
                        color: forgetLink.hovered ? Colors.on_error_container : Colors.on_surface_variant
                    }
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Services.Network.forget(wifiRoot.link.name)
                }

                ClickableRect {
                    id: dcRect
                    width: dcText.implicitWidth + 24
                    height: 26
                    radius: Services.DesktopTheme.rad(13)
                    color: dcRect.hovered ? wifiRoot.accent : "transparent"
                    border.width: 1
                    border.color: Colors.withAlpha(wifiRoot.accent, 0.7)

                    StyledText {
                        id: dcText
                        anchors.centerIn: parent
                        text: "Disconnect"
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        color: dcRect.hovered ? Colors.on_primary : wifiRoot.accent
                    }
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Services.Network.disconnect(wifiRoot.link)
                }
            }

            StyledText {
                id: linkName
                anchors.left: linkSign.right
                anchors.leftMargin: 12
                anchors.right: linkActions.left
                anchors.rightMargin: 8
                anchors.verticalCenter: linkActions.verticalCenter
                text: wifiRoot.link?.name ?? ""
                textFormat: Text.PlainText
                elide: Text.ElideRight
                font.pixelSize: 15
                font.weight: Font.DemiBold
            }
            // how it's connected; on two bands, a chip each (the one in use
            // lit, the other moves it there)
            Row {
                id: linkMeta
                anchors.left: linkName.left
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.top: linkActions.bottom
                anchors.topMargin: 2
                height: 18
                spacing: 6

                // (a count for a model, read by index: an array model would
                // remake the chips at every scan)
                Repeater {
                    model: wifiRoot.linkReach.length > 1 ? wifiRoot.linkReach.length : 0

                    delegate: BandChip {
                        required property int index
                        reach: wifiRoot.linkReach[index] ?? ({ band: "", signal: 0, active: false })
                        ssid: wifiRoot.link?.name ?? ""
                        onClicked: wifiRoot.activate(wifiRoot.link, reach.band)
                    }
                }

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(0, linkMeta.width - x)
                    elide: Text.ElideRight
                    text: {
                        const l = wifiRoot.link
                        if (!l)
                            return ""
                        if (wifiRoot.wired)
                            return "Wired" + (l.device ? "  ·  " + l.device : "")
                        const twoBands = wifiRoot.linkReach.length > 1
                        const parts = twoBands ? [] : [l.band + " GHz"]
                        parts.push("ch " + l.channel)
                        if (l.bandwidth > 20)
                            parts.push(l.bandwidth + " MHz")
                        parts.push(l.security || "Open")
                        if (!twoBands)
                            parts.push(l.strength + "%")
                        return parts.join("  ·  ")
                    }
                    font.pixelSize: 11
                    color: Colors.on_surface_variant
                }
            }
            Item {
                anchors.left: linkName.left
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.top: linkMeta.bottom
                anchors.topMargin: 3
                height: 16
                visible: !wifiRoot.wired

                StyledText {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: Services.Network.ipAddress || "No address yet"
                    font.pixelSize: 11
                    font.features: ({ "tnum": 1 })
                    color: Colors.withAlpha(Colors.on_surface, 0.85)
                }
                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10

                    StyledText {
                        text: "↓ " + wifiRoot.rateText(Services.Network.rxRate)
                        font.pixelSize: 11
                        font.features: ({ "tnum": 1 })
                        color: wifiRoot.accent
                    }
                    StyledText {
                        text: "↑ " + wifiRoot.rateText(Services.Network.txRate)
                        font.pixelSize: 11
                        font.features: ({ "tnum": 1 })
                        color: wifiRoot.accent2
                    }
                }
            }
        }

        // ── In range ──
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 4
            Layout.leftMargin: 4
            visible: wifiRoot.on
            spacing: 6

            StyledText {
                text: "In range"
                font.pixelSize: 10
                font.weight: Font.DemiBold
                font.letterSpacing: 1.4
                font.capitalization: Font.AllUppercase
                color: Colors.withAlpha(Colors.on_surface_variant, 0.8)
            }
            StyledText {
                text: wifiRoot.networks.length
                font.pixelSize: 10
                font.features: ({ "tnum": 1 })
                color: Colors.withAlpha(Colors.on_surface_variant, 0.5)
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                Layout.leftMargin: 4
                color: Colors.withAlpha(Colors.outline_variant, 0.6)
            }
        }

        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: wifiRoot.on
            clip: true
            spacing: 2
            boundsBehavior: Flickable.StopAtBounds
            model: wifiRoot.networks
            ScrollBar.vertical: StyledScrollBar { handleColor: wifiRoot.accent }

            delegate: NetworkRow {}
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: !wifiRoot.on
        }
    }

    // A network in range: its signal, its name and where it is in the air,
    // a chip per band if it's on more than one. Click to join (a secured
    // network not saved yet asks for its password here first).
    component NetworkRow: Rectangle {
        id: row

        required property var modelData
        required property int index

        readonly property bool isExpanded: wifiRoot.expandedSsid === modelData.name
        readonly property bool isConnecting: Services.Network.connecting
            && modelData.name === Services.Network.lastNetworkAttempt
        readonly property bool hasError: Services.Network.lastErrorMessage !== ""
            && Services.Network.lastNetworkAttempt === modelData.name
        readonly property bool lit: rowMouse.containsMouse || wifiFan.hoverSsid === modelData.name
            || wifiRoot.hoveredChip?.ssid === modelData.name
        readonly property var reach: Services.Network.reachOf(modelData.name)
        readonly property bool showsChips: reach.length > 1 && !isConnecting && !(hasError && !isExpanded)

        width: list.width
        height: rowCol.implicitHeight
        radius: Services.DesktopTheme.rad(12)
        color: lit || isExpanded ? Colors.surface_container_high : "transparent"
        Behavior on color { ColorAnimation { duration: 140 } }

        Column {
            id: rowCol
            width: parent.width

            Item {
                width: parent.width
                height: 48

                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onContainsMouseChanged: {
                        if (containsMouse)
                            wifiRoot.hoveredSsid = row.modelData.name
                        else if (wifiRoot.hoveredSsid === row.modelData.name)
                            wifiRoot.hoveredSsid = ""
                    }
                    onClicked: wifiRoot.activate(row.modelData, "")
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 8
                    spacing: 12

                    SignalFan {
                        Layout.preferredWidth: 24
                        Layout.preferredHeight: 19
                        level: row.modelData.strength / 100
                        tone: row.lit ? wifiRoot.accent2 : Colors.on_surface_variant
                        lit: row.lit
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1

                        StyledText {
                            Layout.fillWidth: true
                            text: row.modelData.name
                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                            font.pixelSize: 14
                            font.weight: row.modelData.saved ? Font.Medium : Font.Normal
                            color: Colors.on_surface
                        }
                        StyledText {
                            Layout.fillWidth: true
                            visible: !row.showsChips
                            elide: Text.ElideRight
                            text: row.isConnecting ? "Connecting" + (Services.Network.lastBandAttempt !== ""
                                    ? " on " + Services.Network.lastBandAttempt + " GHz…" : "…")
                                : row.hasError && !row.isExpanded ? Services.Network.lastErrorMessage
                                : row.modelData.band + " GHz  ·  ch " + row.modelData.channel
                                    + (row.modelData.saved ? "  ·  saved" : "")
                            font.pixelSize: 11
                            color: row.isConnecting ? wifiRoot.accent
                                : row.hasError && !row.isExpanded ? Colors.error
                                : Colors.withAlpha(Colors.on_surface_variant, 0.8)
                        }

                        // on two bands: a chip each, to join on that one
                        Row {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 18
                            visible: row.showsChips
                            spacing: 5

                            Repeater {
                                model: row.showsChips ? row.reach.length : 0

                                delegate: BandChip {
                                    required property int index
                                    reach: row.reach[index] ?? ({ band: "", signal: 0, active: false })
                                    ssid: row.modelData.name
                                    chosen: row.isExpanded && wifiRoot.chosenBand === reach.band
                                    onClicked: wifiRoot.activate(row.modelData, reach.band)
                                }
                            }

                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: row.modelData.saved
                                text: "saved"
                                font.pixelSize: 11
                                color: Colors.withAlpha(Colors.on_surface_variant, 0.8)
                            }
                        }
                    }

                    Spinner {
                        visible: row.isConnecting
                        Layout.preferredWidth: 16
                        Layout.preferredHeight: 16
                        border.width: 1.5
                        arcColor: wifiRoot.accent
                    }

                    // forget (saved networks)
                    ClickableRect {
                        id: forgetRect
                        visible: row.modelData.saved && !row.isConnecting && (rowMouse.containsMouse || forgetRect.hovered)
                        Layout.preferredWidth: 26
                        Layout.preferredHeight: 26
                        radius: Services.DesktopTheme.rad(13)
                        color: forgetRect.hovered ? Colors.error_container : "transparent"

                        MaterialIcon {
                            anchors.centerIn: parent
                            text: "󰺝"
                            font.pixelSize: 14
                            color: forgetRect.hovered ? Colors.on_error_container : Colors.on_surface_variant
                        }
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Services.Network.forget(row.modelData.name)
                    }

                    MaterialIcon {
                        visible: row.modelData.isSecure && !row.isConnecting
                        text: "󰌾"
                        font.pixelSize: 12
                        color: Colors.on_surface_variant
                        opacity: 0.5
                    }
                }
            }

            // ── the password, asked here ──
            Loader {
                width: parent.width
                active: row.isExpanded && !row.modelData.active
                visible: active

                sourceComponent: Item {
                    implicitHeight: 50
                    Component.onCompleted: pwField.forceActiveFocus()

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 8
                        anchors.bottomMargin: 10
                        spacing: 8

                        StyledTextField {
                            id: pwField
                            Layout.fillWidth: true
                            Layout.preferredHeight: 36
                            leftPadding: 12
                            rightPadding: 36
                            echoMode: showPw.shown ? TextInput.Normal : TextInput.Password
                            placeholderText: row.hasError ? Services.Network.lastErrorMessage
                                : wifiRoot.chosenBand !== "" ? "Password  (joins on " + wifiRoot.chosenBand + " GHz)"
                                : "Password"
                            placeholderTextColor: row.hasError ? Colors.error : Colors.on_surface_variant
                            font.pixelSize: 13
                            backgroundColor: Colors.surface_container_highest
                            borderColor: row.hasError ? Colors.error : Colors.outline_variant
                            focusBorderColor: row.hasError ? Colors.error : wifiRoot.accent
                            onAccepted: {
                                Services.Network.connect(row.modelData, text, wifiRoot.chosenBand)
                                text = ""
                            }
                            Keys.onEscapePressed: wifiRoot.expandedSsid = ""

                            ClickableRect {
                                id: showPw
                                property bool shown: false
                                anchors.right: parent.right
                                anchors.rightMargin: 5
                                anchors.verticalCenter: parent.verticalCenter
                                width: 26
                                height: 26
                                radius: Services.DesktopTheme.rad(13)
                                color: showPw.hovered ? Colors.surface_container : "transparent"
                                MaterialIcon {
                                    anchors.centerIn: parent
                                    text: showPw.shown ? "󰈉" : "󰈈"
                                    font.pixelSize: 14
                                    color: Colors.on_surface_variant
                                }
                                cursorShape: Qt.PointingHandCursor
                                onClicked: showPw.shown = !showPw.shown
                            }
                        }

                        ClickableRect {
                            id: connRect
                            Layout.preferredWidth: 76
                            Layout.preferredHeight: 36
                            radius: Services.DesktopTheme.rad(10)
                            color: connRect.hovered ? Qt.lighter(wifiRoot.accent, 1.08) : wifiRoot.accent
                            StyledText {
                                anchors.centerIn: parent
                                text: "Join"
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                                color: Colors.on_primary
                            }
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Services.Network.connect(row.modelData, pwField.text, wifiRoot.chosenBand)
                                pwField.text = ""
                            }
                        }
                    }
                }
            }
        }
    }

    // A band a network is on, with its signal there. Lit: the band in use;
    // ringed: the band chosen for the password being typed.
    component BandChip: ClickableRect {
        id: chip

        required property var reach
        required property string ssid
        property bool chosen: false
        readonly property bool inUse: reach.active

        implicitWidth: chipText.implicitWidth + 14
        implicitHeight: 18
        width: implicitWidth
        height: implicitHeight
        radius: Services.DesktopTheme.rad(9)
        color: inUse ? Colors.withAlpha(wifiRoot.accent, 0.2)
            : chosen ? Colors.withAlpha(wifiRoot.accent2, 0.18)
            : hovered ? Colors.surface_container_highest : "transparent"
        border.width: 1
        border.color: inUse ? Colors.withAlpha(wifiRoot.accent, 0.75)
            : chosen || hovered ? Colors.withAlpha(wifiRoot.accent2, 0.8)
            : Colors.withAlpha(Colors.on_surface_variant, 0.3)
        cursorShape: inUse ? Qt.ArrowCursor : Qt.PointingHandCursor

        StyledText {
            id: chipText
            anchors.centerIn: parent
            text: chip.reach.band + " GHz  " + chip.reach.signal + "%"
            font.pixelSize: 10
            font.features: ({ "tnum": 1 })
            color: chip.inUse ? wifiRoot.accent
                : chip.chosen || chip.hovered ? wifiRoot.accent2
                : Colors.withAlpha(Colors.on_surface_variant, 0.9)
        }

        onEntered: wifiRoot.chipEntered(chip.ssid, chip.reach.band)
        onExited: wifiRoot.chipExited(chip.ssid, chip.reach.band)
    }
}
