pragma ComponentBehavior: Bound
import QtQuick
import qs.colors
import qs.services as Services

// The palette's plate: a printer's specimen of what each kind of scheme
// makes of your wallpaper (matugen, dry runs), a row of swatches each: the
// accents, the containers, the surfaces. The kind in use is marked; the one
// pointed at opposite is lit.
Item {
    id: fig

    property string lit: ""

    readonly property var pal: Services.Scheme
    readonly property var roles: ["primary", "secondary", "tertiary", "primary_container", "surface_container_high", "surface"]

    Component.onCompleted: fig.pal.readPreviews()

    Connections {
        target: Services.Scheme
        function onModeChanged() {
            fig.pal.readPreviews();
        }
        function onContrastChanged() {
            fig.pal.readPreviews();
        }
    }

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width - 16
        spacing: 7

        Repeater {
            model: fig.pal.schemes

            Item {
                id: row

                required property var modelData
                readonly property var sw: fig.pal.previews[row.modelData.id] ?? null
                readonly property bool inUse: fig.pal.scheme === row.modelData.id
                readonly property bool lit: fig.lit === row.modelData.id

                width: parent.width
                height: 34

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -3
                    radius: 4
                    color: row.lit ? BookStyle.wellHover : "transparent"
                    border.width: row.inUse ? 1 : 0
                    border.color: BookStyle.accent
                }

                BookText {
                    anchors.verticalCenter: parent.verticalCenter
                    x: 6
                    width: 118
                    text: (row.inUse ? "▸ " : "") + row.modelData.name
                    elide: Text.ElideRight
                    font.family: BookStyle.ui
                    font.pixelSize: 13
                    font.weight: row.inUse ? Font.DemiBold : Font.Normal
                    color: row.inUse || row.lit ? BookStyle.accent : BookStyle.ink
                }

                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: 4
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 5

                    Repeater {
                        model: fig.roles

                        Rectangle {
                            required property string modelData
                            required property int index
                            width: index < 3 ? 62 : 46
                            height: 26
                            radius: 3
                            color: row.sw ? row.sw[modelData] : Colors.withAlpha(BookStyle.ink, 0.08)
                            border.width: 1
                            border.color: BookStyle.line

                            Behavior on color {
                                ColorAnimation {
                                    duration: 300
                                }
                            }
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: fig.pal.setScheme(row.modelData.id)
                }
            }
        }

        BookText {
            width: parent.width
            topPadding: 6
            horizontalAlignment: Text.AlignHCenter
            text: fig.pal.reading ? "Reading the wallpaper…" : "Accents · containers · surfaces, as each would make them"
            font.italic: true
            font.pixelSize: 12
            color: BookStyle.inkSoft
        }
    }
}
