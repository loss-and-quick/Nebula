#!/usr/bin/env python3
import hashlib
import json
import os
import re
import sys
import urllib.request
from collections.abc import Generator
from datetime import date, datetime, timedelta, timezone, tzinfo
from typing import Any, TypeVar, cast
from zoneinfo import ZoneInfo

CACHE = os.path.expanduser("~/.cache/quickshell/events")
PAST = 7
AHEAD = 60
WEEKDAYS = ["MO", "TU", "WE", "TH", "FR", "SA", "SU"]


D = TypeVar("D", date, datetime)


def fetch(url: str) -> str:
    key = hashlib.sha1(url.encode()).hexdigest()[:16]
    path = os.path.join(CACHE, key + ".ics")
    if url.startswith("webcal://"):
        url = "https://" + url[len("webcal://"):]
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "quickshell-events"})
        with urllib.request.urlopen(req, timeout=15) as r:
            body: str = r.read().decode("utf-8", "replace")
        if "BEGIN:VCALENDAR" in body:
            os.makedirs(CACHE, exist_ok=True)
            with open(path, "w") as f:
                _ = f.write(body)
            return body
    except Exception:
        pass
    try:
        with open(path) as f:
            return f.read()
    except OSError:
        return ""


def unfold(text: str) -> list[str]:
    return re.sub(r"\r?\n[ \t]", "", text).splitlines()


def parse_dt(value: str, params: dict[str, str], local: tzinfo | None = None) -> tuple[date | datetime, bool]:
    if params.get("VALUE") == "DATE" or re.fullmatch(r"\d{8}", value):
        return datetime.strptime(value[:8], "%Y%m%d").date(), True
    if value.endswith("Z"):
        dt = datetime.strptime(value, "%Y%m%dT%H%M%SZ").replace(tzinfo=timezone.utc)
    else:
        dt = datetime.strptime(value[:15], "%Y%m%dT%H%M%S")
        tz = params.get("TZID")
        try:
            dt = dt.replace(tzinfo=ZoneInfo(tz)) if tz else dt.replace(tzinfo=local)
        except Exception:
            dt = dt.replace(tzinfo=local)
    return dt.astimezone(local), False


def events_of(text: str, local: tzinfo | None = None) -> list[dict[str, Any]]:
    out: list[dict[str, Any]] = []
    cur: dict[str, Any] | None = None
    for line in unfold(text):
        if line == "BEGIN:VEVENT":
            cur = {"exdates": []}
            continue
        if line == "END:VEVENT":
            if cur and "start" in cur:
                out.append(cur)
            cur = None
            continue
        if cur is None or ":" not in line:
            continue
        head, value = line.split(":", 1)
        parts = head.split(";")
        name = parts[0].upper()
        params: dict[str, str] = dict(p.split("=", 1) for p in parts[1:] if "=" in p)
        if name == "DTSTART":
            cur["start"], cur["allDay"] = parse_dt(value, params, local)
        elif name == "DTEND":
            cur["end"], _ = parse_dt(value, params, local)
        elif name == "SUMMARY":
            cur["title"] = value.replace("\\,", ",").replace("\\;", ";").replace("\\n", " ")
        elif name == "LOCATION":
            cur["location"] = value.replace("\\,", ",").replace("\\;", ";")
        elif name == "RRULE":
            cur["rrule"] = dict(p.split("=", 1) for p in value.split(";") if "=" in p)
        elif name == "EXDATE":
            for v in value.split(","):
                try:
                    cast(list[Any], cur["exdates"]).append(parse_dt(v, params, local)[0])
                except ValueError:
                    pass
        elif name == "STATUS" and value.upper() == "CANCELLED":
            cur["cancelled"] = True
    return [e for e in out if not e.get("cancelled")]


def as_date(x: date | datetime) -> date:
    return x.date() if isinstance(x, datetime) else x


def add_months(d: D, n: int) -> D:
    m = d.month - 1 + n
    y = d.year + m // 12
    m = m % 12 + 1
    day = min(d.day, [31, 29 if y % 4 == 0 and (y % 100 or y % 400 == 0) else 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31][m - 1])
    return cast(D, d.replace(year=y, month=m, day=day))


