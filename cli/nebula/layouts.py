import json
import os
import re
import shutil
import sys
import tempfile
from datetime import datetime
from pathlib import Path
from typing import Any, cast

from nebula import settings
from nebula.paths import HOME

DIR = Path(os.environ.get("XDG_CONFIG_HOME", HOME / ".config")) / "nebula" / "layouts"
PREVIOUS = DIR / ".previous.json"
ACTIVE = DIR / ".active"
FORMAT = 1

SECTIONS = ["bar", "widgets", "dashboard", "panels", "lockscreen"]
LABELS = {"bar": "Bar and dock", "widgets": "Desktop widgets", "dashboard": "Dashboard",
          "panels": "Panel styles", "lockscreen": "Lock screen"}

WIDGET_DATA = {"countdowns", "stickyNoteText"}
DOCK_KEYS = ["dock", "dockAutoHide", "dockMusicPlayer", "dockSdf"]
PANEL_PREFIXES = ("launcher", "notes")
PANEL_KEYS = ["clipboardStyle", "notifPopupStyle", "barWeatherPanel"]


def slug(name: str) -> str:
    s = re.sub(r"[^a-z0-9]+", "-", name.strip().lower()).strip("-")
    return s or "layout"


def _read_settings() -> dict[str, Any]:
    try:
        return settings.load()
    except Exception:
        return {}


def _write_settings(data: dict[str, Any], replace_sections: set[str] | None = None) -> None:
    for section_name, patch in data.items():
        if isinstance(patch, dict):
            settings.update(section_name, cast(dict[str, Any], patch), replace=bool(replace_sections and section_name in replace_sections))


def _panel_keys(general: dict[str, Any]) -> dict[str, Any]:
    return {k: v for k, v in general.items() if k.startswith(PANEL_PREFIXES) or k in PANEL_KEYS}


def capture(only: list[str] | set[str] | None = None) -> dict[str, Any]:
    s = _read_settings()
    raw_g = s.get("general")
    g = cast(dict[str, Any], raw_g) if isinstance(raw_g, dict) else {}
    want = set(only or SECTIONS)
    out: dict[str, Any] = {}
    if "bar" in want and "bar" in s:
        out["bar"] = {"bar": s["bar"], "general": {k: g[k] for k in DOCK_KEYS if k in g}}
        if "dock" in s:
            cast(dict[str, Any], out["bar"])["dock"] = s["dock"]
    if "widgets" in want and "widgets" in s:
        raw_w = s["widgets"]
        w_dict = cast(dict[str, Any], raw_w) if isinstance(raw_w, dict) else {}
        out["widgets"] = {k: v for k, v in w_dict.items() if k not in WIDGET_DATA}
    if "dashboard" in want and "dashboard" in s:
        out["dashboard"] = s["dashboard"]
    if "panels" in want:
        out["panels"] = _panel_keys(g)
    if "lockscreen" in want and "lockscreen" in s:
        out["lockscreen"] = s["lockscreen"]
    return out


