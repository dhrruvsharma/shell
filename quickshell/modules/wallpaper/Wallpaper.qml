import QtQuick
import QtQuick.Layouts
import Qt.labs.folderlistmodel
import QtQuick.Window
import Quickshell
import Quickshell.Io
import qs.services
import "../../colors" as ColorsModule

Rectangle {
    id: window

    width: 1920
    height: 400
    color: "transparent"
    anchors.fill: parent
    focus: true
    visible: false

    readonly property string srcDir: "file://" + Quickshell.env("HOME") + "/Pictures/wallpapers"

    readonly property string setwallCommand: Quickshell.env("HOME") + "/.local/bin/setwall '%1'"

    // Single-wallpaper stage size (one big card instead of a carousel)
    readonly property int itemWidth: 880
    readonly property int itemHeight: 520
    readonly property real skewFactor: -0.35

    // ── Favorites state ───────────────────────────────────────────────────
    // Whether the stage is filtered to favorites only.
    property bool favoritesOnly: false
    // Flat list of every wallpaper: [{ fileName, fileUrl }], rebuilt from the folder.
    property var allWallpapers: []

    // The list actually shown — all, or just favorites.
    readonly property var displayedWallpapers: {
        const favs = WallpaperFavorites.favorites
        if (!window.favoritesOnly)
            return window.allWallpapers
        let set = ({})
        for (let i = 0; i < favs.length; i++)
            set[favs[i]] = true
        return window.allWallpapers.filter(w => set[w.fileName] === true)
    }

    function rebuildList() {
        let arr = []
        for (let i = 0; i < folderModel.count; i++) {
            let url = folderModel.get(i, "fileUrl")
            if (url === undefined)
                url = folderModel.get(i, "fileURL")
            arr.push({
                fileName: folderModel.get(i, "fileName"),
                fileUrl: url
            })
        }
        window.allWallpapers = arr
    }

    function currentFileName() {
        const list = window.displayedWallpapers
        if (view.currentIndex >= 0 && view.currentIndex < list.length)
            return list[view.currentIndex].fileName
        return ""
    }

    function pickCurrent() {
        const name = window.currentFileName()
        if (!name)
            return
        let originalFile = window.srcDir + "/" + name
        originalFile = originalFile.replace(/^file:\/\//, "")
        const finalCmd = window.setwallCommand.arg(originalFile)
        Quickshell.execDetached(["bash", "-c", finalCmd])
        window.visible = false
    }

    function favoriteToggle(name) {
        if (!name)
            return
        const wasFav = WallpaperFavorites.has(name)
        WallpaperFavorites.toggle(name)
        // If we just removed the focused item from the favorites view, keep the
        // selection valid.
        if (window.favoritesOnly && wasFav)
            Qt.callLater(window.clampCurrentIndex)
    }

    function toggleCurrentFavorite() {
        window.favoriteToggle(window.currentFileName())
    }

    function setFavoritesOnly(v) {
        if (v === window.favoritesOnly)
            return
        window.favoritesOnly = v
    }

    function clampCurrentIndex() {
        if (view.count <= 0) {
            view.currentIndex = -1
            return
        }
        if (view.currentIndex >= view.count)
            view.currentIndex = view.count - 1
        else if (view.currentIndex < 0)
            view.currentIndex = 0
    }

    // Switching between All / Favorites always starts from the first wallpaper.
    function resetToStart() {
        view.currentIndex = view.count > 0 ? 0 : -1
    }

    onFavoritesOnlyChanged: Qt.callLater(window.resetToStart)

    // Replay the assemble animation every time the panel is opened.
    onVisibleChanged: if (visible) stage.replay()

    Shortcut { sequence: "Escape"; onActivated: window.visible = false }

    // Non-visual data source. The stage reads window.displayedWallpapers built
    // from this so it can be filtered down to favorites.
    FolderListModel {
        id: folderModel
        folder: window.srcDir
        nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.gif", "*.mp4", "*.mkv", "*.mov", "*.webm"]
        showDirs: false
        sortField: FolderListModel.Name
        onCountChanged: window.rebuildList()
    }

    // A wallpaper sliced into vertical strips that fly together/apart.
    // t drives the whole effect: 1 = staged off the top/bottom-right,
    // 0 = assembled in place, -1 = scattered off the top/bottom-left.
    component ShardImage: Item {
        id: shard
        anchors.fill: parent

        property url source
        property real t: 1
        visible: String(source).length > 0 && Math.abs(t) < 0.999

        readonly property int stripCount: 24
        readonly property real stripW: width / stripCount
        readonly property real imgW: width + height * Math.abs(window.skewFactor) + 50
        readonly property real travelX: window.width > 0 ? window.width : 1920
        readonly property real travelY: (window.height > 0 ? window.height : 1080) * 0.9

        function flyIn() { outAnim.stop(); inAnim.restart() }
        function flyOut() { inAnim.stop(); outAnim.restart() }

        NumberAnimation { id: inAnim; target: shard; property: "t"; to: 0; duration: 650; easing.type: Easing.OutCubic }
        NumberAnimation { id: outAnim; target: shard; property: "t"; to: -1; duration: 480; easing.type: Easing.InCubic }

        transform: Matrix4x4 {
            property real s: window.skewFactor
            matrix: Qt.matrix4x4(1, s, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
        }

        Repeater {
            model: shard.stripCount
            delegate: Item {
                id: strip
                required property int index
                // Alternate strips travel via the top vs. the bottom.
                readonly property int dir: index % 2 === 0 ? -1 : 1
                // Deterministic per-strip scatter so the pieces move at
                // different speeds instead of as one rigid block.
                readonly property real spread: 0.85 + 0.45 * (((index * 7919) % 89) / 89)

                x: index * shard.stripW + shard.t * strip.spread * shard.travelX
                y: Math.abs(shard.t) * strip.dir * strip.spread * shard.travelY
                width: Math.ceil(shard.stripW) + 1
                height: shard.height
                clip: true
                opacity: 1 - 0.6 * Math.abs(shard.t)

                Image {
                    x: (shard.width - shard.imgW) / 2 - 35 - strip.index * shard.stripW
                    y: 0
                    width: shard.imgW
                    height: shard.height

                    fillMode: Image.PreserveAspectCrop
                    source: shard.source
                    sourceSize: Qt.size(Math.round(shard.imgW), Math.round(shard.height))
                    asynchronous: true

                    transform: Matrix4x4 {
                        property real s: -window.skewFactor
                        matrix: Qt.matrix4x4(1, s, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
                    }
                }
            }
        }
    }

    FocusScope {
        focus: parent.visible
        anchors.fill: parent

        // ── Single-wallpaper view ──────────────────────────────────────────
        // Only one wallpaper is on screen at a time. Navigating swaps between
        // two ShardImage slots: the old one scatters off to the left, the new
        // one assembles from the right.
        Item {
            id: view
            anchors.fill: parent
            focus: true

            property int currentIndex: -1
            readonly property int count: window.displayedWallpapers.length
            readonly property var currentEntry: (currentIndex >= 0 && currentIndex < count)
                ? window.displayedWallpapers[currentIndex] : null

            property bool initialFocusSet: false
            onCountChanged: {
                if (!initialFocusSet && count > 0) {
                    var idx = parseInt(Quickshell.env("WALLPAPER_INDEX") || "0")
                    if (count > idx) {
                        currentIndex = idx
                        initialFocusSet = true
                    }
                }
            }

            onCurrentEntryChanged: stage.showEntry(currentEntry)

            function step(d) {
                if (count <= 0)
                    return
                currentIndex = Math.max(0, Math.min(count - 1, currentIndex + d))
            }

            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Left || event.key === Qt.Key_Up) {
                    view.step(-1)
                    event.accepted = true
                } else if (event.key === Qt.Key_Right || event.key === Qt.Key_Down) {
                    view.step(1)
                    event.accepted = true
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    window.pickCurrent()
                    event.accepted = true
                }
            }

            Item {
                id: stage
                anchors.centerIn: parent
                width: window.itemWidth
                height: window.itemHeight

                property ShardImage front: slotA
                property ShardImage back: slotB

                function showEntry(entry) {
                    if (!entry) {
                        front.flyOut()
                        return
                    }
                    if (String(front.source) === String(entry.fileUrl)) {
                        // Same wallpaper but it was flown out (e.g. favorites
                        // emptied and refilled) — bring it back.
                        if (Math.abs(front.t) > 0.5)
                            front.flyIn()
                        return
                    }
                    const out = front
                    front = back
                    back = out
                    front.source = entry.fileUrl
                    front.t = 1
                    out.flyOut()
                    front.flyIn()
                }

                function replay() {
                    if (String(front.source).length > 0) {
                        front.t = 1
                        front.flyIn()
                    }
                }

                // Dark parallelogram backing that stays put while the strips
                // fly, so transitions read as happening "on a stage".
                Rectangle {
                    anchors.fill: parent
                    color: "#B3000000"
                    visible: view.currentEntry !== null || Math.abs(stage.front.t) < 0.999

                    transform: Matrix4x4 {
                        property real s: window.skewFactor
                        matrix: Qt.matrix4x4(1, s, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
                    }
                }

                ShardImage { id: slotA }
                ShardImage { id: slotB }

                MouseArea {
                    anchors.fill: parent
                    z: 15
                    onClicked: window.pickCurrent()
                    onWheel: (wheel) => {
                        if (wheel.angleDelta.y > 0)
                            view.step(-1)
                        else
                            view.step(1)
                    }
                }

                // ── Overlays for the shown wallpaper ──────────────────────
                // Upright (not skewed); fade out while the strips are flying.
                Item {
                    id: overlay
                    anchors.fill: parent
                    z: 20
                    opacity: 1 - Math.abs(stage.front.t)
                    visible: opacity > 0.01 && view.currentEntry !== null

                    readonly property string shownName: view.currentEntry ? view.currentEntry.fileName : ""
                    readonly property bool isVideo: !!overlay.shownName.toLowerCase().match(/\.(mp4|mkv|mov|webm)$/)
                    readonly property bool isFav: {
                        const favs = WallpaperFavorites.favorites
                        for (let i = 0; i < favs.length; i++)
                            if (favs[i] === overlay.shownName)
                                return true
                        return false
                    }

                    Rectangle {
                        visible: overlay.isVideo
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: 14

                        width: 32
                        height: 32
                        radius: 6
                        color: "#60000000"

                        Canvas {
                            anchors.fill: parent
                            anchors.margins: 8
                            onPaint: {
                                var ctx = getContext("2d");
                                ctx.fillStyle = "#EEFFFFFF";
                                ctx.beginPath();
                                ctx.moveTo(4, 0);
                                ctx.lineTo(14, 8);
                                ctx.lineTo(4, 16);
                                ctx.closePath();
                                ctx.fill();
                            }
                        }
                    }

                    // Favorite toggle (top-left). Clicking it toggles the
                    // favorite without selecting the wallpaper.
                    Rectangle {
                        id: favBtn
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.margins: 14

                        width: 32
                        height: 32
                        radius: 16
                        color: favArea.containsMouse ? "#90000000" : "#60000000"

                        onVisibleChanged: if (visible) heartCanvas.requestPaint()

                        Canvas {
                            id: heartCanvas
                            anchors.fill: parent
                            anchors.margins: 8
                            property bool filled: overlay.isFav
                            onFilledChanged: requestPaint()
                            onPaint: {
                                var ctx = getContext("2d");
                                ctx.clearRect(0, 0, width, height);
                                var w = width, h = height;
                                ctx.beginPath();
                                ctx.moveTo(w / 2, h * 0.86);
                                ctx.bezierCurveTo(-w * 0.12, h * 0.42, w * 0.20, -h * 0.06, w / 2, h * 0.30);
                                ctx.bezierCurveTo(w * 0.80, -h * 0.06, w * 1.12, h * 0.42, w / 2, h * 0.86);
                                ctx.closePath();
                                if (filled) {
                                    ctx.fillStyle = "#FF5C7A";
                                    ctx.fill();
                                } else {
                                    ctx.lineWidth = 2;
                                    ctx.strokeStyle = "#EEFFFFFF";
                                    ctx.stroke();
                                }
                            }
                        }

                        MouseArea {
                            id: favArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: window.favoriteToggle(overlay.shownName)
                        }
                    }
                }
            }
        }

        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_F) {
                window.toggleCurrentFavorite()
                event.accepted = true
                return
            }
            if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                window.setFavoritesOnly(!window.favoritesOnly)
                event.accepted = true
                return
            }
            if (event.key === Qt.Key_Left || event.key === Qt.Key_Right ||
                event.key === Qt.Key_Up || event.key === Qt.Key_Down ||
                event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                view.forceActiveFocus()
                event.accepted = false
            }
        }

        // ── View switcher: All / Favorites ────────────────────────────────
        // Sits just above the stage, and is skewed into parallelograms (with
        // counter-skewed labels) to match the wallpaper card.
        Row {
            id: viewTabs
            z: 100
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.verticalCenter
            anchors.bottomMargin: window.itemHeight / 2 + 22
            spacing: 16

            Repeater {
                model: [
                    { label: "All", fav: false },
                    { label: "Favorites", fav: true }
                ]
                delegate: Item {
                    id: tabPill
                    required property var modelData
                    readonly property bool active: window.favoritesOnly === modelData.fav
                    implicitHeight: 34
                    implicitWidth: tabRow.implicitWidth + 40

                    // Skewed parallelogram background. The shear is centered on the
                    // pill (the -s*H/2 term in the matrix translation) so the upright
                    // label sitting at the centre stays centered inside the shape.
                    Rectangle {
                        anchors.fill: parent
                        radius: 6
                        color: tabPill.active ? ColorsModule.Colors.primary : ColorsModule.Colors.surface_container
                        Behavior on color { ColorAnimation { duration: 150 } }

                        transform: Matrix4x4 {
                            property real s: window.skewFactor
                            matrix: Qt.matrix4x4(1, s, 0, -s * (tabPill.implicitHeight / 2),
                                                 0, 1, 0, 0,
                                                 0, 0, 1, 0,
                                                 0, 0, 0, 1)
                        }
                    }

                    // Upright, centered label (not skewed)
                    Row {
                        id: tabRow
                        anchors.centerIn: parent
                        spacing: 6

                        Text {
                            visible: tabPill.modelData.fav
                            anchors.verticalCenter: parent.verticalCenter
                            text: "♥"
                            font.pixelSize: 14
                            color: tabPill.active ? ColorsModule.Colors.on_primary : "#FF5C7A"
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: tabPill.modelData.fav
                                ? tabPill.modelData.label + " (" + WallpaperFavorites.favorites.length + ")"
                                : tabPill.modelData.label
                            font.pixelSize: 13
                            font.weight: Font.Bold
                            color: tabPill.active ? ColorsModule.Colors.on_primary : ColorsModule.Colors.on_surface
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: window.setFavoritesOnly(tabPill.modelData.fav)
                    }
                }
            }
        }

        // ── Empty favorites placeholder ───────────────────────────────────
        Rectangle {
            z: 50
            anchors.centerIn: parent
            visible: window.favoritesOnly && window.displayedWallpapers.length === 0
            implicitWidth: emptyRow.implicitWidth + 40
            implicitHeight: emptyRow.implicitHeight + 28
            radius: 18
            color: ColorsModule.Colors.surface_container

            Row {
                id: emptyRow
                anchors.centerIn: parent
                spacing: 10

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "♥"
                    font.pixelSize: 22
                    color: "#FF5C7A"
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "No favorites yet — focus a wallpaper and press F (or tap the heart)"
                    font.pixelSize: 15
                    color: ColorsModule.Colors.on_surface
                }
            }
        }
    }
}
