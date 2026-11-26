// IconUtil.qml
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.settings

Item {
    id: root

    // --- Recolored icon indexes (kindle / gowall) ---

    property var greyIndex: ({})

    FileView {
        path: KindleMode.recolorIcons && KindleMode.iconAssets !== "" ? KindleMode.iconAssets + "/icon-index.json" : ""
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                greyIndex = JSON.parse(text())
            } catch (e) {
                greyIndex = ({})
            }
        }
    }

    property var colourIndex: ({})

    // Current icon theme, following the same config priority as
    // cli/nebula/gowall_icons.py: qt6ct, qt5ct, gtk-3.0, gtk-4.0.
    // Every file is watched, so theme switches apply without a restart.
    property string qt6Theme: ""
    property string qt5Theme: ""
    property string gtk3Theme: ""
    property string gtk4Theme: ""
    readonly property string iconTheme: qt6Theme || qt5Theme || gtk3Theme || gtk4Theme

    // Drop the recolored index when the theme stops being a gowall kindle
    // theme, so stale mappings cannot override the new theme's icons.
    onIconThemeChanged: {
        if (!(iconTheme.startsWith("gowall-") && iconTheme.endsWith("-kindle")))
            colourIndex = ({})
    }

    function parseThemeKey(content, key) {
        const m = content.match(new RegExp("^" + key + "=(.*)$", "m"))
        return m ? m[1].trim().replace(/^["']|["']$/g, "") : ""
    }

    FileView {
        path: Quickshell.env("HOME") + "/.config/qt6ct/qt6ct.conf"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.qt6Theme = root.parseThemeKey(text(), "icon_theme")
    }

    FileView {
        path: Quickshell.env("HOME") + "/.config/qt5ct/qt5ct.conf"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.qt5Theme = root.parseThemeKey(text(), "icon_theme")
    }

    FileView {
        path: Quickshell.env("HOME") + "/.config/gtk-3.0/settings.ini"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.gtk3Theme = root.parseThemeKey(text(), "gtk-icon-theme-name")
    }

    FileView {
        path: Quickshell.env("HOME") + "/.config/gtk-4.0/settings.ini"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.gtk4Theme = root.parseThemeKey(text(), "gtk-icon-theme-name")
    }

    FileView {
        path: root.iconTheme.startsWith("gowall-") && root.iconTheme.endsWith("-kindle")
            ? Quickshell.env("HOME") + "/.cache/quickshell/gowall/assets-kindle/source-index.json" : ""
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                colourIndex = JSON.parse(text())
            } catch (e) {
                colourIndex = ({})
            }
        }
    }

    // --- Notification helpers ---

    function notificationSymbol(appIcon, appName) {
        // Match on the icon's basename, not the full path: directories and
        // nix store hashes must not trigger substring matches.
        const ic = (appIcon || "").toLowerCase().split("/").pop().replace(/\.(svg|png|xpm|ico)$/, "");
        const ap = (appName || "").toLowerCase();

        // Battery
        if (ic.includes("battery") || ap.includes("battery") || ic.includes("charging") || ap.includes("charging")) {
            if (ic.includes("charging") || ap.includes("charging") || ic.includes("bolt") || ic.includes("adapter"))
                return "battery_android_bolt";
            if (ic.includes("alert") || ic.includes("warn") || ic.includes("critical") || ic.includes("low"))
                return "battery_alert";
            return "battery_android_full";
        }

        // Media & Hardware
        if (ic.includes("camera-photo") || ap.includes("screenshot") || ic.includes("screenshot"))
            return "photo_camera";
        if (ic.includes("camera-video") || ap.includes("record") || ic.includes("record"))
            return "screen_record";
        if (ic.includes("dialog-error") || ic.includes("error"))
            return "error_outline";
        if (ic.includes("bluetooth"))
            return "bluetooth";
        if (ic.includes("network") || ic.includes("wifi"))
            return "wifi";
        if (ic.includes("volume") || ic.includes("audio") || ic.includes("sound"))
            return "volume_up";
        if (ic.includes("brightness") || ap.includes("brightness"))
            return "brightness_6";

        return "";
    }

    // --- Icon resolution ---

    function themeIcon(name, fallback) {
        if (!name)
            return ""
        if (name.startsWith("file://"))
            return name
        if (name.startsWith("/"))
            return "file://" + name
        const file = KindleMode.recolorIcons ? greyIndex[name] : colourIndex[name]
        if (file)
            return "file://" + file
        // iconPath(name, true) returns "" when the theme has no such icon, so
        // callers fall back to a symbol instead of quickshell's black/purple
        // "missing icon" placeholder pixmap (which loads as Image.Ready).
        const checked = Quickshell.iconPath(name, true)
        if (checked !== "")
            return checked
        if (fallback === undefined || fallback === "" || fallback === true)
            return ""
        return Quickshell.iconPath(fallback, true)
    }

    // Notification icon resolution per the freedesktop spec: app_icon first;
    // when it is empty (notify-send puts file paths into the image-path hint
    // instead), use the image hint; last resort is the app name resolved
    // through its desktop entry. Returns "" when nothing resolves so callers
    // show a symbol.
    function notificationIcon(appIcon, image, appName) {
        const fromApp = appIcon ? getDesktopIconPath(appIcon, "") : ""
        if (fromApp !== "")
            return fromApp
        const img = imageSource(image ?? "")
        if (img !== "") {
            if (img.startsWith("image://icon/"))
                return getDesktopIconPath(img.slice(13).split("?")[0], "")
            return img
        }
        if (!appName)
            return ""
        const entry = DesktopEntries.heuristicLookup(appName)
        return getDesktopIconPath(entry?.icon || appName, "")
    }

    function imageSource(src) {
        const s = src ?? ""
        return s.startsWith("image://icon//") ? "file://" + s.slice(13) : s
    }

    // Resolve a window class / app id through its desktop entry, falling back
    // to the class itself as an icon name.
    function getIconPath(windowClass, fallback = "application-x-executable") {
        const cls = windowClass ?? ""
        if (cls === "")
            return ""
        const entry = DesktopEntries.heuristicLookup(cls)
        return themeIcon(entry?.icon || cls, fallback)
    }

    // Resolve a freedesktop icon name or a file path.
    function getDesktopIconPath(iconName, fallback = "application-x-executable") {
        return themeIcon(iconName ?? "", fallback)
    }

    // --- Shell assets ---

    function getSystemIcon(iconName) {
        if (KindleMode.recolorIcons && KindleMode.iconAssets !== "")
            return "file://" + KindleMode.iconAssets + "/" + iconName + ".svg"
        return Qt.resolvedUrl("../../assets/" + iconName + ".svg")
    }

    function getSystemIconPng(iconName){
        return Qt.resolvedUrl("../../assets/" + iconName + ".png")
    }

    function getImage(name){
        return Qt.resolvedUrl("../../assets/" + name)
    }
}
