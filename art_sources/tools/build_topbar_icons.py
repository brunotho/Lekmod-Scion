"""Top bar buttons for Research Info, Unit List and Great Person List (user, 2026-11-27).

The top-left panel buttons (InfoCorner) are 45 px textures inside the game's .fpk archives. Civ V can't scale a
texture down (only crop it), so this extracts the three base textures and writes 24 px copies:
    LEKMOD/Art/Lekmod (v 1)/Art/TopBar/LekmodTopBar{Tech,Units,GP}[HL]24.dds   (B8G8R8A8, one mip; HL = mouse-over glow)
The 45 px sources are kept in art_sources/topbar/ as PNG. Rerunnable: python art_sources/tools/build_topbar_icons.py
"""
import glob, os, struct, subprocess
from PIL import Image

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
RES = r"C:/Program Files (x86)/Steam/steamapps/common/Sid Meier's Civilization V/Resource"
TEXCONV = r"C:/Users/bbruno/civ-tools/texconv.exe"
SRC = os.path.join(REPO, "art_sources", "topbar")
OUT = os.path.join(REPO, "LEKMOD", "Art", "Lekmod (v 1)", "Art", "TopBar")
ICONS = {"maintechbutton.dds": "Tech", "mainunitbutton.dds": "Units", "maingreatpersonbutton.dds": "GP",
         # the glowing versions, shown while the mouse is over a button
         "maintechbuttonhl.dds": "TechHL", "mainunitbuttonhl.dds": "UnitsHL", "maingreatpersonbuttonhl.dds": "GPHL"}
SIZE = 24


def extract(name):
    """Finds name in the .fpk tables: after the name come a few bytes, then u32 size and u32 offset of a DDS."""
    key = name.encode()
    for f in glob.glob(RES + "/**/*.fpk", recursive=True):
        data = open(f, "rb").read()
        i = data.lower().find(key)
        if i < 0:
            continue
        base = i + len(key)
        for k in range(24):
            size, off = struct.unpack_from("<II", data, base + k)
            if 0 < size < 10_000_000 and 0 < off < len(data) - 4 and data[off:off + 4] == b"DDS ":
                return data[off:off + size]
    raise SystemExit("not found in any .fpk: " + name)


def main():
    os.makedirs(SRC, exist_ok=True)
    os.makedirs(OUT, exist_ok=True)
    for name, tag in ICONS.items():
        dds = os.path.join(SRC, name)
        open(dds, "wb").write(extract(name))
        im = Image.open(dds).convert("RGBA")
        im.save(os.path.join(SRC, name.replace(".dds", "_45.png")))
        os.remove(dds)
        png = os.path.join(SRC, "LekmodTopBar%s%d.png" % (tag, SIZE))
        im.resize((SIZE, SIZE), Image.LANCZOS).save(png)
        subprocess.run([TEXCONV, "-nologo", "-y", "-f", "B8G8R8A8_UNORM", "-m", "1", "-o", OUT, png], check=True,
                       stdout=subprocess.DEVNULL)
        os.remove(png)
        print("wrote", os.path.join(OUT, "LekmodTopBar%s%d.dds" % (tag, SIZE)))


if __name__ == "__main__":
    main()
