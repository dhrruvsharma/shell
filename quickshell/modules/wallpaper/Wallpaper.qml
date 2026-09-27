pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Qt.labs.folderlistmodel
import Quickshell
import qs.services
import qs.colors
import qs.components
import qs.modules.lock
import qs.settings

// Wallpaper picker (SUPER+W, `qs ipc call wallpaper toggle|wallhaven`): a
// large preview of the selected wallpaper over a dimmed desktop, and a
// filmstrip of thumbnails under it, for three sources:
//   Local       ~/Pictures/wallpapers
//   Favourites  the hearted ones (services/WallpaperFavorites)
//   Wallhaven   search results (services/Wallhaven), fetched on first visit
//               and page by page as you reach the end; setting one downloads
//               it into ~/Pictures/wallpapers first
// Browsing crossfades the preview (Wallhaven: the thumbnail at once, full
// resolution after a short pause). Enter, a click on the preview or a
// double-click on a thumbnail sets it (services/WallpaperEngine, which plays
// the desktop theme's transition). Follows the desktop theme like the other
// panels.
//
// Keys: ←→ browse, Home/End, PgUp/PgDn, Enter set, F favourite, Tab next
// source, / search (Wallhaven), Esc close.
Rectangle {
    id: window

    readonly property string srcDir: "file://" + Quickshell.env("HOME") + "/Pictures/wallpapers"

    // Source: "local", "favorites" or "wallhaven".
    property string mode: "local"
    readonly property var modes: ["local", "favorites", "wallhaven"]
    readonly property bool favoritesOnly: mode === "favorites"
    readonly property bool online: mode === "wallhaven"
    property var allWallpapers: []
    readonly property var displayedWallpapers: {
        if (online)
            return Wallhaven.onlineWallpapers.map(w => ({ fileName: w.id, fileUrl: w.thumbUrl, fullUrl: w.fullUrl, resolution: w.resolution, item: w }));
        if (!favoritesOnly)
            return allWallpapers;
        const favs = WallpaperFavorites.favorites;
        return allWallpapers.filter(w => favs.indexOf(w.fileName) >= 0);
    }
    // Waiting for a Wallhaven download to finish before closing.
    property bool downloading: false

    readonly property int count: displayedWallpapers.length
    property int currentIndex: -1
    readonly property var currentEntry: currentIndex >= 0 && currentIndex < count ? displayedWallpapers[currentIndex] : null
    readonly property string currentName: currentEntry ? currentEntry.fileName : ""
    readonly property string activeName: WallpaperEngine.current.split("/").pop()

    // Opening/closing choreography, 0..1.
    property real shown: 0

    function rebuildList() {
        const arr = [];
        for (let i = 0; i < folderModel.count; i++)
            arr.push({ fileName: folderModel.get(i, "fileName"), fileUrl: String(folderModel.get(i, "fileUrl")) });
        allWallpapers = arr;
        if (visible && currentIndex < 0)
            selectActive();
    }

    function selectActive() {
        const i = displayedWallpapers.findIndex(w => w.fileName === activeName);
        currentIndex = i >= 0 ? i : (count > 0 ? 0 : -1);
    }

    function step(d) {
        if (count > 0)
            currentIndex = Math.max(0, Math.min(count - 1, currentIndex + d));
    }

    function pickCurrent() {
        if (!currentEntry || downloading)
            return;
        if (currentEntry.item) {
            downloading = true;
            Wallhaven.downloadAndSetWallpaper(currentEntry.item);
            return;
        }
        WallpaperEngine.set(currentEntry.fileUrl);
        close();
    }

    function setMode(m) {
        mode = m;
        if (m === "wallhaven" && Wallhaven.onlineWallpapers.length === 0 && !Wallhaven.isFetchingOnline)
            Wallhaven.fetchWallhaven(true);
    }

    function close() {
        openAnim.stop();
        closeAnim.restart();
    }

    function toggleFavorite(name) {
        if (!name)
            return;
        const wasFav = WallpaperFavorites.has(name);
        WallpaperFavorites.toggle(name);
        if (favoritesOnly && wasFav)
            Qt.callLater(() => currentIndex = Math.min(currentIndex, count - 1));
    }

    anchors.fill: parent
    color: "transparent"
    visible: false
    focus: true

    onVisibleChanged: {
        if (!visible)
            return;
        mode = "local";
        downloading = false;
        selectActive();
        strip.positionViewAtIndex(Math.max(0, currentIndex), ListView.Center);
        keys.forceActiveFocus();
        closeAnim.stop();
        openAnim.restart();
    }
    onModeChanged: {
        currentIndex = count > 0 ? 0 : -1;
        if (mode === "local")
            selectActive();
        strip.positionViewAtIndex(Math.max(0, currentIndex), ListView.Center);
    }
    onCurrentEntryChanged: {
        preview.show(currentEntry ? currentEntry.fileUrl : "");
        if (currentEntry && currentEntry.fullUrl)
            hiresTimer.restart();
        // Next page of results as the end comes into view.
        if (online && currentIndex >= count - 6)
            Wallhaven.fetchNextPage();
    }
    // First results arriving while the Wallhaven tab is open.
    onCountChanged: {
        if (currentIndex < 0 && count > 0)
            currentIndex = 0;
    }

    // Full resolution once the selection settles (the thumbnail shows at once).
    Timer {
        id: hiresTimer
        interval: 550
        onTriggered: {
            if (window.currentEntry && window.currentEntry.fullUrl)
                preview.show(window.currentEntry.fullUrl);
        }
    }

    // Close once the chosen Wallhaven wallpaper has downloaded (and is set).
    Connections {
        target: Wallhaven

        function onDownloadingWallpaperIdChanged() {
            if (window.downloading && Wallhaven.downloadingWallpaperId === "") {
                window.downloading = false;
                window.close();
            }
        }
    }

    // One arc of a loading ring (see LoadRing in the preview).
    component LoadArc: Shape {
        id: arc
        property color color
        property real thickness: 3
        property real start: -90
        property real sweep: 360
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: "transparent"
            strokeColor: arc.color
            strokeWidth: arc.thickness
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: arc.width / 2
                centerY: arc.height / 2
                radiusX: arc.width / 2 - arc.thickness
                radiusY: arc.height / 2 - arc.thickness
                startAngle: arc.start
                sweepAngle: arc.sweep
            }
        }
    }

    NumberAnimation {
        id: openAnim
        target: window
        property: "shown"
        to: 1
        duration: 320
        easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: closeAnim
        target: window
        property: "shown"
        to: 0
        duration: 200
        easing.type: Easing.InCubic
        onFinished: window.visible = false
    }

    FolderListModel {
        id: folderModel
        folder: window.srcDir
        nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.gif"]
        caseSensitive: false
        showDirs: false
        sortField: FolderListModel.Name
        onCountChanged: window.rebuildList()
    }

    // ── Scrim: the desktop, dimmed; click to close ───────────────────────────
    Rectangle {
        anchors.fill: parent
        color: Colors.scrim
        opacity: 0.6 * window.shown

        MouseArea {
            anchors.fill: parent
            onClicked: window.close()
            onWheel: wheel => window.step(wheel.angleDelta.y > 0 ? -1 : 1)
        }
    }

    Item {
        id: keys
        anchors.fill: parent
        focus: true

        Keys.onPressed: event => {
            const k = event.key;
            if (k === Qt.Key_Escape)
                window.close();
            else if (k === Qt.Key_Left || k === Qt.Key_Up)
                window.step(-1);
            else if (k === Qt.Key_Right || k === Qt.Key_Down)
                window.step(1);
            else if (k === Qt.Key_Home)
                window.currentIndex = window.count > 0 ? 0 : -1;
            else if (k === Qt.Key_End)
                window.currentIndex = window.count - 1;
            else if (k === Qt.Key_PageUp)
                window.step(-8);
            else if (k === Qt.Key_PageDown)
                window.step(8);
            else if (k === Qt.Key_Return || k === Qt.Key_Enter)
                window.pickCurrent();
            else if (k === Qt.Key_F && !window.online)
                window.toggleFavorite(window.currentName);
            else if (k === Qt.Key_Tab || k === Qt.Key_Backtab)
                window.setMode(window.modes[(window.modes.indexOf(window.mode) + (k === Qt.Key_Tab ? 1 : 2)) % 3]);
            else if (k === Qt.Key_Slash && window.online)
                search.forceActiveFocus();
            else
                return;
            event.accepted = true;
        }
    }

    Column {
        id: content
        anchors.centerIn: parent
        anchors.verticalCenterOffset: (1 - window.shown) * 30
        width: Math.min(1180, window.width - 120)
        spacing: 18
        opacity: window.shown

        // ── Header ─────────────────────────────────────────────────────────
        Item {
            width: parent.width
            height: 40

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12

                Glyph {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "wallpaper"
                    filled: true
                    font.pixelSize: 26
                    color: Colors.primary
                }

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Wallpapers"
                    font.pixelSize: 22
                    font.weight: Font.Bold
                }

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: window.count > 0 ? (window.currentIndex + 1) + " / " + window.count + (window.online && Wallhaven.hasMorePages ? "+" : "") : ""
                    font.pixelSize: 13
                    color: Colors.on_surface_variant
                }
            }

            // All | Favourites
            Rectangle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: tabs.implicitWidth + 8
                height: 40
                radius: DesktopTheme.rad(20)
                color: Colors.surface_container

                Row {
                    id: tabs
                    anchors.centerIn: parent
                    spacing: 4

                    Repeater {
                        model: [
                            { mode: "local", label: "Local", icon: "photo_library" },
                            { mode: "favorites", label: "Favourites", icon: "favorite" },
                            { mode: "wallhaven", label: "Wallhaven", icon: "travel_explore" }
                        ]

                        ClickableRect {
                            id: tab
                            required property var modelData
                            readonly property bool current: window.mode === modelData.mode
                            width: tabRow.implicitWidth + 28
                            height: 32
                            radius: 16
                            color: current ? Colors.primary : tab.hovered ? Colors.surface_container_high : "transparent"
                            cursorShape: Qt.PointingHandCursor
                            onClicked: window.setMode(modelData.mode)

                            Row {
                                id: tabRow
                                anchors.centerIn: parent
                                spacing: 6

                                Glyph {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: tab.modelData.icon
                                    filled: tab.current
                                    font.pixelSize: 17
                                    color: tab.current ? Colors.on_primary : Colors.on_surface_variant
                                }

                                StyledText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: tab.modelData.label + (tab.modelData.mode === "favorites" ? " (" + WallpaperFavorites.favorites.length + ")" : "")
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
                                    color: tab.current ? Colors.on_primary : Colors.on_surface
                                }
                            }
                        }
                    }
                }
            }
        }

        // ── Wallhaven search and filters ───────────────────────────────────
        Flow {
            id: filters
            visible: window.online
            width: parent.width
            spacing: 8

            component Chip: ClickableRect {
                id: chip
                property string label
                property bool active
                property color activeColor: Colors.secondary_container
                property color activeText: Colors.on_secondary_container
                width: chipText.implicitWidth + 22
                height: 32
                radius: 16
                color: active ? activeColor : chip.hovered ? Colors.surface_container_high : Colors.surface_container
                cursorShape: Qt.PointingHandCursor

                StyledText {
                    id: chipText
                    anchors.centerIn: parent
                    text: chip.label
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    color: chip.active ? chip.activeText : Colors.on_surface
                }
            }

            component Gap: Item {
                width: 6
                height: 32
            }

            StyledTextField {
                id: search
                width: 240
                height: 32
                placeholderText: "Search Wallhaven  ( / )"
                font.pixelSize: 13
                leftPadding: 12
                focusBorderColor: Colors.primary
                text: Wallhaven.currentSearchText
                onAccepted: {
                    Wallhaven.updateSearch(text);
                    keys.forceActiveFocus();
                }
                Keys.onEscapePressed: keys.forceActiveFocus()
            }

            Gap {}

            Repeater {
                model: [["Recent", "date_added"], ["Hot", "toplist"], ["Views", "views"], ["Favs", "favorites"], ["Random", "random"], ["Relevant", "relevance"]]

                Chip {
                    required property var modelData
                    label: modelData[0]
                    active: SettingsConfig.wallhavenSorting === modelData[1]
                    onClicked: SettingsConfig.wallhavenSorting = modelData[1]
                }
            }

            Repeater {
                model: SettingsConfig.wallhavenSorting === "toplist" ? ["1d", "3d", "1w", "1M", "3M", "6M", "1y"] : []

                Chip {
                    required property string modelData
                    label: modelData
                    active: SettingsConfig.wallhavenTopRange === modelData
                    onClicked: SettingsConfig.wallhavenTopRange = modelData
                }
            }

            Chip {
                label: SettingsConfig.wallhavenOrder === "desc" ? "↓" : "↑"
                onClicked: SettingsConfig.wallhavenOrder = SettingsConfig.wallhavenOrder === "desc" ? "asc" : "desc"
            }

            Gap {}

            Repeater {
                model: [["General", 0], ["Anime", 1], ["People", 2]]

                Chip {
                    required property var modelData
                    label: modelData[0]
                    active: SettingsConfig.wallhavenCategories[modelData[1]] === "1"
                    onClicked: {
                        const c = SettingsConfig.wallhavenCategories.split("");
                        c[modelData[1]] = c[modelData[1]] === "1" ? "0" : "1";
                        if (c.includes("1"))
                            SettingsConfig.wallhavenCategories = c.join("");
                    }
                }
            }

            Gap {}

            Repeater {
                model: SettingsConfig.wallhavenApiKey.length > 0 ? [["SFW", 0], ["Sketchy", 1], ["NSFW", 2]] : [["SFW", 0], ["Sketchy", 1]]

                Chip {
                    required property var modelData
                    label: modelData[0]
                    active: SettingsConfig.wallhavenPurity[modelData[1]] === "1"
                    activeColor: modelData[1] === 2 ? Colors.error : Colors.secondary_container
                    activeText: modelData[1] === 2 ? Colors.on_error : Colors.on_secondary_container
                    onClicked: {
                        const p = SettingsConfig.wallhavenPurity.split("");
                        p[modelData[1]] = p[modelData[1]] === "1" ? "0" : "1";
                        if (p.includes("1"))
                            SettingsConfig.wallhavenPurity = p.join("");
                    }
                }
            }
        }

        // ── Preview ────────────────────────────────────────────────────────
        Rectangle {
            id: preview

            property Image front: imgA
            readonly property Image back: front === imgA ? imgB : imgA

            function show(url) {
                if (!url) {
                    front.opacity = 0;
                    return;
                }
                if (String(front.source) === url && front.status !== Image.Null)
                    return;
                back.source = url;
                back.opacity = 0;
                back.scale = 1.04;
                back.z = 2;
                front.z = 1;
                if (back.status === Image.Ready)
                    fadeIn.restart();
            }

            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width
            height: Math.min(width * 10 / 16, window.height - 360 - (window.online ? filters.height + content.spacing : 0))
            radius: DesktopTheme.rad(26)
            color: Colors.surface_container_lowest
            clip: true
            scale: 0.96 + 0.04 * window.shown

            component PreviewImage: Image {
                id: pimg
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                sourceSize: Qt.size(preview.width * 1.25, preview.height * 1.25)
                asynchronous: true
                cache: false
                smooth: true
                opacity: 0
                onStatusChanged: {
                    if (status === Image.Ready && pimg === preview.back)
                        fadeIn.restart();
                }
            }

            Rectangle {
                id: previewMask
                anchors.fill: parent
                radius: preview.radius
                visible: false
                layer.enabled: true
            }

            Item {
                anchors.fill: parent
                layer.enabled: true
                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskSource: previewMask
                    maskThresholdMin: 0.5
                    maskSpreadAtMin: 1.0
                }

                PreviewImage { id: imgA }
                PreviewImage { id: imgB }
            }

            ParallelAnimation {
                id: fadeIn
                NumberAnimation { target: preview.back; property: "opacity"; to: 1; duration: 260; easing.type: Easing.OutCubic }
                NumberAnimation { target: preview.back; property: "scale"; to: 1; duration: 420; easing.type: Easing.OutCubic }
                onFinished: {
                    const old = preview.front;
                    preview.front = preview.back;
                    old.opacity = 0;
                    old.source = "";
                }
            }

            // ── Loading indicators ──────────────────────────────────────────
            // What's loading: the incoming image. With nothing on screen yet
            // (a Wallhaven thumbnail on its way) a card in the middle; with
            // the thumbnail up and its full resolution downloading, a chip in
            // the corner so the picture stays visible.
            readonly property bool loading: back.status === Image.Loading
            readonly property bool frontReady: front.status === Image.Ready && front.opacity > 0.5
            readonly property real progress: back.progress

            component LoadRing: Item {
                id: ring
                property real progress: 0
                property real thickness: 3
                readonly property bool indeterminate: progress <= 0.01

                // Track.
                LoadArc {
                    thickness: ring.thickness
                    color: Colors.withAlpha("white", 0.18)
                }

                // Real progress once the download reports it.
                LoadArc {
                    thickness: ring.thickness
                    visible: !ring.indeterminate
                    color: Colors.primary
                    sweep: Math.max(8, ring.progress * 360)
                }

                // A spinning quarter until then.
                LoadArc {
                    id: spinner
                    thickness: ring.thickness
                    visible: ring.indeterminate
                    color: Colors.primary
                    sweep: 90

                    RotationAnimator on rotation {
                        from: 0
                        to: 360
                        duration: 900
                        loops: Animation.Infinite
                        running: spinner.visible && ring.visible
                    }
                }
            }

            Rectangle {
                z: 4
                anchors.centerIn: parent
                visible: preview.loading && !preview.frontReady
                width: loadCol.implicitWidth + 44
                height: loadCol.implicitHeight + 36
                radius: DesktopTheme.rad(18)
                color: Colors.withAlpha("black", 0.45)

                Column {
                    id: loadCol
                    anchors.centerIn: parent
                    spacing: 12

                    LoadRing {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 46
                        height: 46
                        progress: preview.progress
                    }

                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Loading preview" + (preview.progress > 0.01 ? "  " + Math.round(preview.progress * 100) + "%" : "…")
                        font.pixelSize: 13
                        color: "white"
                    }
                }
            }

            Rectangle {
                z: 4
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: 16
                visible: preview.loading && preview.frontReady
                width: chipRow.implicitWidth + 22
                height: 32
                radius: DesktopTheme.rad(16)
                color: Colors.withAlpha("black", 0.5)

                Row {
                    id: chipRow
                    anchors.centerIn: parent
                    spacing: 8

                    LoadRing {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 18
                        height: 18
                        thickness: 2.5
                        progress: preview.progress
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Full resolution" + (preview.progress > 0.01 ? "  " + Math.round(preview.progress * 100) + "%" : "…")
                        font.pixelSize: 12
                        color: "white"
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                z: 5
                cursorShape: Qt.PointingHandCursor
                onClicked: window.pickCurrent()
                onWheel: wheel => window.step(wheel.angleDelta.y > 0 ? -1 : 1)
            }

            // Name, badges and actions along the bottom.
            Rectangle {
                z: 6
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 76
                gradient: Gradient {
                    GradientStop { position: 0; color: "transparent" }
                    GradientStop { position: 1; color: Colors.withAlpha("black", 0.6) }
                }

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 22
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 16
                    spacing: 10

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: window.online && window.currentEntry ? "wallhaven " + window.currentName + "  ·  " + window.currentEntry.resolution : window.currentName
                        font.pixelSize: 15
                        font.weight: Font.DemiBold
                        color: "white"
                    }

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !window.online && window.currentName !== "" && window.currentName === window.activeName
                        width: activeLabel.implicitWidth + 16
                        height: 22
                        radius: DesktopTheme.rad(11)
                        color: Colors.primary

                        StyledText {
                            id: activeLabel
                            anchors.centerIn: parent
                            text: "Current"
                            font.pixelSize: 11
                            font.weight: Font.Bold
                            color: Colors.on_primary
                        }
                    }
                }

                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: 18
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 12
                    spacing: 8

                    ClickableRect {
                        id: favButton
                        visible: !window.online
                        readonly property bool fav: WallpaperFavorites.favorites.indexOf(window.currentName) >= 0
                        width: 38
                        height: 38
                        radius: 19
                        color: favButton.hovered ? Colors.withAlpha("black", 0.55) : Colors.withAlpha("black", 0.35)
                        cursorShape: Qt.PointingHandCursor
                        onClicked: window.toggleFavorite(window.currentName)

                        Glyph {
                            anchors.centerIn: parent
                            text: "favorite"
                            filled: favButton.fav
                            font.pixelSize: 20
                            color: favButton.fav ? "#ff5c7a" : "white"
                        }
                    }

                    ClickableRect {
                        id: setButton
                        width: setRow.implicitWidth + 30
                        height: 38
                        radius: 19
                        color: setButton.hovered ? Qt.lighter(Colors.primary, 1.08) : Colors.primary
                        cursorShape: Qt.PointingHandCursor
                        onClicked: window.pickCurrent()

                        Row {
                            id: setRow
                            anchors.centerIn: parent
                            spacing: 8

                            Glyph {
                                anchors.verticalCenter: parent.verticalCenter
                                text: window.online ? "download" : "check"
                                font.pixelSize: 18
                                color: Colors.on_primary
                            }

                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: window.downloading ? "Downloading…" : window.online ? "Download & set" : "Set wallpaper"
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                color: Colors.on_primary
                            }
                        }
                    }
                }
            }

            // Nothing to show (no favourites yet).
            Column {
                anchors.centerIn: parent
                visible: window.count === 0 || (window.online && Wallhaven.onlineError.length > 0 && window.count === 0)
                spacing: 10

                Glyph {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: window.online ? (Wallhaven.onlineError ? "cloud_off" : "travel_explore") : window.favoritesOnly ? "heart_plus" : "hide_image"
                    font.pixelSize: 48
                    color: Colors.on_surface_variant
                }

                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: window.online ? (Wallhaven.onlineError || (Wallhaven.isFetchingOnline ? "Searching Wallhaven…" : "No results"))
                        : window.favoritesOnly ? "No favourites yet: press F on a wallpaper you like" : "No wallpapers in ~/Pictures/wallpapers"
                    font.pixelSize: 15
                    color: Colors.on_surface_variant
                }
            }

            PanelDecor {
                radius: preview.radius
                title: "wallpapers"
            }
        }

        // ── Filmstrip ──────────────────────────────────────────────────────
        ListView {
            id: strip

            readonly property real thumbW: 176
            readonly property real thumbH: 110

            width: parent.width
            height: thumbH + 14
            orientation: ListView.Horizontal
            spacing: 12
            clip: true
            model: window.displayedWallpapers
            currentIndex: window.currentIndex
            highlightRangeMode: ListView.ApplyRange
            preferredHighlightBegin: width / 2 - thumbW / 2
            preferredHighlightEnd: width / 2 + thumbW / 2
            highlightMoveDuration: 260
            cacheBuffer: 1200
            boundsBehavior: Flickable.StopAtBounds
            anchors.horizontalCenter: parent.horizontalCenter

            delegate: Item {
                id: thumb

                required property var modelData
                required property int index
                readonly property bool selected: index === window.currentIndex

                width: strip.thumbW
                height: strip.height

                Rectangle {
                    id: frame
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    width: strip.thumbW
                    height: strip.thumbH
                    radius: DesktopTheme.rad(14)
                    color: Colors.surface_container
                    scale: thumb.selected ? 1.0 : thumbArea.containsMouse ? 0.96 : 0.92
                    opacity: thumb.selected ? 1 : thumbArea.containsMouse ? 0.9 : 0.62
                    // Round the thumbnail itself (a radius doesn't clip children).
                    layer.enabled: radius > 0
                    layer.effect: MultiEffect {
                        maskEnabled: true
                        maskSource: thumbMask
                        maskThresholdMin: 0.5
                        maskSpreadAtMin: 1.0
                    }

                    Rectangle {
                        id: thumbMask
                        anchors.fill: parent
                        radius: frame.radius
                        visible: false
                        layer.enabled: true
                    }

                    Behavior on scale {
                        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                    }

                    Behavior on opacity {
                        NumberAnimation { duration: 180 }
                    }

                    Image {
                        anchors.fill: parent
                        source: thumb.modelData.fileUrl
                        fillMode: Image.PreserveAspectCrop
                        sourceSize: Qt.size(strip.thumbW * 1.5, strip.thumbH * 1.5)
                        asynchronous: true
                        smooth: true
                    }

                    // The wallpaper on screen now.
                    Rectangle {
                        visible: thumb.modelData.fileName === window.activeName
                        anchors.left: parent.left
                        anchors.bottom: parent.bottom
                        anchors.margins: 7
                        width: 9
                        height: 9
                        radius: DesktopTheme.rad(4.5)
                        color: Colors.primary
                        border.width: 1.5
                        border.color: "white"
                    }

                    Glyph {
                        visible: WallpaperFavorites.favorites.indexOf(thumb.modelData.fileName) >= 0
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 6
                        text: "favorite"
                        filled: true
                        font.pixelSize: 15
                        color: "#ff5c7a"
                    }
                }

                // Selection ring (outside the layered frame so it isn't clipped).
                Rectangle {
                    anchors.fill: frame
                    anchors.margins: -4
                    visible: thumb.selected
                    radius: frame.radius > 0 ? frame.radius + 4 : 0
                    color: "transparent"
                    border.width: 2.5
                    border.color: Colors.primary
                }

                MouseArea {
                    id: thumbArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: window.currentIndex = thumb.index
                    onDoubleClicked: {
                        window.currentIndex = thumb.index;
                        window.pickCurrent();
                    }
                }
            }

            // Wheel scrolls the selection, not just the strip.
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                onWheel: wheel => window.step(wheel.angleDelta.y > 0 || wheel.angleDelta.x > 0 ? -1 : 1)
            }
        }

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: window.online ? "←→ browse · Enter or click to download & set · / search · Tab local · Esc close"
                : "←→ browse · Enter or click to set · double-click a thumbnail · F favourite · Tab next source · Esc close"
            font.pixelSize: 12
            color: Colors.withAlpha(Colors.on_surface, 0.7)
        }
    }
}
