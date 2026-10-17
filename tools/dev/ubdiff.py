"""Unique buildings vs. their base building, from the loaded DB (cache/Civ5DebugDatabase.db).
usage: python tools/dev/ubdiff.py [civ or building substring ...]   (no argument = all)
Per unique building: Buildings columns that differ (base -> unique), rows of every BuildingType sub-table only the base or only
the unique building has, and the current Help text. Used for the UB tooltip audit (2026-10-17).
"""
import os
import sqlite3
import sys

DB = os.path.expanduser("~/Documents/My Games/Sid Meier's Civilization 5/cache/Civ5DebugDatabase.db")
LOC = os.path.expanduser("~/Documents/My Games/Sid Meier's Civilization 5/cache/Localization-Merged.db")
COSMETIC = {"ID", "Type", "Description", "Civilopedia", "Help", "Strategy", "ArtDefineTag", "IconAtlas", "PortraitIndex",
            "ArtInfoCulturalVariation", "ArtInfoEraVariation", "ArtInfoRandomVariation", "WonderSplashImage", "WonderSplashAnchor",
            "WonderSplashAudio", "ThemingBonusHelp", "Quote", "DisplayPosition", "MinAreaSize", "ConquestProb", "HurryCostModifier",
            "RequiredCivilization", "ShowInPedia"}

c = sqlite3.connect(DB)
c.row_factory = sqlite3.Row
loc = sqlite3.connect(LOC)


def text(tag):
    if not tag:
        return ""
    r = loc.execute("select Text from LocalizedText where Language='en_US' and Tag=?", (tag,)).fetchone()
    return r[0] if r else "<missing %s>" % tag


def subtables():
    out = []
    for (t,) in c.execute("select name from sqlite_master where type='table'"):
        cols = [r[1] for r in c.execute("pragma table_info('%s')" % t)]
        if "BuildingType" in cols and t != "Buildings" and not t.startswith("Civilization_"):
            out.append((t, [x for x in cols if x != "BuildingType"]))
    return out


SUB = subtables()


def rows(t, cols, b):
    return set(tuple(r) for r in c.execute("select %s from %s where BuildingType=?" % (",".join('"%s"' % x for x in cols), t), (b,)))


def main(filters):
    q = """select o.CivilizationType civ, o.BuildingClassType cls, o.BuildingType ub, bc.DefaultBuilding base
           from Civilization_BuildingClassOverrides o join BuildingClasses bc on bc.Type=o.BuildingClassType
           where o.BuildingType is not null and o.BuildingType != '' order by o.CivilizationType"""
    bcols = [r[1] for r in c.execute("pragma table_info('Buildings')")]
    for o in c.execute(q).fetchall():
        key = " ".join([o["civ"], o["ub"]]).upper()
        if filters and not any(f.upper() in key for f in filters):
            continue
        u = c.execute("select * from Buildings where Type=?", (o["ub"],)).fetchone()
        b = c.execute("select * from Buildings where Type=?", (o["base"],)).fetchone() if o["base"] else None
        if u is None:
            continue
        print("=" * 100)
        print(o["civ"], "|", o["ub"], "(%s)" % text(u["Description"]), "replaces", o["base"], "(%s)" % (text(b["Description"]) if b else "-"))
        if b is not None:
            for col in bcols:
                if col in COSMETIC:
                    continue
                if u[col] != b[col]:
                    print("  col %-34s %r -> %r" % (col, b[col], u[col]))
        for t, cols in SUB:
            ru = rows(t, cols, o["ub"])
            rb = rows(t, cols, o["base"]) if b is not None else set()
            for r in sorted(rb - ru, key=str):
                print("  base only %s %s" % (t, dict(zip(cols, r))))
            for r in sorted(ru - rb, key=str):
                print("  UB only   %s %s" % (t, dict(zip(cols, r))))
        print("  HELP:", text(u["Help"]))
        if b is not None:
            print("  BASE HELP:", text(b["Help"]))


if __name__ == "__main__":
    main(sys.argv[1:])
