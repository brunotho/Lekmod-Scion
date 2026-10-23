"""Edit texts in CIV5Units_Mongol.xml by tag. A tag can be defined several times (<Row> and later <Replace>);
the last definition wins in game, so every edit is applied to all definitions. Keeps the file's line endings.

    from textedit import T
    T.get("TXT_KEY_X")                       # text of the last definition
    T.set("TXT_KEY_X", "new text")           # all definitions
    T.sub("TXT_KEY_X", "old", "new")         # replace inside every definition; "old" must occur in the last one
    T.save()

python tools/dev/textedit.py TXT_KEY_X       prints all definitions with line numbers
"""
import re
import sys

PATH = r"C:/Users/bbruno/civ-tools/lek/LEKMOD/Override/CIV5Units_Mongol.xml"


class Texts:
    def __init__(self, path=PATH):
        self.path = path
        raw = open(path, "rb").read()
        self.crlf = b"\r\n" in raw
        self.s = raw.decode("utf-8").replace("\r\n", "\n")
        self.dirty = False

    def _defs(self, tag):
        pat = re.compile(r'(<(?:Row|Replace)\s+Tag\s*=\s*"%s"[^>]*>\s*<Text>)(.*?)(</Text>)' % re.escape(tag), re.S)
        # skip commented-out regions
        comments = [(m.start(), m.end()) for m in re.finditer(r"<!--.*?-->", self.s, re.S)]
        out = []
        for m in pat.finditer(self.s):
            if any(a <= m.start() < b for a, b in comments):
                continue
            out.append(m)
        return out

    def get(self, tag):
        d = self._defs(tag)
        if not d:
            raise KeyError(tag)
        return d[-1].group(2)

    def _rewrite(self, tag, fn):
        d = self._defs(tag)
        if not d:
            raise KeyError(tag)
        for m in reversed(d):
            new = fn(m.group(2))
            self.s = self.s[:m.start(2)] + new + self.s[m.end(2):]
        self.dirty = True

    def set(self, tag, text):
        self._rewrite(tag, lambda _old: text)

    def sub(self, tag, old, new):
        if old not in self.get(tag):
            raise ValueError("%s: %r not in its last definition" % (tag, old))
        self._rewrite(tag, lambda t: t.replace(old, new))

    def save(self):
        if not self.dirty:
            return
        out = self.s.replace("\n", "\r\n") if self.crlf else self.s
        open(self.path, "wb").write(out.encode("utf-8"))
        self.dirty = False


T = Texts()

if __name__ == "__main__":
    for tag in sys.argv[1:]:
        for m in T._defs(tag):
            line = T.s.count("\n", 0, m.start()) + 1
            print("%d: %s" % (line, m.group(2)))
