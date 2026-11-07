pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick
import qs.modules.settings

Singleton {
    id: root

    readonly property string cacheDir: Quickshell.env("HOME") + "/.cache/quickshell/capture-thumbs"

    property var  items: []
    property bool scanning: scanProc.running
    property int  limit: 8

    property var _pending: []
    property bool _refreshPending: false

    function refresh() {
        if (scanProc.running) {
            root._refreshPending = true
            return
        }
        root._refreshPending = false
        root._pending = []
        scanProc.command = ["sh", "-c", root._script, "sh",
                            root._expand(SettingsConfig.screenshot.outputPath),
                            root._expand(SettingsConfig.recording.outputPath),
                            root.cacheDir,
                            String(root.limit)]
        scanProc.running = true
    }

    function _expand(p) {
        return String(p ?? "").replace("~", Quickshell.env("HOME"))
    }

    function humanSize(bytes) {
        const b = Number(bytes)
        if (!isFinite(b) || b <= 0) return ""
        if (b < 1024) return b + " B"
        if (b < 1024 * 1024) return (b / 1024).toFixed(0) + " KB"
        if (b < 1024 * 1024 * 1024) return (b / (1024 * 1024)).toFixed(1) + " MB"
        return (b / (1024 * 1024 * 1024)).toFixed(2) + " GB"
    }

    function humanAge(epochSeconds) {
        const secs = Math.max(0, Math.floor(Date.now() / 1000) - Number(epochSeconds))
        if (secs < 60)    return "just now"
        if (secs < 3600)  return Math.floor(secs / 60) + " min ago"
        if (secs < 86400) return Math.floor(secs / 3600) + " h ago"
        const days = Math.floor(secs / 86400)
        return days === 1 ? "yesterday" : days + " days ago"
    }

    function clock(seconds) {
        const s = Math.max(0, Math.floor(Number(seconds)))
        return String(Math.floor(s / 60)).padStart(2, "0") + ":" + String(s % 60).padStart(2, "0")
    }

    readonly property string _script: `
PIC="$1"; VID="$2"; CACHE="$3"; N="$4"
mkdir -p "$CACHE"
ls -1t "$PIC"/*.png "$PIC"/*.jpg "$PIC"/*.jpeg "$PIC"/*.webp \\
       "$VID"/*.mp4 "$VID"/*.mkv "$VID"/*.webm 2>/dev/null | head -n "$N" |
while IFS= read -r f; do
  [ -f "$f" ] || continue
  mt=$(stat -c %Y "$f") || continue
  sz=$(stat -c %s "$f") || continue
  case "$f" in
    *.mp4|*.mkv|*.webm)
      key=$(printf '%s' "$f" | md5sum | cut -c1-16)
      th="$CACHE/$key.jpg"
      [ -s "$th" ] || ffmpeg -loglevel quiet -y -ss 0.5 -i "$f" -frames:v 1 -vf scale=320:-2 "$th" </dev/null >/dev/null 2>&1
      [ -s "$th" ] || th=""
      dur=$(ffprobe -v quiet -show_entries format=duration -of csv=p=0 "$f" 2>/dev/null)
      printf 'video\\t%s\\t%s\\t%s\\t%s\\t%s\\n' "$mt" "$sz" "\${dur%%.*}" "$th" "$f"
      ;;
    *)
      printf 'image\\t%s\\t%s\\t0\\t%s\\t%s\\n' "$mt" "$sz" "$f" "$f"
      ;;
  esac
done
`

    Process {
        id: scanProc

        stdout: SplitParser {
            onRead: line => {
                const parts = String(line).split("\t")
                if (parts.length < 6) return
                const next = root._pending.slice()
                next.push({
                    kind:     parts[0],
                    mtime:    parseInt(parts[1]) || 0,
                    size:     parseInt(parts[2]) || 0,
                    duration: parseInt(parts[3]) || 0,
                    thumb:    parts[4],
                    path:     parts[5],
                    name:     parts[5].split("/").pop()
                })
                root._pending = next
            }
        }

        onExited: {
            root.items = root._pending
            root._pending = []
            if (root._refreshPending)
                Qt.callLater(root.refresh)
        }
    }

    Connections {
        target: ServiceTools

        function onScreenshotReady(path) { root.refresh() }
        function onIsRecordingChanged()  { if (!ServiceTools.isRecording) root.refresh() }
    }

    function forget(path) {
        root.items = root.items.filter(function (e) { return e.path !== path })
    }
}
