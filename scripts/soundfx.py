#!/usr/bin/env python3
import json
import math
import os
import shutil
import subprocess
import sys
import tempfile
import time
from typing import Any, TypedDict, cast

PRESET = "Nebula"
OUT_DIR = os.path.join(os.environ.get("XDG_CONFIG_HOME", os.path.expanduser("~/.config")), "easyeffects", "output")

BANDS: list[tuple[str, float, float]] = [
    ("Lo-shelf", 80.0, 0.7),
    ("Bell", 250.0, 0.9),
    ("Bell", 1000.0, 0.9),
    ("Bell", 3000.0, 1.0),
    ("Bell", 6000.0, 1.0),
    ("Hi-shelf", 10000.0, 0.7),
]


class StyleConfig(TypedDict):
    eq: list[float]
    enhance: tuple[float, float]
    night: bool


STYLES: dict[str, StyleConfig] = {
    "flat": {"eq": [0.0, 0.0, 0.0, 0.0, 0.0, 0.0], "enhance": (0.0, 0.0), "night": False},
    "boost": {"eq": [6.0, 1.0, 0.0, 0.0, 0.0, 1.0], "enhance": (8.0, 3.0), "night": False},
    "warm": {"eq": [3.0, 2.0, 0.0, -1.0, -2.0, -1.5], "enhance": (3.0, 1.0), "night": False},
    "clear": {"eq": [-1.0, -2.0, 1.0, 3.0, 2.0, 2.0], "enhance": (0.0, 0.0), "night": False},
    "night": {"eq": [2.0, 0.0, 1.0, 2.0, 0.0, 0.0], "enhance": (2.0, 0.0), "night": True},
}


def env() -> dict[str, str]:
    e = dict(os.environ)
    _ = e.pop("LD_PRELOAD", None)
    return e


def detect() -> str:
    try:
        out = subprocess.run(["pactl", "--format=json", "list", "sinks"], capture_output=True, text=True, timeout=5, env=env()).stdout
        sinks_raw: Any = json.loads(out or "[]")
        sinks: list[dict[str, Any]] = cast(list[dict[str, Any]], sinks_raw) if isinstance(sinks_raw, list) else []
    except Exception:
        return "speakers"
    for s in sinks:
        props_raw = s.get("properties", {})
        props: dict[str, Any] = cast(dict[str, Any], props_raw) if isinstance(props_raw, dict) else {}
        if props.get("device.bus") == "bluetooth" or str(s.get("name", "")).startswith("bluez_"):
            return "headphones"
    for s in sinks:
        port = str(s.get("active_port") or "").lower()
        if "headphone" in port or "headset" in port:
            return "headphones"
    return "speakers"


def band(kind: str, freq: float, q: float, gain: float) -> dict[str, Any]:
    return {"type": kind, "mode": "RLC (BT)", "slope": "x1", "solo": False, "mute": False,
            "gain": round(gain, 2), "frequency": freq, "q": q, "width": 4.0}


