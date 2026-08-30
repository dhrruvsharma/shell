import QtQuick
import qs.colors

// The poster tile shared by the manga / anime / novel grids: cover art with a
// placeholder and bottom fade, a two-line title bar, and press/hover feedback.
//
// Anything else the grid needs — score badges, the progress strip — is added as
// an ordinary child. Tell the card how tall the bottom strip is via `footerHeight`
// so the cover and title bar size around it. The hover tint keeps a high `z` so it
// still sits above those children, as it did when it was declared last.
ClickableRect {
    id: root

    property url source: ""
    property string title: ""
    property string bodyFont: ""
    property int gradientHeight: 48
    property int footerHeight: 0

    anchors.margins: 5
    radius: 12
    color: Colors.surface_container
    clip: true

    Image {
        id: cover
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: root.height - titleBar.height - root.footerHeight
        source: root.source
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        opacity: status === Image.Ready ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 300 } }

        Rectangle {
            anchors.fill: parent
            color: Colors.surface_container_high
            visible: cover.status !== Image.Ready

            StyledText {
                anchors.centerIn: parent
                text: "◫"
                font.pixelSize: 32
                color: Colors.outline
                opacity: 0.25
            }
        }

        Rectangle {
            anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
            height: root.gradientHeight
            gradient: Gradient {
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 1.0; color: Colors.surface_container }
            }
        }
    }

    Rectangle {
        id: titleBar
        anchors {
            bottom: parent.bottom
            bottomMargin: root.footerHeight
            left: parent.left
            right: parent.right
        }
        height: titleText.implicitHeight + 10
        color: Colors.surface_container

        StyledText {
            id: titleText
            anchors {
                left: parent.left; right: parent.right
                verticalCenter: parent.verticalCenter
                leftMargin: 10; rightMargin: 10
            }
            text: root.title
            font.family: root.bodyFont
            font.pixelSize: 11
            font.letterSpacing: 0.2
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
            lineHeight: 1.3
        }
    }

    Rectangle {
        z: 10
        anchors.fill: parent
        radius: root.radius
        color: Colors.primary
        opacity: root.pressed ? 0.16 : (root.hovered ? 0.07 : 0)
        Behavior on opacity { NumberAnimation { duration: 130 } }
    }

    transform: Scale {
        origin.x: root.width / 2
        origin.y: root.height / 2
        xScale: root.pressed ? 0.97 : 1.0
        yScale: root.pressed ? 0.97 : 1.0
        Behavior on xScale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
        Behavior on yScale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
    }
}
