// SPDX-License-Identifier: GPL-3.0-or-later
//
// Derived from zesis-shell's widgets/cava/CavaGpuVisualizer.qml.
// Copyright (C) 2026 Squirrel Modeller (zesis-shell)
//   https://github.com/zesis-shell/zesis
// Modifications for this Quickshell config, 2026.
//
// This file is a derivative work of zesis-shell, used with the author's
// permission under the GNU General Public License, version 3 or (at your
// option) any later version. See the full license text in shaders/LICENSE.
// Distributed WITHOUT ANY WARRANTY.

import QtQuick
import qs.services as Services
import qs.colors
import qs.components

// GPU cava visualizer. The CPU only fills a tiny 1xN texture with bar heights;
// the fragment shader (shaders/cava.frag.qsb) does all the drawing, so a full
// size visualizer costs one GPU quad instead of a per-frame CPU repaint.
//
// Data comes from services/Cava.qml (raw cava, values 0..1) by default.
Item {
    id: root

    property var bars: Services.Cava.values
    property color accentColor: Colors.primary
    property int orientation: 0   // 0 bottom, 1 top, 2 left, 3 right
    property int style: 0         // 0 bars, 1 area
    property real gapPx: 2
    property real lineWidthPx: 1.5
    property int flip: 0

    readonly property int barCount: root.bars ? root.bars.length : 0

    // 1xN grayscale data texture: red channel = normalized bar height.
    Canvas {
        id: dataCanvas
        width: Math.max(1, root.barCount)
        height: 1
        visible: false

        property var barsData: root.bars
        onBarsDataChanged: dataCanvas.requestPaint()
        Component.onCompleted: dataCanvas.requestPaint()

        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            var bars = root.bars;
            var n = bars ? bars.length : 0;
            for (var i = 0; i < n; i++) {
                var v = Math.max(0, Math.min(1, bars[i]));
                ctx.fillStyle = Qt.rgba(v, v, v, 1);
                ctx.fillRect(i, 0, 1, 1);
            }
            dataTexSource.scheduleUpdate();
        }
    }

    ShaderEffectSource {
        id: dataTexSource
        sourceItem: dataCanvas
        hideSource: true
        smooth: false
        live: false
    }

    ShaderEffect {
        id: shaderItem
        anchors.fill: parent
        visible: root.barCount > 0

        property variant dataTex: dataTexSource
        property real itemWidth: width
        property real itemHeight: height
        property int barCount: root.barCount
        property int styleMode: root.style
        property int orientation: root.orientation
        property int flip: root.flip
        property real gapPx: root.gapPx
        property real lineWidthPx: root.lineWidthPx
        property color accentColor: root.accentColor

        fragmentShader: Qt.resolvedUrl("../shaders/cava.frag.qsb")
    }

    // Surfaces a compile/load failure instead of silently drawing nothing.
    Rectangle {
        anchors.centerIn: parent
        visible: shaderItem.status === ShaderEffect.Error
        width: Math.min(parent.width - 16, 280)
        height: errText.implicitHeight + 16
        radius: 6
        color: Qt.rgba(1, 0, 0, 0.12)
        border.color: Colors.error
        border.width: 1

        StyledText {
            id: errText
            anchors.centerIn: parent
            width: parent.width - 16
            text: "cava shader failed to load\n" + shaderItem.log
            color: Colors.error
            font.pixelSize: 11
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
        }
    }
}
