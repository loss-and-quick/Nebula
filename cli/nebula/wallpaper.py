import json
import os
import random
import subprocess
import sys
from collections.abc import Sequence
from pathlib import Path
from typing import cast

from nebula import settings
from nebula.paths import COLORS, HOME, SHELL_DIR

IMAGE_EXTS = {".jpg", ".jpeg", ".png", ".webp", ".gif", ".bmp"}


def _self(args: Sequence[str]) -> str:
    r = subprocess.run([str(SHELL_DIR / "bin" / "nebula"), *args], capture_output=True, text=True)
    if r.stderr:
        _ = sys.stderr.write(r.stderr)
    lines = [l for l in r.stdout.splitlines() if l.strip()]
    return lines[-1].strip() if lines else ""


def _scheme(args: Sequence[str]) -> int:
    from nebula import scheme
    saved = sys.argv
    sys.argv = ["nebula scheme generate", *args]
    rc = 0
    try:
        scheme.main()
    except SystemExit as e:
        if e.code not in (None, 0):
            print(f"[nebula] scheme generate exited with {e.code}", file=sys.stderr)
            rc = e.code if isinstance(e.code, int) else 1
    finally:
        sys.argv = saved
    return rc


def defaults() -> dict[str, str]:
    t = settings.section("theme")
    g = settings.section("general")
    scheme = "scheme-custom" if g.get("palette") == "custom" else str(t.get("matugenScheme", "scheme-content"))
    return {
        "scheme": scheme,
        "mode": str(t.get("matugenTheme", "dark")),
        "gowall": str(t.get("gowallTheme", "off")),
        "icons": "on" if t.get("gowallIcons") else "off",
        "invert": "on" if t.get("gowallInvert") else "off",
        "shell": "on" if t.get("gowallShell") else "off",
    }


def apply(wallpaper: str, scheme: str, mode: str, gowall: str = "off",
          icons: str = "off", invert: str = "off", shell: str = "off") -> int:
    if not os.path.isfile(wallpaper):
        print(f"[nebula] no such image: {wallpaper}", file=sys.stderr)
        return 1
    mode = mode.lower()
    gw = (gowall or "off").lower()
    display = wallpaper

    palette_on = gw not in ("", "off", "none")
    invert_on = invert.lower() == "on"
    inv = ["--invert"] if invert_on else []
    icons_on = palette_on and icons.lower() == "on"
    keep = ["--keep-icon-theme"] if icons_on else []
    shell_on = palette_on and shell.lower() == "on" and gw != "match"

    pal: list[str] = []
    if shell_on:
        palette_file = _self(["gowall", "--palette", gowall])
        if palette_file and os.path.isfile(palette_file):
            pal = ["--palette-file", palette_file]

    if palette_on and gw == "match":
        rc = _scheme([wallpaper, scheme, mode, *keep])
        if rc != 0:
            return rc
        converted = _self(["gowall", wallpaper, "match", *inv])
        if converted and os.path.isfile(converted):
            display = converted
        rc = _scheme([wallpaper, scheme, mode, "--display", display, *keep])
        if rc != 0:
            return rc
    elif palette_on or invert_on:
        converted = _self(["gowall", wallpaper, gowall, *inv])
        if converted and os.path.isfile(converted):
            display = converted
        rc = _scheme([display, scheme, mode, "--source", wallpaper, *keep, *pal])
        if rc != 0:
            return rc
    else:
        rc = _scheme([wallpaper, scheme, mode])
        if rc != 0:
            return rc

    if icons_on:
        _ = _self(["gowall-icons", gowall, "--apply"])
    return 0


def current() -> str:
    try:
        raw: object = json.loads(COLORS.read_text())
        if isinstance(raw, dict):
            c = cast(dict[str, object], raw)
            val = c.get("sourceWallpaper") or c.get("wallpaper") or ""
            return str(val) if isinstance(val, str) else ""
    except Exception:
        pass
    return ""


def wallpaper_dir() -> Path:
    d = str(settings.section("general").get("wallpaperDir") or (HOME / "wallpaper"))
    return Path(os.path.expanduser(d))


def pick_random(folder: Path) -> str:
    now = current()
    files = [str(p) for p in folder.rglob("*")
             if p.is_file() and p.suffix.lower() in IMAGE_EXTS and "/." not in str(p)]
    choices = [f for f in files if f != now] or files
    return random.choice(choices) if choices else ""
