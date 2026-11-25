import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Controls
import qs.modules.utils
import qs.modules.services
import qs.modules.settings
import qs.modules.components.custom

Item {
    id: appLauncher

    property var outerCorners: null
    readonly property real contentInset: 10
    function innerCorner(c) {
        const o = appLauncher.outerCorners ? (appLauncher.outerCorners[c] ?? ServiceLauncher.radius) : ServiceLauncher.radius;
        return Math.max(0, o - appLauncher.contentInset);
    }
    implicitHeight: parent.height

    signal closed

    property bool preview: false
    property int entranceDelay: 300
    property real entranceRise: 0

    onVisibleChanged: if (visible && col.visible && !appLauncher.preview)
        appLauncher.focusSearch()

    readonly property string mode: ServiceLauncher.mode
    readonly property bool isApps: mode === "apps"
    readonly property bool isEmoji: mode === "emoji"
    property string query: ""
    readonly property bool searching: appLauncher.query.length > 0

    property Item searchField: null
    property Item modeView: null
    readonly property Item styleItem: styleLoader.item
    readonly property var appView: appLauncher.styleItem ? appLauncher.styleItem.appView : null
    readonly property var activeView: appLauncher.isApps ? appLauncher.appView : appLauncher.modeView

    property string selectedCategory: "All"

    // ── Section dialog (create / rename) ────────────────────────────────────
    property bool sectionDialogOpen: false
    property string sectionDialogMode: "create"  // "create" | "rename"
    property string sectionDialogTarget: ""      // original name when renaming
    property string sectionDialogName: ""        // current text in the field
    property var sectionDialogApp: null          // app to add when creating

    readonly property bool sectionDialogReady: sectionDialogField.text.trim().length > 0

    readonly property var _categoryMap: ({
            "AudioVideo": "Media",
            "Audio": "Media",
            "Video": "Media",
            "Development": "Dev",
            "Education": "Education",
            "Game": "Games",
            "Graphics": "Graphics",
            "Network": "Internet",
            "Office": "Office",
            "Science": "Science",
            "Settings": "Settings",
            "System": "System",
            "Utility": "Utilities"
        })

    readonly property var _categoryIcons: ({
            "All": "apps",
            "Media": "play_circle",
            "Dev": "code",
            "Education": "school",
            "Games": "sports_esports",
            "Graphics": "brush",
            "Internet": "public",
            "Office": "description",
            "Science": "science",
            "Settings": "tune",
            "System": "settings",
            "Utilities": "build"
        })

    function categoryIcon(label) {
        return appLauncher._categoryIcons[label] ?? "category";
    }

    function categoryOf(app) {
        for (const c of (app?.categories ?? [])) {
            const l = appLauncher._categoryMap[c];
            if (l)
                return l;
        }
        return "";
    }

    readonly property var availableCategories: {
        var seen = new Set();
        var result = [
            {
                value: "All",
                label: "All"
            }
        ];
        for (var app of ServiceApps.list) {
            for (var cat of (app.categories ?? [])) {
                var label = _categoryMap[cat];
                if (label && !seen.has(label)) {
                    seen.add(label);
                    result.push({
                        value: cat,
                        label: label
                    });
                }
            }
        }
        result.sort((a, b) => a.label === "All" ? -1 : b.label === "All" ? 1 : a.label.localeCompare(b.label));
        return result;
    }

    readonly property string selectedLabel: {
        const c = appLauncher.availableCategories.find(x => x.value === appLauncher.selectedCategory);
        return c ? c.label : "All";
    }

    property var filteredApps: {
        var base = ServiceApps.filteredApps;
        if (ServiceLauncher.sortMode === "used" && ServiceApps.currentSearchText.length === 0)
            base = ServiceApps.byUsage(base);
        if (selectedCategory === "All")
            return base;
        var catKey = selectedCategory;
        return base.filter(function (app) {
            return (app.categories ?? []).some(function (c) {
                return _categoryMap[c] === _categoryMap[catKey] || c === catKey;
            });
        });
    }

    function usageCount(app) {
        const u = ServiceApps.usage[app?.id ?? ""];
        return u ? u.count : 0;
    }

    function mostUsed(n) {
        const used = ServiceApps.byUsage(ServiceApps.list).filter(a => appLauncher.usageCount(a) > 0);
        const out = used.slice(0, n);
        for (const a of ServiceApps.pinnedApps) {
            if (out.length >= n)
                break;
            if (out.indexOf(a) < 0)
                out.push(a);
        }
        return out;
    }

    function favourites(n) {
        const out = Array.prototype.slice.call(ServiceApps.pinnedApps, 0, n);
        return out.length > 0 ? out : appLauncher.mostUsed(n);
    }

    // ── Launcher sections (SettingsConfig.launcher.sections) ────────────────
    // A section is either a string ("pinned" | "recent" | "shell") or a custom
    // object ({ name, items }). The helpers below mutate the list immutably so
    // the settings adapter and the launcher UI refresh cleanly.
    readonly property int sectionCount: (SettingsConfig.launcher?.sections ?? []).length

    readonly property var customSections: {
        const out = [];
        for (const sec of (SettingsConfig.launcher?.sections ?? [])) {
            if (typeof sec === "object" && sec !== null)
                out.push(sec);
        }
        return out;
    }

    function sectionByName(name) {
        return (SettingsConfig.launcher?.sections ?? []).find(
            sec => typeof sec === "object" && sec !== null && sec.name === name
        ) ?? null;
    }

    function sectionOfApp(app) {
        const list = appLauncher.sectionsOfApp(app);
        return list.length > 0 ? list[0] : null;
    }

    function sectionsOfApp(app) {
        const id = app?.id ?? "";
        if (!id)
            return [];
        const out = [];
        for (const sec of (SettingsConfig.launcher?.sections ?? [])) {
            if (typeof sec === "object" && sec !== null) {
                const items = sec.items ?? sec.apps ?? [];
                if (items.includes(id))
                    out.push(sec.name);
            }
        }
        return out;
    }

    function _writeSections(next) {
        SettingsConfig.launcher = Object.assign({}, SettingsConfig.launcher ?? {}, {
            sections: next
        });
    }

    function addAppToSection(app, sectionName) {
        if (!app || !sectionName)
            return;
        const id = app.id;
        const sections = Array.prototype.slice.call(SettingsConfig.launcher?.sections ?? []);
        const idx = sections.findIndex(sec => typeof sec === "object" && sec !== null && sec.name === sectionName);
        if (idx < 0) {
            sections.push({ name: sectionName, items: [id] });
        } else {
            const items = Array.prototype.slice.call(sections[idx].items ?? sections[idx].apps ?? []);
            if (!items.includes(id)) {
                items.push(id);
                sections[idx] = Object.assign({}, sections[idx], { items: items });
            }
        }
        _writeSections(sections);
    }

    function removeAppFromSection(app, sectionName) {
        if (!app || !sectionName)
            return;
        const id = app.id;
        const sections = Array.prototype.slice.call(SettingsConfig.launcher?.sections ?? []);
        const idx = sections.findIndex(sec => typeof sec === "object" && sec !== null && sec.name === sectionName);
        if (idx < 0)
            return;
        const items = Array.prototype.slice.call(sections[idx].items ?? sections[idx].apps ?? []);
        sections[idx] = Object.assign({}, sections[idx], { items: items.filter(x => x !== id) });
        _writeSections(sections);
    }

    function createSection(name) {
        const trimmed = (name ?? "").trim();
        if (trimmed === "")
            return;
        const sections = Array.prototype.slice.call(SettingsConfig.launcher?.sections ?? []);
        const exists = sections.some(sec => typeof sec === "object" && sec !== null && sec.name === trimmed);
        if (!exists)
            sections.push({ name: trimmed, items: [] });
        _writeSections(sections);
    }

    function removeSection(sectionName) {
        const sections = Array.prototype.slice.call(SettingsConfig.launcher?.sections ?? []);
        _writeSections(sections.filter(sec => !(typeof sec === "object" && sec !== null && sec.name === sectionName)));
    }

    function moveSection(sectionName, delta) {
        const sections = Array.prototype.slice.call(SettingsConfig.launcher?.sections ?? []);
        const idx = sections.findIndex(sec => typeof sec === "object" && sec !== null && sec.name === sectionName);
        if (idx < 0)
            return;
        const to = idx + delta;
        if (to < 0 || to >= sections.length)
            return;
        const [it] = sections.splice(idx, 1);
        sections.splice(to, 0, it);
        _writeSections(sections);
    }

    function renameSection(sectionName, newName) {
        const trimmed = (newName ?? "").trim();
        if (trimmed === "")
            return;
        const sections = Array.prototype.slice.call(SettingsConfig.launcher?.sections ?? []);
        const idx = sections.findIndex(sec => typeof sec === "object" && sec !== null && sec.name === sectionName);
        if (idx < 0)
            return;
        sections[idx] = Object.assign({}, sections[idx], { name: trimmed });
        _writeSections(sections);
    }

    function timeAgo(app) {
        const u = ServiceApps.usage[app?.id ?? ""];
        if (!u)
            return "";
        const m = Math.floor((Date.now() - u.last) / 60000);
        if (m < 1)
            return "Just now";
        if (m < 60)
            return m + " min ago";
        const h = Math.floor(m / 60);
        if (h < 24)
            return h + " h ago";
        const d = Math.floor(h / 24);
        return d === 1 ? "Yesterday" : d + " days ago";
    }

    function iconFor(app) {
        return IconUtil.getDesktopIconPath(app?.icon ?? "");
    }

    function launch(app) {
        if (!app)
            return;
        ServiceApps.run(app);
        appLauncher.closed();
    }

    readonly property var menuApp: ctxMenu.targetApp

    function openMenu(item, x, y, app) {
        const p = item.mapToItem(appLauncher, x, y);
        appLauncher.showContextMenu(p.x, p.y, app);
    }

    function focusSearch() {
        if (appLauncher.searchField && !appLauncher.preview)
            appLauncher.searchField.focusInput();
    }

    function setQuery(text) {
        if (appLauncher.searchField)
            appLauncher.searchField.text = text;
        appLauncher.focusSearch();
    }

    function selectCategory(value) {
        appLauncher.selectedCategory = value;
        if (appLauncher.appView)
            appLauncher.appView.activeIndex = 0;
    }

    onClosed: {
        col.visible = false;
        if (appLauncher.searchField)
            appLauncher.searchField.text = "";
        appLauncher.query = "";
        ServiceApps.reset();
        ServiceLauncher.reset();
        if (appLauncher.appView)
            appLauncher.appView.activeIndex = 0;
        if (appLauncher.styleItem && appLauncher.styleItem.reset)
            appLauncher.styleItem.reset();
        selectedCategory = "All";
    }

    function clearSearch() {
        if (appLauncher.searchField)
            appLauncher.searchField.text = "";
        appLauncher.query = "";
        ServiceLauncher.reset();
        ServiceApps.updateSearch("");
        appLauncher.selectedCategory = "All";
        if (appLauncher.appView)
            appLauncher.appView.activeIndex = 0;
    }

    Component.onCompleted: {
        appLauncher.clearSearch();
        if (GlobalStates.launcherSeed !== "") {
            const seed = GlobalStates.launcherSeed;
            GlobalStates.launcherSeed = "";
            Qt.callLater(function () {
                if (appLauncher.searchField) {
                    appLauncher.searchField.text = seed;
                    appLauncher.searchField.cursorPosition = seed.length;
                }
                appLauncher.updateQuery(seed);
            });
        }
    }

    function updateQuery(text) {
        appLauncher.query = text;
        ServiceLauncher.query = text;
        ServiceApps.updateSearch(ServiceLauncher.mode === "apps" ? text : "");
        if (activeView)
            activeView.activeIndex = 0;
    }

    function activateSelected() {
        const v = appLauncher.activeView;
        if (v)
            v.activateIndex(v.activeIndex);
    }

    function handleKey(event) {
        const view = appLauncher.activeView;
        if (event.key === Qt.Key_Escape) {
            if (ctxMenu.targetApp !== null) {
                ctxMenu.targetApp = null;
                event.accepted = true;
                return;
            }
            if (appLauncher.styleItem && appLauncher.styleItem.handleEscape && appLauncher.styleItem.handleEscape()) {
                event.accepted = true;
            } else if (!appLauncher.isApps || appLauncher.searching) {
                appLauncher.setQuery("");
                event.accepted = true;
            } else {
                appLauncher.closed();
            }
            return;
        }
        if (event.key === Qt.Key_Backspace && appLauncher.searchField && appLauncher.searchField.cursorPosition === 0 && !appLauncher.isApps) {
            appLauncher.setQuery("");
            event.accepted = true;
            return;
        }
        if (!view)
            return;
        if (view.navigate && view.navigate(event.key)) {
            event.accepted = true;
            return;
        }
        const cols = view.columns ?? 1;
        const grid = cols > 1;
        const last = (view.navCount ?? view.count) - 1;
        function moveTo(i) {
            view.activeIndex = Math.max(0, Math.min(last, i));
            if (view.reveal)
                view.reveal(view.activeIndex);
            else
                view.positionViewAtIndex(view.activeIndex, GridView.Contain);
        }
        if (event.key === Qt.Key_Down) {
            moveTo(view.activeIndex + (grid ? cols : 1));
            event.accepted = true;
        } else if (event.key === Qt.Key_Up) {
            moveTo(view.activeIndex - (grid ? cols : 1));
            event.accepted = true;
        } else if (event.key === Qt.Key_Right && grid) {
            moveTo(view.activeIndex + 1);
            event.accepted = true;
        } else if (event.key === Qt.Key_Left && grid) {
            moveTo(view.activeIndex - 1);
            event.accepted = true;
        }
    }

    function showContextMenu(clickX, clickY, app) {
        ctxMenu.targetApp = app;
        ctxMenu.x = Math.max(4, Math.min(clickX, width - ctxMenu.width - 4));
        ctxMenu.y = clickY;
    }

    function openSectionDialog(mode, name, app) {
        sectionDialogMode = mode;
        sectionDialogTarget = mode === "rename" ? name : "";
        sectionDialogName = name ?? "";
        sectionDialogApp = app ?? null;
        sectionDialogOpen = true;
        Qt.callLater(function () {
            if (sectionDialogField) {
                sectionDialogField.text = sectionDialogName;
                sectionDialogField.forceActiveFocus();
            }
        });
    }

    function closeSectionDialog() {
        sectionDialogOpen = false;
        appLauncher.focusSearch();
    }

    function sectionDialogSubmit() {
        if (!appLauncher.sectionDialogReady)
            return;
        const name = sectionDialogField.text.trim();
        if (sectionDialogMode === "rename") {
            renameSection(sectionDialogTarget, name);
        } else {
            createSection(name);
            if (sectionDialogApp)
                addAppToSection(sectionDialogApp, name);
        }
        closeSectionDialog();
    }

    function replayEntrance() {
        if (col.visible || showTimer.running)
            return;
        showTimer.restart();
    }

    Connections {
        target: GlobalStates
        function onLauncherPreviewChanged() {
            if (GlobalStates.launcherPreview)
                appLauncher.replayEntrance();
        }
        function onAppLauncherOpenChanged() {
            if (GlobalStates.appLauncherOpen) {
                appLauncher.clearSearch();
                appLauncher.replayEntrance();
                return;
            }
            if (!appLauncher.preview) {
                showTimer.stop();
                col.visible = false;
            }
        }
    }

    Item {
        id: col
        anchors.fill: parent
        anchors.margins: appLauncher.contentInset
        visible: false
        transform: Translate {
            id: colRise
            y: 0
        }
        onVisibleChanged: if (visible)
            appLauncher.focusSearch()

        Timer {
            id: showTimer
            interval: appLauncher.entranceDelay
            onTriggered: {
                col.visible = true;
                if (appLauncher.entranceRise !== 0)
                    entranceAnim.start();
            }
        }

        Component.onCompleted: showTimer.start()

        NumberAnimation {
            id: entranceAnim
            target: colRise
            property: "y"
            from: appLauncher.entranceRise
            to: 0
            duration: M3Motion.spatialDuration("default")
            easing.type: Easing.BezierSpline
            easing.bezierCurve: [0.2, 0.0, 0.0, 1.0, 1, 1]
        }

        Loader {
            id: styleLoader
            anchors.fill: parent
            active: true
            sourceComponent: ServiceLauncher.style === "hearth" ? hearthComp : paletteComp
            onLoaded: {
                const q = appLauncher.query;
                if (appLauncher.searchField)
                    appLauncher.searchField.text = q;
                appLauncher.focusSearch();
            }
        }

        // ── Section dialog (create / rename) ─────────────────────────────────
        Item {
            id: sectionDialog
            anchors.fill: parent
            visible: appLauncher.sectionDialogOpen
            z: 10
            clip: true

            Rectangle {
                id: sectionDialogScrim
                anchors.fill: parent
                color: Qt.alpha(Colors.scrim, 0.35)
                opacity: 0
                EffectsAnim {
                    target: sectionDialogScrim
                    property: "opacity"
                    from: 0
                    to: 1
                    speed: "fast"
                    running: true
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: appLauncher.closeSectionDialog()
                }
            }

            Rectangle {
                id: sectionDialogCard
                anchors.centerIn: parent
                width: Math.min(parent.width - 40, 380)
                implicitHeight: sectionDialogCol.implicitHeight + 40
                radius: 24
                color: Colors.surfaceContainerHigh
                Behavior on color {
                    EffectsColorAnim {}
                }

                ColumnLayout {
                    id: sectionDialogCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 20
                    anchors.rightMargin: 20
                    spacing: 14

                    CustomText {
                        Layout.fillWidth: true
                        content: appLauncher.sectionDialogMode === "rename" ? "Rename section" : "New section"
                        size: 16
                        weight: 700
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 52
                        radius: 14
                        color: Colors.surfaceContainerHighest
                        border.width: 2
                        border.color: sectionDialogField.activeFocus ? Colors.primary : Qt.alpha(Colors.primary, 0)
                        Behavior on border.color {
                            EffectsColorAnim {}
                        }

                        TextField {
                            id: sectionDialogField
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 14
                            background: null
                            padding: 0
                            placeholderText: "Section name"
                            placeholderTextColor: Colors.outline
                            font.pixelSize: 15
                            font.weight: 600
                            font.family: SettingsConfig.general.defaultFont ?? "Rubik"
                            color: Colors.surfaceText
                            selectionColor: Qt.alpha(Colors.primary, 0.35)
                            selectedTextColor: Colors.surfaceText
                            verticalAlignment: TextInput.AlignVCenter
                            onAccepted: appLauncher.sectionDialogSubmit()
                            Keys.onEscapePressed: appLauncher.closeSectionDialog()
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Item {
                            Layout.fillWidth: true
                        }

                        Rectangle {
                            Layout.preferredHeight: 40
                            Layout.preferredWidth: cancelLabel.implicitWidth + 36
                            radius: 20
                            color: "transparent"

                            CustomText {
                                id: cancelLabel
                                anchors.centerIn: parent
                                content: "Cancel"
                                size: 13
                                weight: 700
                                customColor: Colors.primary
                            }

                            RippleEffect {
                                anchors.fill: parent
                                radius: parent.radius
                                onClicked: appLauncher.closeSectionDialog()
                            }
                        }

                        Rectangle {
                            Layout.preferredHeight: 40
                            Layout.preferredWidth: submitLabel.implicitWidth + 44
                            radius: 20
                            color: appLauncher.sectionDialogReady ? Colors.primary : Colors.surfaceContainerHighest
                            Behavior on color {
                                EffectsColorAnim {}
                            }

                            CustomText {
                                id: submitLabel
                                anchors.centerIn: parent
                                content: appLauncher.sectionDialogMode === "rename" ? "Rename" : "Create"
                                size: 13
                                weight: 700
                                customColor: appLauncher.sectionDialogReady ? Colors.primaryText : Colors.outline
                            }

                            RippleEffect {
                                anchors.fill: parent
                                radius: parent.radius
                                hoverColor: Qt.alpha(Colors.primaryText, 0.1)
                                rippleColor: Qt.alpha(Colors.primaryText, 0.2)
                                onClicked: appLauncher.sectionDialogSubmit()
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: hearthComp
        LauncherStyleHearth {
            launcher: appLauncher
        }
    }
    Component {
        id: paletteComp
        LauncherStylePalette {
            launcher: appLauncher
        }
    }

    // ── Context menu click-away ────────────────────────────────────────────
    MouseArea {
        anchors.fill: parent
        visible: ctxMenu.targetApp !== null
        z: 98
        hoverEnabled: true
        cursorShape: Qt.ArrowCursor
        onClicked: ctxMenu.targetApp = null
        onPressed: ctxMenu.targetApp = null
    }

    // ── Context menu ──────────────────────────────────────────────────────
    Rectangle {
        id: ctxMenu
        property var targetApp: null

        visible: targetApp !== null
        z: 99
        width: 220
        height: cmCol.implicitHeight + 16
        radius: 18
        color: Colors.surfaceContainer

        onHeightChanged: {
            if (y + height > appLauncher.height - 8)
                y = Math.max(4, appLauncher.height - height - 8);
        }

        transformOrigin: Item.Top
        scale: visible ? 1 : 0.88
        opacity: visible ? 1 : 0
        Behavior on scale {
            SpatialAnim {
                speed: "fast"
            }
        }
        Behavior on opacity {
            EffectsAnim {
                speed: "fast"
            }
        }

        ColumnLayout {
            id: cmCol
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                margins: 8
            }
            spacing: 6

            // App header
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 54
                radius: 12
                color: Colors.surfaceContainerHigh

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 10

                    Rectangle {
                        width: 36
                        height: 36
                        radius: 10
                        color: Qt.alpha(Colors.primary, 0.1)

                        Image {
                            anchors.centerIn: parent
                            width: 26
                            height: 26
                            source: IconUtil.getDesktopIconPath(ctxMenu.targetApp?.icon ?? "")
                            sourceSize.width: 26
                            sourceSize.height: 26
                            fillMode: Image.PreserveAspectFit
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        CustomText {
                            Layout.fillWidth: true
                            content: ctxMenu.targetApp?.name ?? ""
                            size: 13
                            weight: 700
                            elide: Text.ElideRight
                        }
                        CustomText {
                            Layout.fillWidth: true
                            content: ctxMenu.targetApp?.genericName || ctxMenu.targetApp?.comment || ""
                            size: 10
                            customColor: Colors.outline
                            elide: Text.ElideRight
                            visible: (ctxMenu.targetApp?.genericName || ctxMenu.targetApp?.comment || "").length > 0
                        }
                    }
                }
            }

            // Actions
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: cmActions.implicitHeight
                radius: 12
                color: Colors.surfaceContainerHigh
                clip: true

                ColumnLayout {
                    id: cmActions
                    anchors {
                        left: parent.left
                        right: parent.right
                    }
                    spacing: 0

                    // Launch
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 42
                        color: "transparent"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 10
                            MaterialIconSymbol {
                                content: "rocket_launch"
                                iconSize: 16
                                customColor: Colors.primary
                            }
                            CustomText {
                                Layout.fillWidth: true
                                content: "Launch"
                                size: 13
                            }
                        }

                        RippleEffect {
                            anchors.fill: parent
                            onClicked: {
                                ServiceApps.run(ctxMenu.targetApp);
                                ctxMenu.targetApp = null;
                                appLauncher.closed();
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 1
                        color: Colors.surfaceContainerHighest
                    }

                    // Pin / Unpin
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 42
                        color: "transparent"

                        readonly property bool pinned: ctxMenu.targetApp ? ServiceApps.isPinned(ctxMenu.targetApp) : false

                        RowLayout {
                            required property bool pinned
                            pinned: parent.pinned
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 10
                            MaterialIconSymbol {
                                content: "push_pin"
                                iconSize: 16
                                fill: parent.pinned ? 1 : 0
                                customColor: Colors.primary
                            }
                            CustomText {
                                Layout.fillWidth: true
                                content: parent.pinned ? "Unpin from Dock" : "Pin to Dock"
                                size: 13
                            }
                        }

                        RippleEffect {
                            anchors.fill: parent
                            onClicked: {
                                ServiceApps.togglePin(ctxMenu.targetApp);
                                ctxMenu.targetApp = null;
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 1
                        color: Colors.surfaceContainerHighest
                    }

                    // Copy name
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 42
                        color: "transparent"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 10
                            MaterialIconSymbol {
                                content: "content_copy"
                                iconSize: 16
                                customColor: Colors.outline
                            }
                            CustomText {
                                Layout.fillWidth: true
                                content: "Copy Name"
                                size: 13
                            }
                        }

                        RippleEffect {
                            anchors.fill: parent
                            onClicked: {
                                Quickshell.clipboardText = ctxMenu.targetApp?.name ?? "";
                                ctxMenu.targetApp = null;
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 1
                        color: Colors.surfaceContainerHighest
                        visible: appLauncher.customSections.length > 0
                    }

                    // Add to each existing custom section (where app is not yet added)
                    Repeater {
                        model: appLauncher.customSections

                        delegate: Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: visible ? 42 : 0
                            visible: ctxMenu.targetApp ? !((modelData.items ?? modelData.apps ?? []).includes(ctxMenu.targetApp.id)) : false
                            color: "transparent"

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 10
                                MaterialIconSymbol {
                                    content: "folder"
                                    iconSize: 16
                                    customColor: Colors.outline
                                }
                                CustomText {
                                    Layout.fillWidth: true
                                    content: "Add to " + modelData.name
                                    size: 13
                                }
                            }

                            RippleEffect {
                                anchors.fill: parent
                                onClicked: {
                                    appLauncher.addAppToSection(ctxMenu.targetApp, modelData.name);
                                    ctxMenu.targetApp = null;
                                }
                            }
                        }
                    }

                    // New section
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 42
                        color: "transparent"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 10
                            MaterialIconSymbol {
                                content: "add_circle"
                                iconSize: 16
                                customColor: Colors.primary
                            }
                            CustomText {
                                Layout.fillWidth: true
                                content: "New section…"
                                size: 13
                            }
                        }

                        RippleEffect {
                            anchors.fill: parent
                            onClicked: {
                                appLauncher.openSectionDialog("create", "", ctxMenu.targetApp);
                                ctxMenu.targetApp = null;
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 1
                        color: Colors.surfaceContainerHighest
                        visible: ctxMenu.targetApp ? appLauncher.sectionsOfApp(ctxMenu.targetApp).length > 0 : false
                    }

                    // Remove from custom sections
                    Repeater {
                        model: ctxMenu.targetApp ? appLauncher.sectionsOfApp(ctxMenu.targetApp) : []

                        delegate: Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 42
                            color: "transparent"

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 10
                                MaterialIconSymbol {
                                    content: "remove"
                                    iconSize: 16
                                    customColor: Colors.outline
                                }
                                CustomText {
                                    Layout.fillWidth: true
                                    content: "Remove from " + modelData
                                    size: 13
                                }
                            }

                            RippleEffect {
                                anchors.fill: parent
                                onClicked: {
                                    appLauncher.removeAppFromSection(ctxMenu.targetApp, modelData);
                                    ctxMenu.targetApp = null;
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