def summary(sections: dict[str, Any]) -> dict[str, Any]:
    info: dict[str, Any] = {}
    bar_sec = sections.get("bar")
    bar_sec_dict = cast(dict[str, Any], bar_sec) if isinstance(bar_sec, dict) else {}
    bar_val = bar_sec_dict.get("bar")
    bar = cast(dict[str, Any], bar_val) if isinstance(bar_val, dict) else {}
    if bar:
        blocks_val = bar.get("blocks")
        blocks: list[Any] = cast(list[Any], blocks_val) if isinstance(blocks_val, list) else []
        if bar.get("edgeVersion") == 2:
            used = {str(cast(dict[str, Any], b).get("edge", "top")) for b in blocks if isinstance(b, dict) and cast(dict[str, Any], b).get("items")}
        else:
            bar_side = str(bar.get("side", "top"))
            dock_val = bar.get("dock")
            dock_dict = cast(dict[str, Any], dock_val) if isinstance(dock_val, dict) else {}
            dock_side = str(dock_dict.get("side", "bottom"))
            used = {bar_side if cast(dict[str, Any], b).get("edge", "top") != "bottom" else dock_side
                    for b in blocks if isinstance(b, dict) and cast(dict[str, Any], b).get("items")}
        info["barSide"] = " + ".join(s for s in ("top", "right", "bottom", "left") if s in used) or "top"
        info["barItems"] = sum(len(cast(list[Any], cast(dict[str, Any], b).get("items")) or []) for b in blocks if isinstance(b, dict))
    w = sections.get("widgets")
    if isinstance(w, dict):
        w_dict = cast(dict[str, Any], w)
        info["widgets"] = sum(1 for k, v in w_dict.items() if k.startswith("show") and k != "showWidgets" and v is True)
    d = sections.get("dashboard")
    if isinstance(d, dict):
        d_dict = cast(dict[str, Any], d)
        items_val = d_dict.get("items")
        info["dashboardItems"] = len(cast(list[Any], items_val) or []) if isinstance(items_val, list) else 0
    p = sections.get("panels")
    if isinstance(p, dict):
        p_dict = cast(dict[str, Any], p)
        info["launcherStyle"] = p_dict.get("launcherStyle", "")
        info["clipboardStyle"] = p_dict.get("clipboardStyle", "")
        info["notifStyle"] = p_dict.get("notifPopupStyle", "")
    ls = sections.get("lockscreen")
    if isinstance(ls, dict):
        ls_dict = cast(dict[str, Any], ls)
        info["lockLayout"] = ls_dict.get("layout", "")
    return info


def _doc(name: str, sections: dict[str, Any]) -> dict[str, Any]:
    return {"nebulaLayout": FORMAT, "name": name, "saved": datetime.now().isoformat(timespec="seconds"),
            "sections": sections}


def _atomic_json(path: Path, obj: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=path.parent, suffix=".tmp")
    with os.fdopen(fd, "w") as f:
        json.dump(obj, f, indent=2)
    os.replace(tmp, path)


def _resolve(ref: str) -> Path:
    p = Path(ref).expanduser()
    if p.suffix == ".json" and p.is_file():
        return p
    return DIR / f"{slug(ref)}.json"


def _load_doc(path: Path) -> dict[str, Any]:
    raw: Any = json.loads(path.read_text())
    if not isinstance(raw, dict):
        raise ValueError(f"{path.name} is not a Nebula layout")
    doc = cast(dict[str, Any], raw)
    sections = doc.get("sections")
    if not isinstance(sections, dict):
        raise ValueError(f"{path.name} is not a Nebula layout")
    if int(doc.get("nebulaLayout", 0)) > FORMAT:
        raise ValueError(f"{path.name} was made by a newer Nebula")
    return doc


def _get_active() -> str | None:
    try:
        ref = ACTIVE.read_text().strip()
    except Exception:
        return None
    return ref if ref and (DIR / f"{ref}.json").is_file() else None


def _set_active(ref: str | None) -> None:
    if ref:
        DIR.mkdir(parents=True, exist_ok=True)
        _ = ACTIVE.write_text(ref)
    elif ACTIVE.exists():
        ACTIVE.unlink()


def _covers(now: Any, saved: Any) -> bool:
    if isinstance(saved, dict):
        saved_dict = cast(dict[str, Any], saved)
        if not isinstance(now, dict):
            return False
        now_dict = cast(dict[str, Any], now)
        return all(k in now_dict and _covers(now_dict[k], v) for k, v in saved_dict.items())
    return bool(now == saved)


def _tracked(sections: dict[str, Any]) -> dict[str, Any]:
    return {k: v for k, v in sections.items() if k in SECTIONS}


