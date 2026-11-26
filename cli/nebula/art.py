#!/usr/bin/env python3
import colorsys
import hashlib
import json
import os
import sys
import urllib.parse
import urllib.request

from PIL import Image

CACHE = os.path.join(os.environ.get("HOME", "/tmp"), ".cache", "quickshell", "art")


def fetch(url):
    if url.startswith("file://"):
        return urllib.parse.unquote(url[7:])
    if url.startswith("/"):
        return url
    os.makedirs(CACHE, exist_ok=True)
    path = os.path.join(CACHE, hashlib.sha1(url.encode()).hexdigest())
    if not os.path.exists(path):
        req = urllib.request.Request(url, headers={"User-Agent": "quickshell"})
        with urllib.request.urlopen(req, timeout=8) as r, open(path + ".part", "wb") as f:
            f.write(r.read())
        os.replace(path + ".part", path)
    return path


def palette(path, count=4):
    img = Image.open(path).convert("RGB")
    img.thumbnail((96, 96))
    q = img.quantize(colors=12, method=Image.Quantize.MEDIANCUT)
    pal = q.getpalette()
    colors = q.getcolors()
    if pal is None or not colors:
        return []
    scored = []
    for n, idx in colors:
        if not isinstance(idx, int):
            continue
        r, g, b = (c / 255 for c in pal[idx * 3: idx * 3 + 3])
        h, l, s = colorsys.rgb_to_hls(r, g, b)
        scored.append((n * (0.25 + s) * (0.3 + min(l, 1 - l)), h, l, s))
    scored.sort(reverse=True)
    picked = []
    for _, h, l, s in scored:
        if all(min(abs(h - p[0]), 1 - abs(h - p[0])) > 0.06 for p in picked) or len(scored) <= count:
            picked.append((h, l, s))
        if len(picked) == count:
            break
    while len(picked) < count and picked:
        h, l, s = picked[len(picked) % len(picked)]
        picked.append(((h + 0.08) % 1, l, s))
    out = []
    for h, l, s in picked:
        l = max(0.55, min(0.75, l + 0.2))
        s = max(0.45, min(0.95, s * 1.3))
        r, g, b = colorsys.hls_to_rgb(h, l, s)
        out.append("#%02x%02x%02x" % (int(r * 255), int(g * 255), int(b * 255)))
    return out


def main():
    if len(sys.argv) < 2 or not sys.argv[1]:
        print("[]")
        return
    try:
        print(json.dumps(palette(fetch(sys.argv[1]))))
    except Exception:
        print("[]")


if __name__ == "__main__":
    main()
