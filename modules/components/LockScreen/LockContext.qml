pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import qs.modules.services

Scope {
	id: root
	signal unlocked()
	signal failed()

	// These properties are in the context and not individual lock surfaces
	// so all surfaces can share the same state.
	property string currentText: ""
	property bool unlockInProgress: false
	property bool showFailure: false

	property bool active: false

	property int failedAttempts: 0
	readonly property bool capsLockOn: ServiceKeyboard.capsLockOn
	property bool clockAwake: false

	function wakeClock() {
		root.clockAwake = true
		clockIdle.restart()
	}

	function pokeClock() {
		if (root.clockAwake)
			clockIdle.restart()
	}

	Timer {
		id: clockIdle
		interval: 20000
		onTriggered: {
			if (root.currentText === "" && !root.unlockInProgress)
				root.clockAwake = false
			else
				clockIdle.restart()
		}
	}

	onUnlocked: root.currentText = ""

	onActiveChanged: {
		root.currentText = ""
		if (active) {
			failedAttempts = 0
			showFailure = false
			clockAwake = false
		}
	}

	// Security: clear password after 10 seconds of inactivity
	Timer {
		id: passwordClearTimer
		interval: 10000
		onTriggered: root.currentText = ""
	}

	// Clear failure text and reset timer when user types
	onCurrentTextChanged: {
		showFailure = false
		pokeClock()
		if (currentText.length > 0) {
			passwordClearTimer.restart()
		}
	}

	function tryUnlock() {
		if (currentText === "") return;

		root.unlockInProgress = true;
		pam.start();
	}

	PamContext {
		id: pam

		// Custom pam config for quickshell
		configDirectory: "pam"
		config: "password.conf"

		onPamMessage: {
			if (this.responseRequired) {
				this.respond(root.currentText);
			}
		}

		onCompleted: result => {
			if (result == PamResult.Success) {
				root.unlocked();
			} else {
				root.currentText = "";
				root.showFailure = true;
				root.failedAttempts++;
				root.failed();
			}

			root.unlockInProgress = false;
		}
	}
}
