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
    property var powerProfiles:[
        {
            name: "Saver",
            icon: "energy_savings_leaf",
            description: "Lowest power draw and battery saver"
        },
        {
            name: "Balanced",
            icon: "balance",
            description: "Default balance between power and battery"
        },
        {
            name: "Performance",
            icon: "rocket_launch",
            description: "Maximum performance and responsiveness"
        }
    ]
    readonly property var availableProfiles: root.powerProfiles
        .map((p, i) => ({ id: i, name: p.name, icon: p.icon, description: p.description }))
        .filter(p => p.id !== 2 || root.hasPerformanceProfile)
    property var powerProfile: PowerProfiles.profile ?? 1
    property string powerProfileIcon: powerProfile === 0 ? "energy_savings_leaf" : powerProfile === 2 ? "rocket_launch" : "balance"
    property bool hasPerformanceProfile: PowerProfiles.hasPerformanceProfile || false

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
                    if (profsStr.includes("performance"))
                        root.hasPerformanceProfile = true;
                    if (actStr.includes("power-saver"))
                        root.powerProfile = 0;
                    else if (actStr.includes("performance"))
                        root.powerProfile = 2;
                    else if (actStr.includes("balanced"))
                        root.powerProfile = 1;
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
    property string timeToFull: formatTime(UPower.displayDevice.timeToFull)
    property real changeRate: UPower.displayDevice.changeRate
    function setPowerProfile(value) {
        root.powerProfile = value;
        try {
            PowerProfiles.profile = value;
        } catch (e) {}

        const name = value === 0 ? "power-saver" : value === 2 ? "performance" : "balanced";
        setProfileProc.command = ["sh", "-c",
            "busctl set-property org.freedesktop.UPower.PowerProfiles /org/freedesktop/UPower/PowerProfiles org.freedesktop.UPower.PowerProfiles ActiveProfile s " + name + " 2>/dev/null || " +
            "busctl set-property net.hadess.PowerProfiles /net/hadess/PowerProfiles net.hadess.PowerProfiles ActiveProfile s " + name + " 2>/dev/null"
        ];
        setProfileProc.running = true;
    }

    function formatTime(seconds) {
        var h = Math.floor(seconds / 3600);
        var m = Math.floor((seconds % 3600) / 60);
        if (h > 0)
        return `${h}h, ${m}m`;
        else
        return `${m}m`;
    }
}


