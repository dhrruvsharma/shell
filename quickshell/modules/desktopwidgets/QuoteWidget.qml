pragma ComponentBehavior: Bound
import QtQuick
import qs.colors
import qs.modules.lock
import qs.services as Services

// A dad joke on the desktop (fetched by services/DesktopWidgets), in the
// look of the desktop theme. The arrow fetches another.
WidgetFrame {
    id: root

    themeId: Services.DesktopTheme.enabled ? Services.DesktopTheme.theme : ""
    title: WidgetStyle.word("quote", themeId)
    seal: "言"

    Text {
        width: 360
        text: Services.DesktopWidgets.joke || "…"
        wrapMode: Text.WordWrap
        // Wasteland's is scrawled on the wall with a typewriter's letters.
        font.family: root.st.frame === "scrap" ? "Special Elite" : root.st.font
        font.pixelSize: root.st.frame === "bare" ? 16 : 14
        font.italic: ["scroll", "bare", "lancet", "clipping", "brass", "patta", "banner"].includes(root.st.frame)
        font.weight: root.st.frame === "bare" ? Font.Light : Font.Normal
        lineHeight: 1.15
        color: root.ink
    }

    MouseArea {
        width: 360
        height: 20
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        onClicked: Services.DesktopWidgets.refreshJoke()

        Glyph {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: "autorenew"
            font.pixelSize: 17
            color: parent.containsMouse ? root.accent : Colors.withAlpha(root.ink, 0.45)
        }
    }
}