def preset(style: str, bass: float, treble: float, target: str) -> dict[str, Any]:
    s = STYLES.get(style, STYLES["boost"])
    gains = list(s["eq"])
    gains[0] += bass
    gains[5] += treble
    if target == "speakers":
        gains[0] = min(gains[0], 3.0) + max(0.0, gains[0] - 3.0) * 0.25
    channel = {f"band{i}": band(k, f, q, gains[i]) for i, (k, f, q) in enumerate(BANDS)}
    headroom = -round(max(0.0, max(gains)) * 0.6, 2)

    speak, phones = s["enhance"]
    amount = speak if target == "speakers" else phones
    if target == "speakers":
        amount += max(0.0, bass) * 0.6
    else:
        amount += max(0.0, bass) * 0.15
    amount = round(min(amount, 14.0), 2)

    order: list[str] = ["equalizer#0"]
    out: dict[str, Any] = {
        "blocklist": [],
        "equalizer#0": {
            "bypass": False, "input-gain": headroom, "output-gain": 0.0, "mode": "IIR", "decramp": "Off",
            "split-channels": False, "balance": 0.0, "pitch-left": 0.0, "pitch-right": 0.0,
            "num-bands": len(BANDS), "left": channel, "right": json.loads(json.dumps(channel)),
        },
    }
    if amount > 0.05:
        order.append("bass_enhancer#0")
        out["bass_enhancer#0"] = {
            "bypass": False, "input-gain": 0.0, "output-gain": 0.0, "amount": amount,
            "harmonics": 8.5 if target == "speakers" else 6.0, "scope": 120.0 if target == "speakers" else 90.0,
            "floor": 20.0, "blend": 0.0, "floor-active": False,
        }
    order.append("limiter#0")
    out["limiter#0"] = {
        "bypass": False, "mode": "Herm Thin", "oversampling": "None", "dithering": "None", "sidechain-type": "Internal",
        "input-gain": 10.0 if s["night"] else 0.0, "output-gain": 0.0,
        "lookahead": 5.0, "attack": 5.0, "release": 40.0 if s["night"] else 20.0,
        "threshold": -14.0 if s["night"] else -1.0, "gain-boost": False, "stereo-link": 100.0,
    }
    out["plugins_order"] = order
    return {"output": out}


def running() -> bool:
    return subprocess.run(["pgrep", "-x", "easyeffects"], capture_output=True).returncode == 0


def apply(style: str, bass: float, treble: float, target: str) -> int:
    if not math.isfinite(bass) or not math.isfinite(treble):
        print(json.dumps({"ok": False, "error": "bass and treble must be finite"}))
        return 1
    if shutil.which("easyeffects") is None:
        print(json.dumps({"ok": False, "error": "missing"}))
        return 1
    if target not in ("speakers", "headphones"):
        target = detect()
    os.makedirs(OUT_DIR, exist_ok=True)
    path = os.path.join(OUT_DIR, PRESET + ".json")
    tmp = None
    try:
        with tempfile.NamedTemporaryFile(mode="w", dir=OUT_DIR, suffix=".tmp", delete=False) as f:
            tmp = f.name
            json.dump(preset(style, bass, treble, target), f, indent=4, allow_nan=False)
        os.replace(tmp, path)
    finally:
        if tmp and os.path.exists(tmp):
            os.unlink(tmp)
    if not running():
        _ = subprocess.Popen(["easyeffects", "--service-mode", "-w"], env=env(), start_new_session=True,
                             stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        for _ in range(40):
            time.sleep(0.25)
            if running():
                break
        time.sleep(1.5)
    _ = subprocess.run(["easyeffects", "-b", "2"], env=env(), capture_output=True, timeout=10)
    _ = subprocess.run(["easyeffects", "-l", PRESET], env=env(), capture_output=True, timeout=10)
    print(json.dumps({"ok": True, "target": target}))
    return 0


def off() -> int:
    if running():
        _ = subprocess.run(["easyeffects", "-q"], env=env(), capture_output=True, timeout=10)
    print(json.dumps({"ok": True, "off": True}))
    return 0


def main(argv: list[str]) -> int:
    if len(argv) >= 2 and argv[1] == "detect":
        print(detect())
        return 0
    if len(argv) >= 2 and argv[1] == "off":
        return off()
    if len(argv) >= 6 and argv[1] == "apply":
        try:
            bass = float(argv[3])
            treble = float(argv[4])
        except ValueError:
            bass = treble = 0.0
        if math.isfinite(bass) and math.isfinite(treble):
            bass = max(-6.0, min(12.0, bass))
            treble = max(-6.0, min(9.0, treble))
        return apply(argv[2], bass, treble, argv[5])
    print("usage: soundfx.py detect | off | apply STYLE BASS TREBLE TARGET", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
