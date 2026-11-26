import sys
from typing import Any, cast

from fontTools.ttLib import TTFont  # pyright: ignore[reportMissingTypeStubs]
from fontTools.varLib import instancer  # pyright: ignore[reportMissingTypeStubs]

FAMILY = "Google Sans Flex Clock"
AXES: dict[str, int] = {"wght": 1000, "wdth": 106, "ROND": 0, "opsz": 144, "slnt": 0}


def main(src: str, dst: str) -> None:
    inst: Any = cast(Any, instancer)
    font: Any = inst.instantiateVariableFont(TTFont(src), AXES, overlap=inst.OverlapMode.REMOVE)
    name: Any = font["name"]
    for rec in list[Any](name.names):
        if rec.nameID in (16, 17, 21, 22, 25):
            _ = name.removeNames(nameID=rec.nameID)
    _ = name.setName(FAMILY, 1, 3, 1, 0x409)
    _ = name.setName("Regular", 2, 3, 1, 0x409)
    _ = name.setName(FAMILY + " Regular", 3, 3, 1, 0x409)
    _ = name.setName(FAMILY, 4, 3, 1, 0x409)
    _ = name.setName(FAMILY.replace(" ", "") + "-Regular", 6, 3, 1, 0x409)
    for table in ("STAT",):
        if table in font:
            del font[table]
    os2: Any = font["OS/2"]
    os2.usWeightClass = 900
    os2.fsSelection = (os2.fsSelection & ~0b1100001) | 0b1000000
    head: Any = font["head"]
    head.macStyle = 0
    _ = font.save(dst)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
