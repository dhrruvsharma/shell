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

    readonly property int itemWidth: 300
    readonly property int itemHeight: 420
    readonly property int borderWidth: 3
    readonly property int spacing: 0
    readonly property real skewFactor: -0.35

    // ── Favorites state ───────────────────────────────────────────────────
    // Whether the carousel is filtered to favorites only.
    property bool favoritesOnly: false
    // Flat list of every wallpaper: [{ fileName, fileUrl }], rebuilt from the folder.
    property var allWallpapers: []

    // The list actually shown by the carousel — all, or just favorites.
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
        view.positionViewAtIndex(view.currentIndex, ListView.Center)
    }

    // Switching between All / Favorites always starts from the first wallpaper.
    function resetToStart() {
        if (view.count > 0) {
            view.currentIndex = 0
            view.positionViewAtIndex(0, ListView.Center)
        } else {
            view.currentIndex = -1
        }
    }

    onFavoritesOnlyChanged: Qt.callLater(window.resetToStart)

    Shortcut { sequence: "Escape"; onActivated: window.visible = false }

    // Non-visual data source. The carousel uses a ScriptModel built from this so
    // it can be filtered down to favorites.
    FolderListModel {
        id: folderModel
        folder: window.srcDir
        nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.gif", "*.mp4", "*.mkv", "*.mov", "*.webm"]
        showDirs: false
        sortField: FolderListModel.Name
        onCountChanged: window.rebuildList()
    }

    FocusScope {
        focus: parent.visible
        anchors.fill: parent
        ListView {
            id: view
            anchors.fill: parent
            anchors.margins: 0

            spacing: window.spacing
            orientation: ListView.Horizontal

            clip: false
            cacheBuffer: 2000  // Keep this for preloading

            highlightRangeMode: ListView.StrictlyEnforceRange
            preferredHighlightBegin: (width / 2) - (window.itemWidth / 2)
            preferredHighlightEnd: (width / 2) + (window.itemWidth / 2)

            highlightMoveDuration: 300

            focus: true

            property bool initialFocusSet: false
            onCountChanged: {
                if (!initialFocusSet && count > 0) {
                    var idx = parseInt(Quickshell.env("WALLPAPER_INDEX") || "0")
                    if (count > idx) {
                        currentIndex = idx
                        positionViewAtIndex(idx, ListView.Center)
                        initialFocusSet = true
                    }
                }
            }

            model: ScriptModel {
                values: window.displayedWallpapers
            }

            Keys.onReturnPressed: {
                if (currentItem) currentItem.pickWallpaper()
            }

            delegate: Item {
                id: delegateRoot
                required property var modelData
                required property int index
                width: window.itemWidth
                height: window.itemHeight
                anchors.verticalCenter: parent.verticalCenter

                readonly property string fileName: modelData.fileName
                readonly property url fileUrl: modelData.fileUrl
                readonly property bool isCurrent: ListView.isCurrentItem
                readonly property bool isVideo: delegateRoot.fileName.toLowerCase().match(/\.(mp4|mkv|mov|webm)$/)
                readonly property int reqImgWidth: window.itemWidth + (window.itemHeight * Math.abs(window.skewFactor)) + 50
                readonly property bool isFav: {
                    const favs = WallpaperFavorites.favorites
                    for (let i = 0; i < favs.length; i++)
                        if (favs[i] === delegateRoot.fileName)
                            return true
                    return false
                }

                z: isCurrent ? 10 : 1

                function pickWallpaper() {
                    let originalFile = window.srcDir + "/" + delegateRoot.fileName

                    originalFile = originalFile.replace(/^file:\/\//, "")

                    const finalCmd = window.setwallCommand.arg(originalFile)
                    Quickshell.execDetached(["bash", "-c", finalCmd])
                    window.visible = false
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        view.currentIndex = delegateRoot.index
                        delegateRoot.pickWallpaper()
                    }
                }

                Item {
                    anchors.centerIn: parent
                    width: parent.width
                    height: parent.height

                    scale: delegateRoot.isCurrent ? 1.15 : 0.95
                    opacity: delegateRoot.isCurrent ? 1.0 : 0.6

                    Behavior on scale { NumberAnimation { duration: 500; easing.type: Easing.OutBack } }
                    Behavior on opacity { NumberAnimation { duration: 500 } }

                    transform: Matrix4x4 {
                        property real s: window.skewFactor
                        matrix: Qt.matrix4x4(1, s, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
                    }

                    Item {
                        anchors.fill: parent
                        anchors.margins: window.borderWidth

                        Rectangle { anchors.fill: parent; color: "black" }
                        clip: true

                        Image {
                            anchors.centerIn: parent
                            anchors.horizontalCenterOffset: -35

                            width: parent.width + (parent.height * Math.abs(window.skewFactor)) + 50
                            height: parent.height

                            fillMode: Image.PreserveAspectCrop
                            source: delegateRoot.fileUrl
                            sourceSize: Qt.size(delegateRoot.reqImgWidth, window.itemHeight)
                            asynchronous: true

                            transform: Matrix4x4 {
                                property real s: -window.skewFactor
                                matrix: Qt.matrix4x4(1, s, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
                            }
                        }

                        Rectangle {
                            visible: delegateRoot.isVideo
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.margins: 10

                            width: 32
                            height: 32
                            radius: 6
                            color: "#60000000"

                            transform: Matrix4x4 {
                                property real s: -window.skewFactor
                                matrix: Qt.matrix4x4(1, s, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
                            }

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

                        // Favorite toggle (top-left). Shown on the focused card, and
                        // as a marker on any favorited card. Clicking it toggles the
                        // favorite without selecting the wallpaper.
                        Rectangle {
                            id: favBtn
                            visible: delegateRoot.isCurrent || delegateRoot.isFav
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.margins: 10

                            width: 32
                            height: 32
                            radius: 16
                            color: favArea.containsMouse ? "#90000000" : "#60000000"

                            transform: Matrix4x4 {
                                property real s: -window.skewFactor
                                matrix: Qt.matrix4x4(1, s, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
                            }

                            onVisibleChanged: if (visible) heartCanvas.requestPaint()

                            Canvas {
                                id: heartCanvas
                                anchors.fill: parent
                                anchors.margins: 8
                                property bool filled: delegateRoot.isFav
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
                                onClicked: window.favoriteToggle(delegateRoot.fileName)
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
        }

        // ── View switcher: All / Favorites ────────────────────────────────
        // Sits just above the carousel, and is skewed into parallelograms (with
        // counter-skewed labels) to match the wallpaper cards.
        Row {
            id: viewTabs
            z: 100
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.verticalCenter
            anchors.bottomMargin: (window.itemHeight * 1.15) / 2 + 18
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
