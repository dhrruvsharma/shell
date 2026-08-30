import QtQuick
import qs.colors

// The indeterminate loading ring. Set `width` to resize; height and radius follow.
Rectangle {
    id: root

    property int duration: 800
    property alias running: spin.running

    width: 28
    height: root.width
    radius: root.width / 2
    color: "transparent"
    border.color: Colors.primary
    border.width: 2

    RotationAnimator on rotation {
        id: spin
        from: 0
        to: 360
        duration: root.duration
        loops: Animation.Infinite
        running: root.visible
        easing.type: Easing.Linear
    }
}
