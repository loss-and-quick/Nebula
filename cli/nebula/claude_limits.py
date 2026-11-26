#!/usr/bin/env python3
"""
Claude Code's real rate-limit utilisation, from the same endpoint /usage uses.

The percentages are not stored anywhere on disk — the CLI fetches them from
https://api.anthropic.com/api/oauth/usage on demand. This does the same call
with the OAuth access token Claude Code already keeps in ~/.claude/.credentials.json.

The token is read into memory, sent to Anthropic's own API and nothing else. It
is never logged and never written to the cache; only the response is cached. An
expired token is not refreshed here — Claude Code owns that file and refreshing
behind its back would race it — so a stale token just returns the last good
answer marked stale.

Usage: claude_limits.py [--ttl SECONDS]
Prints one JSON object on stdout.
"""

import json
import os
import sys
import time
import urllib.error
import urllib.request
from collections.abc import Mapping
from datetime import datetime
from pathlib import Path
from typing import Any, cast

CREDS = Path.home() / ".claude" / ".credentials.json"
CACHE = Path.home() / ".cache" / "quickshell" / "claude_limits.json"
URL   = "https://api.anthropic.com/api/oauth/usage"
TTL   = 120
TIMEOUT = 12


def _read_cache() -> dict[str, Any] | None:
    try:
        raw: Any = json.loads(CACHE.read_text())
        if isinstance(raw, dict):
            return cast(dict[str, Any], raw)
        return None
    except Exception:
        return None


def _write_cache(payload: Mapping[str, Any]) -> None:
    try:
        CACHE.parent.mkdir(parents=True, exist_ok=True)
        tmp = CACHE.with_suffix(".tmp")
        _ = tmp.write_text(json.dumps(payload))
        os.replace(tmp, CACHE)
    except OSError:
        pass


def _seconds_left(iso: str) -> int:
    if not iso:
        return 0
    try:
        when = datetime.fromisoformat(iso.replace("Z", "+00:00"))
        return max(0, int(when.timestamp() - time.time()))
    except Exception:
        return 0


def _retime(payload: dict[str, Any]) -> dict[str, Any]:
    """resets_at is absolute, so the countdown is recomputed on every output —
    a cached answer served an hour later must not repeat the old secondsLeft."""
    limits_raw = payload.get("limits")
    if isinstance(limits_raw, list):
        for item in cast(list[object], limits_raw):
            if isinstance(item, dict):
                item_dict: dict[str, Any] = cast(dict[str, Any], item)
                item_dict["secondsLeft"] = _seconds_left(str(item_dict.get("resetsAt") or ""))
    return payload


def _shape(raw: dict[str, Any]) -> dict[str, Any]:
    """The `limits` array is the forward-compatible view; the named blocks are the fallback."""
    out: list[dict[str, Any]] = []
    limits_raw = raw.get("limits")
    if isinstance(limits_raw, list):
        for item in cast(list[object], limits_raw):
            if not isinstance(item, dict):
                continue
            item_dict: dict[str, Any] = cast(dict[str, Any], item)
            resets_at = str(item_dict.get("resets_at") or "")
            out.append({
                "kind": str(item_dict.get("kind", "")),
                "group": str(item_dict.get("group", "")),
                "percent": item_dict.get("percent") or 0,
                "severity": str(item_dict.get("severity", "normal")),
                "resetsAt": resets_at,
                "secondsLeft": _seconds_left(resets_at),
                "active": bool(item_dict.get("is_active")),
            })

    if not out:
        for kind, group, key in (("session", "session", "five_hour"),
                                 ("weekly_all", "weekly", "seven_day")):
            block_raw = raw.get(key)
            if not isinstance(block_raw, dict):
                continue
            block: dict[str, Any] = cast(dict[str, Any], block_raw)
            utilization = block.get("utilization")
            resets_at = str(block.get("resets_at") or "")
            out.append({
                "kind": kind,
                "group": group,
                "percent": round(float(utilization)) if isinstance(utilization, (int, float)) else 0,
                "severity": "normal",
                "resetsAt": resets_at,
                "secondsLeft": _seconds_left(resets_at),
                "active": True,
            })

    return {"limits": out, "fetchedAt": int(time.time())}


def main() -> int:
    ttl = TTL
    if "--ttl" in sys.argv:
        idx = sys.argv.index("--ttl")
        if idx + 1 < len(sys.argv):
            ttl = max(30, int(sys.argv[idx + 1]))

    cached: dict[str, Any] | None = _read_cache()
    if cached and time.time() - float(cached.get("fetchedAt", 0) or 0) < ttl:
        cached["stale"] = False
        print(json.dumps(_retime(cached)))
        return 0

    def _fallback(reason: str) -> int:
        if cached:
            cached["stale"] = True
            cached["reason"] = reason
            print(json.dumps(_retime(cached)))
        else:
            print(json.dumps({"limits": [], "stale": True, "reason": reason,
                              "fetchedAt": 0}))
        return 0

    try:
        creds_json: Any = json.loads(CREDS.read_text())
        if not isinstance(creds_json, dict):
            return _fallback("no credentials")
        creds_dict: dict[str, Any] = cast(dict[str, Any], creds_json)
        creds_raw = creds_dict.get("claudeAiOauth")
        if not isinstance(creds_raw, dict):
            return _fallback("no credentials")
        creds: dict[str, Any] = cast(dict[str, Any], creds_raw)
    except Exception:
        return _fallback("no credentials")

    expires_at = creds.get("expiresAt")
    if (float(expires_at) if isinstance(expires_at, (int, float)) else 0.0) / 1000.0 <= time.time():
        return _fallback("token expired")

    request = urllib.request.Request(URL, headers={
        "Authorization": "Bearer " + str(creds["accessToken"]),
        "anthropic-beta": "oauth-2025-04-20",
        "Content-Type": "application/json",
        "User-Agent": "quickshell-claude-widget",
    })

    try:
        with urllib.request.urlopen(request, timeout=TIMEOUT) as response:
            raw_data: Any = json.load(response)
            if not isinstance(raw_data, dict):
                return _fallback("unreachable")
            raw: dict[str, Any] = cast(dict[str, Any], raw_data)
    except urllib.error.HTTPError as exc:
        return _fallback("http %d" % exc.code)
    except Exception:
        return _fallback("unreachable")

    payload: dict[str, Any] = _shape(raw)
    _write_cache(payload)
    payload["stale"] = False
    print(json.dumps(payload))
    return 0


if __name__ == "__main__":
    sys.exit(main())
