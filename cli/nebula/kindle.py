import argparse
from datetime import date, datetime
import html
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import shutil
from string import Template
import subprocess
import sys
import tempfile
import threading
import time
from typing import TYPE_CHECKING, Any, cast, override
from urllib.parse import parse_qs, urlparse

if TYPE_CHECKING:
    from PIL import Image

from nebula import settings
from nebula.paths import CACHE_DIR

WIDTH: int = 600
HEIGHT: int = 800
OUT_DIR: Path = CACHE_DIR / "kindle"
CHROMES: tuple[str, ...] = ("google-chrome-stable", "google-chrome", "chromium", "chromium-browser")
WEATHER_MAX_AGE: int = 45 * 60

SUN: str = '<circle cx="24" cy="24" r="9"></circle><path d="M24 4v6M24 38v6M4 24h6M38 24h6M9.9 9.9l4.2 4.2M33.9 33.9l4.2 4.2M9.9 38.1l4.2-4.2M33.9 14.1l4.2-4.2"></path>'
MOON: str = '<path d="M36 30A15 15 0 0 1 19 8a15 15 0 1 0 17 22z"></path>'
CLOUD: str = '<path d="M14 36h20a8 8 0 0 0 0-16 11 11 0 0 0-21-2A9 9 0 0 0 14 36z"></path>'
PARTLY: str = '<path d="M17 8v3M8.5 11.5l2 2M5 20h3M25.5 11.5l-2 2"></path><path d="M11 22a6 6 0 0 1 11.6-2.2"></path><path d="M18 40h18a7 7 0 0 0 0-14 9.5 9.5 0 0 0-18-1.5A7.8 7.8 0 0 0 18 40z"></path>'
RAIN: str = '<path d="M14 30h20a8 8 0 0 0 0-16 11 11 0 0 0-21-2A9 9 0 0 0 14 30z"></path><path d="M16 36l-2 6M24 36l-2 6M32 36l-2 6"></path>'
STORM: str = '<path d="M14 30h20a8 8 0 0 0 0-16 11 11 0 0 0-21-2A9 9 0 0 0 14 30z"></path><path d="M25 32l-5 7h6l-4 7"></path>'
SNOW: str = '<path d="M14 30h20a8 8 0 0 0 0-16 11 11 0 0 0-21-2A9 9 0 0 0 14 30z"></path><path d="M17 37v6M14 40h6M31 37v6M28 40h6"></path>'
FOG: str = '<path d="M8 18h32M6 26h36M10 34h28"></path>'

