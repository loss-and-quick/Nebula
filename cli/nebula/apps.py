#!/usr/bin/env python3
import hashlib
import json
import os
import shutil
import sys
from collections.abc import Iterable, Sequence
from pathlib import Path
from typing import NotRequired, TypedDict, cast

from nebula import settings
from nebula.paths import SHELL_DIR, STATE_DIR

HOME = Path.home()
TEMPLATES = HOME / ".config" / "matugen" / "templates"
MANIFEST = STATE_DIR / "theme-apps-written.json"

TMUX_HOOK = (
    'L="$HOME/.tmux.conf.local"; C="$HOME/.config/tmux/colors.conf"; '
    '{ sed "/^# >>> m3 palette >>>$/q" "$L"; cat "$C"; '
    r'sed -n "/^# <<< m3 palette <<<$/,\$p" "$L"; } > "$L.new" '
    '&& cat "$L.new" > "$L" && rm -f "$L.new"; '
    'for s in "${TMUX_TMPDIR:-/tmp}"/tmux-$(id -u)/*; do '
    '[ -S "$s" ] && tmux -S "$s" source-file "$HOME/.tmux.conf"; '
    'done'
)

GTK3_HOOK = ('gsettings set org.gnome.desktop.interface gtk-theme "" && '
             'gsettings set org.gnome.desktop.interface gtk-theme '
             '"adw-gtk3$([ "${NEBULA_MODE:-dark}" = dark ] && echo -dark)"')

HYPR_HOOK = (
    'F="$HOME/.config/hypr/lua/colors.lua"; '
    r"""a=$(sed -n 's/^M\.active_border *= *"\(.*\)".*/\1/p' "$F"); """
    r"""i=$(sed -n 's/^M\.inactive_border *= *"\(.*\)".*/\1/p' "$F"); """
    '[ -n "$a" ] && [ -n "$i" ] && hyprctl eval '
    r'''"hl.config({ general = { col = { active_border = \"$a\", inactive_border = \"$i\" } } })"'''
)

PAPIRUS_DIRS = [
    Path("/usr/share/icons/Papirus"),
    Path("/usr/share/icons/Papirus-Dark"),
    Path("/usr/share/icons/Papirus-Light"),
    HOME / ".local/share/icons/Papirus",
    HOME / ".icons/Papirus",
]

LIB_DIRS = [Path("/usr/lib"), Path("/usr/lib64"), Path("/usr/lib/x86_64-linux-gnu")]

class AppFile(TypedDict):
    input: str
    output: str
    bins: NotRequired[list[str]]
    needs: NotRequired[str]


class AppDef(TypedDict):
    id: str
    name: str
    group: str
    bins: NotRequired[list[str]]
    libs: NotRequired[list[str]]
    browsers: NotRequired[list[str]]
    files: NotRequired[list[AppFile]]
    hook: NotRequired[str]
    note: NotRequired[str]
    whole: NotRequired[bool]
    papirus: NotRequired[bool]
    vaults: NotRequired[bool]


class DetectedApp(TypedDict):
    id: str
    name: str
    group: str
    installed: bool
    found: str
    hint: str
    note: str
    targets: list[str]
    replacesFile: bool