def occurrences(ev: dict[str, Any], lo: date, hi: date) -> Generator[date | datetime, None, None]:
    start: date | datetime = ev["start"]
    rule: dict[str, str] | None = ev.get("rrule")
    if not rule:
        yield start
        return
    freq = rule.get("FREQ", "")
    interval = int(rule.get("INTERVAL", "1") or 1)
    count = int(rule["COUNT"]) if "COUNT" in rule else None
    until: date | datetime | None = None
    if "UNTIL" in rule:
        try:
            until = parse_dt(rule["UNTIL"], {}, start.tzinfo if isinstance(start, datetime) else None)[0]
        except Exception:
            until = None
    byday: list[str] = [d[-2:] for d in rule.get("BYDAY", "").split(",") if d]
    n = 0
    step = 0
    while step < 5000:
        cands: list[date | datetime]
        if freq == "DAILY":
            cands = [start + timedelta(days=step * interval)]
        elif freq == "WEEKLY":
            base = start + timedelta(weeks=step * interval)
            if byday:
                monday = base - timedelta(days=base.weekday())
                sorted_cands: list[date | datetime] = sorted(monday + timedelta(days=WEEKDAYS.index(d)) for d in byday if d in WEEKDAYS)
                cands = [c for c in sorted_cands if c >= start]
            else:
                cands = [base]
        elif freq == "MONTHLY":
            cands = [add_months(start, step * interval)]
        elif freq == "YEARLY":
            cands = [add_months(start, 12 * step * interval)]
        else:
            yield start
            return
        step += 1
        for c in cands:
            if until is not None:
                if isinstance(c, datetime) and isinstance(until, datetime):
                    past = c > until
                else:
                    past = as_date(c) > as_date(until)
                if past:
                    return
            n += 1
            if count is not None and n > count:
                return
            cd = as_date(c)
            if cd > hi:
                return
            if cd >= lo and c not in cast(list[Any], ev["exdates"]):
                yield c


def main() -> None:
    urls = [u for u in sys.argv[1:] if u.strip()]
    local = datetime.now().astimezone().tzinfo or timezone.utc
    today = date.today()
    lo = today - timedelta(days=PAST)
    hi = today + timedelta(days=AHEAD)
    out: list[dict[str, Any]] = []
    for ci, url in enumerate(urls):
        for ev in events_of(fetch(url), local):
            if ev["allDay"]:
                start_date: date = ev["start"] if isinstance(ev["start"], date) and not isinstance(ev["start"], datetime) else as_date(ev["start"])
                raw_end = ev.get("end")
                end_date: date = (raw_end if isinstance(raw_end, date) and not isinstance(raw_end, datetime) else as_date(raw_end)) if raw_end else start_date + timedelta(days=1)
                dur_date = end_date - start_date
                for s in occurrences(ev, lo, hi):
                    s_date = as_date(s)
                    e_date = s_date + dur_date
                    out.append({"title": ev.get("title", "(no title)"), "allDay": True, "calendar": ci,
                                "start": s_date.isoformat(), "end": e_date.isoformat(),
                                "location": ev.get("location", "")})
            else:
                start_dt: datetime = cast(datetime, ev["start"])
                raw_end = ev.get("end")
                end_dt: datetime = cast(datetime, raw_end) if raw_end else start_dt + timedelta(hours=1)
                dur_dt = end_dt - start_dt
                for s in occurrences(ev, lo, hi):
                    s_dt = cast(datetime, s)
                    e_dt = s_dt + dur_dt
                    out.append({"title": ev.get("title", "(no title)"), "allDay": False, "calendar": ci,
                                "start": int(s_dt.timestamp() * 1000), "end": int(e_dt.timestamp() * 1000),
                                "location": ev.get("location", "")})
    def key(e: dict[str, Any]) -> int:
        if not e["allDay"]:
            return int(e["start"])
        return int(datetime.fromisoformat(str(e["start"])).timestamp() * 1000)
    out.sort(key=key)
    print(json.dumps(out))


if __name__ == "__main__":
    main()