PAGE: Template = Template("""<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<style>
html,body{margin:0;background:#FFFFFF}
body{width:600px;height:800px;overflow:hidden;font-family:Rubik,sans-serif;color:#000000}
.page{width:600px;height:800px;box-sizing:border-box;padding:32px 36px 28px;display:flex;flex-direction:column;gap:16px}
.display{font-family:'Titan One',sans-serif}
.row{display:flex}
.chip{border:2px solid #000000;border-radius:14px;padding:10px 12px;display:flex;flex-direction:column;gap:2px}
.chip .k{font-size:15px;font-weight:500;color:#222222}
.chip .v{font-size:26px;font-weight:600}
.chip .u{font-size:15px}
.cap{font-size:15px;font-weight:600;letter-spacing:1.5px;color:#000000}
.bar{display:flex;flex-direction:column;align-items:center;justify-content:flex-end;gap:6px;height:136px}
.bar .t{font-size:17px;font-weight:600}
.bar .b{width:100%;border-radius:8px 8px 3px 3px}
.bar .l{font-size:15px;font-weight:500;color:#222222}
.sun{flex:1;display:flex;align-items:center;gap:8px;background:#DDDDDD;border-radius:12px;padding:10px 12px;font-size:18px}
.day{border:2px solid #000000;border-radius:14px;padding:12px 14px;display:flex;align-items:center;justify-content:space-between}
</style></head>
<body><div class="page">
<div class="row" style="justify-content:space-between;align-items:flex-end">
<div style="display:flex;flex-direction:column;gap:2px">
<div class="display" style="font-size:46px;line-height:1">$weekday</div>
<div style="font-size:22px;font-weight:500;color:#111111">$longdate</div>
</div>
<div style="display:flex;flex-direction:column;align-items:flex-end;gap:4px;font-size:16px;color:#222222">
<div style="font-weight:600;color:#000000">$place</div>
<div>$stamp</div>
</div>
</div>
<div class="row" style="align-items:center;gap:22px;border-top:3px solid #000000;padding-top:18px">
<svg data-slot="icon" width="118" height="118" viewBox="0 0 48 48" fill="none" stroke="#000000" stroke-width="3" stroke-linecap="round" stroke-linejoin="round">$icon</svg>
<div class="display" style="font-size:150px;line-height:0.9">$temp</div>
<div style="display:flex;flex-direction:column;gap:6px;margin-left:auto;text-align:right">
<div style="font-size:30px;font-weight:600">$desc</div>
<div style="font-size:20px;font-weight:500;color:#111111">$feels</div>
<div style="font-size:20px;font-weight:500;color:#111111">$hilo</div>
</div>
</div>
<div style="display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:10px">
<div class="chip"><div class="k">Humidity</div><div class="v">$humidity</div></div>
<div class="chip"><div class="k">Wind</div><div class="v">$wind <span class="u">$windunit</span></div></div>
<div class="chip"><div class="k">UV</div><div class="v">$uv</div></div>
<div class="chip"><div class="k">Rain</div><div class="v">$rain</div></div>
</div>
<div style="display:flex;flex-direction:column;gap:8px">
<div class="cap">TODAY</div>
<div style="display:grid;grid-template-columns:repeat(8,minmax(0,1fr));gap:8px;align-items:end;height:136px">$bars</div>
</div>
<div class="row" style="gap:10px">
<div class="sun"><svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#000000" stroke-width="2" stroke-linecap="round"><path d="M4 18h16M7 18a5 5 0 0 1 10 0M12 4v4M9.5 6.5 12 4l2.5 2.5"></path></svg>$sunrise</div>
<div class="sun"><svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#000000" stroke-width="2" stroke-linecap="round"><path d="M4 18h16M7 18a5 5 0 0 1 10 0M12 8V4M9.5 5.5 12 8l2.5-2.5"></path></svg>$sunset</div>
<div class="sun" style="flex:1.3">$daylight</div>
</div>
<div style="display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:10px">$days</div>
$footer
</div>$probe</body></html>
""")


def load_settings() -> dict[str, Any]:
    try:
        return settings.load()
    except Exception:
        return {}


def weather_data(settings_map: dict[str, Any]) -> dict[str, Any]:
    from nebula import weather as w
    w_any: Any = w
    cache: dict[str, Any] = cast(dict[str, Any], w_any.load_cache())
    weather_cfg: dict[str, Any] = settings_map.get("weather", {}) if isinstance(settings_map.get("weather"), dict) else {}
    name: str = str(weather_cfg.get("location") or cache.get("location") or "").strip()
    try:
        age: float | None = time.time() - Path(w.CACHE).stat().st_mtime
    except OSError:
        age = None
    stale = age is None or age > WEATHER_MAX_AGE or cache.get("location") != name
    if stale and name:
        try:
            lat, lon, area = w_any.geocode(name, cache)
            cache = {"location": name, "lat": lat, "lon": lon, "area": area, "data": w_any.build(name, lat, lon, area)}
            w_any.save_cache(cache)
        except (OSError, ValueError, KeyError, LookupError, TypeError, IndexError):
            pass
    return cache


def next_holiday(today: date) -> tuple[date, str] | None:
    from nebula import holidays as h
    general_cfg: dict[str, Any] = load_settings().get("general", {}) if isinstance(load_settings().get("general"), dict) else {}
    h_country: Any = general_cfg.get("holidayCountry") or h.detect_country() or ""
    cc = str(h_country).upper()
    rows: list[dict[str, Any]] = []
    for year in (today.year, today.year + 1):
        try:
            with open(Path(h.CACHE_DIR) / f"{cc}-{year}.json") as f:
                loaded: Any = json.load(f)
                if isinstance(loaded, list):
                    loaded_list: list[Any] = cast(list[Any], loaded)
                    for item in loaded_list:
                        if isinstance(item, dict):
                            rows.append(cast(dict[str, Any], item))
        except (OSError, ValueError):
            pass
    for r in sorted(rows, key=lambda row: str(row.get("date", ""))):
        try:
            d = date.fromisoformat(str(r["date"]))
        except (KeyError, ValueError):
            continue
        if d >= today:
            return d, str(r.get("name", ""))
    return None


