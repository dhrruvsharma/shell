import QtQuick
import qs.colors
import qs.components
import qs.modules.lock
import qs.services as Services

// A bind's icon: the app's own for a launcher, the number for a jump to a
// workspace, otherwise a glyph, in the action's colour.
Item {
    id: icon

    property var bind: null
    // the app's icon, when there is one
    property string source: ""
    property int size: 20

    readonly property string glyph: bind ? String(bind.glyph ?? "") : ""
    readonly property color tone: KeyData.toneOf(bind?.category ?? "")

    implicitWidth: size
    implicitHeight: size

    Image {
        id: image
        anchors.fill: parent
        visible: icon.source !== "" && status === Image.Ready
        source: icon.source
        sourceSize: Qt.size(icon.size * 2, icon.size * 2)
        asynchronous: true
    }

    // a workspace, as a numbered pip
    Rectangle {
        anchors.fill: parent
        anchors.margins: Math.round(icon.size * 0.06)
        visible: !image.visible && icon.glyph.startsWith("#")
        radius: Services.DesktopTheme.rad(Math.round(height * 0.28))
        color: Colors.withAlpha(icon.tone, 0.16)
        border.width: 1.5
        border.color: icon.tone

        StyledText {
            anchors.centerIn: parent
            text: icon.glyph.slice(1)
            font.pixelSize: Math.round(parent.height * (text.length > 1 ? 0.5 : 0.62))
            font.weight: Font.Bold
            color: icon.tone
        }
    }

    Glyph {
        anchors.centerIn: parent
        visible: !image.visible && !icon.glyph.startsWith("#")
        text: icon.glyph || "keyboard"
        filled: true
        font.pixelSize: icon.size
        color: icon.tone
    }
}
