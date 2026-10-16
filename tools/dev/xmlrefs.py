"""Every row in CIV5Units.xml that mentions a type name, with its table (comments skipped).

usage: python tools/dev/xmlrefs.py TYPE_NAME [TYPE_NAME ...]
Prints: line, table, and the row's fields on one line. <Update>/<Delete> entries are listed too.
Useful before reworking an item: shows all data that touches it, wherever it sits in the 300k-line file.
"""
import re, sys

P = r"C:/Users/bbruno/civ-tools/lek/LEKMOD/Override/CIV5Units.xml"


def main(names):
    s = open(P, encoding="utf-8").read()
    s = re.sub(r"<!--.*?-->", lambda m: "\n" * m.group(0).count("\n"), s, flags=re.S)
    # table name at each position: the innermost open element directly under <GameData>
    for m in re.finditer(r"<(Row|Update|Delete)\b(.*?)(/>|</\1>)", s, re.S):
        body = m.group(0)
        if not any(n in body for n in names):
            continue
        line = s.count("\n", 0, m.start()) + 1
        t = None
        for tm in re.finditer(r"\n\t<(\w+)>", s[:m.start()]):
            t = tm.group(1)
        # the last table opened before the row (tables are one tab deep)
        tbl = re.findall(r"\n\t<(\w+)>\s*\n", s[max(0, m.start() - 400000):m.start()])
        tbl = tbl[-1] if tbl else "?"
        flat = " ".join(re.sub(r"\s+", " ", body).split())
        print(line, tbl, flat[:400])


if __name__ == "__main__":
    main(sys.argv[1:])
