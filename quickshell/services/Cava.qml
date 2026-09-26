import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton

Singleton {
    id: root

    property bool running: false
    property var values: []
    property int barsCount: 32
    property var _parseBuffer: new Array(barsCount)
    property bool _silent: false
    property var config: ({
        "general": {
            "bars": barsCount,
            "framerate": 20,
            "autosens": 1,
            "sensitivity": 100,
            "lower_cutoff_freq": 50,
            "higher_cutoff_freq": 10000
        },
        "output": {
            "method": "raw",
            "data_format": "ascii",
            "ascii_max_range": 100,
            "bit_format": "8bit",
            "channels": "mono",
            "mono_option": "average"
        },
        "smoothing": {
            "monstercat": 1,
            "noise_reduction": 70
        }
    })

    Process {
        id: process

        stdinEnabled: true
        running: root.running
        command: ["cava", "-p", "/dev/stdin"]
        onStarted: {
            for (const k in config) {
                if (typeof config[k] !== "object") {
                    write(k + "=" + config[k] + "\n");
                    continue;
                }
                write("[" + k + "]\n");
                const obj = config[k];
                for (const k2 in obj) {
                    write(k2 + "=" + obj[k2] + "\n");
                }
            }
            stdinEnabled = false; // Close stdin to let Cava start
            values = Array(barsCount).fill(0);
        }
        onExited: {
            values = Array(barsCount).fill(0);
            stdinEnabled = true; // Reset for next run
        }

        stdout: SplitParser {
            onRead: (data) => {
                const buffer = root._parseBuffer;
                let idx = 0;
                let num = 0;
                let silent = true;
                for (let i = 0, len = data.length - 1; i < len; i++) {
                    const c = data.charCodeAt(i);
                    if (c === 59) {
                        if (num !== 0)
                            silent = false;
                        buffer[idx++] = num * 0.01;
                        num = 0;
                    } else if (c >= 48 && c <= 57) {
                        num = num * 10 + (c - 48);
                    }
                }
                if (num > 0 || idx < root.barsCount) {
                    if (num !== 0)
                        silent = false;
                    buffer[idx++] = num * 0.01;
                }

                // cava keeps emitting all-zero frames when nothing plays; only
                // publish the first one, so consumers stop repainting in silence.
                if (silent && root._silent)
                    return;
                root._silent = silent;
                root.values = buffer.slice(0, idx);
            }
        }

    }

}