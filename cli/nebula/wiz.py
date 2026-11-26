import argparse
import json
import select
import socket
import subprocess
import sys
import time
from collections.abc import Mapping
from typing import Any, TypedDict, cast

PORT = 38899
SKIP = ("lo", "docker", "virbr", "br-", "veth", "tun", "wg", "tailscale")
SEND_GAP = 0.05
CONFIRM_DELAY = 0.4
LOST_AFTER = 3
RESCAN_EVERY = 30.0


class BulbInfo(TypedDict):
    ip: str
    mac: str
    pilot: dict[str, Any]


def own_addresses() -> list[str]:
    try:
        out = subprocess.run(["ip", "-4", "-o", "addr"], capture_output=True, text=True, timeout=3).stdout
    except (OSError, subprocess.SubprocessError):
        return []
    found: list[str] = []
    for line in out.splitlines():
        parts = line.split()
        if len(parts) < 4 or parts[1].startswith(SKIP):
            continue
        found.append(parts[3].split("/")[0])
    return found


def scan(timeout: float = 2.5) -> list[BulbInfo]:
    own = own_addresses()
    targets: list[str] = []
    for addr in own:
        base = addr.rsplit(".", 1)[0]
        targets.extend(f"{base}.{i}" for i in range(1, 255))
    targets = [t for t in dict.fromkeys(targets) if t not in own]
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
    msg = json.dumps({"method": "getPilot", "params": {}}).encode()
    for target in ["255.255.255.255", *targets]:
        try:
            _ = sock.sendto(msg, (target, PORT))
        except OSError:
            pass
    sock.settimeout(0.25)
    bulbs: dict[str, dict[str, Any]] = {}
    end = time.monotonic() + timeout
    while time.monotonic() < end:
        try:
            data, (addr, _) = sock.recvfrom(4096)
        except (socket.timeout, OSError):
            continue
        try:
            reply_raw: Any = json.loads(data)
        except ValueError:
            continue
        if not isinstance(reply_raw, dict):
            continue
        reply: dict[str, Any] = cast(dict[str, Any], reply_raw)
        result = reply.get("result")
        if reply.get("method") == "getPilot" and isinstance(result, dict):
            bulbs[str(addr)] = cast(dict[str, Any], result)
    sock.close()
    return [{"ip": ip, "mac": str(r.get("mac", "")), "pilot": r} for ip, r in sorted(bulbs.items())]


def request(ip: str, method: str, params: Mapping[str, Any], timeout: float = 1.5) -> dict[str, Any]:
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.settimeout(timeout)
    try:
        _ = sock.sendto(json.dumps({"id": 1, "method": method, "params": params}).encode(), (ip, PORT))
        res_raw: Any = json.loads(sock.recvfrom(4096)[0])
        return cast(dict[str, Any], res_raw) if isinstance(res_raw, dict) else {}
    finally:
        sock.close()


