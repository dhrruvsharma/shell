import QtQuick
import qs.colors
import qs.components
import qs.modules.lock
import qs.services as Services

// One container's width: its glyph and name, Auto (as wide as its text),
// narrower and wider buttons around a slider, and the width it comes to.
// It only shows what it's given and says what's asked of it; the Width tab
// does the setting.
ClickableRect {
    id: root

    property string icon
    property string name
    // The width set (0: auto) and its width when it's auto.
    property real setWidth: 0
    property real autoWidth: 0
    // Overrides the width shown on the right (the "All widgets" row).
    property string valueText: ""
    property bool selected: false
    // The text no longer fits, so it scrolls (or is cut short).
    readonly property bool overflows: root.setWidth > 0 && root.autoWidth > root.setWidth + 0.5
    readonly property bool isAuto: root.setWidth <= 0

    signal autoClicked
    signal nudged(int delta)
    signal slid(real value)

    implicitHeight: 38
    radius: Services.DesktopTheme.rad(12)
    color: root.selected ? Colors.surface_container_high : root.hovered ? Colors.withAlpha(Colors.surface_container_high, 0.6) : "transparent"
    border.width: root.selected ? 1 : 0
    border.color: Colors.withAlpha(Colors.primary, 0.6)

    Rectangle {
        id: badge
        x: 6
        anchors.verticalCenter: parent.verticalCenter
        width: 28
        height: 28
        radius: Services.DesktopTheme.rad(9)
        color: root.isAuto ? Colors.surface_container_highest : Colors.primary_container

        Glyph {
            anchors.centerIn: parent
            text: root.icon
            filled: !root.isAuto
            font.pixelSize: 17
            color: root.isAuto ? Colors.on_surface_variant : Colors.on_primary_container
        }
    }

    StyledText {
        id: nameText
        anchors.left: badge.right
        anchors.leftMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        width: 118
        text: root.name
        elide: Text.ElideRight
        font.pixelSize: 13
        font.weight: Font.DemiBold
    }

    // Auto, a chip that's lit while it's on.
    ClickableRect {
        id: autoChip
        anchors.left: nameText.right
        anchors.leftMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        width: 58
        height: 26
        radius: Services.DesktopTheme.rad(13)
        color: root.isAuto ? Colors.secondary_container : autoChip.hovered ? Colors.surface_container_highest : Colors.surface_container
        border.width: root.isAuto ? 0 : 1
        border.color: Colors.withAlpha(Colors.outline_variant, 0.8)
        cursorShape: Qt.PointingHandCursor
        onClicked: root.autoClicked()

        StyledText {
            anchors.centerIn: parent
            text: "Auto"
            font.pixelSize: 12
            font.weight: Font.DemiBold
            color: root.isAuto ? Colors.on_secondary_container : Colors.on_surface_variant
        }
    }

    Step {
        id: minus
        anchors.left: autoChip.right
        anchors.leftMargin: 12
        glyph: "remove"
        onClicked: root.nudged(-4)
    }

    WidthSlider {
        id: slider
        anchors.left: minus.right
        anchors.leftMargin: 6
        anchors.right: plus.left
        anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        from: Services.BarSettings.widthMin
        to: Services.BarSettings.widthMax
        value: root.isAuto ? root.autoWidth : root.setWidth
        muted: root.isAuto
        onMoved: v => root.slid(v)
    }

    Step {
        id: plus
        anchors.right: valueBox.left
        anchors.rightMargin: 8
        glyph: "add"
        onClicked: root.nudged(4)
    }

    Row {
        id: valueBox
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        width: 92
        layoutDirection: Qt.RightToLeft
        spacing: 4

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: root.valueText || (root.isAuto ? "Auto · " + Math.round(root.autoWidth) : Math.round(root.setWidth) + " px")
            font.pixelSize: 12
            font.weight: root.isAuto ? Font.Normal : Font.DemiBold
            font.features: ({ "tnum": 1 })
            color: root.isAuto ? Colors.on_surface_variant : Colors.on_surface
        }

        // Says it's narrower than its text.
        Glyph {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.overflows && !root.valueText
            text: Services.BarSettings.overflow === "cut" ? "content_cut" : "swap_horiz"
            font.pixelSize: 15
            color: Colors.tertiary
        }
    }

    // A small round − or + button.
    component Step: ClickableRect {
        id: step

        property string glyph

        anchors.verticalCenter: parent.verticalCenter
        width: 26
        height: 26
        radius: 13
        color: step.pressed ? Colors.surface_container_highest : step.hovered ? Colors.surface_container_high : Colors.surface_container
        border.width: 1
        border.color: Colors.withAlpha(Colors.outline_variant, 0.8)
        cursorShape: Qt.PointingHandCursor

        Glyph {
            anchors.centerIn: parent
            text: step.glyph
            font.pixelSize: 16
            weight: 600
            color: Colors.on_surface
        }
    }
}
