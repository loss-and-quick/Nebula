pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import Quickshell.Networking
import QtQuick

Singleton {
    id: root

    property var availableNetworks: Networking.devices ?? null
    readonly property var devices: availableNetworks?.values ?? []

    readonly property var wifiDevice:  devices.find(d => d.type === DeviceType.Wifi)  ?? null
    readonly property var wiredDevice: devices.find(d => d.type === DeviceType.Wired) ?? null

    readonly property var activeDevice: wiredDevice?.connected ? wiredDevice
                                      : wifiDevice?.connected  ? wifiDevice
                                      : null

    readonly property string activeInterface: activeDevice?.name ?? ""

    property bool isConnected: activeDevice !== null
    property var currentNetwork: wifiDevice

    property var networks: !currentNetwork?.networks?.values ? [] :
    currentNetwork.networks.values.slice()

    property var connectedNetwork: networks.find(n => n.connected) ?? null
    property var savedNetworks: networks.filter(n => n.known && !n.connected)
    property var available: networks.filter(n => !n.known && !n.connected)
    property var connectedAndSavedNetworks: networks.filter(n => n.connected || n.known)
    .sort((a, b) => b.connected - a.connected)



    property bool wifiEnabled: Networking.wifiEnabled

    property string currentSSID: connectedNetwork?.name ?? ""

    property string ipAddress: ""
    property int freqMhz: 0
    property bool autoconnect: true
    property int savedCount: 0

    property bool joining: false
    property string connectionError: ""
    signal joinFinished(bool success, string error)

    property string connectionType: {
        if (wiredDevice?.connected) return "ethernet"
        if (Networking.wifiEnabled && connectedNetwork) return "wifi"
        return "disconnected"
    }

    readonly property string connectionLabel: connectionType === "ethernet" ? "Ethernet" : currentSSID

    property string icon: {
        if (connectionType === "ethernet") return "lan"
        const sig = (connectedNetwork?.signalStrength ?? 0) * 100
        if (!Networking.wifiEnabled || !connectedNetwork) return "signal_wifi_off"
        if (sig >= 90) return "signal_wifi_4_bar"
        if (sig >= 60) return "network_wifi_3_bar"
        if (sig >= 30) return "network_wifi_2_bar"
        return "network_wifi_1_bar"
    }

    function toggleWifi() {
        Networking.wifiEnabled = !Networking.wifiEnabled
    }

    function setWifiEnabled(enabled) {
        Networking.wifiEnabled = enabled
    }

    function refreshInfo() {
        if (infoProcess.running) return
        const iface = root.wifiDevice?.name ?? ""
        const curName = root.connectedNetwork?.name ?? ""
        infoProcess.command = ["sh", "-c",
            "nmcli -t -g IP4.ADDRESS dev show \"$1\" 2>/dev/null | head -n1; "
            + "nmcli -t -f ACTIVE,FREQ dev wifi list --rescan no 2>/dev/null | awk -F: '$1==\"yes\"{print $2+0; exit}'; echo; "
            + "nmcli -g connection.autoconnect connection show id \"$2\" 2>/dev/null; echo; "
            + "nmcli -t -f TYPE connection show 2>/dev/null | awk '/802-11-wireless/{c++} END{print c+0}'",
            "sh", iface, curName]
        infoProcess.running = true
    }

    function setAutoconnect(uuid, enabled) {
        if (typeof uuid === "boolean" && enabled === undefined) {
            enabled = uuid
            uuid = root.connectedNetwork?.name ?? ""
        }
        const target = (typeof uuid === "object" ? (uuid?.name || uuid?.uuid) : uuid) || root.connectedNetwork?.name || ""
        if (!target) return
        root.autoconnect = !!enabled
        Quickshell.execDetached(["nmcli", "connection", "modify", target,
                                 "connection.autoconnect", enabled ? "yes" : "no"])
        infoTimer.restart()
    }

    function connectTo(network, password) {
        if (!network) return
        root.connectionError = ""
        if (password !== undefined && password !== null && password !== "") {
            network.connectWithPsk(password)
        } else {
            network.connect()
        }
    }

    function disconnectFrom(network) {
        const target = network || root.connectedNetwork
        if (!target) return
        target.disconnect()
    }

    function forgetNetwork(network) {
        const target = network || root.connectedNetwork
        if (!target) return
        target.forget()
        infoTimer.restart()
    }

    function joinHidden(ssid, password) {
        root.connectionError = ""
        root.joining = true
        const psk = password || ""
        joinerProcess.command = ["nmcli", "dev", "wifi", "connect", ssid, "hidden", "yes"]
            .concat(psk !== "" ? ["password", psk] : [])
        joinerProcess.running = true
    }

    function scan() {
        const dev = root.wifiDevice
        if (!Networking.wifiEnabled || !dev) return false
        if (dev.scannerEnabled) rescanProcess.running = true
        else dev.scannerEnabled = true
        return true
    }

    function bucket(n) {
        return Math.min(3, Math.floor((n?.signalStrength ?? 0) * 4))
    }

    function ordered(list) {
        return list.slice().sort((a, b) => root.bucket(b) - root.bucket(a)
            || (a.name || "").localeCompare(b.name || ""))
    }

    function strengthLabel(strength) {
        const v = (strength ?? 0) * 100
        if (v >= 75) return "Excellent"
        if (v >= 50) return "Good"
        if (v >= 25) return "Fair"
        return "Weak"
    }

    function securityLabel(security) {
        switch (security) {
        case WifiSecurityType.Wpa3SuiteB192:
        case WifiSecurityType.Sae: return "WPA3"
        case WifiSecurityType.Wpa2Psk:
        case WifiSecurityType.Wpa2Eap: return "WPA2"
        case WifiSecurityType.WpaPsk:
        case WifiSecurityType.WpaEap: return "WPA"
        case WifiSecurityType.StaticWep:
        case WifiSecurityType.DynamicWep: return "WEP"
        case WifiSecurityType.Leap: return "LEAP"
        case WifiSecurityType.Owe: return "Enhanced open"
        case WifiSecurityType.Open: return "Open"
        }
        return ""
    }

    function isSecured(security) {
        if (security === undefined || security === null) return false
        return security !== WifiSecurityType.Open
            && security !== WifiSecurityType.Owe
            && security !== WifiSecurityType.Unknown
    }

    function band(mhz) {
        if (mhz <= 0) return ""
        if (mhz < 3000) return "2.4 GHz"
        if (mhz < 5925) return "5 GHz"
        return "6 GHz"
    }

    function signalIcon(n) {
        const bars = Math.round((n?.signalStrength ?? 0) * 4)
        const locked = root.isSecured(n?.security)
        if (bars >= 4) return locked ? "wifi_lock" : "wifi"
        if (bars >= 1) return "network_wifi_" + bars + "_bar" + (locked ? "_locked" : "")
        return locked ? "wifi_lock" : "signal_wifi_off"
    }

    Process {
        id: rescanProcess
        command: ["nmcli", "device", "wifi", "rescan"]
    }

    property string qrImagePath: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/wifi_qr.png"
    signal qrGenerated(string path)
    signal qrFailed()

    property string _pendingSsid: ""
    property string _pendingAuth: ""
    property string _fetchedPassword: ""
    property bool _qrBusy: false
    property var _qrQueue: []
    property string _qrPayload: ""

    // security: WifiSecurityType value from WifiNetwork.security
    function generateQr(ssid, security) {
        if (root._qrBusy) {
            root._qrQueue = root._qrQueue.concat([{ ssid: ssid, security: security }])
            return
        }
        root._qrBusy = true
        root._pendingSsid = ssid
        root._pendingAuth = _securityToQrAuth(security)
        root._fetchedPassword = ""

        if (root._pendingAuth === "nopass") {
            // open network — no password needed
            var wifiString = "WIFI:T:nopass;S:" + _escapeWifi(ssid) + ";;"
            root._startQrProcess(wifiString)
        } else {
            passwordFetcher.command = ["nmcli", "-s", "-g", "802-11-wireless-security.psk", "connection", "show", ssid]
            passwordFetcher.running = true
        }
    }

    function _startQrProcess(payload) {
        root._qrPayload = payload
        qrProcess.running = true
    }

    function _finishQr(success) {
        root._pendingSsid = ""
        root._fetchedPassword = ""
        root._qrPayload = ""
        root._qrBusy = false
        if (success) root.qrGenerated(root.qrImagePath)
        else root.qrFailed()
        if (!root._qrBusy && root._qrQueue.length > 0) {
            const next = root._qrQueue[0]
            root._qrQueue = root._qrQueue.slice(1)
            root.generateQr(next.ssid, next.security)
        }
    }

    function _securityToQrAuth(security) {
        switch (security) {
            case WifiSecurityType.StaticWep:
            case WifiSecurityType.DynamicWep:
                return "WEP"
            case WifiSecurityType.Open:
            case WifiSecurityType.Owe:
                return "nopass"
            default:
                return "WPA"
        }
    }

    function _escapeWifi(str) {
        return str.replace(/\\/g, "\\\\")
                  .replace(/;/g, "\\;")
                  .replace(/,/g, "\\,")
                  .replace(/"/g, "\\\"")
                  .replace(/:/g, "\\:")
    }

    Process {
        id: passwordFetcher
        running: false
        stdout: SplitParser {
            onRead: function(line) {
                root._fetchedPassword = line.trim()
            }
        }
        onExited: function(code) {
            if (code === 0 && root._fetchedPassword !== "") {
                var wifiString = "WIFI:T:" + root._pendingAuth
                    + ";S:" + root._escapeWifi(root._pendingSsid)
                    + ";P:" + root._escapeWifi(root._fetchedPassword) + ";;"
                root._startQrProcess(wifiString)
            } else {
                Qt.callLater(root._finishQr, false)
            }
        }
    }

    Process {
        id: qrProcess
        running: false
        command: ["qrencode", "-o", root.qrImagePath, "-s", "10"]
        stdinEnabled: true
        onStarted: {
            qrProcess.write(root._qrPayload)
            root._qrPayload = ""
            qrProcess.stdinEnabled = false
        }
        onExited: function(code) {
            qrProcess.stdinEnabled = true
            Qt.callLater(root._finishQr, code === 0)
        }
    }

    Process {
        id: infoProcess
        running: false
        stdout: StdioCollector {
            id: infoOut
            onStreamFinished: {
                const lines = infoOut.text.split("\n").map(l => l.trim()).filter(l => l !== "")
                const ipLine = lines.find(l => /^\d+\.\d+\.\d+\.\d+/.test(l)) ?? ""
                root.ipAddress = ipLine.split("/")[0]
                const f = lines.find(l => /^\d{4}$/.test(l))
                root.freqMhz = f ? parseInt(f) : 0
                const ac = lines.find(l => l === "yes" || l === "no")
                root.autoconnect = ac !== "no"
                const count = lines.length > 0 ? parseInt(lines[lines.length - 1]) : 0
                root.savedCount = isNaN(count) ? 0 : count
            }
        }
    }

    Timer {
        id: infoTimer
        interval: 1200
        onTriggered: root.refreshInfo()
    }

    onConnectedNetworkChanged: infoTimer.restart()

    Process {
        id: joinerProcess
        running: false
        stderr: StdioCollector { id: joinErr }
        onExited: function(code) {
            root.joining = false
            if (code === 0) {
                root.connectionError = ""
                root.joinFinished(true, "")
                infoTimer.restart()
            } else {
                const msg = (joinErr.text || "").trim().split("\n").pop()
                root.connectionError = msg !== "" ? msg.replace(/^Error:\s*/, "") : "Couldn't join that network"
                root.joinFinished(false, root.connectionError)
            }
        }
    }

    Component.onCompleted: {
        root.refreshInfo()
    }
}
