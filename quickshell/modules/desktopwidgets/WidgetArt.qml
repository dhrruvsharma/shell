pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import qs.colors
import qs.components
import qs.modules.lock

// Album art cut to a desktop theme's shape (WidgetStyle.art), with a
// placeholder note when there is none.
Item {
    id: art

    property string themeId
    property string source
    readonly property var st: WidgetStyle.of(themeId)
    readonly property color accent: Colors[st.accentRole]
    readonly property real radius: st.art === "circle" ? width / 2 : st.art === "rounded" ? 14 : st.art === "soft" ? 12 : st.art === "seal" ? 4 : 0

    implicitWidth: 76
    implicitHeight: 76

    Rectangle {
        id: shapeMask
        anchors.fill: parent
        radius: art.radius
        visible: false
        layer.enabled: art.st.art !== "chamfer"
    }

    HudMask {
        id: chamferMask
        cut: 10
        active: art.st.art === "chamfer"
    }

    Item {
        anchors.fill: parent
        layer.enabled: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: art.st.art === "chamfer" ? chamferMask : shapeMask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1.0
        }

        Rectangle {
            anchors.fill: parent
            color: Colors.withAlpha(art.accent, 0.18)

            Glyph {
                anchors.centerIn: parent
                text: "music_note"
                font.pixelSize: art.width * 0.42
                color: art.accent
            }
        }

        Image {
            anchors.fill: parent
            source: art.source
            fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(art.width * 2, art.height * 2)
            asynchronous: true
            visible: status === Image.Ready
        }
    }

    // Theme touches.
    Rectangle {
        anchors.fill: parent
        visible: art.st.art === "square" || art.st.art === "seal"
        radius: art.radius
        color: "transparent"
        border.width: 1
        border.color: Colors.withAlpha(art.accent, art.st.art === "seal" ? 0.8 : 0.5)
    }

    HudTick {
        visible: art.st.art === "chamfer"
        cut: 10
        color: art.accent
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: -5
        visible: art.st.art === "circle"
        radius: width / 2
        color: "transparent"
        border.width: 1
        border.color: Colors.withAlpha(art.accent, 0.35)
    }
}
