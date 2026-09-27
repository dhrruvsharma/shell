pragma ComponentBehavior: Bound
import QtQuick
import qs.colors
import qs.services as Services

// Desktop system monitor: CPU (with a short history), memory, temperature
// and disk from services/System (polled every 2 s), in the look of the
// desktop theme.
WidgetFrame {
    id: root

    readonly property var sys: Services.System
    property var history: []

    themeId: Services.DesktopTheme.enabled ? Services.DesktopTheme.theme : ""
    title: WidgetStyle.word("sysmon", themeId)
    seal: "气"

    Connections {
        target: Services.System

        function onCpuChanged() {
            const h = root.history.slice(-39);
            h.push(Services.System.cpu);
            root.history = h;
        }
    }

    Repeater {
        model: [
            { key: "cpu", value: root.sys.cpu / 100, text: Math.round(root.sys.cpu) + "%" },
            { key: "ram", value: root.sys.ram / 100, text: Math.round(root.sys.ram) + "%" },
            { key: "temp", value: root.sys.temp / 100, text: Math.round(root.sys.temp) + "°C" },
            { key: "disk", value: root.sys.disk / 100, text: Math.round(root.sys.disk) + "%" }
        ]

        Column {
            id: row
            required property var modelData
            width: 260
            spacing: 5

            Item {
                width: parent.width
                height: name.implicitHeight

                Text {
                    id: name
                    text: WidgetStyle.label(WidgetStyle.word(row.modelData.key, root.themeId), root.st)
                    font.family: root.st.cjk ?? (root.st.frame === "chamfer" ? root.st.mono : root.st.font)
                    font.pixelSize: 12
                    font.letterSpacing: root.st.labelCase === "upper" ? 2 : 0.3
                    color: Colors.withAlpha(Colors.on_surface, 0.78)
                }

                Text {
                    anchors.right: parent.right
                    text: row.modelData.text
                    font.family: root.st.frame === "glass" ? root.st.display : root.st.mono
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    color: Colors.on_surface
                }
            }

            WidgetBar {
                width: parent.width
                themeId: root.themeId
                value: row.modelData.value
            }
        }
    }

    // CPU history: a line chart, block characters on the console.
    Canvas {
        id: spark
        width: 260
        height: 34
        visible: root.st.frame !== "console" && root.st.frame !== "bare"

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const h = root.history;
            if (h.length < 2)
                return;
            const step = width / 39;
            const x0 = width - (h.length - 1) * step;
            ctx.beginPath();
            for (let i = 0; i < h.length; i++) {
                const x = x0 + i * step;
                const y = height - 2 - (height - 4) * Math.min(1, h[i] / 100);
                if (i === 0)
                    ctx.moveTo(x, y);
                else
                    ctx.lineTo(x, y);
            }
            ctx.strokeStyle = Colors[root.st.accentRole];
            ctx.lineWidth = root.st.frame === "chamfer" ? 1.5 : 2;
            ctx.stroke();
            ctx.lineTo(width, height);
            ctx.lineTo(x0, height);
            ctx.closePath();
            ctx.fillStyle = Colors.withAlpha(Colors[root.st.accentRole], 0.15);
            ctx.fill();
        }

        Connections {
            target: root

            function onHistoryChanged() {
                spark.requestPaint();
            }
        }
    }

    Text {
        visible: root.st.frame === "console"
        text: "cpu " + root.history.map(v => "▁▂▃▄▅▆▇█".charAt(Math.min(7, Math.floor(v / 12.5)))).join("")
        font.family: root.st.mono
        font.pixelSize: 13
        color: Colors[root.st.accentRole]
    }

    Text {
        text: WidgetStyle.label(WidgetStyle.word("uptime", root.themeId), root.st) + "  " + root.sys.uptime
        font.family: root.st.mono
        font.pixelSize: 11
        font.letterSpacing: root.st.labelCase === "upper" ? 1.5 : 0
        color: Colors.withAlpha(Colors.on_surface, 0.6)
    }
}