def _differs(sections: dict[str, Any], now: dict[str, Any] | None = None) -> bool:
    tracked = _tracked(sections)
    now_captured = now if now is not None else capture(list(tracked.keys()))
    return any(not _covers(now_captured.get(k), v) for k, v in tracked.items())


def save(name: str, only: list[str] | None = None) -> int:
    sections = capture(only)
    if not sections:
        print("[nebula] nothing to save", file=sys.stderr)
        return 1
    path = DIR / f"{slug(name)}.json"
    _atomic_json(path, _doc(name.strip() or "Layout", sections))
    _set_active(path.stem)
    print(str(path))
    return 0


def update(ref: str) -> int:
    path = _resolve(ref)
    if path.parent != DIR or not path.is_file():
        print(f"[nebula] no layout '{ref}'", file=sys.stderr)
        return 1
    try:
        doc = _load_doc(path)
    except Exception as e:
        print(f"[nebula] {e}", file=sys.stderr)
        return 1
    doc_sections = cast(dict[str, Any], doc["sections"])
    sections = capture(list(_tracked(doc_sections).keys()))
    if not sections:
        print("[nebula] nothing to save", file=sys.stderr)
        return 1
    _atomic_json(path, _doc(str(doc.get("name", path.stem)), sections))
    _set_active(path.stem)
    print(str(path))
    return 0


def _patch(sections: dict[str, Any], want: set[str]) -> tuple[dict[str, Any], list[str]]:
    patch: dict[str, Any] = {}
    general: dict[str, Any] = {}
    applied: list[str] = []
    if "bar" in want and "bar" in sections:
        bar_sec = cast(dict[str, Any], sections["bar"])
        if "bar" in bar_sec:
            patch["bar"] = bar_sec["bar"]
        if "dock" in bar_sec:
            patch["dock"] = bar_sec["dock"]
        gen_val = bar_sec.get("general")
        if isinstance(gen_val, dict):
            general.update(cast(dict[str, Any], gen_val))
        applied.append("bar")
    if "widgets" in want and "widgets" in sections:
        patch["widgets"] = sections["widgets"]
        applied.append("widgets")
    for key in ("dashboard", "lockscreen"):
        if key in want and key in sections:
            patch[key] = sections[key]
            applied.append(key)
    if "panels" in want and "panels" in sections:
        panels_val = sections["panels"]
        if isinstance(panels_val, dict):
            general.update(cast(dict[str, Any], panels_val))
        applied.append("panels")
    if general:
        patch["general"] = general
    return patch, applied


def apply_sections(sections: dict[str, Any], only: list[str] | set[str] | None = None, emit: bool = False) -> list[str]:
    want = set(only or SECTIONS)
    patch, applied = _patch(sections, want)
    if emit:
        print(json.dumps({"apply": patch, "sections": applied}), flush=True)
    else:
        s = _read_settings()
        to_write: dict[str, Any] = {}
        for key, value in patch.items():
            if key == "general":
                to_write["general"] = value
            elif key == "widgets":
                raw_cur = s.get("widgets")
                cur = cast(dict[str, Any], raw_cur) if isinstance(raw_cur, dict) else {}
                val_dict = cast(dict[str, Any], value) if isinstance(value, dict) else {}
                to_write["widgets"] = {**val_dict, **{k: v for k, v in cur.items() if k in WIDGET_DATA}}
            else:
                to_write[key] = value
        _write_settings(to_write, replace_sections={k for k in to_write if k != "general"})
    return applied


def load(ref: str, only: list[str] | None = None, emit: bool = False) -> int:
    path = _resolve(ref)
    if not path.is_file():
        print(f"[nebula] no layout '{ref}'", file=sys.stderr)
        return 1
    try:
        doc = _load_doc(path)
    except Exception as e:
        print(f"[nebula] {e}", file=sys.stderr)
        return 1
    doc_sections = cast(dict[str, Any], doc["sections"])
    touched = [k for k in _tracked(doc_sections) if not only or k in only]
    before = _doc("Before " + str(doc.get("name", path.stem)), capture(touched))
    before["active"] = _get_active()
    _atomic_json(PREVIOUS, before)
    applied = apply_sections(doc_sections, only, emit)
    _set_active(path.stem if path.parent == DIR else None)
    print(json.dumps({"loaded": doc.get("name", path.stem), "sections": applied}))
    return 0


