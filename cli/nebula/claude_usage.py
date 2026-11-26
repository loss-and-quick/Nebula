#!/usr/bin/env python3
"""
Daily Claude Code usage, read straight out of the local transcripts.

~/.claude/stats-cache.json exists but stops updating (it was months stale here),
so this walks ~/.claude/projects/**/*.jsonl itself and totals the per-message
`usage` objects. Transcripts are append-only, so the scan is incremental: each
file's byte offset and running totals are kept, and a rerun reads only what was
appended. First run on ~36 files is a few seconds; after that it is milliseconds.

Usage: claude_usage.py [--days N] [--rescan]
Prints one JSON object on stdout.
"""

import json
import os
import sys
import time
from collections import defaultdict
from datetime import datetime, timedelta
from pathlib import Path
from typing import Any, TypedDict, cast

PROJECTS = Path.home() / ".claude" / "projects"
HISTORY  = Path.home() / ".claude" / "history.jsonl"
CACHE    = Path.home() / ".cache" / "quickshell" / "claude_usage.json"
DAYS     = 7
IDLE_SEC = 300

# Anthropic bills usage against a rolling 5-hour session block and a 7-day
# window. Neither the limits nor the percentages are written anywhere on disk
# (/usage reads them off the API response), so the sizes below are only the
# window lengths — the totals are computed from the transcripts themselves.
CACHE_VERSION  = 2
BLOCK_SEC      = 5 * 3600
WEEK_SEC       = 7 * 24 * 3600
EVENT_KEEP_SEC = 12 * 3600      # enough to always contain the open block's start
HOUR_KEEP_SEC  = 90 * 24 * 3600 # hourly buckets, for scaling against past peaks


class UsageSlot(TypedDict):
    tokens: int
    input: int
    output: int
    cacheRead: int
    cacheWrite: int
    messages: int
    models: dict[str, int]
    sessions: list[str]


class CacheFile(TypedDict):
    offset: int
    size: int


class CacheData(TypedDict):
    version: int
    files: dict[str, CacheFile]
    days: dict[str, UsageSlot]
    events: list[list[int]]
    hours: dict[str, int]


class SeriesEntry(TypedDict):
    date: str
    weekday: str
    tokens: int
    messages: int
    sessions: int


def _day(ts: str) -> str:
    try:
        return datetime.fromisoformat(ts.replace("Z", "+00:00")).astimezone().strftime("%Y-%m-%d")
    except Exception:
        return ""


def _epoch(ts: str) -> float:
    try:
        return datetime.fromisoformat(ts.replace("Z", "+00:00")).timestamp()
    except Exception:
        return 0.0


def _hour_key(epoch: float) -> str:
    return datetime.fromtimestamp(epoch).strftime("%Y-%m-%dT%H")


def _empty() -> UsageSlot:
    return {"tokens": 0, "input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0,
            "messages": 0, "models": {}, "sessions": []}


def _merge(into: dict[str, UsageSlot], day: str, add: UsageSlot) -> None:
    slot = into.setdefault(day, _empty())
    slot["tokens"] += add["tokens"]
    slot["input"] += add["input"]
    slot["output"] += add["output"]
    slot["cacheRead"] += add["cacheRead"]
    slot["cacheWrite"] += add["cacheWrite"]
    slot["messages"] += add["messages"]
    for model, count in add["models"].items():
        slot["models"][model] = slot["models"].get(model, 0) + count
    for session in add["sessions"]:
        if session not in slot["sessions"]:
            slot["sessions"].append(session)


