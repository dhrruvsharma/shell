pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.components
import qs.colors
import qs.services as Services

// Popout hanging from the top bar's Updates atom. Lists pending pacman/AUR
// updates and offers "update all", "update selected", or a per-package update,
// each handing off to a terminal (see Updates service). Detection stays
// passwordless.
Popout {
    id: root
    alignment: 1                    // attachedTopRight — hangs below the bar, right side
    // Hidden once fully collapsed so its spinner (and any repaint) stops;
    // a zero-width but visible panel still drives frames of the whole shell.
    visible: root.opened || root.implicitWidth > 0
    focus: true

    property bool opened: false

    readonly property var svc: Services.Updates

    // Names of packages ticked for a batch update.
    property var selected: []

    function isSelected(name) {
        return root.selected.indexOf(name) >= 0;
    }
    function toggle(name) {
        var s = root.selected.slice();
        var i = s.indexOf(name);
        if (i >= 0)
            s.splice(i, 1);
        else
            s.push(name);
        root.selected = s;
    }
    function selectAll() {
        var s = [];
        for (var i = 0; i < root.svc.updates.length; i++)
            s.push(root.svc.updates[i].name);
        root.selected = s;
    }
    function clearSelection() {
        root.selected = [];
    }

    // A fresh check invalidates the old selection; closing clears it too.
    onOpenedChanged: if (!root.opened) root.clearSelection()
    Connections {
        target: root.svc
        function onLastCheckedChanged() { root.clearSelection(); }
    }

    implicitHeight: 520
    implicitWidth: opened ? 460 : 0

    Behavior on implicitWidth {
        NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
    }

    Rectangle {
        anchors.fill: parent
        color: Colors.surface
        radius: Services.DesktopTheme.rad(14)
        clip: true

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 14

            // ---- header -------------------------------------------------
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                MaterialIcon {
                    text: "󰚰"
                    font.pixelSize: 22
                    color: Colors.primary
                }

                StyledText {
                    text: "Updates"
                    font.pixelSize: 17
                    font.weight: Font.DemiBold
                }

                Rectangle {
                    visible: root.svc.count > 0
                    radius: Services.DesktopTheme.rad(9)
                    implicitHeight: 18
                    implicitWidth: countLabel.implicitWidth + 14
                    color: Colors.primary

                    StyledText {
                        id: countLabel
                        anchors.centerIn: parent
                        text: root.svc.count
                        color: Colors.on_primary
                        font.pixelSize: 11
                        font.weight: Font.Bold
                    }
                }

                Item { Layout.fillWidth: true }

                // Select-all / clear toggle.
                IconButton {
                    visible: root.svc.count > 0
                    icon: root.selected.length === root.svc.count ? "󰄲" : "󰄱"
                    iconColor: root.selected.length > 0 ? Colors.primary : Colors.on_surface_variant
                    onClicked: {
                        if (root.selected.length === root.svc.count)
                            root.clearSelection();
                        else
                            root.selectAll();
                    }
                }

                IconButton {
                    icon: "󰑐"
                    enabled: !root.svc.checking
                    opacity: root.svc.checking ? 0.4 : 1
                    onClicked: root.svc.refresh()
                }

                IconButton {
                    icon: "󰅖"
                    iconColor: Colors.error
                    onClicked: root.opened = false
                }
            }

            // ---- primary action ----------------------------------------
            // Updates the ticked packages when any are selected, otherwise the
            // whole system.
            ActionButton {
                readonly property int selCount: root.selected.length
                icon: "󰇚"
                label: {
                    if (selCount > 0)
                        return "Update selected (" + selCount + ")";
                    return root.svc.count > 0 ? "Update all (" + root.svc.count + ")" : "System up to date";
                }
                buttonColor: root.svc.count > 0 ? Colors.primary_container : Colors.surface_container
                enabled: root.svc.count > 0
                opacity: root.svc.count > 0 ? 1 : 0.5
                onClicked: {
                    if (selCount > 0)
                        root.svc.updateMany(root.selected);
                    else
                        root.svc.updateAll();
                    root.opened = false;
                }
            }

            // ---- list ---------------------------------------------------
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Services.DesktopTheme.rad(12)
                color: Colors.surface_container_low
                clip: true

                ListView {
                    id: list
                    anchors.fill: parent
                    anchors.margins: 6
                    spacing: 4
                    model: root.svc.updates
                    clip: true
                    visible: root.svc.count > 0

                    ScrollBar.vertical: StyledScrollBar {}

                    delegate: Rectangle {
                        id: row
                        required property var modelData
                        readonly property bool checked: root.isSelected(row.modelData.name)
                        width: list.width - 12
                        implicitHeight: 46
                        radius: Services.DesktopTheme.rad(10)
                        color: row.checked ? Colors.withAlpha(Colors.primary, 0.12)
                             : rowMouse.containsMouse ? Colors.surface_container_high : "transparent"

                        // Clicking anywhere on the row toggles its selection.
                        MouseArea {
                            id: rowMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: root.toggle(row.modelData.name)
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 8
                            spacing: 10

                            // Checkbox.
                            Rectangle {
                                Layout.alignment: Qt.AlignVCenter
                                implicitWidth: 20
                                implicitHeight: 20
                                radius: Services.DesktopTheme.rad(6)
                                color: row.checked ? Colors.primary : "transparent"
                                border.width: row.checked ? 0 : 1.5
                                border.color: Colors.outline

                                MaterialIcon {
                                    anchors.centerIn: parent
                                    visible: row.checked
                                    text: "󰄬"
                                    font.pixelSize: 14
                                    color: Colors.on_primary
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1

                                RowLayout {
                                    spacing: 6
                                    StyledText {
                                        text: row.modelData.name
                                        font.pixelSize: 13
                                        font.weight: Font.DemiBold
                                        elide: Text.ElideRight
                                        Layout.maximumWidth: 220
                                    }
                                    Rectangle {
                                        visible: row.modelData.aur
                                        radius: Services.DesktopTheme.rad(6)
                                        implicitHeight: 15
                                        implicitWidth: aurTag.implicitWidth + 10
                                        color: Colors.tertiary_container
                                        StyledText {
                                            id: aurTag
                                            anchors.centerIn: parent
                                            text: "AUR"
                                            color: Colors.on_tertiary_container
                                            font.pixelSize: 9
                                            font.weight: Font.Bold
                                        }
                                    }
                                }

                                StyledText {
                                    text: row.modelData.oldVer + "  →  " + row.modelData.newVer
                                    font.pixelSize: 11
                                    color: Colors.on_surface_variant
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }

                            // Quick single-package update, independent of the ticks.
                            IconButton {
                                icon: "󰇚"
                                iconColor: Colors.primary
                                onClicked: {
                                    root.svc.updateOne(row.modelData.name);
                                    root.opened = false;
                                }
                            }
                        }
                    }
                }

                EmptyState {
                    visible: root.svc.count === 0 && !root.svc.checking
                    glyph: "󰄬"
                    title: "Everything is up to date"
                    subtitle: "No pending package updates"
                }

                Spinner {
                    anchors.centerIn: parent
                    visible: root.svc.checking && root.svc.count === 0
                    running: visible
                }
            }
        }
    }
}
