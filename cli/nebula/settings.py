import json
import os
import sys
import tempfile
import time
from contextlib import suppress
from pathlib import Path
from typing import Any, cast

from nebula.paths import CONFIG_DIR, dropin_files

Settings = dict[str, Any]


class CorruptSettingsError(ValueError):
    """The main settings.json exists but is not a valid JSON object."""


def _user_settings_path() -> Path:
    return CONFIG_DIR / "settings.json"


def write_atomic(path: Path, text: str) -> None:
    target = path.resolve() if path.is_symlink() else path
    with suppress(OSError, UnicodeDecodeError):
        if target.read_text() == text:
            return
    target.parent.mkdir(parents=True, exist_ok=True)
    mode = target.stat().st_mode & 0o7777 if target.exists() else 0o644
    fd, tmp = tempfile.mkstemp(dir=target.parent, prefix=f".{target.name}.")
    try:
        with os.fdopen(fd, "w") as f:
            _ = f.write(text)
        os.chmod(tmp, mode)
        os.replace(tmp, target)
    except BaseException:
        with suppress(OSError):
            os.unlink(tmp)
        raise


def _read_json(path: Path) -> Settings:
    try:
        data: Any = json.loads(path.read_text())
    except (OSError, ValueError):
        return {}
    return cast(Settings, data) if isinstance(data, dict) else {}


def _backup_corrupt(path: Path) -> Path | None:
    ts = time.strftime("%Y%m%d-%H%M%S")
    try:
        fd, tmp = tempfile.mkstemp(prefix=f"{path.name}.corrupt-{ts}-", dir=path.parent)
        with os.fdopen(fd, "wb") as out:
            _ = out.write(path.read_bytes())
    except OSError:
        return None
    return Path(tmp)


def load_user() -> Settings:
    path = _user_settings_path()
    try:
        raw = path.read_text()
    except FileNotFoundError:
        return {}
    except OSError as e:
        raise CorruptSettingsError(f"Settings file '{path}' is unreadable ({e}).") from e
    try:
        data: Any = json.loads(raw)
        if not isinstance(data, dict):
            raise ValueError("root of settings must be a JSON object")
    except ValueError as e:
        backup = _backup_corrupt(path)
        where = f" Backed up to '{backup}'." if backup else ""
        raise CorruptSettingsError(f"Settings file '{path}' is corrupt ({e}).{where}") from e
    return cast(Settings, data)


def is_path_locked(locks: set[str], path: str) -> bool:
    parts = path.split(".")
    return any(".".join(parts[:i]) in locks for i in range(1, len(parts) + 1))


def is_key_locked(section_name: str, key: str = "") -> bool:
    path = f"{section_name}.{key}" if key else section_name
    return is_path_locked(get_locks(), path)


def get_locks() -> set[str]:
    locks: set[str] = set()
    for f in dropin_files():
        locked_items = _read_json(f).get("locked")
        if isinstance(locked_items, list):
            for item in cast(list[Any], locked_items):
                if isinstance(item, str) and item.strip():
                    locks.add(item.strip())
    return locks


def _merge_layer(
    target: Settings,
    overlay: Settings,
    prefix: str,
    locks: set[str],
    source_name: str,
    sources: dict[str, str],
    enforce_locks: bool,
) -> None:
    for k, v in overlay.items():
        if not prefix and k == "locked":
            continue
        path = f"{prefix}.{k}" if prefix else k
        if enforce_locks and is_path_locked(locks, path):
            continue
        if isinstance(v, dict):
            target_entry = target.get(k)
            if not isinstance(target_entry, dict):
                target[k] = {}
            _merge_layer(cast(Settings, target[k]), cast(Settings, v), path, locks, source_name, sources, enforce_locks)
        else:
            target[k] = v
            sources[path] = source_name


def _build_effective() -> tuple[Settings, dict[str, str], set[str]]:
    locks = get_locks()
    merged: Settings = {}
    sources: dict[str, str] = {}

    for f in dropin_files():
        _merge_layer(merged, _read_json(f), "", locks, str(f), sources, enforce_locks=False)

    user_file = _user_settings_path()
    _merge_layer(merged, load_user(), "", locks, str(user_file), sources, enforce_locks=True)

    if locks:
        merged["locked"] = sorted(locks)
    return merged, sources, locks


def load() -> Settings:
    merged, _, _ = _build_effective()
    return merged


def section(name: str) -> Settings:
    sec = load().get(name)
    return dict(cast(Settings, sec)) if isinstance(sec, dict) else {}


def update(name: str, patch: Settings, replace: bool = False) -> None:
    locks = get_locks()
    user_data = load_user()
    orig = user_data.get(name)
    original: Settings = cast(Settings, orig) if isinstance(orig, dict) else {}
    sec: Settings = {
        k: v
        for k, v in original.items()
        if not is_path_locked(locks, f"{name}.{k}") and (not replace or k in patch)
    }
    for k, v in patch.items():
        if is_path_locked(locks, f"{name}.{k}"):
            print(f"nebula: warning: setting '{name}.{k}' is locked by administrator; ignoring update", file=sys.stderr)
            continue
        if v is None:
            _ = sec.pop(k, None)
        else:
            sec[k] = v
    if sec == original:
        return
    if sec:
        user_data[name] = sec
    else:
        user_data.pop(name, None)
    write_atomic(_user_settings_path(), json.dumps(user_data, indent=4) + "\n")


def get_source(key: str) -> Settings:
    merged, sources, locks = _build_effective()
    user_path = str(_user_settings_path())

    val: Any = merged
    found = True
    for part in key.split("."):
        if isinstance(val, dict) and part in val:
            val = cast(Settings, val)[part]
        else:
            found = False
            val = None
            break

    src = sources.get(key)
    if src:
        source_type = "user" if src == user_path else "drop-in"
    elif found:
        source_type = "drop-in"
        src = "system drop-in"
    else:
        source_type = "default"
        src = "default"

    return {
        "key": key,
        "value": val,
        "source": src,
        "sourceType": source_type,
        "locked": is_path_locked(locks, key),
    }


def get_all_sources() -> Settings:
    merged, sources, locks = _build_effective()
    user_path = str(_user_settings_path())
    flat: list[Settings] = []

    def flatten(obj: Settings, prefix: str = "") -> None:
        for k, v in sorted(obj.items()):
            if not prefix and k == "locked":
                continue
            path = f"{prefix}.{k}" if prefix else k
            if isinstance(v, dict):
                flatten(cast(Settings, v), path)
            else:
                src = sources.get(path, "default")
                flat.append({
                    "key": path,
                    "value": v,
                    "source": src,
                    "sourceType": "user" if src == user_path else ("drop-in" if src != "default" else "default"),
                    "locked": is_path_locked(locks, path),
                })

    flatten(merged)
    return {
        "dropinFiles": [str(f) for f in dropin_files()],
        "locked": sorted(locks),
        "settings": flat,
    }