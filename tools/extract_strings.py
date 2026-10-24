#!/usr/bin/env python3
"""Collects UI source strings (gettext-style keys) into data/i18n/strings.csv.

Keys are the English source text, which Godot auto-translates on Label/Button.
To add Spanish later, add an "es" column and fill translations; untranslated
rows fall back to English. Run from the repository root.
"""
import csv, glob, re
pat = re.compile(r'(?:UI\.(?:label|button)|header|Sheet\.open\(self,)\(?\s*"((?:[^"\\]|\\.)+)"')
keys = []
for path in sorted(glob.glob("scenes/**/*.gd", recursive=True) + glob.glob("scripts/**/*.gd", recursive=True)):
    for m in pat.finditer(open(path, encoding="utf-8").read()):
        s = m.group(1)
        if "%" in s or s in keys:
            continue
        keys.append(s)
with open("data/i18n/strings.csv", "w", newline="", encoding="utf-8") as f:
    w = csv.writer(f)
    w.writerow(["keys", "en"])
    for k in keys:
        w.writerow([k, k])
print(len(keys), "strings")
