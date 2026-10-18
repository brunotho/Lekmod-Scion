"""Check unit '(was X)' stats in changelog.txt against upstream v35.4 data (Units table, standard costs x0.67 for quick)."""
import math, os, re, subprocess, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from changelog_cards import load, items

def show(path):
    s = subprocess.run(["git", "-C", r"C:\Users\bbruno\civ-tools\lek", "show", "201df6c5:" + path], capture_output=True).stdout.decode("utf-8", "replace")
    return re.sub(r"<!--.*?-->", "", s, flags=re.S)

data, txt = show("LEKMOD/Override/CIV5Units.xml"), show("LEKMOD/Override/CIV5Units_Mongol.xml")
texts = {t: re.sub(r"\s+", " ", x).strip() for t, x in re.findall(r'<(?:Row|Replace)\s+Tag\s*=\s*"([^"]+)"[^>]*>\s*<Text>(.*?)</Text>', txt, re.S)}
units = {}
for blk in re.findall(r"<Units>(.*?)</Units>", data, re.S):
    for row in re.findall(r"<Row>(.*?)</Row>", blk, re.S):
        r = dict(re.findall(r"<(\w+)>([^<]*)</\1>", row))
        name = texts.get(r.get("Description", ""), "")
        name = re.sub(r"\[[^\]]*\]", "", name).strip()
        if name:
            units.setdefault(name.lower(), r)
    for upd in re.findall(r"<Update>(.*?)</Update>", blk, re.S):
        t = re.search(r'<Where\s+Type="([^"]+)"', upd)
        if t:
            for r in units.values():
                if r.get("Type") == t.group(1):
                    r.update(dict(re.findall(r'(\w+)="([^"]*)"', re.search(r"<Set\s+([^>]*)/?>", upd).group(1))))

def quick(c):
    return [math.floor(int(c) * 67 / 100), round(int(c) * 0.67), math.ceil(int(c) * 0.67)]

lines, _ = load()
PLAYER = re.compile(r"^- (Added|Changed|Removed|Fixed): (.*)$")
head = None
problems = 0
for s, e, title, tags in items(lines):
    for n in range(s, e):
        l = lines[n]
        m = PLAYER.match(l)
        if m:
            text = m.group(2)
            hm = re.match(r"^(?:\{[^}]*\} )?(?:[A-Za-z' ]+ renamed |the )?([A-Z][\w' .-]{2,40}?)(?: is renamed [\w' ]+)?(?: \(and [^)]*\))?:", text)
            head = hm.group(1) if hm else None
            body = text
        elif re.match(r"^\s{2,}- ", l):
            body = l.strip()[2:]
        else:
            continue
        if not head or head.lower() not in units:
            continue
        u = units[head.lower()]
        checks = [
            (r"(\d+) Ranged Strength \(was (\d+)\)", "RangedCombat", None),
            (r"(?<!Ranged )(\d+) (?:Combat )?Strength \(was (\d+)", "Combat", None),
            (r"(\d+) [Mm]ovement \(was (\d+)\)", "Moves", None),
            (r"costs? (\d+) \((?:like [^,]*, )?was (\d+)\)", "Cost", "quick"),
            (r"cost (\d+) -> (\d+)", "Cost", "quick-first"),
        ]
        for pat, col, mode in checks:
            for mm in re.finditer(pat, body):
                was = mm.group(1) if mode == "quick-first" else mm.group(2)
                val = u.get(col)
                if val is None:
                    continue
                ok = int(was) in quick(val) if mode else int(was) == int(val)
                if not ok:
                    problems += 1
                    print("%-22s %-20s %-12s changelog was %s, v35.4 %s%s" % (title[:22], head[:20], col, was, val,
                          " (quick %s)" % quick(val) if mode else ""))
print("problems:", problems)
