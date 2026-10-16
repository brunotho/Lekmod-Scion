"""Effective texts of every civ's UA, unique units, buildings and improvements, from the Override files (no game DB needed).

usage: python tools/dev/civtexts.py [ua|ub|uu|ui|all] [CIVILIZATION_X ...] > out.txt
The text of a tag is its last <Row>/<Replace> in CIV5Units_Mongol.xml (later definitions win, like in the game).
Civ links are read from CIV5Units.xml: Civilization_Leaders -> Leader_Traits -> Traits.Description,
Civilization_UnitClassOverrides / Civilization_BuildingClassOverrides (Help texts), Improvements.SpecificCivRequired.
Rows inside XML comments are ignored. <Delete> rows are not applied (rare for these tables; check by hand if odd).
"""
import re, sys

REPO = r"C:/Users/bbruno/civ-tools/lek/LEKMOD/Override/"


def nocomments(s):
    return re.sub(r"<!--.*?-->", "", s, flags=re.S)


def texts():
    s = nocomments(open(REPO + "CIV5Units_Mongol.xml", encoding="utf-8").read())
    out = {}
    for m in re.finditer(r'<(?:Row|Replace) Tag="([^"]+)"[^>]*>\s*<Text>(.*?)</Text>', s, re.S):
        out[m.group(1)] = re.sub(r"\s+", " ", m.group(2)).strip()
    return out


def rows(data, table):
    out = []
    for blk in re.findall(r"<%s>(.*?)</%s>" % (table, table), data, re.S):
        for r in re.findall(r"<Row>(.*?)</Row>", blk, re.S):
            out.append(dict(re.findall(r"<(\w+)>([^<]*)</\1>", r)))
    return out


def main():
    what = sys.argv[1] if len(sys.argv) > 1 else "all"
    only = set(sys.argv[2:])
    d = nocomments(open(REPO + "CIV5Units.xml", encoding="utf-8").read())
    t = texts()
    leaders = {}
    for r in rows(d, "Civilization_Leaders"):
        leaders.setdefault(r.get("CivilizationType"), []).append(r.get("LeaderheadType"))
    ltraits = {}
    for r in rows(d, "Leader_Traits"):
        ltraits.setdefault(r.get("LeaderType"), []).append(r.get("TraitType"))
    traits, units, buildings, imps = {}, {}, {}, {}
    for r in rows(d, "Traits"):
        if "Type" in r:
            traits[r["Type"]] = r
    for r in rows(d, "Units"):
        if "Type" in r:
            units[r["Type"]] = r
    for r in rows(d, "Buildings"):
        if "Type" in r:
            buildings[r["Type"]] = r
    for r in rows(d, "Improvements"):
        if "Type" in r:
            imps[r["Type"]] = r
    civs = sorted(c for c in leaders if c and (not only or c in only))
    uu = {}
    for r in rows(d, "Civilization_UnitClassOverrides"):
        if r.get("UnitType"):
            uu.setdefault(r.get("CivilizationType"), []).append(r["UnitType"])
    ub = {}
    for r in rows(d, "Civilization_BuildingClassOverrides"):
        if r.get("BuildingType"):
            ub.setdefault(r.get("CivilizationType"), []).append(r["BuildingType"])
    for b in buildings.values():
        if b.get("RequiredCivilization"):
            ub.setdefault(b["RequiredCivilization"], []).append(b["Type"])
    ui = {}
    for i in imps.values():
        if i.get("SpecificCivRequired") == "true" and i.get("CivilizationType"):
            ui.setdefault(i["CivilizationType"], []).append(i["Type"])
    for c in civs:
        print("=" * 8, c)
        if what in ("ua", "all"):
            for l in leaders[c]:
                for tr in ltraits.get(l, []):
                    k = traits.get(tr, {}).get("Description")
                    print("UA", tr, k, "::", t.get(k, "?"))
        if what in ("uu", "all"):
            for u in sorted(set(uu.get(c, []))):
                k = units.get(u, {}).get("Help")
                print("UU", u, k, "::", t.get(k, "?"))
        if what in ("ub", "all"):
            for b in sorted(set(ub.get(c, []))):
                k = buildings.get(b, {}).get("Help")
                print("UB", b, k, "::", t.get(k, "?"))
        if what in ("ui", "all"):
            for i in sorted(set(ui.get(c, []))):
                k = imps.get(i, {}).get("Help")
                print("UI", i, k, "::", t.get(k, "?"))


if __name__ == "__main__":
    main()
