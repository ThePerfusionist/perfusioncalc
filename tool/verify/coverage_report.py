#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
PerfusionCalc — Testabdeckung auswerten

Liest `coverage/lcov.info` (erzeugt von `flutter test --coverage`) und listet
die Dateien nach Abdeckung, ungetestete zuerst.

Warum das gebraucht wird: Bis v0.4.11 war `CardioplegiaSettings` die einzige
der drei persistierten Einstellungen ohne Tests — gefunden wurde das durch
Zufall beim Durchsehen, nicht systematisch. Eine Lücke, die man nicht sieht,
schließt man nicht.

Aufruf:
    flutter test --coverage
    python3 tool/verify/coverage_report.py

Optionen:
    --min N     beendet mit 1, wenn eine Datei unter N % liegt (Standard: aus)
    --ignore    Komma-Liste von Pfadfragmenten, die übersprungen werden
"""

import os
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
LCOV = os.path.join(ROOT, "coverage", "lcov.info")

# Reine UI-Dateien lassen sich sinnvoll nur mit Widget-Tests abdecken; sie
# hier auszublenden macht die Liste lesbar. Modelle und utils sind der Teil,
# der Unit-Tests haben MUSS - dort rechnet die App.
DEFAULT_IGNORE = ("lib/screens/", "lib/widgets/", "lib/theme/")


def main() -> int:
    args = sys.argv[1:]
    min_pct = None
    if "--min" in args:
        min_pct = float(args[args.index("--min") + 1])
    ignore = DEFAULT_IGNORE
    if "--ignore" in args:
        ignore = tuple(a.strip() for a in args[args.index("--ignore") + 1].split(","))
    show_all = "--all" in args

    if not os.path.exists(LCOV):
        print(f"coverage/lcov.info nicht gefunden.\n"
              f"Zuerst ausführen:  flutter test --coverage")
        return 1

    files: dict[str, tuple[int, int]] = {}
    current = None
    found = hit = 0
    with open(LCOV, encoding="utf-8", errors="replace") as fh:
        for line in fh:
            line = line.strip()
            if line.startswith("SF:"):
                current = line[3:].replace("\\", "/")
                if ROOT.replace("\\", "/") in current:
                    current = current.split("perfusioncalc/")[-1]
                found = hit = 0
            elif line.startswith("DA:"):
                _, count = line[3:].split(",")[:2]
                found += 1
                if int(count) > 0:
                    hit += 1
            elif line == "end_of_record" and current:
                files[current] = (hit, found)
                current = None

    if not files:
        print("lcov.info enthält keine Datensätze.")
        return 1

    rows = []
    for path, (hit, found) in files.items():
        if not show_all and any(i in path for i in ignore):
            continue
        pct = (hit / found * 100) if found else 100.0
        rows.append((pct, path, hit, found))
    rows.sort()

    total_hit = sum(h for _, (h, f) in files.items())
    total_found = sum(f for _, (h, f) in files.items())

    print()
    print(f"  {'Abdeckung':>10}  {'Zeilen':>12}  Datei")
    print(f"  {'-' * 10}  {'-' * 12}  {'-' * 46}")
    below = []
    for pct, path, hit, found in rows:
        mark = " "
        if found == 0 or hit == 0:
            mark = "!"
            below.append(path)
        elif min_pct is not None and pct < min_pct:
            mark = "!"
            below.append(path)
        print(f"{mark} {pct:9.1f}%  {hit:5d}/{found:<6d}  {path}")

    print()
    overall = (total_hit / total_found * 100) if total_found else 0
    print(f"  Gesamt (alle Dateien): {overall:.1f}%  ({total_hit}/{total_found} Zeilen)")
    if not show_all:
        print(f"  Ausgeblendet: {', '.join(ignore)}  —  mit --all vollständig anzeigen")

    if below:
        print()
        print(f"  {len(below)} Datei(en) unter der Schwelle bzw. ohne jede Abdeckung:")
        for p in below:
            print(f"    {p}")
        if min_pct is not None:
            return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