def _scan(path: Path, offset: int) -> tuple[defaultdict[str, UsageSlot], list[list[int]], dict[str, int], int]:
    """Totals per day from `offset` onward, plus events, hourly buckets and the new offset."""
    days: defaultdict[str, UsageSlot] = defaultdict(_empty)
    events: list[list[int]] = []
    hours: defaultdict[str, int] = defaultdict(int)
    session = path.stem
    with open(path, "r", errors="ignore") as fh:
        _ = fh.seek(offset)
        for line in fh:
            if not line.endswith("\n"):
                break                      # a half-written line: stop, re-read next time
            offset += len(line.encode("utf-8", "ignore"))
            try:
                entry_val: Any = json.loads(line)
            except Exception:
                continue
            if not isinstance(entry_val, dict):
                continue
            entry: dict[str, Any] = cast(dict[str, Any], entry_val)
            message_val = entry.get("message")
            if not isinstance(message_val, dict):
                continue
            message: dict[str, Any] = cast(dict[str, Any], message_val)
            usage_val = message.get("usage")
            if not isinstance(usage_val, dict) or not usage_val:
                continue
            usage: dict[str, Any] = cast(dict[str, Any], usage_val)
            day = _day(str(entry.get("timestamp", "")))
            if not day:
                continue
            slot = days[day]
            inp = int(usage.get("input_tokens", 0) or 0)
            out = int(usage.get("output_tokens", 0) or 0)
            read = int(usage.get("cache_read_input_tokens", 0) or 0)
            write = int(usage.get("cache_creation_input_tokens", 0) or 0)
            slot["input"] += inp
            slot["output"] += out
            slot["cacheRead"] += read
            slot["cacheWrite"] += write
            slot["tokens"] += inp + out + read + write
            slot["messages"] += 1
            model = str(message.get("model") or entry.get("model") or "unknown")
            slot["models"][model] = slot["models"].get(model, 0) + inp + out + read + write
            if session not in slot["sessions"]:
                slot["sessions"].append(session)

            epoch = _epoch(str(entry.get("timestamp", "")))
            if epoch > 0:
                total = inp + out + read + write
                events.append([int(epoch), total])
                hours[_hour_key(epoch)] += total
    return days, events, dict(hours), offset


def _safe_hour(key: str) -> bool:
    try:
        _ = datetime.strptime(key, "%Y-%m-%dT%H")
        return True
    except Exception:
        return False


def _load_cache() -> CacheData:
    try:
        cached_val: Any = json.loads(CACHE.read_text())
        if isinstance(cached_val, dict):
            cached_raw: dict[str, Any] = cast(dict[str, Any], cached_val)
            if cached_raw.get("version") == CACHE_VERSION:
                cached_raw.setdefault("events", [])
                cached_raw.setdefault("hours", {})
                return cast(CacheData, cast(object, cached_raw))
    except Exception:
        pass
    # A version bump forces one full rescan, which is how the event and hourly
    # history gets backfilled for transcripts already read at v1.
    return {"version": CACHE_VERSION, "files": {}, "days": {}, "events": [], "hours": {}}


def _recent_prompt() -> tuple[str | None, float, str]:
    """Last prompt and how long ago, from the live history file."""
    if not HISTORY.is_file():
        return None, 0.0, ""
    last = None
    try:
        with open(HISTORY, "r", errors="ignore") as fh:
            for line in fh:
                if line.strip():
                    last = line
    except OSError:
        return None, 0.0, ""
    if not last:
        return None, 0.0, ""
    try:
        entry_raw: Any = json.loads(last)
        if not isinstance(entry_raw, dict):
            return None, 0.0, ""
        entry: dict[str, Any] = cast(dict[str, Any], entry_raw)
    except Exception:
        return None, 0.0, ""
    ts_val = entry.get("timestamp", 0)
    ts = float(ts_val) if isinstance(ts_val, (int, float)) else 0.0
    age = max(0.0, time.time() - ts / 1000.0)
    project = os.path.basename(str(entry.get("project", "") or ""))
    display = entry.get("display")
    return str(display) if display is not None else None, age, project


