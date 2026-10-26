import QtQuick

// A rule across the page in the theme's manner: a hairline, a double rule,
// a heavy rule over a thin one (newsprint), dashes, or a gilt line. `kind`
// overrides the theme's.
Item {
    id: rule

    property string kind: BookStyle.b.rule ?? "single"
    property color color: rule.kind === "gold" ? BookStyle.gold : BookStyle.line

    implicitHeight: rule.kind === "double" ? 4 : rule.kind === "thick" ? 6 : rule.kind === "none" ? 0 : 1
    visible: rule.kind !== "none"

    Rectangle {
        visible: rule.kind !== "dashed"
        width: parent.width
        height: rule.kind === "thick" ? 3 : 1
        color: rule.color
    }

    Rectangle {
        visible: rule.kind === "double" || rule.kind === "thick"
        y: parent.height - 1
        width: parent.width
        height: 1
        color: rule.color
    }

    Row {
        visible: rule.kind === "dashed"
        spacing: 4
        clip: true
        width: parent.width

        Repeater {
            model: rule.kind === "dashed" ? Math.ceil(rule.width / 10) : 0

            Rectangle {
                width: 6
                height: 1
                color: rule.color
            }
        }
    }
}
