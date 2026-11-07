pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.colors
import qs.services as Services
import qs.modules.control

// The time, large in the theme's display face, the day, and the month:
// today lit, the days with notes on the calendar marked; arrows page
// through the months, the month's name brings today back.
PaneSection {
    id: pane

    title: EdgeWords.word("calendar")
    preferredWidth: 296

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    readonly property date now: clock.date
    // The first of the month shown.
    property date month: new Date(pane.now.getFullYear(), pane.now.getMonth(), 1)
    readonly property int firstDay: Qt.locale().firstDayOfWeek
    // The grid's first day: the week's start on or before the 1st.
    readonly property date gridStart: {
        const lead = (pane.month.getDay() - pane.firstDay + 7) % 7;
        return new Date(pane.month.getFullYear(), pane.month.getMonth(), 1 - lead);
    }

    function page(n) {
        pane.month = new Date(pane.month.getFullYear(), pane.month.getMonth() + n, 1);
    }

    function sameDay(a, b) {
        return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
    }

    // The time.
    Item {
        width: parent.width
        height: big.implicitHeight

        Text {
            id: big
            text: Qt.formatDateTime(pane.now, "h:mm AP").split(" ")[0]
            font.family: ControlStyle.display
            font.pixelSize: 40
            font.weight: Font.DemiBold
            color: ControlStyle.ink
        }

        Text {
            anchors.left: big.right
            anchors.leftMargin: 6
            anchors.baseline: big.baseline
            text: Qt.formatDateTime(pane.now, "AP")
            font.family: ControlStyle.body
            font.pixelSize: 13
            font.weight: Font.Bold
            color: ControlStyle.accent
        }

        Column {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            Text {
                anchors.right: parent.right
                text: Qt.formatDateTime(pane.now, "dddd")
                font.family: ControlStyle.body
                font.pixelSize: 13
                font.weight: Font.DemiBold
                color: ControlStyle.ink
            }

            Text {
                anchors.right: parent.right
                text: Qt.formatDateTime(pane.now, "d MMMM yyyy")
                font.family: ControlStyle.body
                font.pixelSize: 12
                color: Colors.withAlpha(ControlStyle.ink, 0.65)
            }
        }
    }

    // The month and its arrows.
    Item {
        width: parent.width
        height: 26

        PaneChip {
            id: back
            icon: "chevron_left"
            onClicked: pane.page(-1)
        }

        MouseArea {
            anchors.centerIn: parent
            width: monthName.implicitWidth + 16
            height: parent.height
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: pane.month = new Date(pane.now.getFullYear(), pane.now.getMonth(), 1)

            Text {
                id: monthName
                anchors.centerIn: parent
                text: ControlStyle.label(Qt.formatDate(pane.month, "MMMM yyyy"))
                font.family: ControlStyle.ui
                font.pixelSize: 13
                font.weight: Font.DemiBold
                font.capitalization: ControlStyle.caps
                font.letterSpacing: ControlStyle.labelSpacing
                color: parent.containsMouse ? ControlStyle.accent : ControlStyle.labelColor
            }
        }

        PaneChip {
            anchors.right: parent.right
            icon: "chevron_right"
            onClicked: pane.page(1)
        }
    }

    // The weeks.
    Grid {
        id: days
        width: parent.width
        columns: 7
        rowSpacing: 2

        readonly property real cell: days.width / 7

        Repeater {
            model: 7

            Text {
                required property int index
                width: days.cell
                horizontalAlignment: Text.AlignHCenter
                bottomPadding: 4
                text: Qt.locale().dayName((pane.firstDay + index) % 7, Locale.NarrowFormat)
                font.family: ControlStyle.ui
                font.pixelSize: 11
                font.weight: Font.DemiBold
                color: Colors.withAlpha(ControlStyle.ink, 0.5)
            }
        }

        Repeater {
            model: 42

            Item {
                id: day
                required property int index
                readonly property date date: new Date(pane.gridStart.getFullYear(), pane.gridStart.getMonth(), pane.gridStart.getDate() + day.index)
                readonly property bool inMonth: day.date.getMonth() === pane.month.getMonth()
                readonly property bool today: pane.sameDay(day.date, pane.now)
                readonly property int noted: Services.CalendarNotes.countFor(Services.CalendarNotes.dateKey(day.date))

                width: days.cell
                height: 30

                Rectangle {
                    anchors.centerIn: parent
                    width: 26
                    height: 26
                    radius: ControlStyle.radius(13)
                    color: day.today ? ControlStyle.accent : "transparent"
                }

                Text {
                    anchors.centerIn: parent
                    text: day.date.getDate()
                    font.family: ControlStyle.body
                    font.pixelSize: 12
                    font.weight: day.today ? Font.Bold : Font.Normal
                    color: day.today ? ControlStyle.inkOn(ControlStyle.accent) : Colors.withAlpha(ControlStyle.ink, day.inMonth ? 0.9 : 0.3)
                }

                Rectangle {
                    visible: day.noted > 0 && !day.today
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 1
                    width: 4
                    height: 4
                    radius: 2
                    color: ControlStyle.accent
                }
            }
        }
    }
}