APPS: list[AppDef] = [
    {"id": "kitty", "name": "kitty", "group": "terminal", "bins": ["kitty"],
     "files": [{"input": "kitty-colors.conf", "output": ".config/kitty/colors.conf"}]},
    {"id": "tmux", "name": "tmux", "group": "terminal", "bins": ["tmux"],
     "files": [{"input": "tmux-colors.conf", "output": ".config/tmux/colors.conf"}],
     "hook": TMUX_HOOK, "note": "~/.tmux.conf.local palette block"},
    {"id": "starship", "name": "Starship", "group": "terminal", "bins": ["starship"], "whole": True,
     "files": [{"input": "starship.toml", "output": ".config/starship.toml"}]},
    {"id": "btop", "name": "btop", "group": "terminal", "bins": ["btop"],
     "files": [{"input": "btop.theme", "output": ".config/btop/themes/matugen.theme"}]},
    {"id": "hyprland", "name": "Hyprland borders", "group": "desktop", "bins": ["hyprctl", "Hyprland"],
     "files": [{"input": "hyprland-colors.conf", "output": ".config/hypr/colors.conf"},
               {"input": "hyprland-colors.lua", "output": ".config/hypr/lua/colors.lua", "needs": ".config/hypr/lua"}],
     "hook": HYPR_HOOK},
    {"id": "gtk3", "name": "GTK 3", "group": "desktop", "libs": ["libgtk-3.so.0"], "whole": True,
     "files": [{"input": "gtk-colors.css", "output": ".config/gtk-3.0/gtk.css"}], "hook": GTK3_HOOK},
    {"id": "gtk4", "name": "GTK 4", "group": "desktop", "libs": ["libgtk-4.so.1"], "whole": True,
     "files": [{"input": "gtk4-colors.css", "output": ".config/gtk-4.0/gtk.css"}]},
    {"id": "qt", "name": "Qt5ct and Qt6ct", "group": "desktop", "bins": ["qt6ct", "qt5ct"],
     "files": [{"input": "qt-colors.conf", "output": ".config/qt6ct/colors/matugen.conf", "bins": ["qt6ct"]},
               {"input": "qt-colors.conf", "output": ".config/qt5ct/colors/matugen.conf", "bins": ["qt5ct"]}]},
    {"id": "papirus", "name": "Papirus folders", "group": "desktop", "bins": ["papirus-folders"],
     "papirus": True, "note": "folder colour nearest to primary"},
    {"id": "firefox", "name": "Firefox and Zen", "group": "apps", "bins": ["pywalfox"],
     "browsers": ["firefox", "zen-browser", "zen", "librewolf", "floorp"],
     "files": [{"input": "pywalfox-colors.json", "output": ".cache/wal/colors.json"}],
     "hook": 'pywalfox update && pywalfox "${NEBULA_MODE:-dark}"', "note": "through the Pywalfox add-on"},
    {"id": "obsidian", "name": "Obsidian", "group": "apps", "bins": ["obsidian"], "vaults": True,
     "files": [{"input": "obsidian.css", "output": ".obsidian/themes/Matugen/theme.css"}]},
    {"id": "waybar", "name": "Waybar", "group": "apps", "bins": ["waybar"],
     "files": [{"input": "colors.css", "output": ".config/waybar/colors.css"}]},
    {"id": "nwgdock", "name": "nwg-dock", "group": "apps", "bins": ["nwg-dock-hyprland"],
     "files": [{"input": "colors.css", "output": ".config/nwg-dock-hyprland/colors.css"}]},
]

BY_ID: dict[str, AppDef] = {a["id"]: a for a in APPS}


def pretty(path: Path | str) -> str:
    s = str(path)
    h = str(HOME)
    return "~" + s[len(h):] if s.startswith(h + "/") else s


def which(names: Sequence[str] | None) -> str:
    for n in names or []:
        p = shutil.which(n)
        if p:
            return p
    return ""


def find_lib(names: Sequence[str] | None) -> str:
    for n in names or []:
        for d in LIB_DIRS:
            if (d / n).exists():
                return str(d / n)
    return ""


def obsidian_vaults() -> list[Path]:
    cfg = HOME / ".config" / "obsidian" / "obsidian.json"
    try:
        raw: object = json.loads(cfg.read_text())
        vaults: object = cast(dict[str, object], raw).get("vaults", {}) if isinstance(raw, dict) else {}
    except Exception:
        return []
    out: list[Path] = []
    if isinstance(vaults, dict):
        for v in cast(dict[str, object], vaults).values():
            if isinstance(v, dict):
                v_dict = cast(dict[str, object], v)
                p_val = v_dict.get("path")
                if isinstance(p_val, str):
                    p = Path(p_val)
                    if p.is_dir() and (p / ".obsidian").is_dir():
                        out.append(p)
    return out


def targets(app: AppDef) -> list[tuple[Path, Path]]:
    out: list[tuple[Path, Path]] = []
    for f in app.get("files", []):
        bins = f.get("bins")
        if bins and not which(bins):
            continue
        needs = f.get("needs")
        if needs and not (HOME / needs).is_dir():
            continue
        if app.get("vaults"):
            for v in obsidian_vaults():
                out.append((TEMPLATES / f["input"], v / f["output"]))
        else:
            out.append((TEMPLATES / f["input"], HOME / f["output"]))
    return out


def enabled_ids() -> set[str] | None:
    raw: object = settings.section("theme").get("themeApps")
    if isinstance(raw, list):
        items = cast(list[object], raw)
        return {str(x) for x in items}
    return None


def parse_ids(arg: str | None) -> set[str] | None:
    return {s for s in arg.split(",") if s} if arg is not None else None


def _sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def load_manifest() -> dict[str, str]:
    try:
        raw: object = json.loads(MANIFEST.read_text())
        if isinstance(raw, dict):
            d = cast(dict[object, object], raw)
            return {str(k): str(v) for k, v in d.items()}
    except Exception:
        pass
    return {}


def save_manifest(m: dict[str, str]) -> None:
    try:
        MANIFEST.parent.mkdir(parents=True, exist_ok=True)
        tmp = MANIFEST.with_suffix(".tmp")
        _ = tmp.write_text(json.dumps(m, indent=1))
        os.replace(tmp, MANIFEST)
    except Exception as e:
        print(f"[theme_apps] manifest ERROR: {e}", file=sys.stderr)


def is_user_file(path: Path, manifest: dict[str, str]) -> bool:
    if path.is_symlink():
        return True
    if not path.is_file():
        return False
    try:
        return manifest.get(str(path)) != _sha(path.read_bytes())
    except Exception:
        return True


