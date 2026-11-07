pragma Singleton
import QtQuick
import Quickshell
import qs.modules.control

// What the edge line's tiles are called under each desktop theme ("" = no
// theme), in the spirit of the widgets' words (WidgetStyle.words); the
// control centre's own sections bring theirs.
Singleton {
    readonly property var words: ({
            workspaces: { "": "Workspaces", hud: "Sectors", terminal: "~ $ hyprctl workspaces", cosmos: "Orbits", zen: "spaces", xianxia: "洞府 · Cave chambers", cyberpunk: "Districts // 地区", wabisabi: "間 · rooms", artdeco: "The floors", gothic: "The chapels", newspaper: "Departments", wasteland: "Outposts", observatory: "The houses", abyss: "Compartments", devaloka: "लोक · Realms", siege: "The keeps", sekiro: "Regions" },
            calendar: { "": "Calendar", hud: "Mission clock", terminal: "~ $ cal", cosmos: "Star date", zen: "today", xianxia: "历 · Almanac", cyberpunk: "Timeline // 時間", wabisabi: "暦 · the days", artdeco: "The engagement book", gothic: "Book of hours", newspaper: "Dateline", wasteland: "Logbook", observatory: "The almanac", abyss: "Dive log", devaloka: "पञ्चाङ्ग · Panchang", siege: "The siege diary", sekiro: "暦 · Seasons" },
            network: { "": "Wi-Fi", hud: "Comms", terminal: "~ $ nmcli", cosmos: "Relays", zen: "connection", xianxia: "传音 · Sound transmission", cyberpunk: "Net // ネット", wabisabi: "縁 · ties", artdeco: "The wireless", gothic: "The bell tower", newspaper: "The wire", wasteland: "Radio", observatory: "The aether", abyss: "Surface link", devaloka: "आकाश · Ether", siege: "Beacons", sekiro: "Messengers" },
            bluetooth: { "": "Bluetooth", hud: "Paired gear", terminal: "~ $ bluetoothctl", cosmos: "Docked craft", zen: "nearby", xianxia: "法器 · Bound artifacts", cyberpunk: "Linked chrome // 接続", wabisabi: "近く · nearby", artdeco: "The valet", gothic: "The vestry", newspaper: "Correspondents", wasteland: "Salvage", observatory: "Instruments", abyss: "Sonar contacts", devaloka: "वाहन · Vahanas", siege: "The retinue", sekiro: "Prosthetic tools" },
            dns: { "": "DNS", hud: "Resolver", terminal: "~ $ cat /etc/resolv.conf", cosmos: "Star catalogue", zen: "names", xianxia: "问路 · Asking the way", cyberpunk: "Resolver // 名前解決", wabisabi: "名 · names", artdeco: "The switchboard", gothic: "The parish register", newspaper: "Who's who", wasteland: "Signposts", observatory: "The catalogue", abyss: "Chart room", devaloka: "नाम · Names", siege: "The heralds", sekiro: "道標 · Signposts" },
            vpn: { "": "VPN", hud: "Secure channel", terminal: "~ $ nmcli con up", cosmos: "Wormholes", zen: "tunnel", xianxia: "密道 · Secret passage", cyberpunk: "Tunnel // トンネル", wabisabi: "隠れ道 · hidden path", artdeco: "The private line", gothic: "The secret stair", newspaper: "Off the record", wasteland: "Smuggler's run", observatory: "The hidden passage", abyss: "Silent running", devaloka: "गुप्तमार्ग · Hidden way", siege: "The postern gate", sekiro: "隠し通路 · Hidden path" },
            sound: { "": "Sound", hud: "Audio", terminal: "~ $ wpctl status", cosmos: "Comms volume", zen: "sound", xianxia: "音 · Resonance", cyberpunk: "Audio // 音", wabisabi: "響 · echo", artdeco: "The orchestra", gothic: "The organ", newspaper: "Wireless set", wasteland: "Noise", observatory: "The music of the spheres", abyss: "Hydrophone", devaloka: "नाद · Nada", siege: "The war drums", sekiro: "笛 · The flute" },
            notes: { "": "Notes", hud: "Mission notes", terminal: "~ $ cat notes.txt", cosmos: "Captain's log", zen: "notes", xianxia: "玉简 · Jade slips", cyberpunk: "Memos // メモ", wabisabi: "覚書 · jottings", artdeco: "The notepad", gothic: "Marginalia", newspaper: "Notebook", wasteland: "Scrawls", observatory: "Observations", abyss: "Logbook", devaloka: "पत्र · Palm leaves", siege: "Dispatches", sekiro: "Scrolls" },
            commands: { "": "Commands", hud: "Command line", terminal: "~ $ qs ipc call", cosmos: "Mission control", zen: "at hand", xianxia: "符箓 · Talismans", cyberpunk: "Macros // マクロ", wabisabi: "道具 · tools", artdeco: "The bell pulls", gothic: "The incantations", newspaper: "Standing orders", wasteland: "Jury-rigs", observatory: "The levers", abyss: "Controls", devaloka: "मन्त्र · Mantras", siege: "Orders of the day", sekiro: "忍具 · Shinobi tools" },
            tray: { "": "Tray", hud: "Background tasks", terminal: "~ $ jobs", cosmos: "Satellites", zen: "in the background", xianxia: "随身 · Carried along", cyberpunk: "Daemons // デーモン", wabisabi: "棚 · the shelf", artdeco: "The cloakroom", gothic: "The cloister", newspaper: "In brief", wasteland: "Stowed", observatory: "Satellites", abyss: "Ballast", devaloka: "गण · Attendants", siege: "The baggage train", sekiro: "Pouch" }
        })

    function word(key) {
        const w = words[key];
        return w ? (w[ControlStyle.themeId] ?? w[""]) : "";
    }
}
