#!/usr/bin/env python3
import json
import os
import re
import sys
import urllib.error
import urllib.request
from datetime import date
from typing import Any, TypedDict, cast

CACHE_DIR: str = os.path.expanduser("~/.cache/quickshell/holidays")
NAGER_URL: str = "https://date.nager.at/api/v3/PublicHolidays/{year}/{cc}"
ICS_URL: str = (
    "https://calendar.google.com/calendar/ical/"
    "{cid}%23holiday%40group.v.calendar.google.com/public/basic.ics"
)

ICS_ALT: dict[str, str] = {"IN": "en.indian", "MY": "en.malaysia", "TW": "en.taiwan", "IL": "en.jewish"}

MONTHS: list[str] = [
    "January", "February", "March", "April", "May", "June",
    "July", "August", "September", "October", "November", "December",
]
DAYS: list[str] = [
    "Monday", "Tuesday", "Wednesday", "Thursday",
    "Friday", "Saturday", "Sunday",
]


class HolidayEntry(TypedDict):
    date: str
    day: int
    month: str
    monthNum: int
    year: int
    dayOfWeek: str
    dayOfWeekShort: str
    name: str


def detect_country() -> str:
    tz = os.environ.get("TZ", "").lstrip(":")
    if not tz:
        try:
            tz = os.path.realpath("/etc/localtime").split("zoneinfo/")[-1]
        except OSError:
            pass
    if tz:
        try:
            with open("/usr/share/zoneinfo/zone.tab") as f:
                for line in f:
                    if line.startswith("#"):
                        continue
                    parts = line.split()
                    if len(parts) >= 3 and parts[2] == tz:
                        return parts[0]
        except OSError:
            pass
    for var in ("LC_TIME", "LC_ALL", "LANG"):
        m = re.search(r"_([A-Za-z]{2})", os.environ.get(var, ""))
        if m:
            return m.group(1)
    return ""


def fetch(url: str, timeout: int = 20) -> str | None:
    req = urllib.request.Request(url, headers={"User-Agent": "quickshell-holidays"})
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            if r.status != 200:
                return None
            body: str = r.read().decode("utf-8", "replace")
            return body or None
    except (urllib.error.URLError, urllib.error.HTTPError, OSError, ValueError):
        return None


def entry(d: date, name: str) -> HolidayEntry:
    return {
        "date": d.isoformat(),
        "day": d.day,
        "month": MONTHS[d.month - 1],
        "monthNum": d.month,
        "year": d.year,
        "dayOfWeek": DAYS[d.weekday()],
        "dayOfWeekShort": DAYS[d.weekday()][:3],
        "name": name,
    }


def from_nager(year: int, cc: str) -> list[HolidayEntry]:
    body = fetch(NAGER_URL.format(year=year, cc=cc))
    if not body:
        return []
    try:
        raw: object = json.loads(body)
    except ValueError:
        return []
    if not isinstance(raw, list):
        return []
    out: list[HolidayEntry] = []
    for raw_item in cast(list[object], raw):
        if not isinstance(raw_item, dict):
            continue
        h: dict[str, Any] = cast(dict[str, Any], raw_item)
        try:
            date_val = h.get("date")
            if not isinstance(date_val, str):
                continue
            y, m, d = (int(p) for p in date_val.split("-"))
            name = str(h.get("localName") or h.get("name") or "")
            if name:
                out.append(entry(date(y, m, d), name))
        except (KeyError, TypeError, ValueError):
            continue
    return out


def unescape(text: str) -> str:
    return (
        text.replace("\\n", " ")
        .replace("\\N", " ")
        .replace("\\,", ",")
        .replace("\\;", ";")
        .replace("\\\\", "\\")
        .strip()
    )


def from_ics(year: int, cc: str) -> list[HolidayEntry]:
    for cid in (f"en.{cc.lower()}", ICS_ALT.get(cc)):
        if not cid:
            continue
        body = fetch(ICS_URL.format(cid=cid))
        if not body:
            continue
        body = body.replace("\r\n", "\n").replace("\n ", "").replace("\n\t", "")
        out: list[HolidayEntry] = []
        for block in re.findall(r"BEGIN:VEVENT(.*?)END:VEVENT", body, re.S):
            start = re.search(r"^DTSTART[^:\n]*:(\d{8})", block, re.M)
            summary = re.search(r"^SUMMARY[^:\n]*:(.*)$", block, re.M)
            if not start or not summary:
                continue
            stamp = start.group(1)
            try:
                d = date(int(stamp[:4]), int(stamp[4:6]), int(stamp[6:8]))
            except ValueError:
                continue
            if d.year != year:
                continue
            name = unescape(summary.group(1))
            if name:
                out.append(entry(d, name))
        if out:
            return out
    return []


def dedupe(rows: list[HolidayEntry]) -> list[HolidayEntry]:
    seen: set[tuple[str, str]] = set()
    out: list[HolidayEntry] = []
    for r in sorted(rows, key=lambda r: (r["date"], r["name"])):
        key = (r["date"], r["name"])
        if key in seen:
            continue
        seen.add(key)
        out.append(r)
    return out


def main() -> int:
    year = date.today().year
    if len(sys.argv) > 1 and sys.argv[1].strip():
        try:
            year = int(sys.argv[1])
        except ValueError:
            pass

    cc = sys.argv[2].strip().upper() if len(sys.argv) > 2 else ""
    if not cc:
        cc = detect_country().upper()
    if not re.fullmatch(r"[A-Z]{2}", cc):
        print("[]")
        return 1

    cache_file = os.path.join(CACHE_DIR, f"{cc}-{year}.json")
    try:
        with open(cache_file) as f:
            cached = json.load(f)
        if isinstance(cached, list) and cached:
            print(json.dumps(cached))
            return 0
    except (OSError, ValueError):
        pass

    rows = dedupe(from_nager(year, cc) or from_ics(year, cc))
    if not rows:
        print("[]")
        return 1

    payload = json.dumps(rows)
    try:
        os.makedirs(CACHE_DIR, exist_ok=True)
        tmp = cache_file + ".tmp"
        with open(tmp, "w") as f:
            _ = f.write(payload)
        os.replace(tmp, cache_file)
    except OSError:
        pass

    print(payload)
    return 0


if __name__ == "__main__":
    sys.exit(main())
