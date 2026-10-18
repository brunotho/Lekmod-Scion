"""Re-copy collection lines ('{Source} head: ...') from their source cards, matched by kind and head."""
import os, re, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from changelog_cards import load, items, PATH

lines, crlf = load()
PLAYER = re.compile(r"^- (Added|Changed|Removed|Fixed): (.*)$")


def entries(s, e):
    out = []
    for n in range(s, e):
        m = PLAYER.match(lines[n])
        if m:
            out.append([m.group(1), m.group(2), [], n, n])
        elif re.match(r"^\s{2,}- ", lines[n]) and out:
            out[-1][2].append(lines[n].strip()[2:])
            out[-1][4] = n
    return out


cards = {}
for s, e, title, tags in items(lines):
    name = re.sub(r"\s*\((NEW|[^()]*)\)\s*$", "", re.sub(r"\s*\(NEW\)", "", title)).strip().upper()
    cards[name] = (s, e, title)

fixes = []
for name, (s, e, title) in cards.items():
    if not any(lines[n].startswith("Collects:") for n in range(s, e)):
        continue
    for kind, text, its, a, b in entries(s, e):
        m = re.match(r"^\{([^}]*)\} (.*)$", text)
        src, body = m.group(1), m.group(2)
        ss, se, _ = cards[src.upper()]
        head = body.split(":")[0]
        cands = [x for x in entries(ss, se) if x[1].split(":")[0] == head and x[0] == kind]
        if any(x[1] == body and x[2] == its for x in cands):
            continue
        assert len(cands) == 1, (src, head, len(cands))
        x = cands[0]
        fixes.append((a, b, ["- %s: {%s} %s" % (kind, src, x[1])] + ["  - " + i for i in x[2]]))
        print("resynced", src, head)
for a, b, new in sorted(fixes, reverse=True):
    lines[a:b + 1] = new
res = "\n".join(lines)
if crlf:
    res = res.replace("\n", "\r\n")
open(PATH, "wb").write(res.encode("utf-8"))