class Server:
    ip: str
    poll: float
    sock: socket.socket
    pending: dict[str, Any] | None
    last_send: float
    confirm_at: float
    next_poll: float
    missed: int
    lost: bool
    next_scan: float

    def __init__(self, ip: str, poll: float):
        self.ip = ip
        self.poll = poll
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.sock.setblocking(False)
        self.pending = None
        self.last_send = 0.0
        self.confirm_at = 0.0
        self.next_poll = 0.0
        self.missed = 0
        self.lost = False
        self.next_scan = 0.0

    def emit(self, obj: Mapping[str, Any]) -> None:
        _ = sys.stdout.write(json.dumps(obj) + "\n")
        _ = sys.stdout.flush()

    def send(self, method: str, params: Mapping[str, Any]) -> None:
        if not self.ip:
            return
        try:
            _ = self.sock.sendto(json.dumps({"id": 1, "method": method, "params": params}).encode(), (self.ip, PORT))
        except OSError as e:
            self.emit({"type": "error", "op": method, "code": -1, "message": str(e)})

    def find(self) -> None:
        self.emit({"type": "scanning"})
        bulbs = scan()
        self.next_scan = time.monotonic() + RESCAN_EVERY
        if not bulbs:
            self.emit({"type": "notfound"})
            return
        match = next((b for b in bulbs if b["ip"] == self.ip), bulbs[0])
        self.attach(match["ip"])
        self.emit({"type": "state", "ip": self.ip, "pilot": match["pilot"]})

    def attach(self, ip: str) -> None:
        self.ip = ip
        self.missed = 0
        self.lost = False
        self.emit({"type": "host", "ip": ip})
        self.send("getSystemConfig", {})
        self.send("getModelConfig", {})
        self.send("getPilot", {})
        self.next_poll = time.monotonic() + self.poll

    def command(self, line: str) -> None:
        try:
            msg_raw: Any = json.loads(line)
        except ValueError:
            return
        if not isinstance(msg_raw, dict):
            return
        msg: dict[str, Any] = cast(dict[str, Any], msg_raw)
        op = msg.get("op")
        params = msg.get("params")
        if op == "pilot" and isinstance(params, dict):
            self.pending = cast(dict[str, Any], params)
        elif op == "refresh":
            self.send("getPilot", {})
        elif op == "scan":
            self.find()
        elif op == "host" and msg.get("ip"):
            self.attach(str(msg["ip"]))

    def receive(self) -> None:
        while True:
            try:
                data, (addr, _) = self.sock.recvfrom(4096)
            except (BlockingIOError, OSError):
                return
            if addr != self.ip:
                continue
            try:
                reply_raw: Any = json.loads(data)
            except ValueError:
                continue
            if not isinstance(reply_raw, dict):
                continue
            reply: dict[str, Any] = cast(dict[str, Any], reply_raw)
            method = str(reply.get("method", ""))
            if self.lost:
                self.lost = False
                self.emit({"type": "host", "ip": self.ip})
            self.missed = 0
            if "error" in reply:
                err_raw = reply["error"]
                err: dict[str, Any] = cast(dict[str, Any], err_raw) if isinstance(err_raw, dict) else {}
                self.emit({"type": "error", "op": method, "code": err.get("code", 0), "message": err.get("message", "")})
            elif method == "getPilot":
                self.emit({"type": "state", "ip": self.ip, "pilot": cast(dict[str, Any], reply.get("result", {}))})
            elif method == "setPilot":
                self.emit({"type": "ok", "op": method})
                self.confirm_at = time.monotonic() + CONFIRM_DELAY
            elif method == "getSystemConfig":
                self.emit({"type": "system", "config": cast(dict[str, Any], reply.get("result", {}))})
            elif method == "getModelConfig":
                self.emit({"type": "model", "config": cast(dict[str, Any], reply.get("result", {}))})

    def tick(self) -> None:
        now = time.monotonic()
        if self.pending is not None and now - self.last_send >= SEND_GAP:
            self.send("setPilot", self.pending)
            self.pending = None
            self.last_send = now
        if self.confirm_at and now >= self.confirm_at:
            self.confirm_at = 0.0
            self.send("getPilot", {})
        if self.ip and now >= self.next_poll:
            self.next_poll = now + self.poll
            self.missed += 1
            if self.missed > LOST_AFTER and not self.lost:
                self.lost = True
                self.emit({"type": "lost", "ip": self.ip})
            self.send("getPilot", {})
        if (self.lost or not self.ip) and now >= self.next_scan:
            self.find()

    def wait(self) -> float:
        now = time.monotonic()
        waits = [max(0.0, self.next_poll - now)] if self.ip else [1.0]
        if self.pending is not None:
            waits.append(max(0.0, self.last_send + SEND_GAP - now))
        if self.confirm_at:
            waits.append(max(0.0, self.confirm_at - now))
        return min(waits)

    def run(self) -> None:
        if self.ip:
            self.attach(self.ip)
            self.next_scan = time.monotonic() + 3.0
            self.missed = LOST_AFTER
        else:
            self.find()
        stdin = sys.stdin
        while True:
            ready, _, _ = select.select([stdin, self.sock], [], [], self.wait())
            if stdin in ready:
                line = stdin.readline()
                if not line:
                    return
                self.command(line)
            if self.sock in ready:
                self.receive()
            self.tick()


def main() -> int:
    parser = argparse.ArgumentParser(prog="nebula wiz", description="WiZ smart bulbs on the local network")
    sub = parser.add_subparsers(dest="cmd", required=True)
    p_serve = sub.add_parser("serve", help="JSON lines in on stdin, bulb state out on stdout")
    _ = p_serve.add_argument("--ip", default="")
    _ = p_serve.add_argument("--poll", type=float, default=4.0)
    _ = sub.add_parser("scan", help="list bulbs on the network")
    p_state = sub.add_parser("state", help="print one bulb's state")
    _ = p_state.add_argument("--ip", default="")
    p_set = sub.add_parser("set", help='send setPilot params, e.g. \'{"dimming": 40}\'')
    _ = p_set.add_argument("params")
    _ = p_set.add_argument("--ip", default="")
    args = parser.parse_args()

    if args.cmd == "serve":
        try:
            Server(str(args.ip), max(1.0, float(args.poll))).run()
        except KeyboardInterrupt:
            pass
        return 0
    if args.cmd == "scan":
        print(json.dumps(scan(), indent=2))
        return 0
    ip: str = str(args.ip)
    if not ip:
        bulbs = scan()
        if not bulbs:
            print("no WiZ bulb found", file=sys.stderr)
            return 1
        ip = bulbs[0]["ip"]
    try:
        if args.cmd == "state":
            print(json.dumps(request(ip, "getPilot", {}), indent=2))
        else:
            set_params_raw: Any = json.loads(args.params)
            set_params: dict[str, Any] = cast(dict[str, Any], set_params_raw) if isinstance(set_params_raw, dict) else {}
            print(json.dumps(request(ip, "setPilot", set_params), indent=2))
    except (OSError, ValueError) as e:
        print(f"{ip}: {e}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