def main() -> int:
    days_wanted = DAYS
    if "--days" in sys.argv:
        idx = sys.argv.index("--days")
        if idx + 1 < len(sys.argv):
            days_wanted = max(1, min(90, int(sys.argv[idx + 1])))

    cache: CacheData = ({"version": CACHE_VERSION, "files": {}, "days": {}, "events": [], "hours": {}}
             if "--rescan" in sys.argv else _load_cache())
    files, totals = cache["files"], cache["days"]

    if not PROJECTS.is_dir():
        print(json.dumps({"error": "no ~/.claude/projects"}))
        return 0

    scanned = 0
    for path in PROJECTS.rglob("*.jsonl"):
        key = str(path)
        try:
            size = path.stat().st_size
        except OSError:
            continue
        seen: CacheFile = files.get(key, {"offset": 0, "size": 0})
        if seen["offset"] > size:          # truncated or replaced — start over
            seen = {"offset": 0, "size": 0}
        if seen["offset"] == size:
            continue
        fresh, events, hours, offset = _scan(path, seen["offset"])
        for day, add in fresh.items():
            _merge(totals, day, add)
        cache["events"].extend(events)
        for hour, count in hours.items():
            cache["hours"][hour] = cache["hours"].get(hour, 0) + count
        files[key] = {"offset": offset, "size": size}
        scanned += 1

    now_epoch = time.time()
    cache["events"] = sorted(e for e in cache["events"]
                             if e[0] >= now_epoch - EVENT_KEEP_SEC)
    hour_floor = datetime.fromtimestamp(now_epoch - HOUR_KEEP_SEC).strftime("%Y-%m-%dT%H")
    cache["hours"] = {h: c for h, c in cache["hours"].items() if h >= hour_floor}

    CACHE.parent.mkdir(parents=True, exist_ok=True)
    tmp = CACHE.with_suffix(".tmp")
    _ = tmp.write_text(json.dumps(cache))
    os.replace(tmp, CACHE)

    today = datetime.now().strftime("%Y-%m-%d")
    series: list[SeriesEntry] = []
    for back in range(days_wanted - 1, -1, -1):
        date = (datetime.now() - timedelta(days=back)).strftime("%Y-%m-%d")
        slot = totals.get(date, _empty())
        series.append({
            "date": date,
            "weekday": datetime.strptime(date, "%Y-%m-%d").strftime("%a")[0],
            "tokens": slot["tokens"],
            "messages": slot["messages"],
            "sessions": len(slot["sessions"]),
        })

    # ── Rolling windows ───────────────────────────────────────────────
    # The 5-hour block is reconstructed the way Anthropic's session window
    # works: the first message opens a block, and the first message after it
    # expires opens the next one.
    events = cache["events"]
    block_start: float | None = None
    for event in events:
        ts = event[0]
        if block_start is None or ts - block_start >= BLOCK_SEC:
            block_start = float(ts)

    block_active = block_start is not None and (now_epoch - block_start) < BLOCK_SEC
    block_tokens = 0
    block_messages = 0
    if block_active and block_start is not None:
        for event in events:
            ts = event[0]
            tok = event[1]
            if ts >= block_start:
                block_tokens += tok
                block_messages += 1

    hours = cache["hours"]

    def _window_sum(end_epoch: float, length: float) -> int:
        start = end_epoch - length
        total = 0
        for hour, count in hours.items():
            try:
                h = datetime.strptime(hour, "%Y-%m-%dT%H").timestamp()
            except Exception:
                continue
            if start <= h <= end_epoch:
                total += count
        return total

    week_tokens = _window_sum(now_epoch, WEEK_SEC)

    # Scale bars against the user's own history rather than inventing a limit.
    hour_epochs: list[tuple[float, int]] = sorted(
        (datetime.strptime(h, "%Y-%m-%dT%H").timestamp(), c)
        for h, c in hours.items()
        if _safe_hour(h)
    )
    block_peak = 0
    week_peak = 0
    for i, (h, _c) in enumerate(hour_epochs):
        run = 0
        for h2, c2 in hour_epochs[i:]:
            if h2 - h >= BLOCK_SEC:
                break
            run += c2
        block_peak = max(block_peak, run)
    for i, (h, _c) in enumerate(hour_epochs):
        if h > now_epoch - WEEK_SEC:
            break
        run = 0
        for h2, c2 in hour_epochs[i:]:
            if h2 - h >= WEEK_SEC:
                break
            run += c2
        week_peak = max(week_peak, run)
    block_peak = max(block_peak, block_tokens)
    week_peak = max(week_peak, week_tokens)

    now = totals.get(today, _empty())
    models: list[tuple[str, int]] = sorted(((n, c) for n, c in now["models"].items() if c > 0), key=lambda kv: -kv[1])
    prompt, age, project = _recent_prompt()

    print(json.dumps({
        "today": {
            "tokens": now["tokens"],
            "input": now["input"],
            "output": now["output"],
            "cacheRead": now["cacheRead"],
            "cacheWrite": now["cacheWrite"],
            "messages": now["messages"],
            "sessions": len(now["sessions"]),
            "models": [{"name": name, "tokens": count} for name, count in models],
        },
        "series": series,
        "peak": max((d["tokens"] for d in series), default=0),
        "block": {
            "active": block_active,
            "tokens": block_tokens,
            "messages": block_messages,
            "startedAt": int(block_start) if (block_active and block_start is not None) else 0,
            "endsAt": int(block_start + BLOCK_SEC) if (block_active and block_start is not None) else 0,
            "secondsLeft": max(0, int(block_start + BLOCK_SEC - now_epoch)) if (block_active and block_start is not None) else 0,
            "peak": block_peak,
        },
        "week": {
            "tokens": week_tokens,
            "peak": week_peak,
            "days": sum(1 for d in series if d["tokens"] > 0),
        },
        "live": age < IDLE_SEC,
        "lastPrompt": (prompt or "")[:120],
        "lastAgeSec": int(age),
        "project": project,
        "filesScanned": scanned,
    }))
    return 0


if __name__ == "__main__":
    sys.exit(main())
