pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick
import qs.modules.utils

Singleton {
    id: root

    // Clipboard history entries (raw strings from cliphist)
    property list<string> entries: []
    property bool isLoading: false
    property bool _refreshPending: false
    property real items: entries.length

    // Temp directory for decoded images
    property string cliphistDecodeDir: `${Quickshell.env("HOME")}/.cache/cliphist-decode`

    property string currentSearchText: ""
    readonly property var filteredEntries: root.currentSearchText.length > 0
        ? root.fuzzyQuery(root.currentSearchText)
        : Array.prototype.slice.call(root.entries)

    // Computed lazily on first search, invalidated when entries change (1500+ entries × Fuzzy.prepare is expensive)
    property var _preppedEntries: null
    onEntriesChanged: _preppedEntries = null

    function _ensurePrepared() {
        if (!_preppedEntries)
            _preppedEntries = entries.map(a => ({ content: Fuzzy.prepare(`${getEntryText(a)}`), entry: a }))
        return _preppedEntries
    }

    function fuzzyQuery(search: string): var {
        if (root.sloppySearch) {
            const results = entries.map(obj => ({
                entry: obj,
                score: Levendist.computeScore(getEntryText(obj).toLowerCase(), search.toLowerCase())
            })).filter(item => item.score > root.scoreThreshold)
            .sort((a, b) => b.score - a.score)
            return results
            .map(item => item.entry)
        }

        return Fuzzy.go(search, _ensurePrepared(), {
            all: true,
            key: "content"
        }).map(r => {
            return r.obj.entry
        });
    }

    function updateSearch(searchText){
        root.currentSearchText = searchText
    }
    


    // Check if entry is an image
    function entryIsImage(entry) {
        return !!(/^\d+\t\[\[.*binary data.*\d+x\d+.*\]\]$/.test(entry))
    }

    function entryKind(entry) {
        if (root.entryIsImage(entry))
            return "image"
        return /^https?:\/\/\S+$/.test(root.getEntryText(entry).trim()) ? "link" : "text"
    }

    function imageInfo(entry) {
        const m = entry.match(/binary data (.+?) (\w+) (\d+)x(\d+)/)
        if (!m)
            return { size: "", format: "", width: 0, height: 0 }
        return { size: m[1], format: m[2], width: parseInt(m[3]), height: parseInt(m[4]) }
    }

    signal textDecoded(string entryId, string text)
    property var _textCache: ({})
    property var _textOrder: []
    property string _pendingText: ""

    function decodeText(entry) {
        const id = root.getEntryId(entry)
        if (!id)
            return
        if (root._textCache[id] !== undefined) {
            root.textDecoded(id, root._textCache[id])
            return
        }
        root._pendingText = entry
        if (!textProc.running)
            root._startText()
    }

    function _startText() {
        const e = root._pendingText
        root._pendingText = ""
        if (!e)
            return
        textProc.entryId = root.getEntryId(e)
        textProc.command = ["bash", "-c", `printf '%s' '${e.replace(/'/g, "'\\''")}' | cliphist decode`]
        textProc.running = true
    }

    function _remember(id, text) {
        root._textCache[id] = text
        root._textOrder.push(id)
        while (root._textOrder.length > 20)
            delete root._textCache[root._textOrder.shift()]
    }

    Process {
        id: textProc
        property string entryId: ""
        stdout: StdioCollector { id: textOut }
        onExited: (exitCode, exitStatus) => {
            const text = exitCode === 0 ? textOut.text : ""
            root._remember(textProc.entryId, text)
            root.textDecoded(textProc.entryId, text)
            if (root._pendingText !== "")
                Qt.callLater(root._startText)
        }
    }

    // Get image dimensions from entry
    function getImageDimensions(entry) {
        const match = entry.match(/(\d+)x(\d+)/)
        return match ? { width: parseInt(match[1]), height: parseInt(match[2]) } : { width: 0, height: 0 }
    }

    // Get decoded image path for an entry
    function getImagePath(entry) {
        const entryId = getEntryId(entry)
        return entryId ? `${cliphistDecodeDir}/${entryId}` : ""
    }

    // Decode image entry to temp file
    function decodeImage(entry, callback) {
        const escaped = entry.replace(/'/g, "'\\''")
        const imagePath = getImagePath(entry)

        if (!imagePath) {
            console.error("[Cliphist] Invalid entry for image decode")
            return
        }

        // Check if already decoded, if not decode it
        Quickshell.execDetached([
            "bash", "-c",
            `mkdir -p '${cliphistDecodeDir}' && [ -f '${imagePath}' ] || printf '%s' '${escaped}' | cliphist decode > '${imagePath}'`
        ])

        if (callback) callback(imagePath)
    }

    // Clean up decoded image
    function cleanupImage(entry) {
        const imagePath = getImagePath(entry)
        if (imagePath) {
            Quickshell.execDetached(["bash", "-c", `rm -f '${imagePath}'`])
        }
    }

    // Clean up all decoded images
    function cleanupAllImages() {
        Quickshell.execDetached(["bash", "-c", `rm -rf '${cliphistDecodeDir}'`])
    }

    // Refresh clipboard history
    function refresh() {
        if (readProc.running) {
            root._refreshPending = true
            return
        }
        root._refreshPending = false
        readProc.buffer = []
        readProc.running = true
    }

    // Copy entry to clipboard
    function copy(entry) {
        // Escape single quotes for shell
        const escaped = entry.replace(/'/g, "'\\''")
        Quickshell.execDetached(["bash", "-c", `printf '%s' '${escaped}' | cliphist decode | wl-copy`])
    }

    // Delete entry from history
    function deleteEntry(entry) {
        deleteProc.entry = entry
        deleteProc.running = true
    } 

    // Wipe all clipboard history
    function wipe() {
        wipeProc.running = true
    }

    // Get entry ID (first field before tab)
    function getEntryId(entry) {
        const tabIndex = entry.indexOf('\t')
        return tabIndex > 0 ? entry.substring(0, tabIndex) : ""
    }

    // Get entry text (everything after tab)
    function getEntryText(entry) {
        const tabIndex = entry.indexOf('\t')
        return tabIndex > 0 ? entry.substring(tabIndex + 1) : entry
    }

    // Process to read clipboard list
    Process { 
        id: readProc
        property list<string> buffer: []
        command: ["cliphist", "list"]

        stdout: SplitParser {
            onRead: (line) => {
                readProc.buffer.push(line)
            }
        }

        onStarted: {
            root.isLoading = true
        }

        onExited: (exitCode, exitStatus) => {
            root.isLoading = false
            if (exitCode === 0) {
                root.entries = readProc.buffer
            }
            if (root._refreshPending)
                Qt.callLater(root.refresh)
        }
    }

    // Process to delete entry
    Process {
        id: deleteProc
        property string entry: ""
        command: ["bash", "-c", `echo '${deleteProc.entry.replace(/'/g, "'\\''")}' | cliphist delete`]

        onExited: (exitCode, exitStatus) => {
            deleteProc.entry = ""
            root.refresh()
        }
    }

    // Process to wipe history
    Process {
        id: wipeProc
        command: ["cliphist", "wipe"]

        onExited: (exitCode, exitStatus) => {
            root.refresh()
        }
    }

    // Listen for clipboard changes (text only)
    Connections {
        target: Quickshell
        function onClipboardTextChanged() {
            root.refresh()
        }
    }

    // IPC Handler for external triggers (e.g., from wl-paste hooks)
    IpcHandler {
        target: "cliphistService"

        function update(): void {
            root.refresh()
        }
    }

    Component.onCompleted: {
        refresh()
    }
}
