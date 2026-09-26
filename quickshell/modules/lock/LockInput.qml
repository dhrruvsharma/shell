import QtQuick

// Keyboard and click plumbing shared by every lock theme: an invisible
// TextInput mirrored into ctx.buffer (it keeps IME, compose and every keyboard
// layout working), plus a surface-wide MouseArea that re-focuses it. Declare it
// first in a theme so the theme's own controls stack above the catch-all
// MouseArea.
//
// Esc is left to the theme (`escapePressed`): close a menu, else clear the
// input. In a preview, Esc on an empty passcode ends the preview.
Item {
    id: li

    required property LockContext ctx
    // False for still thumbnails: never takes focus or clicks.
    property bool active: true

    signal escapePressed
    signal backgroundPressed

    function focusInput() {
        if (active)
            input.forceActiveFocus();
    }

    anchors.fill: parent

    Component.onCompleted: focusInput()

    MouseArea {
        anchors.fill: parent
        enabled: li.active
        hoverEnabled: li.active
        onPositionChanged: li.ctx.poke()
        onPressed: {
            li.ctx.poke();
            li.ctx.skip();
            li.backgroundPressed();
            li.focusInput();
        }
    }

    TextInput {
        id: input

        width: 1
        height: 1
        opacity: 0
        focus: li.active
        enabled: li.active
        echoMode: TextInput.Password
        passwordMaskDelay: 0
        inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase | Qt.ImhHiddenText
        readOnly: li.ctx.inputLocked
        selectByMouse: false

        onTextChanged: li.ctx.setBuffer(text)
        onAccepted: li.ctx.submit()

        Keys.onPressed: event => {
            const c = li.ctx;
            c.poke();
            if (event.key === Qt.Key_CapsLock)
                c.refreshCaps();
            if (c.phase === "granted" || c.phase === "exiting") {
                c.skip();
                event.accepted = true;
            } else if (event.key === Qt.Key_Escape) {
                if (c.preview && c.buffer.length === 0)
                    c.previewExit();
                else
                    li.escapePressed();
                event.accepted = true;
            }
        }

        Connections {
            target: li.ctx

            function onBufferChanged() {
                if (input.text !== li.ctx.buffer)
                    input.text = li.ctx.buffer;
            }
        }
    }
}
