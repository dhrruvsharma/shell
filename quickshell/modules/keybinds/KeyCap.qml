pragma ComponentBehavior: Bound
import QtQuick
import qs.colors
import qs.components
import qs.modules.lock
import qs.services as Services

// One key of the keyboard map. A bound key takes its action's colour and
// icon (the app's own for a launcher, the workspace's number for a jump);
// a modifier key lights up when it is part of the layer shown; a key with
// two binds on it carries a red dot.
Item {
    id: cap

    required property var spec
    property real u: 48
    // binds on this key in the layer shown
    property var binds: []
    property bool modActive: false
    property bool selected: false
    // the editor's key
    property bool target: false
    property bool picking: false
    property bool dimmed: false
    // app icons by program, from the panel
    property var appIcon: null

    signal clicked
    signal doubleClicked
    signal hoverChanged(bool on)

    readonly property bool isMod: (spec.mod ?? "") !== ""
    readonly property bool extra: spec.group !== undefined
    readonly property var bind: binds.length ? binds[0] : null
    readonly property bool bound: binds.length > 0
    readonly property bool conflict: binds.length > 1
    readonly property bool hovered: mouse.containsMouse
    readonly property color tone: bind ? KeyData.toneOf(bind.category) : Colors.outline
    readonly property real gap: Math.max(3, u * 0.085)
    readonly property real lip: Math.max(2, Math.round(u * 0.07))
    readonly property string iconSource: bind && bind.category === "app" && appIcon ? appIcon(bind.app) : ""
    // wide enough to name what it does
    readonly property bool roomy: spec.w >= 1.7 && !extra
    // A key that does what's printed on it (an arrow moving focus its own
    // way, Mute muting) shows the one icon.
    readonly property bool echoes: !!bind && (extra ? spec.icon === bind.glyph
        : ({ left: "arrow_back", right: "arrow_forward", up: "arrow_upward", down: "arrow_downward" })[String(spec.name).toLowerCase()] === bind.glyph)

    x: spec.x * u
    y: (extra ? KeyData.extrasY : spec.y) * u
    width: spec.w * u
    height: (extra ? KeyData.extrasHeight : 1) * u
    opacity: dimmed ? 0.26 : 1

    Behavior on opacity {
        NumberAnimation { duration: 160 }
    }

    readonly property color faceColor: {
        if (isMod)
            return modActive ? Services.DesktopTheme.accent : Colors.surface_container_high;
        if (bound)
            return Qt.tint(Colors.surface_container_high, Colors.withAlpha(tone, hovered ? 0.3 : 0.2));
        return hovered ? Colors.surface_container_highest : Colors.surface_container_high;
    }

    // the key's side, showing under the face as a lip
    Rectangle {
        id: side
        x: cap.gap / 2
        y: cap.gap / 2
        width: cap.width - cap.gap
        height: cap.height - cap.gap
        radius: Services.DesktopTheme.rad(Math.round(cap.u * 0.16))
        color: Qt.darker(cap.faceColor, cap.bound || cap.modActive ? 1.55 : 1.4)

        Rectangle {
            id: face
            anchors.fill: parent
            anchors.topMargin: mouse.pressed ? cap.lip - 1 : 0
            anchors.bottomMargin: mouse.pressed ? 1 : cap.lip
            radius: parent.radius
            color: cap.faceColor
            border.width: 1
            border.color: cap.isMod && cap.modActive ? Qt.lighter(cap.faceColor, 1.2)
                : cap.bound ? Colors.withAlpha(cap.tone, cap.hovered ? 0.95 : 0.55)
                : Colors.withAlpha(cap.hovered ? Colors.outline : Colors.outline_variant, cap.hovered ? 0.9 : 0.6)

            Behavior on color {
                ColorAnimation { duration: 120 }
            }

            // what's printed on the key
            StyledText {
                id: legend
                visible: (cap.spec.icon === undefined || cap.spec.icon === "") && !cap.echoes
                x: cap.extra ? Math.round(cap.u * 0.14) : Math.round(cap.u * 0.13)
                y: cap.extra ? (parent.height - height) / 2 : Math.round(cap.u * 0.08)
                text: cap.spec.legend ?? ""
                font.pixelSize: Math.max(9, Math.round(cap.u * (cap.spec.legend && cap.spec.legend.length > 2 ? 0.2 : 0.24)))
                font.weight: cap.bound || cap.modActive ? Font.DemiBold : Font.Medium
                color: cap.modActive ? Colors.on_primary : cap.bound ? Colors.on_surface : Colors.on_surface_variant
                opacity: cap.bound || cap.modActive ? 0.92 : 0.62
            }

            Glyph {
                visible: (cap.spec.icon ?? "") !== "" && !cap.echoes
                x: Math.round(cap.u * 0.12)
                anchors.verticalCenter: parent.verticalCenter
                text: cap.spec.icon ?? ""
                font.pixelSize: Math.round(cap.u * 0.3)
                color: cap.bound ? Colors.on_surface : Colors.on_surface_variant
                opacity: cap.bound ? 0.85 : 0.55
            }

            // what it does
            Row {
                id: action
                visible: cap.bound && !cap.isMod
                spacing: Math.round(cap.u * 0.1)
                anchors.verticalCenter: cap.extra || cap.echoes ? parent.verticalCenter : undefined
                anchors.right: cap.extra && !cap.echoes ? parent.right : undefined
                anchors.rightMargin: Math.round(cap.u * 0.14)
                anchors.horizontalCenter: cap.extra && !cap.echoes || cap.roomy ? undefined : parent.horizontalCenter
                x: Math.round(cap.u * 0.14)
                y: parent.height - height - Math.round(cap.u * 0.1)

                Item {
                    width: Math.round(cap.u * (cap.extra ? 0.36 : 0.42))
                    height: width
                    anchors.verticalCenter: parent.verticalCenter

                    Image {
                        anchors.fill: parent
                        visible: cap.iconSource !== "" && status === Image.Ready
                        source: cap.iconSource
                        sourceSize: Qt.size(width * 2, height * 2)
                        asynchronous: true
                        smooth: true
                    }

                    // a workspace, as a numbered pip
                    Rectangle {
                        anchors.fill: parent
                        visible: cap.iconSource === "" && !!cap.bind && String(cap.bind.glyph).startsWith("#")
                        radius: Services.DesktopTheme.rad(Math.round(height * 0.28))
                        color: Colors.withAlpha(cap.tone, 0.16)
                        border.width: 1.5
                        border.color: cap.tone

                        StyledText {
                            anchors.centerIn: parent
                            text: cap.bind ? String(cap.bind.glyph).slice(1) : ""
                            font.pixelSize: Math.round(parent.height * (text.length > 1 ? 0.5 : 0.6))
                            font.weight: Font.Bold
                            color: cap.tone
                        }
                    }

                    Glyph {
                        anchors.centerIn: parent
                        visible: cap.iconSource === "" && cap.bind && !String(cap.bind.glyph).startsWith("#")
                        text: cap.bind ? cap.bind.glyph : ""
                        filled: true
                        font.pixelSize: parent.height
                        color: cap.tone
                    }
                }

                StyledText {
                    visible: cap.roomy
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, cap.width - cap.u * 0.95)
                    text: cap.bind ? cap.bind.title : ""
                    elide: Text.ElideRight
                    font.pixelSize: Math.max(10, Math.round(cap.u * 0.22))
                    font.weight: Font.Medium
                    color: Colors.on_surface
                    opacity: 0.85
                }
            }

            // a free key, while picking one
            Glyph {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: cap.extra ? 0 : Math.round(cap.u * 0.08)
                visible: cap.picking && cap.hovered && !cap.bound && !cap.isMod
                text: "add"
                font.pixelSize: Math.round(cap.u * 0.36)
                color: Services.DesktopTheme.accent
            }
        }
    }

    // selected, or the key the editor is setting
    Rectangle {
        anchors.fill: side
        anchors.margins: -3
        visible: cap.selected || cap.target
        radius: side.radius + 3
        color: "transparent"
        border.width: 2
        border.color: cap.target ? Services.DesktopTheme.accent : Colors.on_surface
    }

    Rectangle {
        visible: cap.conflict
        width: Math.round(cap.u * 0.16)
        height: width
        radius: width / 2
        x: side.x + side.width - width - Math.round(cap.u * 0.1)
        y: side.y + Math.round(cap.u * 0.1)
        color: Colors.error
        border.width: 1.5
        border.color: cap.faceColor
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: cap.clicked()
        onDoubleClicked: cap.doubleClicked()
        onContainsMouseChanged: cap.hoverChanged(containsMouse)
    }
}