def undo(emit: bool = False) -> int:
    if not PREVIOUS.is_file():
        print("[nebula] nothing to undo", file=sys.stderr)
        return 1
    doc = _load_doc(PREVIOUS)
    doc_sections = cast(dict[str, Any], doc["sections"])
    applied = apply_sections(doc_sections, emit=emit)
    PREVIOUS.unlink()
    raw_active = doc.get("active")
    _set_active(str(raw_active) if raw_active is not None else None)
    print(json.dumps({"restored": doc.get("name", ""), "sections": applied}))
    return 0


def delete(ref: str) -> int:
    path = _resolve(ref)
    if path.parent != DIR or not path.is_file():
        print(f"[nebula] no layout '{ref}'", file=sys.stderr)
        return 1
    path.unlink()
    if _get_active() is None:
        _set_active(None)
    return 0


def import_file(src: str, name: str | None = None) -> int:
    p = Path(src).expanduser()
    try:
        doc = _load_doc(p)
    except Exception as e:
        print(f"[nebula] {e}", file=sys.stderr)
        return 1
    if name:
        doc["name"] = name
    raw_name = doc.get('name')
    doc_name = str(raw_name) if raw_name is not None else p.stem
    dest = DIR / f"{slug(doc_name)}.json"
    _atomic_json(dest, doc)
    print(str(dest))
    return 0


def export(ref: str, dest: str) -> int:
    path = _resolve(ref)
    if not path.is_file():
        print(f"[nebula] no layout '{ref}'", file=sys.stderr)
        return 1
    out = Path(dest).expanduser()
    if out.is_dir():
        out = out / path.name
    _ = shutil.copyfile(path, out)
    print(str(out))
    return 0


def entries() -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    active = _get_active()
    now = capture()
    docs: dict[str, dict[str, Any]] = {}
    if DIR.is_dir():
        for p in sorted(DIR.glob("*.json")):
            if p.name.startswith("."):
                continue
            try:
                doc = _load_doc(p)
            except Exception:
                continue
            docs[p.stem] = doc
            doc_sections = cast(dict[str, Any], doc["sections"])
            rows.append({"id": p.stem, "name": str(doc.get("name", p.stem)), "file": str(p),
                         "saved": str(doc.get("saved", "")), "sections": list(_tracked(doc_sections).keys()),
                         "current": p.stem == active,
                         "modified": p.stem == active and _differs(doc_sections, now),
                         **summary(doc_sections)})
    rows.sort(key=lambda r: str(r["saved"]), reverse=True)
    if active is None:
        for r in rows:
            r_id = str(r["id"])
            if not _differs(cast(dict[str, Any], docs[r_id]["sections"]), now):
                r["current"] = True
                break
    return rows


def print_list(as_json: bool) -> int:
    rows = entries()
    if as_json:
        current = next((str(r["id"]) for r in rows if r["current"]), "")
        print(json.dumps({"dir": str(DIR), "canUndo": PREVIOUS.is_file(), "active": current, "layouts": rows}))
        return 0
    if not rows:
        print(f"No layouts yet. Save one with `nebula layout save <name>` ({DIR})")
        return 0
    for r in rows:
        r_sections = cast(list[str], r["sections"])
        parts = [LABELS[s] for s in r_sections if s in LABELS]
        mark = "*" if r["current"] else " "
        saved_str = str(r["saved"])
        print(f"{mark} {str(r['name']):<24} {saved_str[:16].replace('T', ' ')}   {', '.join(parts)}")
    return 0
