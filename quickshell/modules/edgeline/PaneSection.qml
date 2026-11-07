pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.control

// One of the popout's panes, without a frame of its own (the popout is
// one): its title on the theme's section line, things at that line's right
// end (`trailing`), and what it shows under it, as wide as its cell makes
// it. `titled: false` for the control centre's sections, which bring their
// own title line.
Item {
    id: section

    property string title
    property bool titled: true
    // The width it's made for; its cell can give it more.
    property real preferredWidth: 300
    property real spacing: 12
    default property alias content: body.data
    property alias trailing: heading.trailing

    implicitWidth: section.preferredWidth
    implicitHeight: (section.titled ? heading.height + section.spacing : 0) + body.implicitHeight

    SectionTitle {
        id: heading
        width: section.width
        visible: section.titled
        text: section.title
    }

    Column {
        id: body
        y: section.titled ? heading.height + section.spacing : 0
        width: section.width
        spacing: 12
    }
}
