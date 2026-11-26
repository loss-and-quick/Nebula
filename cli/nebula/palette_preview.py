#!/usr/bin/env python3
import json
import os
import sys
from pathlib import Path

from materialyoucolor.hct import Hct  # pyright: ignore[reportMissingTypeStubs]
from nebula import scheme as g


def main() -> None:
    if len(sys.argv) < 5:
        print(f"Usage: {sys.argv[0]} <original> <thumb> <variant> <mode>", file=sys.stderr)
        sys.exit(1)

    original, thumb = sys.argv[1], sys.argv[2]
    variant = sys.argv[3].removeprefix("scheme-").replace("-", "")
    mode = sys.argv[4].lower()

    fixed = g.fixed_scheme(variant, mode != "light")
    if fixed is not None:
        print(json.dumps(fixed))
        return

    primary: Hct | None = None
    if os.path.isfile(original):
        img_hash = g.image_hash(original)
        idx = g.chosen_seed(img_hash)
        name = f"{variant}_{mode}_s{idx}.json" if idx else f"{variant}_{mode}.json"
        cached: Path = g.CACHE_DIR / "color_cache" / img_hash / name
        if cached.exists():
            cached_data: object = json.loads(cached.read_text())
            print(json.dumps(cached_data))
            return
        primary = g.seed_primary(original, img_hash, idx)

    if primary is None:
        source = thumb if os.path.isfile(thumb) else original
        primary = g.quantize_and_score(source)
    print(json.dumps(g.build_scheme(primary, variant, mode != "light")))


if __name__ == "__main__":
    main()
