#!/usr/bin/env python3
import hashlib
import os
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor

from PIL import Image, ImageOps

CACHE: str = os.path.join(os.environ.get("HOME", "/tmp"), ".cache", "quickshell", "phone-thumbs")
IMAGES: set[str] = {".jpg", ".jpeg", ".png", ".webp", ".gif", ".bmp", ".heic"}
VIDEOS: set[str] = {".mp4", ".mkv", ".webm", ".mov", ".3gp", ".avi"}
SIZE: int = 320


def key(path: str) -> str:
    st = os.stat(path)
    raw = f"{path}\0{st.st_size}\0{int(st.st_mtime)}".encode()
    return os.path.join(CACHE, hashlib.sha1(raw).hexdigest() + ".jpg")


def make(path: str, out: str) -> None:
    ext = os.path.splitext(path)[1].lower()
    tmp = out + ".part.jpg"
    if ext in VIDEOS:
        _ = subprocess.run(["ffmpegthumbnailer", "-i", path, "-o", tmp, "-s", str(SIZE), "-q", "6"],
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=40, check=True)
    else:
        with Image.open(path) as im:
            _ = im.draft("RGB", (SIZE * 2, SIZE * 2))
            im = ImageOps.exif_transpose(im).convert("RGB")
            im.thumbnail((SIZE, SIZE))
            im.save(tmp, "JPEG", quality=82)
    os.replace(tmp, out)


def emit(path: str, thumb: str) -> None:
    _ = sys.stdout.write(f"{path}\t{thumb}\n")
    _ = sys.stdout.flush()


def work(item: tuple[str, str]) -> None:
    path, out = item
    try:
        make(path, out)
        emit(path, out)
    except Exception:
        emit(path, "")


def main() -> int:
    files = [f for f in sys.argv[1:] if os.path.splitext(f)[1].lower() in IMAGES | VIDEOS]
    os.makedirs(CACHE, exist_ok=True)
    todo: list[tuple[str, str]] = []
    for f in files:
        try:
            out = key(f)
        except OSError:
            continue
        if os.path.exists(out):
            emit(f, out)
        else:
            todo.append((f, out))
    with ThreadPoolExecutor(max_workers=4) as pool:
        _ = list(pool.map(work, todo))
    return 0


if __name__ == "__main__":
    sys.exit(main())
