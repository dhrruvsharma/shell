pragma ComponentBehavior: Bound
import QtQuick
import qs.colors
import qs.modules.desktopwidgets
import qs.modules.lock
import qs.services as Services

// The desktop themes as books on a shelf: a spine for each, bound in its
// own colours and lettered in its own type, the one in use pulled out.
// Take one down (a click) and the desktop, and this book, change to it.
Item {
    id: fig

    // A theme pointed at ("" for none; "off" for no theme).
    property string hoveredId: ""

    readonly property var shelf: [{ id: "", name: "No theme", icon: "auto_stories" }].concat(Services.DesktopTheme.themes)
    readonly property real spineW: Math.min(36, (fig.width - 20) / fig.shelf.length - 3)
    readonly property real baseY: fig.height * 0.7

    // The shelf board.
    Rectangle {
        x: 0
        y: fig.baseY
        width: fig.width
        height: 10
        radius: 2
        color: Qt.darker(BookStyle.cover, 1.1)
        border.width: 1
        border.color: Qt.darker(BookStyle.cover, 1.6)
    }

    Rectangle {
        x: 4
        y: fig.baseY + 10
        width: fig.width - 8
        height: 8
        gradient: Gradient {
            GradientStop { position: 0; color: Colors.withAlpha("#000000", 0.3) }
            GradientStop { position: 1; color: "transparent" }
        }
    }

    Row {
        id: books
        anchors.horizontalCenter: parent.horizontalCenter
        y: 0
        height: fig.baseY
        spacing: 3

        Repeater {
            model: fig.shelf

            Item {
                id: book

                required property var modelData
                required property int index
                readonly property string tid: book.modelData.id
                readonly property bool inUse: (Services.DesktopTheme.enabled ? Services.DesktopTheme.theme : "") === book.tid
                readonly property var st: WidgetStyle.of(book.tid)
                readonly property color cloth: book.tid === "" ? Colors.surface_container_high
                    : Qt.darker(Services.DesktopTheme.accentOf(book.tid), BookStyle.lightPaper ? 1.9 : 2.3)
                readonly property color gilt: book.tid === "" ? Colors.on_surface : Qt.lighter(Services.DesktopTheme.accentOf(book.tid), 1.15)
                readonly property real tall: fig.baseY * (0.72 + 0.22 * ((book.index * 37) % 11) / 10)
                readonly property real pulled: book.inUse ? 26 : area.containsMouse ? 12 : 0

                width: fig.spineW
                height: fig.baseY

                Rectangle {
                    id: spine
                    x: 0
                    y: fig.baseY - book.tall - book.pulled
                    width: parent.width
                    height: book.tall
                    radius: 2
                    color: book.cloth
                    border.width: book.inUse ? 2 : 1
                    border.color: book.inUse ? BookStyle.accent : Qt.darker(book.cloth, 1.5)

                    Behavior on y {
                        NumberAnimation {
                            duration: 220
                            easing.type: Easing.OutCubic
                        }
                    }

                    // Bands at head and foot, as on a bound spine.
                    Repeater {
                        model: [8, book.tall - 12]

                        Rectangle {
                            required property real modelData
                            x: 3
                            y: modelData
                            width: spine.width - 6
                            height: 2
                            color: Colors.withAlpha(book.gilt, 0.6)
                        }
                    }

                    Glyph {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 16
                        text: book.modelData.icon
                        filled: true
                        font.pixelSize: Math.min(18, spine.width - 10)
                        color: book.gilt
                    }

                    // Its name, up the spine, in its own type.
                    Text {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: 14
                        rotation: -90
                        width: book.tall - 70
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: book.modelData.name
                        font.family: book.st.display || book.st.font || Qt.application.font.family
                        font.pixelSize: Math.min(15, spine.width - 16)
                        font.letterSpacing: 1
                        color: book.gilt
                    }
                }

                MouseArea {
                    id: area
                    anchors.fill: spine
                    hoverEnabled: true
                    cursorShape: book.inUse ? Qt.ArrowCursor : Qt.PointingHandCursor
                    onContainsMouseChanged: {
                        if (containsMouse)
                            fig.hoveredId = book.tid || "off";
                        else if (fig.hoveredId === (book.tid || "off"))
                            fig.hoveredId = "";
                    }
                    onClicked: Services.DesktopTheme.setTheme(book.tid)
                }
            }
        }
    }

    // The one pointed at (or in use), named under the shelf.
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: fig.baseY + 28
        spacing: 4

        readonly property var shown: fig.shelf.find(t => (t.id || "off") === fig.hoveredId)
            ?? fig.shelf.find(t => t.id === (Services.DesktopTheme.enabled ? Services.DesktopTheme.theme : ""))

        BookText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: parent.shown ? parent.shown.name : ""
            font.family: BookStyle.display
            font.pixelSize: 22
            color: BookStyle.ink
        }

        BookText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: parent.shown ? (parent.shown.tagline ?? "The shell as it comes") : ""
            font.italic: true
            font.pixelSize: 13
            color: BookStyle.inkSoft
        }
    }
}
