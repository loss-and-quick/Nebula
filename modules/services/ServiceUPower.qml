pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import Quickshell.Services.UPower
import qs.modules.utils

Singleton{
    id: root
    readonly property var profileMetadata: ({
        "power-saver": {
            id: 0,
            name: "Saver",
            icon: "energy_savings_leaf",
            description: "Lowest power draw and battery saver"
        },
        "balanced": {
            id: 1,
            name: "Balanced",
            icon: "balance",
            description: "Default balance between power and battery"
        },
        "performance": {
            id: 2,
            name: "Performance",
            icon: "rocket_launch",
            description: "Maximum performance and responsiveness"
        },
        "quiet": {
            id: 3,
            name: "Quiet",
            icon: "volume_mute",
            description: "Low noise, silent fan operation"
        }
    })

    function profileEntry(name, index) {
        const key = (name || "").toLowerCase();
        const meta = root.profileMetadata[key];
        if (meta) {
            return {
                id: meta.id,
                profileKey: key,
                name: meta.name,
                icon: meta.icon,
                description: meta.description
            };
        }
        const title = key.split(/[-_]/).map(w => w.charAt(0).toUpperCase() + w.slice(1)).join(" ");
        return {
            id: 10 + index,
            profileKey: key,
            name: title,
            icon: "speed",
            description: title + " mode"
        };
    }

    property var rawProfileList: ["power-saver", "balanced", "performance"]

    readonly property var availableProfiles: root.rawProfileList.map((p, i) => root.profileEntry(p, i))
    readonly property var currentProfileEntry: root.availableProfiles.find(p => p.profileKey === root.activeProfileKey || p.id === root.powerProfile) ?? root.profileEntry("balanced", 1)

    property string activeProfileKey: "balanced"
    property int powerProfile: 1
    property string powerProfileIcon: root.currentProfileEntry.icon
    readonly property bool hasPerformanceProfile: root.rawProfileList.includes("performance")

    property bool ppdAvailable: false

    readonly property var holds: {
        const raw = PowerProfiles.holds;
        if (!raw || !raw.length)
            return [];
        const out = [];
        for (let i = 0; i < raw.length; i++) {
            const h = raw[i];
            out.push({
                applicationId: h.applicationId ?? "",
                profile: h.profile,
                reason: h.reason ?? "",
                profileName: root.powerProfiles[h.profile]?.name ?? "Unknown"
            });
        }
        return out;
    }
    readonly property bool hasHolds: root.holds.length > 0

    readonly property int degradationReason: PowerProfiles.degradationReason
    readonly property bool isDegraded: root.degradationReason !== 0
    readonly property string degradationText: {
        switch (root.degradationReason) {
        case 1:
            return "Lap detected — performance reduced for skin safety";
        case 2:
            return "High temperature — performance throttled";
        default:
            return "";
        }
    }

    Process {
        id: ppdCheck
        command: ["sh", "-c", "act=$(busctl get-property org.freedesktop.UPower.PowerProfiles /org/freedesktop/UPower/PowerProfiles org.freedesktop.UPower.PowerProfiles ActiveProfile 2>/dev/null || busctl get-property net.hadess.PowerProfiles /net/hadess/PowerProfiles net.hadess.PowerProfiles ActiveProfile 2>/dev/null); profs=$(busctl get-property org.freedesktop.UPower.PowerProfiles /org/freedesktop/UPower/PowerProfiles org.freedesktop.UPower.PowerProfiles Profiles 2>/dev/null || busctl get-property net.hadess.PowerProfiles /net/hadess/PowerProfiles net.hadess.PowerProfiles Profiles 2>/dev/null); echo \"$act|$profs\""]
        running: true
        stdout: SplitParser {
            onRead: data => {
                const parts = data.trim().split("|");
                if (parts.length >= 2) {
                    const actStr = parts[0];
                    const profsStr = parts[1];
                    root.ppdAvailable = actStr.length > 0;

                    // Parse dynamic profiles list from D-Bus. QML's JS engine
                    // has no String.prototype.matchAll, so use an exec loop.
                    const profileRe = /"Profile"\s+s\s+"([^"]+)"/g;
                    const matches = [];
                    let pm;
                    while ((pm = profileRe.exec(profsStr)) !== null)
                        matches.push(pm[1]);
                    if (matches.length > 0)
                        root.rawProfileList = matches;

                    const activeMatch = actStr.match(/"([^"]+)"/);
                    if (activeMatch && activeMatch[1]) {
                        const key = activeMatch[1];
                        root.activeProfileKey = key;
                        const entry = root.profileMetadata[key];
                        if (entry)
                            root.powerProfile = entry.id;
                    }
                }
            }
        }
        onExited: exitCode => {
            if (exitCode !== 0)
                root.ppdAvailable = false;
        }
    }

    Process {
        id: setProfileProc
        onExited: {
            ppdCheck.running = true;
        }
    }

    Timer {
        interval: 10000
        repeat: true
        running: true
        onTriggered: ppdCheck.running = true
    }

    Connections {
        target: PowerProfiles
        ignoreUnknownSignals: true
        function onProfileChanged() {
            root.ppdAvailable = true;
            root.powerProfile = PowerProfiles.profile;
        }
        function onHasPerformanceProfileChanged() {
            root.ppdAvailable = true;
            if (PowerProfiles.hasPerformanceProfile)
                root.hasPerformanceProfile = true;
        }
        function onHoldsChanged() {
            root.ppdAvailable = true;
        }
    } 
    property real powerLevel: UPower.displayDevice.percentage
    property bool isCharging: UPowerDeviceState.Charging === UPower.displayDevice.state
    property real health: 0
    property bool _lowNotified: false
    property bool _ready: false



    Timer {
        interval: 4000
        running: true
        onTriggered: root._ready = true
    }

    onIsChargingChanged: {
        if (!root._ready || !UPower.displayDevice.isLaptopBattery)
            return
        if (isCharging) {
            _lowNotified = false
            //Quickshell.execDetached(["notify-send", "-i", "battery_charging_full", "Battery", "Charging — " + Math.round(powerLevel) + "%"])
            ServiceNotification.sendNotification(
                "Battery",
                "Charging — " + Math.round(powerLevel * 100) + "%",
                "Battery",
                "battery_android_bolt"
            )
        } else {
            //Quickshell.execDetached(["notify-send", "-i", "battery_full", "Battery", "Unplugged — " + Math.round(powerLevel) + "%"])
            ServiceNotification.sendNotification(
                "Battery",
                "Unplugged — " + Math.round(powerLevel * 100) + "%",
                "Battery",
                "battery_android_full"
            )
        }
    }



    Process {
        id: healthProcess
        command: ["sh", "-c", "for b in /sys/class/power_supply/BAT*; do for k in charge energy; do [ -r \"$b/${k}_full\" ] && [ -r \"$b/${k}_full_design\" ] && awk 'NR==1{full=$1} NR==2{design=$1} END{if (design > 0) printf \"%.1f\", full/design*100}' \"$b/${k}_full\" \"$b/${k}_full_design\" && exit 0; done; done"]
        running: true
        stdout: SplitParser {
            onRead: data => root.health = parseFloat(data) / 100
        }
    }
    property string timeToFull: root.formatBatteryDuration(UPower.displayDevice.timeToFull)
    property real changeRate: UPower.displayDevice.changeRate
    function setPowerProfile(value) {
        let key = "";
        if (typeof value === "string") {
            key = value;
        } else {
            const found = root.availableProfiles.find(p => p.id === value);
            key = found ? found.profileKey : (value === 0 ? "power-saver" : value === 2 ? "performance" : "balanced");
        }

        root.activeProfileKey = key;
        const entry = root.profileMetadata[key];
        if (entry)
            root.powerProfile = entry.id;

        try {
            if (entry)
                PowerProfiles.profile = entry.id;
        } catch (e) {}

        setProfileProc.command = ["sh", "-c",
            "busctl set-property org.freedesktop.UPower.PowerProfiles /org/freedesktop/UPower/PowerProfiles org.freedesktop.UPower.PowerProfiles ActiveProfile s " + key + " 2>/dev/null || " +
            "busctl set-property net.hadess.PowerProfiles /net/hadess/PowerProfiles net.hadess.PowerProfiles ActiveProfile s " + key + " 2>/dev/null"
        ];
        setProfileProc.running = true;
    }

    function formatBatteryDuration(seconds) {
        var h = Math.floor(seconds / 3600);
        var m = Math.floor((seconds % 3600) / 60);
        if (h > 0)
            return `${h}h, ${m}m`;
        return `${m}m`;
    }
}


