import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

from typing import cast

from nebula.paths import SHELL_DIR

__version__ = "1.0.0"

__all__ = [
    "__version__",
    "descendants",
    "instance_pids",
    "qs_bin",
    "stop_shell",
]


def qs_bin() -> str | None:
    qs = shutil.which("qs") or shutil.which("quickshell")
    if not qs:
        print("nebula: quickshell is not installed", file=sys.stderr)
    return qs


def instance_pids(qs: str) -> list[int]:
    r = subprocess.run([qs, "list", "-j", "-p", str(SHELL_DIR / "shell.qml")],
                       capture_output=True, text=True)
    try:
        raw: object = json.loads(r.stdout or "[]")
        if isinstance(raw, list):
            items = cast(list[object], raw)
            res: list[int] = []
            for item in items:
                if isinstance(item, dict):
                    d = cast(dict[str, object], item)
                    pid_val = d.get("pid")
                    if isinstance(pid_val, (int, str)):
                        res.append(int(pid_val))
            return res
    except Exception:
        pass
    return []


def descendants(roots: list[int]) -> set[int]:
    children: dict[int, list[int]] = {}
    for stat in Path("/proc").glob("[0-9]*/stat"):
        try:
            fields = stat.read_text().rsplit(")", 1)[1].split()
            children.setdefault(int(fields[1]), []).append(int(stat.parent.name))
        except (OSError, IndexError, ValueError):
            continue
    found: set[int] = set()
    todo = list(roots)
    while todo:
        pid = todo.pop()
        if pid in found:
            continue
        found.add(pid)
        todo.extend(children.get(pid, []))
    return found


def stop_shell(quiet: bool = False) -> int:
    import signal
    qs = qs_bin()
    if not qs:
        return 1
    roots = instance_pids(qs)
    if not roots:
        if not quiet:
            print("nebula: the shell isn't running", file=sys.stderr)
        return 1
    procs = descendants(roots)
    for sig in (signal.SIGSTOP, signal.SIGKILL):
        for pid in procs:
            try:
                os.kill(pid, sig)
            except (ProcessLookupError, PermissionError):
                pass
    return 0

