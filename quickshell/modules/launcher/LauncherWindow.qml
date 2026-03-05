import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import "../../colors" as ColorsModule
import qs.services as Services

Item {
    id: root

    property bool isOpen: false
    property string searchText: ""

    property var filteredApps: {
        const q = searchText.trim().toLowerCase()
        if (!q) return Services.AppRegistry.apps
        return Services.AppRegistry.apps.filter(app =>
            app.name.toLowerCase().includes(q) ||
            (app.comment && app.comment.toLowerCase().includes(q))
        )
    }

    function toggle() {
        if (isOpen) close()
        else open()
    }

    function open() {
        if (isOpen) return
        isOpen = true
        searchField.text = ""
        searchField.forceActiveFocus()
        // Reset panel to start position before animating in
        panel.opacity = 0
        panel.scale  = 0.88
        panel.y      = panel._centerY + 28
        openAnim.restart()
    }

    function close() {
        if (!isOpen) return
        closeAnim.restart()
    }

    anchors.fill: parent

    Rectangle {
        id: scrim
        anchors.fill: parent
        color: ColorsModule.Colors.scrim
        opacity: 0

        enabled: scrim.opacity > 0.01

        Behavior on opacity {
            NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
        }

        MouseArea {
            anchors.fill: parent
            enabled: parent.enabled
            onClicked: root.close()
        }
    }

    Rectangle {
        id: panel

        width: 640
        height: 600

        property real _centerX: (root.width  - width)  / 2
        property real _centerY: (root.height - height) / 2

        x: _centerX
        y: _centerY

        radius: 24

        color: ColorsModule.Colors.surface_container
        border.color: ColorsModule.Colors.outline_variant
        border.width: 1

        opacity: 0
        scale:   0.88
        enabled: opacity > 0.01

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: ColorsModule.Colors.shadow
            shadowBlur: 0.7
            shadowVerticalOffset: 16
            shadowHorizontalOffset: 0
            shadowOpacity: 0.65
        }

        ParallelAnimation {
            id: openAnim

            NumberAnimation {
                target: scrim; property: "opacity"
                to: 0.55; duration: 260; easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: panel; property: "opacity"
                to: 1; duration: 220; easing.type: Easing.OutCubic
            }
            SequentialAnimation {
                NumberAnimation {
                    target: panel; property: "scale"
                    to: 1.02; duration: 200; easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: panel; property: "scale"
                    to: 1.0; duration: 100; easing.type: Easing.InOutQuad
                }
            }
            NumberAnimation {
                target: panel; property: "y"
                to: panel._centerY; duration: 280; easing.type: Easing.OutCubic
            }
        }

        ParallelAnimation {
            id: closeAnim

            NumberAnimation {
                target: scrim; property: "opacity"
                to: 0; duration: 180; easing.type: Easing.InCubic
            }
            NumberAnimation {
                target: panel; property: "opacity"
                to: 0; duration: 160; easing.type: Easing.InCubic
            }
            NumberAnimation {
                target: panel; property: "scale"
                to: 0.90; duration: 180; easing.type: Easing.InCubic
            }
            NumberAnimation {
                target: panel; property: "y"
                to: panel._centerY + 20; duration: 180; easing.type: Easing.InCubic
            }

            onFinished: root.isOpen = false
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            Item {
                Layout.fillWidth: true
                height: 72

                Rectangle {
                    anchors.fill: parent
                    color: ColorsModule.Colors.surface_container_high
                    radius: 24
                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 24
                        color: parent.color
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 20
                    anchors.rightMargin: 20
                    spacing: 14

                    Text {
                        text: "⌕"
                        font.pixelSize: 22
                        color: searchField.activeFocus
                            ? ColorsModule.Colors.primary
                            : ColorsModule.Colors.on_surface_variant
                        Layout.alignment: Qt.AlignVCenter
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }

                    TextField {
                        id: searchField
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter

                        placeholderText: "Search applications…"
                        font.pixelSize: 16
                        font.family: "Noto Sans"
                        color: ColorsModule.Colors.on_surface
                        placeholderTextColor: ColorsModule.Colors.on_surface_variant

                        background: Item {}

                        onTextChanged: root.searchText = text

                        Keys.onEscapePressed: root.close()
                        Keys.onReturnPressed: {
                            if (root.filteredApps.length > 0)
                                launchApp(root.filteredApps[gridView.currentIndex >= 0 ? gridView.currentIndex : 0])
                        }
                        Keys.onDownPressed: gridView.forceActiveFocus()
                    }

                    Rectangle {
                        visible: searchField.text.length > 0
                        width: 26; height: 26
                        radius: 13
                        color: clearHover.containsMouse
                            ? ColorsModule.Colors.surface_container_highest
                            : ColorsModule.Colors.surface_container_high
                        Layout.alignment: Qt.AlignVCenter
                        Behavior on color { ColorAnimation { duration: 100 } }

                        Text {
                            anchors.centerIn: parent
                            text: "✕"
                            font.pixelSize: 11
                            color: ColorsModule.Colors.on_surface_variant
                        }

                        MouseArea {
                            id: clearHover
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: searchField.text = ""
                            cursorShape: Qt.PointingHandCursor
                        }
                    }
                }

                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 1
                    color: searchField.activeFocus
                        ? ColorsModule.Colors.primary
                        : ColorsModule.Colors.outline_variant
                    opacity: searchField.activeFocus ? 0.9 : 0.5
                    Behavior on color   { ColorAnimation  { duration: 180 } }
                    Behavior on opacity { NumberAnimation { duration: 180 } }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                GridView {
                    id: gridView
                    anchors.fill: parent
                    anchors.margins: 16
                    anchors.bottomMargin: 8

                    cellWidth: 118
                    cellHeight: 112
                    clip: true

                    model: root.filteredApps

                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded
                        contentItem: Rectangle {
                            implicitWidth: 4
                            radius: 2
                            color: ColorsModule.Colors.outline
                            opacity: 0.6
                        }
                        background: Item {}
                    }

                    Keys.onReturnPressed: {
                        if (currentIndex >= 0 && currentIndex < root.filteredApps.length)
                            launchApp(root.filteredApps[currentIndex])
                    }
                    Keys.onEscapePressed: root.close()
                    Keys.onUpPressed: {
                        if (currentIndex < gridView.columns)
                            searchField.forceActiveFocus()
                        else
                            moveCurrentIndexUp()
                    }

                    delegate: Item {
                        id: delegateRoot
                        width: gridView.cellWidth
                        height: gridView.cellHeight

                        property var app: root.filteredApps[index]
                        property bool isHovered: false
                        property bool isFocused: GridView.isCurrentItem

                        opacity: 0
                        scale: 0.85
                        Component.onCompleted: entranceAnim.start()

                        ParallelAnimation {
                            id: entranceAnim
                            running: false
                            NumberAnimation {
                                target: delegateRoot; property: "opacity"
                                from: 0; to: 1; duration: 200
                                easing.type: Easing.OutCubic
                            }
                            NumberAnimation {
                                target: delegateRoot; property: "scale"
                                from: 0.82; to: 1; duration: 220
                                easing.type: Easing.OutBack
                            }
                        }

                        Rectangle {
                            id: appCard
                            anchors.fill: parent
                            anchors.margins: 5
                            radius: 16

                            color: isHovered || isFocused
                                ? ColorsModule.Colors.surface_container_highest
                                : "transparent"
                            border.color: isFocused ? ColorsModule.Colors.primary : "transparent"
                            border.width: isFocused ? 1.5 : 0

                            Behavior on color        { ColorAnimation { duration: 120 } }
                            Behavior on border.color { ColorAnimation { duration: 120 } }

                            Image {
                                id: appIcon
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.top: parent.top
                                anchors.topMargin: 14
                                width: 42; height: 42

                                sourceSize.width: 64
                                sourceSize.height: 64

                                source: Services.AppRegistry.iconForAppMeta(app)
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                                mipmap: false
                                antialiasing: true

                                scale: isHovered ? 1.12 : 1.0
                                Behavior on scale { NumberAnimation { duration: 130; easing.type: Easing.OutBack } }

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 10
                                    color: ColorsModule.Colors.primary_container
                                    visible: parent.status === Image.Error || parent.status === Image.Null

                                    Text {
                                        anchors.centerIn: parent
                                        text: app && app.name ? app.name.charAt(0).toUpperCase() : "?"
                                        font.pixelSize: 18
                                        font.weight: Font.Medium
                                        renderType: Text.NativeRendering
                                        color: ColorsModule.Colors.on_primary_container
                                    }
                                }
                            }

                            Text {
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 10
                                anchors.left: parent.left; anchors.right: parent.right
                                anchors.leftMargin: 5;     anchors.rightMargin: 5

                                text: app ? app.name : ""
                                font.pixelSize: 11
                                font.family: "Noto Sans"
                                renderType: Text.NativeRendering
                                color: isFocused
                                    ? ColorsModule.Colors.primary
                                    : ColorsModule.Colors.on_surface
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                                maximumLineCount: 2
                                wrapMode: Text.WordWrap
                                Behavior on color { ColorAnimation { duration: 120 } }
                            }

                            Rectangle {
                                id: pressOverlay
                                anchors.fill: parent
                                radius: appCard.radius
                                color: ColorsModule.Colors.primary
                                opacity: 0
                                NumberAnimation on opacity {
                                    id: pressAnim; running: false
                                    from: 0.18; to: 0; duration: 350
                                    easing.type: Easing.OutCubic
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: { isHovered = true; gridView.currentIndex = index }
                                onExited:  isHovered = false
                                onPressed: pressAnim.restart()
                                onClicked: launchApp(root.filteredApps[index])
                            }
                        }
                    }

                    Column {
                        anchors.centerIn: parent
                        visible: root.filteredApps.length === 0
                        spacing: 8
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "⊘"; font.pixelSize: 32
                            color: ColorsModule.Colors.on_surface_variant; opacity: 0.5
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "No apps found"; font.pixelSize: 14
                            font.family: "Noto Sans"
                            color: ColorsModule.Colors.on_surface_variant
                        }
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                height: 42

                Rectangle {
                    anchors.fill: parent
                    color: ColorsModule.Colors.surface_container_low
                    radius: 24
                    Rectangle {
                        anchors.top: parent.top
                        anchors.left: parent.left; anchors.right: parent.right
                        height: 24
                        color: parent.color
                    }
                }

                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left; anchors.right: parent.right
                    height: 1
                    color: ColorsModule.Colors.outline_variant; opacity: 0.4
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 20; anchors.rightMargin: 16
                    spacing: 6

                    Rectangle {
                        width: 6; height: 6; radius: 3
                        color: ColorsModule.Colors.primary; opacity: 0.7
                    }
                    Text {
                        text: root.filteredApps.length + " app" + (root.filteredApps.length !== 1 ? "s" : "")
                        font.pixelSize: 11; font.family: "Noto Sans"
                        color: ColorsModule.Colors.on_surface_variant
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: "↵ launch  ·  ↑↓←→ navigate  ·  Esc close"
                        font.pixelSize: 11; font.family: "Noto Sans"
                        color: ColorsModule.Colors.on_surface_variant; opacity: 0.6
                    }
                }
            }
        }
    }

    function launchApp(app) {
        if (!app || !app.exec) return
        const cmd = app.exec.replace(/%[uUfFdDnNickvm]/g, "").trim()
        launcher.command = ["bash", "-c", cmd]
        launcher.running = true
        root.close()
    }

    Process {
        id: launcher
        running: false
    }
}