def icon_for(code: Any, desc: str) -> str:
    c = str(code)
    if desc == "Clear":
        return MOON
    if c == "113":
        return SUN
    if c == "116":
        return PARTLY
    if c in ("248", "260"):
        return FOG
    if c in ("386", "389"):
        return STORM
    if c in ("179", "326", "332", "338", "368", "371"):
        return SNOW
    if c == "122":
        return CLOUD
    return RAIN


def clock24(text: str) -> str:
    try:
        return datetime.strptime(text.strip(), "%I:%M %p").strftime("%H:%M")
    except ValueError:
        return text


def minutes(hhmm: str) -> int:
    h, m = hhmm.split(":")
    return int(h) * 60 + int(m)


def summary(desc: str) -> str:
    words = {"Overcast": "Cloudy", "Mainly clear": "Mostly sunny"}
    return words.get(desc, desc)


def day_label(hourly: list[dict[str, Any]]) -> str:
    descs: list[str] = []
    for x in hourly:
        raw_desc: Any = x.get("weatherDesc")
        if isinstance(raw_desc, list) and raw_desc and isinstance(raw_desc[0], dict):
            item: dict[str, Any] = cast(dict[str, Any], raw_desc[0])
            val: Any = item.get("value")
            if isinstance(val, str):
                descs.append(val)
    if any("rain" in d.lower() or "thunder" in d.lower() for d in descs):
        return "Rain likely"
    late = descs[len(descs) // 2:]
    if any(d in ("Overcast", "Partly cloudy") for d in late) and descs and descs[0] in ("Sunny", "Clear", "Mainly clear"):
        return "Clouds later"
    if not descs:
        return ""
    desc_set: set[str] = set(descs)
    common: str = max(desc_set, key=lambda d: descs.count(d))
    return summary(common)


PROBE: str = """<style>body.tpl [data-slot]{color:transparent!important}body.tpl svg[data-slot]{visibility:hidden}body.tpl .bar .b{visibility:hidden}</style>
<script>
(function () {
  var out = [];
  var els = document.querySelectorAll('[data-slot]');
  for (var i = 0; i < els.length; i++) {
    var e = els[i], r = e.getBoundingClientRect(), cs = getComputedStyle(e);
    out.push({slot: e.getAttribute('data-slot'), align: e.getAttribute('data-align') || 'left',
              x: r.left, y: r.top, w: r.width, h: r.height, right: r.right,
              size: parseFloat(cs.fontSize), family: cs.fontFamily, weight: cs.fontWeight, color: cs.color});
  }
  var bars = document.querySelectorAll('.bar .b');
  for (var j = 0; j < bars.length; j++) {
    var b = bars[j].getBoundingClientRect();
    out.push({slot: 'col' + j, x: b.left, y: b.bottom, w: b.width, h: 0});
  }
  var pre = document.createElement('pre');
  pre.id = 'rects';
  pre.textContent = JSON.stringify(out);
  document.body.appendChild(pre);
  document.body.className = 'tpl';
})();
</script>"""


def build_html(battery: int | None = None, slots: bool = False) -> str:
    def sl(name: str, value: str, align: str = "left") -> str:
        if not slots:
            return value
        return f'<span data-slot="{name}" data-align="{align}">{value}</span>'

    settings_map = load_settings()
    weather_cfg: dict[str, Any] = settings_map.get("weather", {}) if isinstance(settings_map.get("weather"), dict) else {}
    metric = bool(weather_cfg.get("useMetric", True))
    cache = weather_data(settings_map)
    raw_data: Any = cache.get("data")
    data: dict[str, Any] = cast(dict[str, Any], raw_data) if isinstance(raw_data, dict) else {}
    now = datetime.now()
    today = now.date()
    u = "C" if metric else "F"

    raw_cur: Any = data.get("current_condition")
    cur_list: list[dict[str, Any]] = cast(list[dict[str, Any]], raw_cur) if isinstance(raw_cur, list) else [{}]
    cur: dict[str, Any] = cur_list[0] if cur_list else {}
    raw_days: Any = data.get("weather")
    days: list[dict[str, Any]] = cast(list[dict[str, Any]], raw_days) if isinstance(raw_days, list) else []
    t0: dict[str, Any] = days[0] if days else {}
    raw_hourly: Any = t0.get("hourly")
    hourly: list[dict[str, Any]] = cast(list[dict[str, Any]], raw_hourly) if isinstance(raw_hourly, list) else []
    slot = min(now.hour // 3, max(len(hourly) - 1, 0))
    rain_now = str(hourly[slot].get("chanceofrain", "0")) if hourly else "0"

    raw_desc_list: Any = cur.get("weatherDesc")
    desc_list: list[dict[str, Any]] = cast(list[dict[str, Any]], raw_desc_list) if isinstance(raw_desc_list, list) else []
    desc = str(desc_list[0]["value"]) if desc_list and "value" in desc_list[0] else ""
    temps = [int(h.get(f"temp{u}", 0)) for h in hourly] or [0]
    lo, hi = min(temps) - 4, max(temps) + 1
    bars: list[str] = []
    for i, h in enumerate(hourly):
        t = int(h.get(f"temp{u}", 0))
        px = round(14 + (t - lo) / max(hi - lo, 1) * 70)
        fill = "#000000" if i == slot else "#999999"
        bars.append(f'<div class="bar"><div class="t">{sl(f"bart{i}", f"{t}°", "center")}</div><div class="b" style="height:{px}px;background:{fill}"></div>'
                    + f'<div class="l">{int(h.get("time", "0")) // 100:02d}</div></div>')

    astro_list: Any = t0.get("astronomy")
    astro: dict[str, Any] = cast(dict[str, Any], astro_list[0]) if isinstance(astro_list, list) and astro_list and isinstance(astro_list[0], dict) else {}
    rise, sets = clock24(str(astro.get("sunrise", ""))), clock24(str(astro.get("sunset", "")))
    try:
        span = minutes(sets) - minutes(rise)
        daylight = f"{span // 60} h {span % 60:02d} m light"
    except ValueError:
        daylight = ""

    cards: list[str] = []
    for n, d in enumerate(days[1:3], start=1):
        name = date.fromisoformat(str(d["date"])).strftime("%A")
        raw_d_hourly: Any = d.get("hourly")
        hourly_d: list[dict[str, Any]] = cast(list[dict[str, Any]], raw_d_hourly) if isinstance(raw_d_hourly, list) else []
        cards.append(f'<div class="day"><div style="display:flex;flex-direction:column"><div style="font-size:20px;font-weight:600">{sl(f"d{n}name", name)}</div>'
                     + f'<div style="font-size:15px;font-weight:500;color:#222222">{sl(f"d{n}desc", html.escape(day_label(hourly_d)))}</div></div>'
                     + f'<div style="font-size:22px;font-weight:600">{sl(f"d{n}hi", str(d.get(f"maxtemp{u}", "")) + "°", "right")} '
                     + f'<span style="color:#444444">{sl(f"d{n}lo", str(d.get(f"mintemp{u}", "")) + "°", "right")}</span></div></div>')

    footer = ""
    hol = next_holiday(today)
    if hol or slots:
        hd, hname = hol or (today, "")
        when = "Today" if hd == today else "Tomorrow" if (hd - today).days == 1 else hd.strftime("%a %-d %b")
        ftag = 'data-slot="footer" data-align="box" ' if slots else ""
        footer = (f'<div {ftag}style="margin-top:auto;display:flex;align-items:center;gap:10px;background:#000000;color:#FFFFFF;border-radius:14px;padding:12px 16px;font-size:18px">'
                  + '<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#FFFFFF" stroke-width="2" stroke-linecap="round"><rect x="3" y="5" width="18" height="16" rx="3"></rect><path d="M3 10h18M8 3v4M16 3v4"></path></svg>'
                  + f'<div style="font-weight:600;white-space:nowrap">{sl("when", when)}</div><div style="color:#FFFFFF;white-space:nowrap;overflow:hidden;text-overflow:ellipsis">{sl("hname", html.escape(hname) or "Holiday")}</div></div>')

    stamp = f"updated {now:%H:%M}"
    if battery is not None:
        stamp += f" · kindle {battery}%"
    wind = str(cur.get("windspeedKmph", "0"))
    if not metric:
        wind = str(round(int(wind or 0) * 0.621371))

    return PAGE.substitute(
        weekday=sl("weekday", now.strftime("%A")),
        longdate=sl("longdate", now.strftime("%-d %B %Y")),
        place=sl("place", html.escape(str(cache.get("location") or "")), "right"),
        stamp=sl("stamp", stamp, "right"),
        icon=icon_for(cur.get("weatherCode", ""), desc),
        temp=sl("temp", f"{cur.get(f'temp_{u}', '–')}°"),
        desc=sl("desc", html.escape(summary(desc)), "right"),
        feels=sl("feels", f"feels {cur.get(f'FeelsLike{u}', '–')}°", "right"),
        hilo=sl("hilo", f"↑ {t0.get(f'maxtemp{u}', '–')}°&nbsp;&nbsp;↓ {t0.get(f'mintemp{u}', '–')}°", "right"),
        humidity=sl("humidity", f"{cur.get('humidity', '–')}%"),
        wind=sl("wind", wind),
        windunit=sl("windunit", "km/h" if metric else "mph"),
        uv=sl("uv", str(cur.get("uvIndex", "–"))),
        rain=sl("rain", f"{rain_now}%"),
        bars="".join(bars),
        sunrise=sl("sunrise", rise),
        sunset=sl("sunset", sets),
        daylight=sl("daylight", daylight),
        days="".join(cards),
        footer=footer,
        probe=PROBE if slots else "",
    )


def chrome() -> str | None:
    for name in CHROMES:
        path = shutil.which(name)
        if path:
            return path
    return None


def screenshot(page_html: str, width: int, height: int) -> "Image.Image":
    from PIL import Image
    exe = chrome()
    if not exe:
        raise RuntimeError("no Chrome or Chromium found")
    with tempfile.TemporaryDirectory(prefix="nebula-kindle-") as tmp:
        page = Path(tmp) / "page.html"
        shot = Path(tmp) / "shot.png"
        _ = page.write_text(page_html, encoding="utf-8")
        shoot(exe, page, shot, width, height, tmp)
        return Image.open(shot).convert("L").crop((0, 0, width, height))


def render(out: Path | str, battery: int | None = None) -> Path:
    out_path = Path(out)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    img = snap(screenshot(build_html(battery), WIDTH, HEIGHT))
    tmp_out = out_path.with_suffix(".tmp.png")
    img.save(tmp_out, optimize=True)
    _ = tmp_out.replace(out_path)
    return out_path


ICONS: dict[str, str] = {"sun": SUN, "moon": MOON, "cloud": CLOUD, "partly": PARTLY, "rain": RAIN, "storm": STORM, "snow": SNOW, "fog": FOG}
KINDLE_DIR: Path = Path(__file__).resolve().parents[2] / "config" / "kindle" / "nebula-dash"


def snap(img: "Image.Image") -> "Image.Image":
    any_img: Any = img.convert("L")
    lut: list[int] = [round(v / 17) * 17 for v in range(256)]
    res: Any = any_img.point(lut)
    return cast("Image.Image", res)


def shoot(exe: str, page: Path, out: Path, width: int, height: int, tmp: str) -> None:
    _ = subprocess.run([exe, "--headless=new", "--disable-gpu", "--hide-scrollbars", "--no-first-run",
                    "--no-default-browser-check", "--force-device-scale-factor=1",
                    f"--user-data-dir={tmp}/profile", f"--window-size={width},{height}",
                    "--virtual-time-budget=1500", f"--screenshot={out}", page.as_uri()],
                   check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=60)


def font_file(family: str, weight: str | int | float | None) -> str:
    if "Titan" in family:
        return "TitanOne-Regular"
    w = int(float(weight or 400))
    return "Rubik-Regular" if w < 500 else "Rubik-Medium" if w < 600 else "Rubik-SemiBold"


def hex_color(css: str) -> str:
    nums = [int(float(v)) for v in css[css.find("(") + 1:css.find(")")].split(",")[:3]] if "(" in css else [0, 0, 0]
    g = round(sum(nums) / 3 / 17) * 17
    return f"#{g:02X}{g:02X}{g:02X}"


def build_assets(out_dir: Path | str) -> Path:
    import re
    from PIL import Image
    exe = chrome()
    if not exe:
        raise RuntimeError("no Chrome or Chromium found")
    out_dir_path = Path(out_dir)
    (out_dir_path / "icons").mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="nebula-kindle-") as tmp:
        page = Path(tmp) / "slots.html"
        _ = page.write_text(build_html(slots=True), encoding="utf-8")
        dom = subprocess.run([exe, "--headless=new", "--disable-gpu", "--no-first-run", "--no-default-browser-check",
                              f"--user-data-dir={tmp}/profile", f"--window-size={WIDTH},{HEIGHT}",
                              "--virtual-time-budget=1500", "--dump-dom", page.as_uri()],
                             check=True, capture_output=True, text=True, timeout=60).stdout
        match = re.search(r'<pre id="rects">(.*?)</pre>', dom, re.S)
        rects: list[dict[str, Any]] = json.loads(html.unescape(match.group(1))) if match else []
        shot = Path(tmp) / "template.png"
        shoot(exe, page, shot, WIDTH, HEIGHT, tmp)
        snap(Image.open(shot).crop((0, 0, WIDTH, HEIGHT))).save(out_dir_path / "template.png", optimize=True)

        icons = Path(tmp) / "icons.html"
        cells = "".join(f'<svg width="118" height="118" viewBox="0 0 48 48" fill="none" stroke="#000000" stroke-width="3" '
                        + f'stroke-linecap="round" stroke-linejoin="round" style="display:block;float:left">{svg}</svg>'
                        for svg in ICONS.values())
        _ = icons.write_text(f'<!doctype html><html><body style="margin:0;background:#FFFFFF">{cells}</body></html>', encoding="utf-8")
        ishot = Path(tmp) / "icons.png"
        shoot(exe, icons, ishot, 118 * len(ICONS), 118, tmp)
        strip = Image.open(ishot)
        for i, name in enumerate(ICONS):
            snap(strip.crop((i * 118, 0, i * 118 + 118, 118))).save(out_dir_path / "icons" / f"{name}.png", optimize=True)

    lines: list[str] = []
    for r in rects:
        name = str(r["slot"])
        if name.startswith("col"):
            lines.append(f'C_{name[3:]}="{round(r["x"])} {round(r["y"])} {round(r["w"])}"')
            continue
        align = str(r.get("align", "left"))
        if name == "icon" or align == "box":
            lines.append(f'S_{name}="{round(r["x"])} {round(r["y"])} {round(r["w"])} {round(r["h"])}"')
            continue
        x = float(r["right"]) if align == "right" else float(r["x"]) + float(r["w"]) / 2 if align == "center" else float(r["x"])
        lines.append(f'S_{name}="{round(x)} {round(r["y"])} {round(r["h"])} {round(r["size"])} '
                     + f'{font_file(str(r["family"]), r["weight"])} {hex_color(str(r["color"]))} {align}"')
    lines += ["BAR_BASE=14", "BAR_SPAN=70", "BAR_GAP=6"]
    import importlib
    rotate = "ccw"
    try:
        for line in (out_dir_path / "config.sh").read_text().splitlines():
            if line.startswith("ROTATE="):
                rotate = line.split("=", 1)[1].strip().strip('"')
    except OSError:
        pass
    k_ac: Any = importlib.import_module("nebula.kindle_ac")
    _ = k_ac.build(out_dir_path / "ac", rotate)
    _ = k_ac.build_sys(out_dir_path / "sys", rotate)
    k_clock: Any = importlib.import_module("nebula.kindle_clock")
    _ = k_clock.build(out_dir_path / "clock", rotate, weather_data(load_settings()).get("location") or "")
    _ = (out_dir_path / "layout.sh").write_text("\n".join(lines) + "\n")
    write_place(out_dir_path / "place.sh")
    return out_dir_path


def write_place(path: Path) -> None:
    from nebula import holidays as h
    settings_map = load_settings()
    cache = weather_data(settings_map)
    general_cfg: dict[str, Any] = settings_map.get("general", {}) if isinstance(settings_map.get("general"), dict) else {}
    cc = str(general_cfg.get("holidayCountry") or h.detect_country() or "").upper()
    cid = h.ICS_ALT.get(cc) or f"en.{cc.lower()}"
    weather_cfg: dict[str, Any] = settings_map.get("weather", {}) if isinstance(settings_map.get("weather"), dict) else {}
    metric = bool(weather_cfg.get("useMetric", True))
    place = str(cache.get("location") or "").replace('"', "")
    _ = path.write_text(
        f'PLACE="{place}"\n'
        + f'LAT={cache.get("lat", 0)}\n'
        + f'LON={cache.get("lon", 0)}\n'
        + f'UNITS={"metric" if metric else "imperial"}\n'
        + f'ICS="{h.ICS_URL.format(cid=cid)}"\n')


class Handler(BaseHTTPRequestHandler):
    lock: threading.Lock = threading.Lock()
    out: Path = OUT_DIR / "dashboard.png"

    def do_GET(self) -> None:
        url = urlparse(self.path)
        q = parse_qs(url.query)
        battery: int | None = None
        if q.get("battery", [""])[0].isdigit():
            battery = int(q["battery"][0])
        rotate = q.get("rotate", ["ccw"])[0]
        if rotate not in ("cw", "ccw", "none"):
            rotate = "ccw"
        if url.path == "/dashboard.png":
            try:
                with Handler.lock:
                    out = render(Handler.out, battery)
                body = out.read_bytes()
            except Exception as e:
                self.send_error(500, str(e))
                return
            self._send(body, "image/png")
        elif url.path == "/frame.png":
            self._frame(rotate)
        elif url.path == "/dashboard.html":
            self._send(build_html(battery).encode(), "text/html; charset=utf-8")
        else:
            self.send_error(404)

    def _frame(self, rotate: str) -> None:
        from email.utils import formatdate, parsedate_to_datetime
        from nebula import kindle_frame
        with Handler.lock:
            out = kindle_frame.rendered(rotate)
        if not out:
            self.send_error(404)
            return
        mtime = int(kindle_frame.SOURCE.stat().st_mtime)
        since = self.headers.get("If-Modified-Since")
        try:
            if since and parsedate_to_datetime(since).timestamp() >= mtime - 2:
                self.send_response(304)
                self.end_headers()
                return
        except (TypeError, ValueError):
            pass
        body = out.read_bytes()
        self.send_response(200)
        self.send_header("Content-Type", "image/png")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Last-Modified", formatdate(mtime, usegmt=True))
        self.end_headers()
        _ = self.wfile.write(body)

    def _send(self, body: bytes, ctype: str) -> None:
        self.send_response(200)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        _ = self.wfile.write(body)

    @override
    def log_message(self, format: str, *args: object) -> None:
        _ = sys.stderr.write(f"{datetime.now():%H:%M:%S} {self.client_address[0]} {format % args}\n")


def main() -> int:
    p = argparse.ArgumentParser(prog="nebula kindle", description="Kindle e-ink dashboard")
    sub = p.add_subparsers(dest="action", required=True)
    r = sub.add_parser("render", help="render the dashboard PNG once")
    _ = r.add_argument("--out", default=str(OUT_DIR / "dashboard.png"))
    _ = r.add_argument("--html", action="store_true", help="print the HTML instead")
    g = sub.add_parser("assets", help="build the on-device template, icons and layout")
    _ = g.add_argument("--out", default=None)
    f = sub.add_parser("frame", help="set the still image shown while the Kindle rests")
    _ = f.add_argument("image", nargs="?", help="any image file; omit to only change --fit")
    _ = f.add_argument("--fit", choices=("cover", "contain"), default=None)
    _ = f.add_argument("--clear", action="store_true")
    _ = f.add_argument("--push", action="store_true", help="also copy it over USB if the Kindle is plugged in")
    _ = sub.add_parser("push", help="copy the frame image to a USB-connected Kindle")
    _ = sub.add_parser("status", help="print frame, USB and server state as JSON")
    w = sub.add_parser("wifi", help="run the frame server in the background (systemd user unit)")
    _ = w.add_argument("state", choices=("on", "off"))
    s = sub.add_parser("serve", help="serve a freshly rendered PNG on every request")
    _ = s.add_argument("--port", type=int, default=8777)
    _ = s.add_argument("--bind", default="0.0.0.0")
    a = p.parse_args()

    if a.action == "assets":
        print(build_assets(a.out or KINDLE_DIR))
        return 0

    if a.action in ("frame", "push", "status", "wifi"):
        from nebula import kindle_frame as kf
        result: dict[str, Any] = {}
        if a.action == "frame":
            if a.clear:
                kf.clear()
            elif a.image:
                _ = kf.set_image(a.image, a.fit or "cover")
            elif a.fit:
                _ = kf.set_fit(a.fit)
            else:
                p.error("frame needs an image, --fit or --clear")
        if a.action == "push" or (a.action == "frame" and a.push and not a.clear):
            ok, msg = kf.push()
            result = {"ok": ok, "message": msg}
        if a.action == "wifi":
            kf.wifi(a.state == "on")
        print(json.dumps({**kf.status(), **result}))
        return 0

    if a.action == "render":
        if a.html:
            _ = sys.stdout.write(build_html())
            return 0
        print(render(a.out))
        return 0

    server = ThreadingHTTPServer((a.bind, a.port), Handler)
    print(f"serving http://{a.bind}:{a.port}/dashboard.png", file=sys.stderr)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    return 0


if __name__ == "__main__":
    sys.exit(main())
