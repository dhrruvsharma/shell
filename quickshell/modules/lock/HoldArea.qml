import QtQuick

// Press-and-hold to confirm, for power actions on the lock screen: `progress`
// fills while held and `confirmed` fires once it reaches 1; letting go early
// drains it. Themes draw their own button around it.
MouseArea {
    id: area

    property int holdMs: 750
    property real progress: 0
    signal confirmed

    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor

    onPressed: {
        drain.stop();
        fill.duration = Math.max(1, holdMs * (1 - progress));
        fill.restart();
    }
    onReleased: {
        if (progress < 1) {
            fill.stop();
            drain.restart();
        }
    }
    onCanceled: {
        fill.stop();
        drain.restart();
    }

    NumberAnimation {
        id: fill
        target: area
        property: "progress"
        to: 1
        onFinished: {
            if (area.progress >= 1) {
                area.progress = 0;
                area.confirmed();
            }
        }
    }

    NumberAnimation {
        id: drain
        target: area
        property: "progress"
        to: 0
        duration: 220
        easing.type: Easing.OutCubic
    }
}
