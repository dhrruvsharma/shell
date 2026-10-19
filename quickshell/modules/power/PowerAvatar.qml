import QtQuick
import QtQuick.Effects
import Quickshell

// Your picture (~/.cache/current_avatar), cut to a rounded square (a circle
// by default). A plain wash stands in until it loads, or if there is none.
Item {
    id: avatar

    property real radius: width / 2
    property color placeholder: Qt.rgba(1, 1, 1, 0.12)
    readonly property bool ready: img.status === Image.Ready

    Rectangle {
        id: mask
        anchors.fill: parent
        radius: avatar.radius
        visible: false
        layer.enabled: true
    }

    Image {
        id: img
        anchors.fill: parent
        source: "file://" + Quickshell.env("HOME") + "/.cache/current_avatar"
        sourceSize: Qt.size(avatar.width * 2, avatar.height * 2)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        visible: false
    }

    MultiEffect {
        anchors.fill: parent
        source: img
        visible: avatar.ready
        maskEnabled: true
        maskSource: mask
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1.0
    }

    Rectangle {
        anchors.fill: parent
        visible: !avatar.ready
        radius: avatar.radius
        color: avatar.placeholder
    }
}
