import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Greetd
import qs.modules.services

Scope {
    id: root
    signal readyToLaunch()
    signal failed()

    // Shared state for all greeter surfaces
    property string currentText: ""
    property string currentUser: ""
    property bool unlockInProgress: false
    property bool showFailure: false
    property int failedAttempts: 0
    readonly property bool capsLockOn: ServiceKeyboard.capsLockOn

    // Clear the failure text once the user starts typing
    onCurrentTextChanged: showFailure = false

    FileView {
        path: "/etc/passwd"
        blockLoading: false
        onLoaded: {
            if (root.currentUser !== "")
                return
            for (const line of text().split("\n")) {
                const f = line.split(":")
                const uid = parseInt(f[2])
                if (f.length >= 7 && uid >= 1000 && uid < 60000 && !/(nologin|false)$/.test(f[6])) {
                    root.currentUser = f[0]
                    return
                }
            }
        }
    }

    function tryUnlock() {
        if (currentUser === "" || currentText === "") return

        root.unlockInProgress = true
        Greetd.createSession(currentUser)
    }

    function launchSession() {
        // start-hyprland (/usr/bin/start-hyprland) rather than the Hyprland
        // binary directly — the wrapper sets up the session environment.
        Greetd.launch(["start-hyprland"], [], true)
    }

    // Handle authentication messages from greetd
    Connections {
        target: Greetd

        function onAuthMessage(message, error, responseRequired, echoResponse) {
            console.log("Auth message:", message, "Error:", error, "Response required:", responseRequired)

            if (responseRequired) {
                // Send the password
                Greetd.respond(root.currentText)
            }
        }

        function onAuthFailure(message) {
            console.log("Auth failed:", message)
            root.currentText = ""
            root.showFailure = true
            root.unlockInProgress = false
            root.failedAttempts += 1
            root.failed()
        }

        function onReadyToLaunch() {
            console.log("Ready to launch!")
            root.readyToLaunch()
        }

        function onLaunched() {
            console.log("Session launched!")
        }

        function onError(error) {
            console.error("Greetd error:", error)
            root.showFailure = true
            root.unlockInProgress = false
            root.failed()
        }

        function onStateChanged() {
            console.log("Greetd state:", Greetd.state)
        }
    }
}
