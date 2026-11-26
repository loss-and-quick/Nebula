pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.modules.utils
import qs.modules.services
import qs.modules.settings
import qs.modules.components.custom

Item {
    id: root

    required property Item launcher
    readonly property Item appView: nav

    property string filter: "all"
    property int chipIndex: -1
    property bool heroOpen: false

    readonly property string q: root.launcher.query.trim().toLowerCase()
    readonly property bool searching: root.q.length > 0

    readonly property var filters: [
        {
            value: "all",
            label: "All"
        },
        {
            value: "apps",
            label: "Apps"
        },
        {
            value: "actions",
            label: "Actions"
        },
        {
            value: "windows",
            label: "Windows"
        },
        {
            value: "shell",
            label: "Shell"
        }
    ]

    readonly property var shellActions: [
        {
            id: "note",
            title: "New note",
            sub: "Pins a note to the screen edge",
            symbol: "sticky_note_2",
            words: "sticky memo add",
            feature: "notes",
            run: () => ServiceNotes.requestOpen(ServiceNotes.add())
        },
        {
            id: "screenshot",
            title: "Take a screenshot",
            sub: "Select an area to capture",
            symbol: "screenshot_region",
            words: "capture snip screen",
            run: () => {
                GlobalStates.areaSelectMode = "screenshot";
                GlobalStates.areaSelectOpen = true;
            }
        },
        {
            id: "clipboard",
            title: "Clipboard history",
            sub: "Paste something you copied",
            symbol: "content_paste",
            words: "copy paste cliphist",
            feature: "clipboard",
            run: () => {
                GlobalStates.clipboardOpen = true;
            }
        },
        {
            id: "wallpaper",
            title: "Change wallpaper",
            sub: "Opens the wallpaper picker",
            symbol: "wallpaper",
            words: "background image theme",
            run: () => {
                GlobalStates.wallpaperOpen = true;
            }
        },
        {
            id: "dnd",
            title: ServiceNotification.dnd ? "Turn off Do not disturb" : "Turn on Do not disturb",
            sub: "Silences notification popups",
            symbol: "do_not_disturb_on",
            words: "dnd quiet notifications mute",
            run: () => ServiceNotification.setDnd(!ServiceNotification.dnd, 0)
        },
        {
            id: "reading",
            title: "Reading filter",
            sub: "Warm, sepia or e-ink screen",
            symbol: "chrome_reader_mode",
            words: "eye night warm sepia eink",
            feature: "reading",
            run: () => ServiceReading.toggle()
        },
        {
            id: "caffeine",
            title: "Keep awake",
            sub: "Stops the screen from sleeping",
            symbol: "coffee",
            words: "caffeine idle inhibit",
            run: () => ServiceIdleInhibit.toggle()
        },
        {
            id: "settings",
            title: "Open settings",
            sub: "Shell settings",
            symbol: "settings",
            words: "preferences config",
            run: () => {
                GlobalStates.settingsOpen = true;
            }
        },
        {
            id: "power",
            title: "Power options",
            sub: "Shut down, restart or log out",
            symbol: "power_settings_new",
            words: "shutdown reboot logout suspend",
            run: () => ServiceSession.openShutdown()
        },
        {
            id: "lock",
            title: "Lock screen",
            sub: "Locks this session",
            symbol: "lock",
            words: "lock away",
            run: () => ServiceSession.lock()
        }
    ]

    readonly property var recentApps: {
        ServiceApps.usage;
        const r = ServiceApps.recent(5);
        return r.length > 0 ? r : root.launcher.mostUsed(5);
    }

    function matches(text) {
        const t = (text ?? "").toLowerCase();
        return root.q.split(/\s+/).every(w => t.indexOf(w) >= 0);
    }

    function rank(title) {
        const t = (title ?? "").toLowerCase();
        if (t.startsWith(root.q))
            return 0;
        if (t.split(/\s+/).some(w => w.startsWith(root.q)))
            return 1;
        return 2;
    }

    function opened(app) {
        const n = root.launcher.usageCount(app);
        return n === 1 ? "Opened once" : n > 1 ? "Opened " + n + " times" : "";
    }

    function appItem(a) {
        return {
            kind: "app",
            title: a.name,
            sub: root.opened(a) || a.genericName || a.comment || "",
            label: "App",
            app: a,
            iconPath: root.launcher.iconFor(a),
            rank: root.searching ? root.rank(a.name) : 0
        };
    }

    function actionsOf(a) {
        const out = [];
        const acts = a?.actions ?? [];
        for (let i = 0; i < acts.length; i++)
            if (acts[i] && acts[i].name)
                out.push(acts[i]);
        return out;
    }

    function actionItems(cap) {
        const out = [];
        for (const a of ServiceApps.byUsage(ServiceApps.list)) {
            for (const act of root.actionsOf(a)) {
                if (root.searching && !root.matches(act.name + " " + a.name))
                    continue;
                out.push({
                    kind: "action",
                    title: act.name,
                    sub: a.name,
                    label: "App action",
                    app: a,
                    action: act,
                    iconPath: IconUtil.getDesktopIconPath(act.icon || a.icon || ""),
                    rank: root.searching ? Math.min(root.rank(act.name), root.rank(a.name) + 1) : 0
                });
                if (out.length >= cap)
                    return out;
            }
        }
        return out;
    }

    function windowItems() {
        const out = [];
        for (const t of Array.from(ToplevelManager.toplevels.values)) {
            if (!t || (t.appId ?? "").length === 0)
                continue;
            const entry = DesktopEntries.heuristicLookup(t.appId);
            const title = (t.title ?? "").length > 0 ? t.title : t.appId;
            if (root.searching && !root.matches(title + " " + t.appId + " " + (entry?.name ?? "")))
                continue;
            out.push({
                kind: "window",
                title: title,
                sub: (entry?.name ?? t.appId) + ", open window",
                label: "Window",
                win: t,
                iconPath: IconUtil.getDesktopIconPath(entry?.icon ?? t.appId),
                rank: root.searching ? Math.min(root.rank(title), root.rank(entry?.name ?? t.appId)) : 0
            });
        }
        return out;
    }

    function resolveLauncherItem(rawItem) {
        if (!rawItem)
            return null;

        if (typeof rawItem === "object") {
            const title = rawItem.title || rawItem.name || "Action";
            const sub = rawItem.sub || rawItem.subtitle || "";
            const sym = rawItem.symbol || rawItem.icon || "terminal";
            const cmd = rawItem.command || rawItem.exec;
            if (!cmd)
                return null;
            return {
                kind: "shell",
                id: rawItem.id || title,
                title: title,
                sub: sub,
                label: "Custom",
                symbol: sym,
                run: () => ServiceApps.spawn(Array.isArray(cmd) ? cmd : [cmd], ""),
                rank: root.searching ? root.rank(title) : 0
            };
        }

        const id = String(rawItem).trim();

        const sAction = root.shellActions.find(s => s.id === id);
        if (sAction) {
            if (sAction.feature && !Features.on(sAction.feature))
                return null;
            return {
                kind: "shell",
                id: sAction.id,
                title: sAction.title,
                sub: sAction.sub,
                label: "Shell",
                symbol: sAction.symbol,
                run: sAction.run,
                rank: root.searching ? root.rank(sAction.title) : 0
            };
        }

        const app = ServiceApps.resolveApp(id);
        if (app)
            return root.appItem(app);

        return null;
    }

    readonly property var customSectionActions: {
        const out = [];
        const cfgSections = SettingsConfig.launcher?.sections ?? [];
        for (const secDef of cfgSections) {
            if (typeof secDef === "object" && secDef !== null) {
                const rawItems = secDef.items || secDef.apps || [];
                for (const raw of rawItems) {
                    if (typeof raw === "object" && raw !== null) {
                        const it = root.resolveLauncherItem(raw);
                        if (it)
                            out.push(it);
                    }
                }
            }
        }
        return out;
    }

    function shellItems() {
        const out = [];
        for (const s of root.shellActions) {
            if (s.feature && !Features.on(s.feature))
                continue;
            if (root.searching && !root.matches(s.title + " " + s.words))
                continue;
            out.push({
                kind: "shell",
                id: s.id,
                title: s.title,
                sub: s.sub,
                label: "Shell",
                symbol: s.symbol,
                run: s.run,
                rank: root.searching ? root.rank(s.title) : 0
            });
        }
        return out;
    }

    function group(items, header, sectionMeta) {
        const meta = sectionMeta ?? { name: header, index: -1, isCustom: false };
        return items.map((it, i) => Object.assign({}, it, {
                header: i === 0 ? header : "",
                first: i === 0,
                last: i === items.length - 1,
                sectionName: i === 0 ? meta.name : "",
                sectionIndex: i === 0 ? meta.index : -1,
                isCustomSection: i === 0 ? meta.isCustom : false
            }));
    }

    readonly property var rows: {
        ServiceApps.usage;
        ToplevelManager.toplevels.values;
        const f = root.filter;
        const apps = root.launcher.filteredApps;

        if (f === "apps")
            return root.group(Array.prototype.map.call(apps, a => root.appItem(a)), "Apps");
        if (f === "actions")
            return root.group(root.actionItems(200), "App actions");
        if (f === "windows")
            return root.group(root.windowItems(), "Open windows");
        if (f === "shell")
            return root.group(root.shellItems(), "Shell");

        if (!root.searching) {
            const cfgSections = SettingsConfig.launcher?.sections ?? ["pinned", "recent", "shell"];
            let outRows = [];

            for (let i = 0; i < cfgSections.length; i++) {
                const secDef = cfgSections[i];
                if (typeof secDef === "string") {
                    const secName = secDef.toLowerCase();
                    if (secName === "pinned" || secName === "@pinned") {
                        if (ServiceApps.pinnedApps.length > 0)
                            outRows = outRows.concat(root.group(ServiceApps.pinnedApps.map(a => root.appItem(a)), "Pinned", { name: "Pinned", index: i, isCustom: false }));
                    } else if (secName === "recent" || secName === "@recent") {
                        const unpinnedRecent = root.recentApps.filter(a => !ServiceApps.isPinned(a));
                        if (unpinnedRecent.length > 0)
                            outRows = outRows.concat(root.group(unpinnedRecent.map(a => root.appItem(a)), "Recent", { name: "Recent", index: i, isCustom: false }));
                    } else if (secName === "shell" || secName === "@shell") {
                        const items = root.shellItems();
                        if (items.length > 0)
                            outRows = outRows.concat(root.group(items.slice(0, 5), "Shell", { name: "Shell", index: i, isCustom: false }));
                    }
                } else if (typeof secDef === "object" && secDef !== null) {
                    const secTitle = secDef.name || secDef.title || "Section";
                    const rawItems = secDef.items || secDef.apps || [];
                    const items = [];
                    for (const raw of rawItems) {
                        if (raw === "pinned" || raw === "@pinned") {
                            for (const a of ServiceApps.pinnedApps)
                                items.push(root.appItem(a));
                        } else if (raw === "recent" || raw === "@recent") {
                            for (const a of root.recentApps)
                                if (!ServiceApps.isPinned(a))
                                    items.push(root.appItem(a));
                        } else if (raw === "shell" || raw === "@shell") {
                            for (const s of root.shellItems())
                                items.push(s);
                        } else {
                            const it = root.resolveLauncherItem(raw);
                            if (it)
                                items.push(it);
                        }
                    }
                    if (items.length > 0)
                        outRows = outRows.concat(root.group(items, secTitle, { name: secTitle, index: i, isCustom: true }));
                }
            }
            return outRows;
        }

        const pool = Array.prototype.slice.call(apps, 0, 6).map(a => root.appItem(a)).concat(root.actionItems(6), root.windowItems(), root.shellItems(), root.customSectionActions);
        const order = {
            app: 0,
            action: 1,
            shell: 2,
            window: 3
        };
        const sorted = pool.map((it, i) => ({
                    it,
                    i
                })).sort((x, y) => (x.it.rank - y.it.rank) || (order[x.it.kind] - order[y.it.kind]) || (x.i - y.i)).map(x => x.it);
        const web = {
            kind: "web",
            title: "Search the web for “" + root.launcher.query.trim() + "”",
            sub: "Opens in your browser",
            label: "Web",
            symbol: "travel_explore"
        };
        if (sorted.length === 0)
            return root.group([web], "");
        const top = Object.assign({}, sorted[0], {
            top: true,
            header: "",
            first: true,
            last: true
        });
        return [top].concat(root.group(sorted.slice(1).concat([web]), "More matches"));
    }

    readonly property var topChips: {
        const t = root.rows.length > 0 && root.rows[0].top ? root.rows[0] : null;
        if (!t || !t.app)
            return [];
        return root.actionsOf(t.app).filter(a => !t.action || a.name !== t.action.name).slice(0, 3);
    }

    function runAction(app, act) {
        const l = root.launcher;
        ServiceApps.spawn(act.command, app?.workingDirectory ?? "");
        l.closed();
    }

    function activate(it) {
        if (!it)
            return;
        const l = root.launcher;
        switch (it.kind) {
        case "app":
            l.launch(it.app);
            return;
        case "action":
            root.runAction(it.app, it.action);
            return;
        case "window":
            {
                const w = it.win;
                l.closed();
                if (w)
                    w.activate();
                return;
            }
        case "shell":
            {
                const fn = it.run;
                l.closed();
                fn();
                return;
            }
        case "web":
            {
                const url = "https://duckduckgo.com/?q=" + encodeURIComponent(l.query.trim());
                l.closed();
                ServiceApps.spawn(["xdg-open", url], "");
                return;
            }
        }
    }

    function reset() {
        root.heroOpen = false;
        root.filter = "all";
        root.chipIndex = -1;
        sectionMenu.targetSection = null;
        nav.activeIndex = 0;
        flick.contentY = 0;
    }

    function handleEscape() {
        if (sectionMenu.targetSection !== null) {
            sectionMenu.targetSection = null;
            return true;
        }
        if (root.launcher.sectionDialogOpen) {
            root.launcher.closeSectionDialog();
            return true;
        }
        if (root.heroOpen) {
            root.heroOpen = false;
            return true;
        }
        if (root.filter !== "all") {
            root.filter = "all";
            return true;
        }
        return false;
    }

    function showSectionMenu(sectionName, sectionIndex, item, x, y) {
        const p = item.mapToItem(root, x, y);
        sectionMenu.targetSection = sectionName;
        sectionMenu.targetSectionIndex = sectionIndex;
        sectionMenu.x = Math.max(4, Math.min(p.x, root.width - sectionMenu.width - 4));
        sectionMenu.y = p.y;
    }

    function cycleFilter(step) {
        const i = root.filters.findIndex(x => x.value === root.filter);
        const n = root.filters.length;
        root.filter = root.filters[(i + step + n) % n].value;
    }

    onRowsChanged: {
        root.heroOpen = false;
        sectionMenu.targetSection = null;
        nav.activeIndex = 0;
        root.chipIndex = -1;
        flick.contentY = 0;
    }

    Item {
        id: nav
        property int activeIndex: 0
        readonly property int navCount: root.rows.length
        readonly property int count: nav.navCount
        readonly property int columns: 1

        onActiveIndexChanged: {
            root.chipIndex = -1;
            nav.reveal(nav.activeIndex);
        }

        function activateIndex(i) {
            const it = root.rows[i];
            if (it && it.top && root.chipIndex >= 0 && root.chipIndex < root.topChips.length) {
                root.runAction(it.app, root.topChips[root.chipIndex]);
                return;
            }
            root.activate(it);
        }

        function reveal(i) {
            const item = rowRepeater.itemAt(i);
            if (!item)
                return;
            const y = item.y;
            const h = item.height;
            if (y < flick.contentY)
                flick.contentY = y;
            else if (y + h > flick.contentY + flick.height)
                flick.contentY = y + h - flick.height;
        }

        function navigate(key) {
            if (key === Qt.Key_Tab || key === Qt.Key_Backtab) {
                if (root.launcher.isApps)
                    root.cycleFilter(key === Qt.Key_Tab ? 1 : -1);
                return true;
            }
            const onTop = nav.activeIndex === 0 && root.rows.length > 0 && root.rows[0].top;
            if (onTop && key === Qt.Key_Right && root.topChips.length > 0) {
                root.chipIndex = Math.min(root.topChips.length - 1, root.chipIndex + 1);
                return true;
            }
            if (onTop && key === Qt.Key_Left && root.chipIndex >= 0) {
                root.chipIndex = root.chipIndex - 1;
                return true;
            }
            return false;
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        LauncherSearch {
            launcher: root.launcher
            Layout.fillWidth: true
            Layout.preferredHeight: 58
            radius: 29
            fontSize: 16
            color: Colors.surfaceContainerHighest
            placeholder: root.width >= 420 ? "Search apps, actions and windows" : "Search"
        }

        M3ButtonGroup {
            visible: root.launcher.isApps
            Layout.preferredHeight: 36
            height: 36
            textSize: 13
            inactiveColor: Colors.surfaceContainerHigh
            model: root.filters
            activeCheck: value => root.filter === value
            onSegmentClicked: value => {
                root.filter = value;
                root.launcher.focusSearch();
            }
        }

        LauncherModeArea {
            launcher: root.launcher
            visible: !root.launcher.isApps
            Layout.fillWidth: true
            Layout.fillHeight: true
        }

        Item {
            visible: root.launcher.isApps
            Layout.fillWidth: true
            Layout.fillHeight: true

            Flickable {
                id: flick
                anchors.fill: parent
                contentWidth: width
                contentHeight: list.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                clip: true
                ScrollBar.vertical: CustomScrollBar {
                    id: scrollBar
                }

                Column {
                    id: list
                    width: flick.width - (scrollBar.size < 1.0 ? 14 : 0)
                    spacing: 2

                    Rectangle {
                        id: addSectionBtn
                        visible: !root.searching
                        Layout.preferredHeight: 34
                        Layout.preferredWidth: addSectionLabel.implicitWidth + 56
                        radius: 17
                        color: Colors.surfaceContainerHigh
                        Behavior on color {
                            EffectsColorAnim {}
                        }

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 8
                            MaterialIconSymbol {
                                Layout.alignment: Qt.AlignVCenter
                                content: "add"
                                iconSize: 16
                                customColor: Colors.primary
                            }
                            CustomText {
                                id: addSectionLabel
                                Layout.alignment: Qt.AlignVCenter
                                content: "Add Section"
                                size: 12
                                weight: 500
                                customColor: Colors.outline
                            }
                        }

                        RippleEffect {
                            anchors.fill: parent
                            radius: parent.radius
                            hoverColor: Qt.alpha(Colors.primary, 0.08)
                            rippleColor: Qt.alpha(Colors.primary, 0.18)
                            onClicked: root.launcher.openSectionDialog("create", "", null)
                        }
                    }

                    Repeater {
                        id: rowRepeater
                        model: root.rows

                        delegate: Column {
                            id: entry
                            required property var modelData
                            required property int index
                            readonly property bool active: nav.activeIndex === entry.index
                            width: list.width
                            spacing: 0
                            topPadding: entry.modelData.header !== "" && entry.index > 0 ? 10 : 0

                            Rectangle {
                                id: sectionHeader
                                visible: entry.modelData.header !== ""
                                width: parent.width
                                implicitHeight: 26
                                radius: 8
                                color: entry.modelData.isCustomSection && sectionHeaderHover.hovered ? Qt.alpha(Colors.primary, 0.08) : "transparent"
                                Behavior on color {
                                    EffectsColorAnim {}
                                }

                                CustomText {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 6
                                    anchors.right: moreIcon.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    content: entry.modelData.header
                                    size: 12
                                    weight: 600
                                    customColor: Colors.primary
                                }

                                MaterialIconSymbol {
                                    id: moreIcon
                                    anchors.right: parent.right
                                    anchors.rightMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: entry.modelData.isCustomSection && sectionHeaderHover.containsMouse
                                    content: "more_horiz"
                                    iconSize: 16
                                    customColor: Colors.outline
                                }

                                MouseArea {
                                    id: sectionHeaderHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    cursorShape: entry.modelData.isCustomSection ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    onClicked: mouse => {
                                        if (entry.modelData.isCustomSection) {
                                            root.showSectionMenu(entry.modelData.sectionName, entry.modelData.sectionIndex, sectionHeader, mouse.x, mouse.y);
                                        } else if (mouse.button === Qt.RightButton) {
                                            root.launcher.openSectionDialog("create", "", null);
                                        }
                                    }
                                }
                            }

                            Loader {
                                width: parent.width
                                active: entry.modelData.top === true
                                visible: active
                                sourceComponent: Rectangle {
                                    id: hero
                                    height: heroCol.implicitHeight + 28
                                    radius: 24
                                    color: Colors.primaryContainer
                                    border.width: entry.active && root.chipIndex < 0 ? 2 : 0
                                    border.color: Colors.primary

                                    RippleEffect {
                                        anchors.fill: parent
                                        radius: 24
                                        hoverColor: Qt.alpha(Colors.primaryContainerText, 0.06)
                                        rippleColor: Qt.alpha(Colors.primaryContainerText, 0.16)
                                        onClicked: root.activate(entry.modelData)
                                        onRightClicked: if (entry.modelData.app) {
                                            root.launcher.openMenu(hero, 24, 40, entry.modelData.app);
                                        }
                                    }

                                    ColumnLayout {
                                        id: heroCol
                                        x: 16
                                        y: 14
                                        width: parent.width - 30
                                        spacing: 12

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 14

                                            Image {
                                                Layout.preferredWidth: 48
                                                Layout.preferredHeight: 48
                                                visible: (entry.modelData.iconPath ?? "") !== ""
                                                source: entry.modelData.iconPath ?? ""
                                                sourceSize.width: 48
                                                sourceSize.height: 48
                                                fillMode: Image.PreserveAspectFit
                                            }

                                            Rectangle {
                                                visible: (entry.modelData.iconPath ?? "") === ""
                                                Layout.preferredWidth: 48
                                                Layout.preferredHeight: 48
                                                radius: 16
                                                color: Colors.tertiaryContainer
                                                MaterialIconSymbol {
                                                    anchors.centerIn: parent
                                                    content: entry.modelData.symbol ?? "bolt"
                                                    iconSize: 26
                                                    fill: 1
                                                    customColor: Colors.tertiaryContainerText
                                                }
                                            }

                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 2
                                                CustomText {
                                                    Layout.fillWidth: true
                                                    content: entry.modelData.title
                                                    size: 17
                                                    weight: 600
                                                    elide: Text.ElideRight
                                                    customColor: Colors.primaryContainerText
                                                }
                                                CustomText {
                                                    Layout.fillWidth: true
                                                    visible: content !== ""
                                                    content: entry.modelData.kind === "action" ? entry.modelData.sub + (root.opened(entry.modelData.app) !== "" ? ", " + root.opened(entry.modelData.app).toLowerCase() : "") : entry.modelData.sub
                                                    size: 13
                                                    weight: 400
                                                    elide: Text.ElideRight
                                                    customColor: Qt.alpha(Colors.primaryContainerText, 0.85)
                                                }
                                            }

                                            Row {
                                                spacing: 2

                                                Rectangle {
                                                    id: openBtn
                                                    width: openRow.implicitWidth + 30
                                                    height: 44
                                                    topLeftRadius: 22
                                                    bottomLeftRadius: 22
                                                    readonly property real inner: openRipple.pressed ? 4 : 6
                                                    topRightRadius: menuBtn.visible ? openBtn.inner : 22
                                                    bottomRightRadius: menuBtn.visible ? openBtn.inner : 22
                                                    color: Colors.primary
                                                    Behavior on topRightRadius {
                                                        SpatialAnim {
                                                            speed: "fast"
                                                        }
                                                    }
                                                    Behavior on bottomRightRadius {
                                                        SpatialAnim {
                                                            speed: "fast"
                                                        }
                                                    }

                                                    Row {
                                                        id: openRow
                                                        anchors.centerIn: parent
                                                        spacing: 6
                                                        MaterialIconSymbol {
                                                            anchors.verticalCenter: parent.verticalCenter
                                                            content: "keyboard_return"
                                                            iconSize: 18
                                                            customColor: Colors.primaryText
                                                        }
                                                        CustomText {
                                                            anchors.verticalCenter: parent.verticalCenter
                                                            content: "Open"
                                                            size: 14
                                                            weight: 600
                                                            customColor: Colors.primaryText
                                                        }
                                                    }

                                                    RippleEffect {
                                                        id: openRipple
                                                        anchors.fill: parent
                                                        topLeftRadius: 22
                                                        bottomLeftRadius: 22
                                                        topRightRadius: parent.topRightRadius
                                                        bottomRightRadius: parent.bottomRightRadius
                                                        hoverColor: Qt.alpha(Colors.primaryText, 0.08)
                                                        rippleColor: Qt.alpha(Colors.primaryText, 0.18)
                                                        onClicked: root.activate(entry.modelData)
                                                    }
                                                }

                                                Rectangle {
                                                    id: menuBtn
                                                    readonly property real inner: root.heroOpen ? 22 : menuRipple.pressed ? 4 : 6
                                                    visible: !!entry.modelData.app
                                                    width: 44
                                                    height: 44
                                                    topLeftRadius: menuBtn.inner
                                                    bottomLeftRadius: menuBtn.inner
                                                    topRightRadius: 22
                                                    bottomRightRadius: 22
                                                    color: root.heroOpen ? Colors.primaryContainerText : Colors.primary
                                                    Behavior on topLeftRadius {
                                                        SpatialAnim {
                                                            speed: "fast"
                                                        }
                                                    }
                                                    Behavior on bottomLeftRadius {
                                                        SpatialAnim {
                                                            speed: "fast"
                                                        }
                                                    }
                                                    Behavior on color {
                                                        EffectsColorAnim {
                                                            speed: "fast"
                                                        }
                                                    }

                                                    MaterialIconSymbol {
                                                        anchors.centerIn: parent
                                                        content: "expand_more"
                                                        iconSize: 22
                                                        rotation: root.heroOpen ? 180 : 0
                                                        customColor: root.heroOpen ? Colors.primaryContainer : Colors.primaryText
                                                        Behavior on rotation {
                                                            SpatialAnim {}
                                                        }
                                                    }

                                                    RippleEffect {
                                                        id: menuRipple
                                                        anchors.fill: parent
                                                        topLeftRadius: menuBtn.topLeftRadius
                                                        bottomLeftRadius: menuBtn.bottomLeftRadius
                                                        topRightRadius: 22
                                                        bottomRightRadius: 22
                                                        hoverColor: Qt.alpha(Colors.primaryText, 0.08)
                                                        rippleColor: Qt.alpha(Colors.primaryText, 0.18)
                                                        onClicked: {
                                                            root.heroOpen = !root.heroOpen;
                                                            root.launcher.focusSearch();
                                                        }
                                                    }

                                                    CustomToolTip {
                                                        content: root.heroOpen ? "Hide details" : "Details"
                                                        visible: menuHover.hovered
                                                    }

                                                    HoverHandler {
                                                        id: menuHover
                                                    }
                                                }
                                            }
                                        }

                                        Flow {
                                            Layout.fillWidth: true
                                            Layout.leftMargin: 62
                                            visible: entry.modelData.top === true && root.topChips.length > 0
                                            spacing: 8

                                            Repeater {
                                                model: entry.modelData.top === true ? root.topChips : []

                                                delegate: Rectangle {
                                                    id: chip
                                                    required property var modelData
                                                    required property int index
                                                    readonly property bool on: entry.active && root.chipIndex === chip.index
                                                    width: chipRow.implicitWidth + 22
                                                    height: 32
                                                    radius: 10
                                                    color: chip.on ? Colors.primary : Qt.alpha(Colors.primaryContainerText, 0.14)
                                                    Behavior on color {
                                                        EffectsColorAnim {
                                                            speed: "fast"
                                                        }
                                                    }

                                                    Row {
                                                        id: chipRow
                                                        anchors.centerIn: parent
                                                        spacing: 6
                                                        MaterialIconSymbol {
                                                            anchors.verticalCenter: parent.verticalCenter
                                                            content: "open_in_new"
                                                            iconSize: 16
                                                            customColor: chip.on ? Colors.primaryText : Colors.primaryContainerText
                                                        }
                                                        CustomText {
                                                            anchors.verticalCenter: parent.verticalCenter
                                                            content: chip.modelData.name
                                                            size: 13
                                                            weight: 500
                                                            customColor: chip.on ? Colors.primaryText : Colors.primaryContainerText
                                                        }
                                                    }

                                                    RippleEffect {
                                                        anchors.fill: parent
                                                        radius: 10
                                                        hoverColor: Qt.alpha(Colors.primaryContainerText, 0.08)
                                                        rippleColor: Qt.alpha(Colors.primaryContainerText, 0.18)
                                                        onClicked: root.runAction(entry.modelData.app, chip.modelData)
                                                    }
                                                }
                                            }
                                        }

                                        Item {
                                            id: detailsBox
                                            readonly property var app: entry.modelData.app ?? null
                                            property real openH: root.heroOpen ? details.implicitHeight : 0
                                            Behavior on openH {
                                                SpatialAnim {}
                                            }
                                            visible: entry.modelData.top === true && detailsBox.app !== null && detailsBox.openH > 0.5
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: detailsBox.openH
                                            clip: true

                                            ColumnLayout {
                                                id: details
                                                width: parent.width
                                                spacing: 0
                                                opacity: root.heroOpen ? 1 : 0
                                                Behavior on opacity {
                                                    EffectsAnim {}
                                                }

                                                Rectangle {
                                                    Layout.fillWidth: true
                                                    Layout.topMargin: 2
                                                    Layout.bottomMargin: 6
                                                    implicitHeight: 1
                                                    color: Qt.alpha(Colors.primaryContainerText, 0.16)
                                                }

                                                Repeater {
                                                    model: detailsBox.app ? [
                                                        {
                                                            k: "Category",
                                                            v: root.launcher.categoryOf(detailsBox.app) || "Other"
                                                        },
                                                        {
                                                            k: "Last opened",
                                                            v: root.launcher.timeAgo(detailsBox.app) || "Never"
                                                        },
                                                        {
                                                            k: "Runs",
                                                            v: detailsBox.app.execString || ""
                                                        }
                                                    ].filter(d => d.v !== "") : []

                                                    delegate: RowLayout {
                                                        id: line
                                                        required property var modelData
                                                        Layout.fillWidth: true
                                                        Layout.preferredHeight: 32
                                                        spacing: 12

                                                        CustomText {
                                                            content: line.modelData.k
                                                            size: 12
                                                            weight: 500
                                                            customColor: Qt.alpha(Colors.primaryContainerText, 0.75)
                                                        }
                                                        CustomText {
                                                            Layout.fillWidth: true
                                                            horizontalAlignment: Text.AlignRight
                                                            content: line.modelData.v
                                                            size: 12
                                                            weight: 600
                                                            elide: Text.ElideMiddle
                                                            customColor: Colors.primaryContainerText
                                                        }
                                                    }
                                                }

                                                RowLayout {
                                                    Layout.fillWidth: true
                                                    Layout.topMargin: 8
                                                    spacing: 2

                                                    Rectangle {
                                                        readonly property bool pinned: detailsBox.app ? ServiceApps.isPinned(detailsBox.app) : false
                                                        Layout.fillWidth: true
                                                        Layout.preferredWidth: 1
                                                        Layout.preferredHeight: 40
                                                        topLeftRadius: 20
                                                        bottomLeftRadius: 20
                                                        topRightRadius: 6
                                                        bottomRightRadius: 6
                                                        color: Qt.alpha(Colors.primaryContainerText, 0.14)

                                                        RowLayout {
                                                            required property bool pinned
                                                            pinned: parent.pinned
                                                            anchors.centerIn: parent
                                                            spacing: 6
                                                            MaterialIconSymbol {
                                                                content: "push_pin"
                                                                iconSize: 18
                                                                fill: parent.pinned ? 1 : 0
                                                                customColor: Colors.primaryContainerText
                                                            }
                                                            CustomText {
                                                                content: parent.pinned ? "Unpin" : "Pin"
                                                                size: 13
                                                                weight: 600
                                                                customColor: Colors.primaryContainerText
                                                            }
                                                        }

                                                        RippleEffect {
                                                            anchors.fill: parent
                                                            topLeftRadius: 20
                                                            bottomLeftRadius: 20
                                                            topRightRadius: 6
                                                            bottomRightRadius: 6
                                                            hoverColor: Qt.alpha(Colors.primaryContainerText, 0.08)
                                                            rippleColor: Qt.alpha(Colors.primaryContainerText, 0.18)
                                                            onClicked: ServiceApps.togglePin(detailsBox.app)
                                                        }
                                                    }

                                                    Rectangle {
                                                        Layout.fillWidth: true
                                                        Layout.preferredWidth: 1
                                                        Layout.preferredHeight: 40
                                                        topLeftRadius: 6
                                                        bottomLeftRadius: 6
                                                        topRightRadius: 20
                                                        bottomRightRadius: 20
                                                        color: "transparent"
                                                        border.width: 1
                                                        border.color: Qt.alpha(Colors.primaryContainerText, 0.35)

                                                        RowLayout {
                                                            anchors.centerIn: parent
                                                            spacing: 6
                                                            MaterialIconSymbol {
                                                                content: "content_copy"
                                                                iconSize: 18
                                                                customColor: Colors.primaryContainerText
                                                            }
                                                            CustomText {
                                                                content: "Copy name"
                                                                size: 13
                                                                weight: 600
                                                                customColor: Colors.primaryContainerText
                                                            }
                                                        }

                                                        RippleEffect {
                                                            anchors.fill: parent
                                                            topLeftRadius: 6
                                                            bottomLeftRadius: 6
                                                            topRightRadius: 20
                                                            bottomRightRadius: 20
                                                            hoverColor: Qt.alpha(Colors.primaryContainerText, 0.08)
                                                            rippleColor: Qt.alpha(Colors.primaryContainerText, 0.18)
                                                            onClicked: Quickshell.clipboardText = detailsBox.app?.name ?? ""
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                id: row
                                visible: entry.modelData.top !== true
                                width: parent.width
                                height: visible ? 58 : 0
                                topLeftRadius: entry.modelData.first ? 18 : 6
                                topRightRadius: entry.modelData.first ? 18 : 6
                                bottomLeftRadius: entry.modelData.last ? 18 : 6
                                bottomRightRadius: entry.modelData.last ? 18 : 6
                                color: entry.active ? Colors.primaryContainer : Colors.surfaceContainerHigh
                                border.width: entry.active ? 1.5 : 0
                                border.color: Colors.primary
                                Behavior on color {
                                    EffectsColorAnim {
                                        speed: "fast"
                                    }
                                }

                                RippleEffect {
                                    anchors.fill: parent
                                    topLeftRadius: row.topLeftRadius
                                    topRightRadius: row.topRightRadius
                                    bottomLeftRadius: row.bottomLeftRadius
                                    bottomRightRadius: row.bottomRightRadius
                                    onClicked: root.activate(entry.modelData)
                                    onRightClicked: if (entry.modelData.kind === "app") {
                                        root.launcher.openMenu(row, 24, 40, entry.modelData.app);
                                    }
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 14
                                    spacing: 14

                                    Item {
                                        Layout.preferredWidth: 36
                                        Layout.preferredHeight: 36

                                        Image {
                                            anchors.fill: parent
                                            visible: (entry.modelData.iconPath ?? "") !== ""
                                            source: entry.modelData.iconPath ?? ""
                                            sourceSize.width: 36
                                            sourceSize.height: 36
                                            fillMode: Image.PreserveAspectFit
                                        }

                                        Rectangle {
                                            anchors.fill: parent
                                            visible: (entry.modelData.iconPath ?? "") === ""
                                            radius: entry.modelData.kind === "web" ? 18 : 12
                                            color: entry.modelData.kind === "web" ? Colors.surfaceContainerHighest : Colors.tertiaryContainer
                                            MaterialIconSymbol {
                                                anchors.centerIn: parent
                                                content: entry.modelData.symbol ?? "bolt"
                                                iconSize: 20
                                                fill: 1
                                                customColor: entry.modelData.kind === "web" ? Colors.primary : Colors.tertiaryContainerText
                                            }
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1
                                        CustomText {
                                            Layout.fillWidth: true
                                            content: entry.modelData.title
                                            size: 14
                                            weight: 500
                                            elide: Text.ElideRight
                                            customColor: entry.active ? Colors.primaryContainerText : Colors.surfaceText
                                        }
                                        CustomText {
                                            Layout.fillWidth: true
                                            visible: (entry.modelData.sub ?? "") !== ""
                                            content: entry.modelData.sub ?? ""
                                            size: 12
                                            weight: 400
                                            elide: Text.ElideRight
                                            customColor: entry.active ? Qt.alpha(Colors.primaryContainerText, 0.8) : Colors.surfaceVariantText
                                        }
                                    }

                                    CustomText {
                                        visible: root.width >= 400
                                        content: entry.modelData.label ?? ""
                                        size: 12
                                        weight: 400
                                        customColor: entry.active ? Colors.primaryContainerText : Colors.surfaceVariantText
                                    }
                                }
                            }
                        }
                    }
                }
            }

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 8
                visible: root.rows.length === 0

                MaterialIconSymbol {
                    Layout.alignment: Qt.AlignHCenter
                    content: root.filter === "windows" ? "select_window" : "search_off"
                    iconSize: 30
                    customColor: Colors.outline
                }
                CustomText {
                    Layout.alignment: Qt.AlignHCenter
                    content: root.filter === "windows" ? "No open windows" : "Nothing matches"
                    size: 13
                    customColor: Colors.outline
                }
            }
        }

        RowLayout {
            visible: root.height >= 420 && root.width >= 360
            Layout.fillWidth: true
            Layout.leftMargin: 6
            Layout.rightMargin: 6
            spacing: 16

            Row {
                spacing: 6
                LauncherKey {
                    label: "↑↓"
                }
                CustomText {
                    anchors.verticalCenter: parent.verticalCenter
                    content: "Move"
                    size: 12
                    customColor: Colors.surfaceVariantText
                }
            }
            Row {
                spacing: 6
                LauncherKey {
                    label: "Enter"
                }
                CustomText {
                    anchors.verticalCenter: parent.verticalCenter
                    content: "Open"
                    size: 12
                    customColor: Colors.surfaceVariantText
                }
            }
            Row {
                spacing: 6
                visible: root.topChips.length > 0
                LauncherKey {
                    label: "→"
                }
                CustomText {
                    anchors.verticalCenter: parent.verticalCenter
                    content: "App actions"
                    size: 12
                    customColor: Colors.surfaceVariantText
                }
            }
            Row {
                spacing: 6
                visible: root.width >= 480
                LauncherKey {
                    label: "Tab"
                }
                CustomText {
                    anchors.verticalCenter: parent.verticalCenter
                    content: "Filter"
                    size: 12
                    customColor: Colors.surfaceVariantText
                }
            }
            Item {
                Layout.fillWidth: true
            }
            Row {
                spacing: 6
                LauncherKey {
                    label: "Esc"
                }
                CustomText {
                    anchors.verticalCenter: parent.verticalCenter
                    content: root.filter !== "all" ? "All results" : root.launcher.searching ? "Clear" : "Close"
                    size: 12
                    customColor: Colors.surfaceVariantText
                }
            }
        }
    }

    // ── Section management menu ──────────────────────────────────────────────
    Rectangle {
        id: sectionMenu
        property var targetSection: null
        property int targetSectionIndex: -1

        visible: targetSection !== null
        z: 100
        width: 220
        height: smCol.implicitHeight + 16
        radius: 18
        color: Colors.surfaceContainer

        onHeightChanged: {
            if (y + height > root.height - 8)
                y = Math.max(4, root.height - height - 8);
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
            id: smCol
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                margins: 8
            }
            spacing: 6

            // Header
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

                        MaterialIconSymbol {
                            anchors.centerIn: parent
                            content: "folder"
                            iconSize: 20
                            customColor: Colors.primary
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        CustomText {
                            Layout.fillWidth: true
                            content: targetSection ?? ""
                            size: 13
                            weight: 700
                            elide: Text.ElideRight
                        }
                        CustomText {
                            Layout.fillWidth: true
                            content: "Section"
                            size: 10
                            customColor: Colors.outline
                            elide: Text.ElideRight
                        }
                    }
                }
            }

            // Actions
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: smActions.implicitHeight
                radius: 12
                color: Colors.surfaceContainerHigh
                clip: true

                ColumnLayout {
                    id: smActions
                    anchors {
                        left: parent.left
                        right: parent.right
                    }
                    spacing: 0

                    // Rename
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
                                content: "edit"
                                iconSize: 16
                                customColor: Colors.primary
                            }
                            CustomText {
                                Layout.fillWidth: true
                                content: "Rename"
                                size: 13
                            }
                        }

                        RippleEffect {
                            anchors.fill: parent
                            onClicked: {
                                root.launcher.openSectionDialog("rename", targetSection, null);
                                targetSection = null;
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 1
                        color: Colors.surfaceContainerHighest
                    }

                    // Move up
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 42
                        color: "transparent"
                        visible: targetSectionIndex > 0

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 10
                            MaterialIconSymbol {
                                content: "arrow_upward"
                                iconSize: 16
                                customColor: Colors.outline
                            }
                            CustomText {
                                Layout.fillWidth: true
                                content: "Move up"
                                size: 13
                            }
                        }

                        RippleEffect {
                            anchors.fill: parent
                            onClicked: {
                                root.launcher.moveSection(targetSection, -1);
                                targetSection = null;
                            }
                        }
                    }

                    // Move down
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 42
                        color: "transparent"
                        visible: targetSectionIndex < root.launcher.sectionCount - 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 10
                            MaterialIconSymbol {
                                content: "arrow_downward"
                                iconSize: 16
                                customColor: Colors.outline
                            }
                            CustomText {
                                Layout.fillWidth: true
                                content: "Move down"
                                size: 13
                            }
                        }

                        RippleEffect {
                            anchors.fill: parent
                            onClicked: {
                                root.launcher.moveSection(targetSection, 1);
                                targetSection = null;
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 1
                        color: Colors.surfaceContainerHighest
                    }

                    // Delete
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
                                content: "delete"
                                iconSize: 16
                                customColor: Colors.primary
                            }
                            CustomText {
                                Layout.fillWidth: true
                                content: "Delete"
                                size: 13
                            }
                        }

                        RippleEffect {
                            anchors.fill: parent
                            onClicked: {
                                root.launcher.removeSection(targetSection);
                                targetSection = null;
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Section menu click-away ──────────────────────────────────────────────
    MouseArea {
        anchors.fill: parent
        visible: sectionMenu.targetSection !== null
        z: 99
        hoverEnabled: true
        cursorShape: Qt.ArrowCursor
        onClicked: sectionMenu.targetSection = null
        onPressed: sectionMenu.targetSection = null
    }
}