def _free_backup(path: Path) -> Path:
    bak = path.with_name(path.name + ".bak")
    n = 1
    while bak.exists() or bak.is_symlink():
        bak = path.with_name(f"{path.name}.bak.{n}")
        n += 1
    return bak


def backup_if_user_file(app: AppDef, path: Path, manifest: dict[str, str]) -> bool:
    if not app.get("whole") or not is_user_file(path, manifest):
        return False
    _ = shutil.copy2(path, _free_backup(path), follow_symlinks=True)
    return True


def record(path: Path, content: str, manifest: dict[str, str]) -> None:
    manifest[str(path)] = _sha(content.encode())


def locate(app: AppDef) -> str:
    return find_lib(app.get("libs")) if app.get("libs") else which(app.get("bins"))


def is_installed(app: AppDef) -> bool:
    if not locate(app):
        return False
    if app.get("papirus"):
        return any(p.exists() for p in PAPIRUS_DIRS)
    if app.get("vaults"):
        return bool(obsidian_vaults())
    return True


def detect_one(app: AppDef, manifest: dict[str, str]) -> DetectedApp:
    found = locate(app)
    hint = ""
    installed = bool(found)
    if app.get("papirus"):
        installed = installed and any(p.exists() for p in PAPIRUS_DIRS)
        if not found and any(p.exists() for p in PAPIRUS_DIRS):
            hint = "Install papirus-folders"
    if app["id"] == "firefox" and not installed and which(app.get("browsers")):
        hint = "Install python-pywalfox and its browser add-on"
    tg = targets(app) if installed else []
    if app.get("vaults") and installed and not tg:
        installed = False
        hint = "No Obsidian vault found"
    paths = [t[1] for t in tg]
    note = app.get("note") or (pretty(paths[0]) if len(paths) == 1 else
                               f"{len(paths)} vaults" if app.get("vaults") and paths else
                               ", ".join(pretty(p) for p in paths))
    return {
        "id": app["id"],
        "name": app["name"],
        "group": app["group"],
        "installed": installed,
        "found": found,
        "hint": hint,
        "note": note,
        "targets": [pretty(p) for p in paths],
        "replacesFile": bool(app.get("whole")) and any(is_user_file(p, manifest) for p in paths),
    }


def detect() -> list[DetectedApp]:
    manifest = load_manifest()
    return [detect_one(a, manifest) for a in APPS]


def picked_ids(detected: list[DetectedApp] | None = None) -> set[str]:
    saved = enabled_ids()
    if saved is not None:
        return saved
    active = detected if detected is not None else detect()
    return {a["id"] for a in active if a["installed"]}


def _save(ids: Iterable[str]) -> None:
    order = [a["id"] for a in APPS]
    id_list: list[str] = list(ids)
    settings.update("theme", {"themeApps": sorted(id_list, key=lambda i: order.index(i) if i in order else 99)})


def _apply_now() -> int:
    import subprocess
    return subprocess.run([str(SHELL_DIR / "bin" / "nebula"), "scheme", "apply"]).returncode


def print_list(as_json: bool) -> int:
    detected = detect()
    picked = picked_ids(detected)
    if as_json:
        print(json.dumps([dict(a, picked=a["id"] in picked) for a in detected]))
        return 0
    auto = enabled_ids() is None
    tty = sys.stdout.isatty()
    on = "\033[32m●\033[0m" if tty else "on "
    off = "\033[2m○\033[0m" if tty else "off"
    groups = {"terminal": "Terminal and shell", "desktop": "Desktop", "apps": "Apps"}
    for g, title in groups.items():
        print(title)
        for a in detected:
            if a["group"] != g:
                continue
            mark = (on if a["id"] in picked else off) if a["installed"] else " - "
            extra = a["note"] if a["installed"] else (a["hint"] or "not installed")
            if a["installed"] and a["replacesFile"]:
                extra += "  (replaces your file, keeps a .bak)"
            print(f"  {mark} {a['id']:<10} {a['name']:<18} {extra}")
    if auto:
        print("\nNo choice saved yet: every detected app is themed. `nebula apps disable <id>` to opt out.")
    return 0


def set_picked(ids: Sequence[str], on: bool, apply_now: bool) -> int:
    unknown = [i for i in ids if i not in BY_ID]
    if unknown:
        print(f"nebula: unknown app id: {', '.join(unknown)}. See `nebula apps`.", file=sys.stderr)
        return 2
    picked = set(picked_ids())
    picked = picked | set(ids) if on else picked - set(ids)
    _save(picked)
    print(("Enabled " if on else "Disabled ") + ", ".join(BY_ID[i]["name"] for i in ids))
    return _apply_now() if apply_now else 0


def reset(apply_now: bool) -> int:
    settings.update("theme", {"themeApps": None})
    print("Every detected app follows the palette again.")
    return _apply_now() if apply_now else 0


def main() -> int:
    print(json.dumps(detect()))
    return 0
