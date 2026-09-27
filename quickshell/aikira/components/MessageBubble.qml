import QtQuick
import qs.services as Services
import QtQuick.Layouts
import qs.aikira
import qs.colors
import qs.components

Item {
    id: root

    property var    message:          null
    property string characterName:    "AI"
    property string personaName:      "You"
    property bool   isStreaming:      false
    property bool   isLastAiMessage:  false
    property int    totalAlternatives: 1
    property int    currentAltIndex:   0

    signal deleteRequested()
    signal rerollRequested()
    signal prevAlternative()
    signal nextAlternative()

    readonly property bool isUser: message && message.role === "user"

    height: bubbleCol.implicitHeight + 16

    HoverHandler { id: msgHover }

    function formatText(raw) {
        // Split on fenced code blocks so their content isn't touched by other transforms
        const codeBlockRe = /```(\w*)\n?([\s\S]*?)```/g
        const parts = []
        let lastIndex = 0
        let m
        while ((m = codeBlockRe.exec(raw)) !== null) {
            if (m.index > lastIndex)
                parts.push({ type: "text", content: raw.slice(lastIndex, m.index) })
            parts.push({ type: "code", lang: m[1], content: m[2] })
            lastIndex = m.index + m[0].length
        }
        if (lastIndex < raw.length)
            parts.push({ type: "text", content: raw.slice(lastIndex) })

        let result = ""
        for (let i = 0; i < parts.length; i++) {
            const part = parts[i]
            if (part.type === "code") {
                const escaped = part.content
                    .replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
                    .replace(/\n$/, "")          // trim trailing newline inside block
                    .replace(/\n/g, "<br/>")
                const langTag = part.lang
                    ? '<span style="color:#d0bcfe;font-size:10px;font-family:monospace;">'
                      + part.lang + '</span><br/>'
                    : ''
                result += '<br/>' + langTag
                    + '<span style="background-color:#0f0d13;color:#cac4cf;'
                    + 'font-family:monospace;font-size:12px;padding:6px 10px;">'
                    + escaped + '</span><br/>'
            } else {
                let t = part.content
                    .replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")

                t = t.replace(/^### (.+)$/mg,
                    '<span style="font-size:15px;font-weight:600;color:#d0bcfe;">$1</span>')
                t = t.replace(/^## (.+)$/mg,
                    '<span style="font-size:17px;font-weight:600;color:#d0bcfe;">$1</span>')
                t = t.replace(/^# (.+)$/mg,
                    '<span style="font-size:19px;font-weight:600;color:#d0bcfe;">$1</span>')

                // Bold and italic
                t = t.replace(/\*\*([^*\n]+)\*\*/g, "<b>$1</b>")
                t = t.replace(/\*([^*\n]+)\*/g, "<i>$1</i>")

                // Inline code
                t = t.replace(/`([^`\n]+)`/g,
                    '<span style="background-color:#211f24;color:#d0bcfe;'
                    + 'font-family:monospace;font-size:12px;padding:1px 4px;">$1</span>')

                // Bullet lists (- or *)
                t = t.replace(/^[ \t]*[-*] (.+)$/mg, '\u00a0\u00a0• $1')

                // Horizontal rule
                t = t.replace(/^---$/mg,
                    '<span style="color:#49454e;">\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500</span>')

                // Newlines
                t = t.replace(/\n/g, "<br/>")
                result += t
            }
        }
        return result
    }

    property bool cursorVisible: true
    Timer {
        running: isStreaming
        interval: 530
        repeat: true
        onTriggered: root.cursorVisible = !root.cursorVisible
    }

    // Delete button — appears on hover beside the bubble
    ClickableRect {
        id: msgDeleteBtn
        visible: msgHover.hovered && !isStreaming && message !== null && message.id !== "streaming"
        width: 22; height: 22; radius: 5
        z: 1
        anchors {
            top: bubbleCol.top
            topMargin: 20
            right: isUser ? bubbleCol.left : undefined
            left: isUser ? undefined : bubbleCol.right
            rightMargin: isUser ? 4 : 0
            leftMargin: isUser ? 0 : 4
        }
        color: msgDeleteBtn.hovered ? Colors.error_container : "transparent"
        Behavior on color { ColorAnimation { duration: 100 } }
        StyledText {
            anchors.centerIn: parent
            text: "×"; font.pixelSize: 14
            color: msgDeleteBtn.hovered
                ? Colors.on_error_container
                : Colors.on_surface_variant
            opacity: msgDeleteBtn.hovered ? 1.0 : 0.45
        }
        cursorShape: Qt.PointingHandCursor
        onClicked: root.deleteRequested()
    }

    // Reroll button — only on the last AI message, on hover
    ClickableRect {
        id: msgRerollBtn
        visible: msgHover.hovered && !isStreaming && !isUser && isLastAiMessage && message !== null
        width: 22; height: 22; radius: 5
        z: 1
        anchors {
            top: msgDeleteBtn.bottom
            topMargin: 4
            left: bubbleCol.right
            leftMargin: 4
        }
        color: msgRerollBtn.hovered ? Colors.secondary_container : "transparent"
        Behavior on color { ColorAnimation { duration: 100 } }
        StyledText {
            anchors.centerIn: parent
            text: "↺"; font.pixelSize: 13
            color: msgRerollBtn.hovered
                ? Colors.on_secondary_container
                : Colors.on_surface_variant
            opacity: msgRerollBtn.hovered ? 1.0 : 0.45
        }
        cursorShape: Qt.PointingHandCursor
        onClicked: root.rerollRequested()
    }

    ColumnLayout {
        id: bubbleCol
        anchors {
            top: parent.top
            topMargin: 8
            left: isUser ? undefined : parent.left
            right: isUser ? parent.right : undefined
            leftMargin: isUser ? 0 : 16
            rightMargin: isUser ? 16 : 0
        }
        spacing: 4

        // Role label
        StyledText {
            text: isUser ? personaName : characterName
            font { pixelSize: 10; letterSpacing: 1; weight: Font.Bold }
            color: isUser
                ? Colors.secondary
                : Colors.primary
            opacity: 0.85
            Layout.alignment: isUser ? Qt.AlignRight : Qt.AlignLeft
            Layout.maximumWidth: root.width * 0.78
            elide: Text.ElideRight
        }

        // Bubble
        Rectangle {
            Layout.alignment: isUser ? Qt.AlignRight : Qt.AlignLeft
            // Width tracks text content but never exceeds 78% of the available area.
            // contentText.width is capped independently of bubble width, breaking
            // the circular dependency that caused overflow.
            width: contentText.width + (isUser ? 24 : 26)
            height: contentText.implicitHeight + 20
            radius: isUser
                ? 16  // round pill for user
                : 4   // sharp/geometric for AI
            color: isUser
                ? Colors.primary_container
                : Colors.surface_container_high

            // Subtle left accent bar for AI messages
            Rectangle {
                visible: !isUser
                width: 2
                height: parent.height - 12
                anchors { left: parent.left; leftMargin: 0; verticalCenter: parent.verticalCenter }
                radius: Services.DesktopTheme.rad(1)
                color: Colors.primary
                opacity: 0.6
            }

            StyledText {
                id: contentText
                x: isUser ? 12 : 14
                y: 10
                // Cap at 78% of root width minus horizontal padding.
                // This is evaluated without a circular dependency so wrapping
                // and implicit height are always computed correctly.
                width: Math.min(implicitWidth, root.width * 0.78 - (isUser ? 24 : 26))
                height: implicitHeight
                text: {
                    const base = isStreaming ? AppState.streamBuffer : (message ? message.content : "")
                    let raw
                    if (isStreaming && root.cursorVisible) raw = base + "▋"
                    else if (isStreaming) raw = base + " "
                    else raw = base
                    return root.formatText(raw)
                }
                wrapMode: Text.WordWrap
                font { pixelSize: 13; family: "monospace" }
                color: isUser
                    ? Colors.on_primary_container
                    : Colors.on_surface
                lineHeight: 1.55
                textFormat: Text.RichText
            }
        }

        // Response navigation — ← 1/3 → below the last AI message bubble.
        // Visible only when at least one reroll has been done (totalAlternatives > 1).
        // Hidden while streaming and for all user messages.
        Row {
            id: navRow
            visible: !isUser && isLastAiMessage && totalAlternatives > 1 && !isStreaming
            spacing: 4
            Layout.alignment: Qt.AlignLeft

            ClickableRect {
                id: prevAltRect
                width: 22; height: 22; radius: 5
                opacity: currentAltIndex > 0 ? 1.0 : 0.3
                color: prevAltRect.hovered && currentAltIndex > 0
                    ? Colors.surface_container_highest : "transparent"
                Behavior on color { ColorAnimation { duration: 100 } }
                StyledText {
                    anchors.centerIn: parent; text: "←"; font.pixelSize: 12
                    color: Colors.on_surface_variant
                }
                cursorShape: currentAltIndex > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: { if (currentAltIndex > 0) root.prevAlternative() }
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: (currentAltIndex + 1) + " / " + totalAlternatives
                font { pixelSize: 10; family: "monospace" }
                color: Colors.on_surface_variant
                opacity: 0.55
            }

            ClickableRect {
                id: nextAltRect
                width: 22; height: 22; radius: 5
                opacity: currentAltIndex < totalAlternatives - 1 ? 1.0 : 0.3
                color: nextAltRect.hovered && currentAltIndex < totalAlternatives - 1
                    ? Colors.surface_container_highest : "transparent"
                Behavior on color { ColorAnimation { duration: 100 } }
                StyledText {
                    anchors.centerIn: parent; text: "→"; font.pixelSize: 12
                    color: Colors.on_surface_variant
                }
                cursorShape: currentAltIndex < totalAlternatives - 1 ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: { if (currentAltIndex < totalAlternatives - 1) root.nextAlternative() }
            }
        }
    }
}
