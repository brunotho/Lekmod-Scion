"""Parse changelog.txt into item blocks (used by the other changelog_* scripts).

Usage: changelog_cards.py "game mechanics"       dump the player text of every card whose first tag is that
       changelog_cards.py "FEAR AURA" --title      dump the cards whose title starts with that
"""
import re, sys

PATH = r"C:\Users\bbruno\civ-tools\lek\changelog.txt"


def load():
    raw = open(PATH, "rb").read()
    crlf = b"\r\n" in raw
    lines = raw.decode("utf-8").replace("\r\n", "\n").split("\n")
    return lines, crlf


def is_title(lines, i):
    return i + 1 < len(lines) and re.match(r"^-{3,}\s*$", lines[i + 1]) and lines[i].strip() and not lines[i].startswith("- ")


def items(lines):
    """Yield (start, end, title, tags) with end exclusive (up to the next title or a '## ' line)."""
    i = 0
    while i < len(lines):
        if is_title(lines, i):
            j = i + 2
            tags = []
            if j < len(lines) and lines[j].startswith("Tags:"):
                tags = [t.strip() for t in lines[j][5:].split(",")]
            k = i + 2
            while k < len(lines) and not is_title(lines, k) and not lines[k].startswith("## "):
                k += 1
            yield i, k, lines[i].strip(), tags
            i = k
        else:
            i += 1


if __name__ == "__main__":
    lines, _ = load()
    for s, e, title, tags in items(lines):
        if ("--title" in sys.argv and title.startswith(sys.argv[1])) or ("--title" not in sys.argv and tags and tags[0] == sys.argv[1]):
            print("##", title[:80], "|", ", ".join(tags))
            for l in lines[s + 2:e]:
                if l.strip() and not re.match(r"- (Dev|DLL|Note):|Tags:", l):
                    print("  " + l[:280])
