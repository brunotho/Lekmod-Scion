"""Print rows of a table in upstream v35.4 (201df6c5) CIV5Units.xml that contain a text. Usage: v354rows.py TABLE TEXT"""
import re, subprocess, sys

table, needle = sys.argv[1], sys.argv[2]
s = subprocess.run(["git", "-C", r"C:\Users\bbruno\civ-tools\lek", "show", "201df6c5:LEKMOD/Override/CIV5Units.xml"],
                   capture_output=True).stdout.decode("utf-8", "replace")
s = re.sub(r"<!--.*?-->", "", s, flags=re.S)
for blk in re.findall(r"<%s>(.*?)</%s>" % (table, table), s, re.S):
    for el in re.findall(r"<Row>.*?</Row>|<Delete[^>]*/>|<Update>.*?</Update>", blk, re.S):
        if needle in el:
            print(re.sub(r"\s+", " ", el))
