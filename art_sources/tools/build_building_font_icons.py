"""Font icons for buildings that have no base-game font icon, for tooltips: [ICON_BUILDING_LEKMOD_SLAVE_MARKET] (1),
[ICON_BUILDING_LEKMOD_FEITORIA] (2). Each is the building's 64 px round icon from LEKMOD_BUILDING_ATLAS scaled to
22x22, in one 64x64 texture (LekmodBuildingFontIcons.dds) with its glyph file LekmodBuildingFontIcons_22.ggxml
(the pattern of the resource font icons; glyph ch = IconMapping). Written uncompressed (B8G8R8A8) with texconv.
To add one: append (atlas index, name) to ICONS, rerun, and add the IconFontMapping row (next number).
usage: python art_sources/tools/build_building_font_icons.py
"""
import os, subprocess
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ART = os.path.join(ROOT, "LEKMOD", "Art", "Lekmod (v 1)", "Art", "Buildings")
ATLAS = os.path.join(ART, "buildings_icons_64.dds")
TEXCONV = r"C:/Users/bbruno/civ-tools/texconv.exe"
ICONS = [(23, "Slave Market"), (7, "Feitoria")]  # LEKMOD_BUILDING_ATLAS PortraitIndex, 8 per row
SIZE, TEX = 22, 64

atlas = Image.open(ATLAS).convert("RGBA")
tex = Image.new("RGBA", (TEX, TEX), (0, 0, 0, 0))
glyphs = []
for n, (idx, _name) in enumerate(ICONS):
    x, y = (idx % 8) * 64, (idx // 8) * 64
    icon = atlas.crop((x, y, x + 64, y + 64)).resize((SIZE, SIZE), Image.LANCZOS)
    u, v = (n * SIZE) % (TEX - TEX % SIZE), (n * SIZE) // (TEX - TEX % SIZE) * SIZE
    tex.paste(icon, (u, v))
    glyphs.append('        <glyph ch="%d" u="%d" v="%d" width="%d" height="%d" a="0" b="%d" c="0" originx="0" originy="%d" />'
                  % (n + 1, u, v, SIZE, SIZE, SIZE, SIZE))

png = os.path.join(ART, "LekmodBuildingFontIcons.png")
tex.save(png)
subprocess.run([TEXCONV, "-f", "B8G8R8A8_UNORM", "-m", "1", "-y", "-o", ART, png], check=True, stdout=subprocess.DEVNULL)
os.remove(png)

GGXML = """<?xml version="1.0" encoding="UTF-8" ?>
<glyphgen>
    <textures width="%d" height="%d">
        <texture name="" src="LekmodBuildingFontIcons.dds" allowcolor="1" alloweffects="1" inuse="1" />
    </textures>
    <styles count="1">
        <style name="">
            <layers count="1">
                <layer tex="" />
            </layers>
        </style>
    </styles>
    <glyphs fudgeadv="0" ascadj="-6" spacing="0" count="%d" height="0" ascent="0" descent="0">
%s
    </glyphs>
    <imports />
    <toolonly>
        <metainfo pt="0.000000" width="256" height="256" alphabias="64" maxsize="256" bestfit="0" pow2="1" freetype="2" fontsrc="" />
        <glyphsets>
            <set name="GlyphSetAscii" />
        </glyphsets>
    </toolonly>
</glyphgen>
""" % (TEX, TEX, len(glyphs), "\n".join(glyphs))
with open(os.path.join(ART, "LekmodBuildingFontIcons_22.ggxml"), "w", encoding="utf-8", newline="\n") as f:
    f.write(GGXML)
print("wrote LekmodBuildingFontIcons.dds / _22.ggxml with", len(glyphs), "icons")
