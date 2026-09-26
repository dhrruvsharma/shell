import QtQuick

// One clock digit that rolls like a slot-machine reel when it changes: the old
// value slides up and out while the new one rises into place. Its width
// follows the digit (Orbitron's figures are proportional), easing from the
// old digit's width to the new one's during the roll.
Item {
    id: digit

    property string value: "0"
    property font font
    property color color: LockTheme.ink

    property string _shown: ""
    property string _prev: ""
    property real _t: 1

    implicitWidth: Math.ceil(_prev === "" ? cur.advanceWidth : prev.advanceWidth + (cur.advanceWidth - prev.advanceWidth) * _t)
    implicitHeight: Math.ceil(cur.height)
    clip: true

    Component.onCompleted: _shown = value
    onValueChanged: {
        if (_shown === "" || value === _shown)
            return;
        _prev = _shown;
        _shown = value;
        roll.restart();
    }

    TextMetrics {
        id: cur
        font: digit.font
        text: digit._shown === "" ? digit.value : digit._shown
    }

    TextMetrics {
        id: prev
        font: digit.font
        text: digit._prev
    }

    Text {
        width: digit.width
        y: -digit._t * digit.height * 0.9
        opacity: 1 - digit._t
        visible: digit._t < 1
        horizontalAlignment: Text.AlignHCenter
        text: digit._prev
        font: digit.font
        color: digit.color
    }

    Text {
        width: digit.width
        y: (1 - digit._t) * digit.height * 0.9
        opacity: digit._t
        horizontalAlignment: Text.AlignHCenter
        text: digit._shown
        font: digit.font
        color: digit.color
    }

    NumberAnimation {
        id: roll
        target: digit
        property: "_t"
        from: 0
        to: 1
        duration: 520
        easing.type: Easing.OutBack
        easing.overshoot: 1.2
    }
}
