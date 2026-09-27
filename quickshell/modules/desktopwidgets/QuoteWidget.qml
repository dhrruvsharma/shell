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
        font.family: root.st.font
        font.pixelSize: root.st.frame === "bare" ? 16 : 14
        font.italic: root.st.frame === "scroll" || root.st.frame === "bare"
        font.weight: root.st.frame === "bare" ? Font.Light : Font.Normal
        lineHeight: 1.15
        color: Colors.on_surface
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
            color: parent.containsMouse ? Colors[root.st.accentRole] : Colors.withAlpha(Colors.on_surface, 0.45)
        }
    }
}
