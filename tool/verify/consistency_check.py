#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
PerfusionCalc — Konsistenzprüfung
=================================

Prüft die Zusicherungen, die `flutter analyze` und `flutter test` NICHT
abdecken können, weil sie über Dateigrenzen und Sprachgrenzen hinweg gelten:
Dart gegen YAML, Dart gegen JavaScript, Code gegen Dokumentation.

Jede Prüfung hier steht für einen Fehler, der in dieser Codebasis schon
einmal aufgetreten ist. Die Nummern verweisen auf PROJECT_STATE.md § 7.

Aufruf:
    python3 tool/verify/consistency_check.py
    python3 tool/verify/consistency_check.py --quiet     # nur Fehler

Beendet mit 0, wenn alles passt, sonst 1.
"""

import glob
import os
import re
import subprocess
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))

RED, GREEN, YELLOW, DIM, OFF = "\033[31m", "\033[32m", "\033[33m", "\033[2m", "\033[0m"
if os.environ.get("NO_COLOR") or not sys.stdout.isatty():
    RED = GREEN = YELLOW = DIM = OFF = ""

failures: list[str] = []
warnings: list[str] = []
quiet = "--quiet" in sys.argv


def read(rel: str) -> str:
    with open(os.path.join(ROOT, rel), encoding="utf-8") as f:
        return f.read()


def dart_files(*subdirs: str) -> list[str]:
    out = []
    for sub in subdirs:
        out += glob.glob(os.path.join(ROOT, sub, "**", "*.dart"), recursive=True)
    return sorted(out)


def ok(msg: str) -> None:
    if not quiet:
        print(f"  {GREEN}ok{OFF}    {msg}")


def fail(check: str, msg: str) -> None:
    failures.append(f"{check}: {msg}")
    print(f"  {RED}FEHL{OFF}  {check}")
    print(f"        {msg}")


def warn(check: str, msg: str) -> None:
    warnings.append(f"{check}: {msg}")
    print(f"  {YELLOW}warn{OFF}  {check}")
    print(f"        {msg}")


def section(title: str) -> None:
    if not quiet:
        print(f"\n{DIM}── {title} {'─' * max(0, 60 - len(title))}{OFF}")


# ═══════════════════════════════════════════════════════════════════════════
# 1. Versionsnummer an allen drei Stellen gleich
#    Hintergrund: PROJECT_STATE nennt drei Orte, alles andere leitet ab.
#    Ein Auseinanderlaufen fällt sonst erst im ausgelieferten PDF auf, das
#    kAppVersion in die Fußzeile schreibt.
# ═══════════════════════════════════════════════════════════════════════════
def check_version() -> None:
    section("Version")
    pub = re.search(r"^version:\s*([0-9.]+)\+([0-9]+)\s*$", read("pubspec.yaml"), re.M)
    if not pub:
        return fail("Version", "keine 'version:'-Zeile in pubspec.yaml gefunden")
    ver, build = pub.group(1), pub.group(2)

    app = re.search(r"const kAppVersion = '([^']+)'", read("lib/main.dart"))
    if not app:
        return fail("Version", "kAppVersion nicht in lib/main.dart gefunden")
    if app.group(1) != ver:
        return fail("Version", f"pubspec {ver} != kAppVersion {app.group(1)}")

    badge = re.search(r"badge/version-([0-9.]+)-orange", read("README.md"))
    if not badge:
        return fail("Version", "Versions-Badge nicht in README.md gefunden")
    if badge.group(1) != ver:
        return fail("Version", f"pubspec {ver} != README-Badge {badge.group(1)}")

    ok(f"pubspec, kAppVersion und README-Badge stimmen überein ({ver}+{build})")


# ═══════════════════════════════════════════════════════════════════════════
# 2. Test-Badge im README entspricht der tatsächlichen Anzahl
#    K-2: Eine Zahl in der Dokumentation, die nicht mitwächst, ist derselbe
#    Fall wie ein Kommentar, der eine überholte Annahme trägt.
# ═══════════════════════════════════════════════════════════════════════════
def check_test_count() -> None:
    section("Testanzahl")
    actual = 0
    for f in dart_files("test"):
        with open(f, encoding="utf-8") as fh:
            actual += len(re.findall(r"^\s*test\(", fh.read(), re.M))
    badge = re.search(r"badge/tests-(\d+)%20passing", read("README.md"))
    if not badge:
        return fail("Testanzahl", "Test-Badge nicht in README.md gefunden")
    if int(badge.group(1)) != actual:
        return fail("Testanzahl",
                    f"README nennt {badge.group(1)}, gezählt wurden {actual}")
    ok(f"README-Badge und Testdateien stimmen überein ({actual})")


# ═══════════════════════════════════════════════════════════════════════════
# 3. i18n: Vollständigkeit und keine Karteileichen
#    NEU-11 / 1.7: Der Paritätstest in Dart prüft EN gegen DE. Was er nicht
#    sehen kann: ob ein im Code benutzter Schlüssel überhaupt existiert
#    (dann steht in der App der Bug-Marker) und ob Schlüssel verwaisen.
# ═══════════════════════════════════════════════════════════════════════════
def check_i18n() -> None:
    section("i18n")
    table = set(re.findall(r"^\s*'([a-z0-9_]+)':\s*\{AppLocale",
                           read("lib/i18n/app_strings.dart"), re.M))
    if not table:
        return fail("i18n", "keine Schlüssel in app_strings.dart gefunden")

    used: set[str] = set()
    for f in dart_files("lib"):
        with open(f, encoding="utf-8") as fh:
            src = fh.read()
        used |= set(re.findall(r"\bt\('([a-z0-9_]+)'\)", src))
        used |= set(re.findall(r"(?:noteKey|titleKey|messageKey):\s*'([a-z0-9_]+)'", src))

    missing = sorted(used - table)
    if missing:
        fail("i18n", f"im Code benutzt, aber nicht definiert: {missing}")
    else:
        ok(f"alle {len(used)} benutzten Schlüssel sind definiert")

    # Karteileichen nur als Warnung: ein Schlüssel kann legitim für einen
    # noch nicht verdrahteten Screen vorbereitet sein.
    referenced_anywhere: set[str] = set()
    for f in dart_files("lib", "test"):
        with open(f, encoding="utf-8") as fh:
            referenced_anywhere |= set(re.findall(r"'([a-z0-9_]+)'", fh.read()))
    orphans = sorted(table - referenced_anywhere)
    if orphans:
        warn("i18n", f"{len(orphans)} Schlüssel nirgends referenziert: {orphans[:8]}")
    else:
        ok(f"keine verwaisten Schlüssel ({len(table)} insgesamt)")


# ═══════════════════════════════════════════════════════════════════════════
# 4. Service-Worker-Platzhalter und die sed-Muster der Workflows
#    4.1 / N-2 / R-1: sw.js wurde in dieser Codebasis mehrfach umgebaut. Die
#    beiden Platzhalter sind die Nahtstelle zur CI — passt das sed-Muster
#    nicht mehr, bricht der Job (gut) oder, ohne Verifikation, liefert er
#    still einen Worker ohne Cache-Invalidierung aus (schlecht).
# ═══════════════════════════════════════════════════════════════════════════
def check_sw_placeholders() -> None:
    section("Service Worker ↔ CI")
    sw = read("web/sw.js")
    placeholders = {
        "BUILD_ID": "const BUILD_ID = 'DEV';",
        "BUILD_ASSETS": "const BUILD_ASSETS = [];",
    }
    for name, literal in placeholders.items():
        if literal not in sw:
            fail("SW-Platzhalter", f"{literal!r} steht nicht mehr in web/sw.js")
        else:
            ok(f"{name}-Platzhalter vorhanden")

    workflows = sorted(glob.glob(os.path.join(ROOT, ".github/workflows/*.yml")))
    if not workflows:
        return warn("SW ↔ CI", ".github/ fehlt im Paket - Workflows nicht prüfbar")

    for wf in workflows:
        with open(wf, encoding="utf-8") as fh:
            content = fh.read()
        if "Stamp service worker" not in content:
            continue
        name = os.path.basename(wf)
        if "const BUILD_ID = 'DEV';" not in content:
            fail("SW ↔ CI", f"{name}: sed-Muster für BUILD_ID passt nicht mehr zu sw.js")
        elif "const BUILD_ASSETS = \\[\\];" not in content and \
             "const BUILD_ASSETS = [];" not in content:
            fail("SW ↔ CI", f"{name}: Muster für BUILD_ASSETS passt nicht mehr zu sw.js")
        else:
            ok(f"{name}: beide Muster passen zu web/sw.js")


# ═══════════════════════════════════════════════════════════════════════════
# 5. JavaScript-Syntax von sw.js
#    Ein Syntaxfehler hier fällt sonst erst im Browser auf - und der
#    Service Worker ist genau die Komponente, die offline alles trägt.
# ═══════════════════════════════════════════════════════════════════════════
def check_sw_syntax() -> None:
    section("sw.js Syntax")
    try:
        r = subprocess.run(["node", "--check", os.path.join(ROOT, "web/sw.js")],
                           capture_output=True, text=True)
    except FileNotFoundError:
        return warn("sw.js Syntax", "node nicht installiert - Prüfung übersprungen")
    if r.returncode != 0:
        fail("sw.js Syntax", r.stderr.strip().splitlines()[0] if r.stderr else "node --check fehlgeschlagen")
    else:
        ok("node --check bestanden")


# ═══════════════════════════════════════════════════════════════════════════
# 6. Gesamtbericht deckt alle Rechen-Tabs ab
#    B-1: Die Kandidatenliste war eine handgepflegte Kopie der Tabreihenfolge.
#    Der Dart-Test prüft Anzahl und Reihenfolge; hier prüfen wir zusätzlich,
#    dass jeder Screen mit PDF-Sektionen auch tatsächlich eingebunden ist -
#    das kann der Dart-Test nicht sehen.
# ═══════════════════════════════════════════════════════════════════════════
def check_combined_report() -> None:
    section("Gesamtbericht")
    builders = set()
    for f in dart_files("lib/screens"):
        with open(f, encoding="utf-8") as fh:
            builders |= set(re.findall(r"List<PdfSection>\s+(build\w+PdfSections)", fh.read()))
    main = read("lib/main.dart")
    used = set(re.findall(r"(build\w+PdfSections)\(", main))
    forgotten = sorted(builders - used)
    if forgotten:
        fail("Gesamtbericht",
             f"Screens mit PDF-Sektionen, die im Gesamtbericht fehlen: {forgotten}")
    else:
        ok(f"alle {len(builders)} PDF-Bauer sind im Gesamtbericht eingebunden")


# ═══════════════════════════════════════════════════════════════════════════
# 7. Vorbelegte Werte dürfen nicht ungefiltert ins PDF
#    C-1: Ein Wert aus einer Einstellung ist IMMER gesetzt. Ungefiltert in
#    eine PDF-Zeile geschrieben, macht er den Tab für den "nur gefüllte
#    Tabs"-Filter dauerhaft nicht-leer - der Tab liegt dann jedem Bericht bei.
# ═══════════════════════════════════════════════════════════════════════════
def check_defaults_not_in_pdf() -> None:
    section("Vorbelegungen im PDF")
    suspicious = []
    for f in dart_files("lib/screens"):
        with open(f, encoding="utf-8") as fh:
            src = fh.read()
        if "PdfSection" not in src:
            continue
        # Namen lokaler Variablen, die aus einer Einstellung stammen
        setting_vars = set(re.findall(r"final\s+(\w+)\s*=\s*\w*Settings\.instance\.\w+", src))
        if not setting_vars:
            continue
        for m in re.finditer(r"PdfRow\.numeric\((?:[^()]|\((?:[^()]|\([^()]*\))*\))*?value:\s*([^,\n]+)", src):
            val = m.group(1).strip()
            if val not in setting_vars:
                continue
            # Dokumentierte Ausnahme: eine Zeile darf einen Einstellungswert
            # tragen, wenn sie ohnehin nur bei vorhandener Eingabe entsteht -
            # etwa innerhalb eines `if (delNido) ...[`. Der Checker kann das
            # nicht zuverlaessig parsen, deshalb wird die Ausnahme am Ort (in den
            # acht Zeilen davor) begruendet statt die Pruefung aufzuweichen.
            preceding = src[:m.start()].splitlines()[-8:]
            if any("verify:ok" in line for line in preceding):
                continue
            line_no = src[:m.start()].count("\n") + 1
            suspicious.append(
                f"{os.path.basename(f)}:{line_no}: value: {val} (aus einer Einstellung, ungefiltert)")
    if suspicious:
        for s in suspicious:
            fail("Vorbelegung im PDF",
                 s + "\n        → resultIf(...) verwenden, oder die Zeile mit"
                     "\n          `// verify:ok <Begruendung>` als bewusste Ausnahme markieren")
    else:
        ok("keine Einstellungswerte ungefiltert in PDF-Zeilen")


# ═══════════════════════════════════════════════════════════════════════════
# 8. Listener werden wieder abgemeldet
#    Jedes addListener in einer State-Klasse braucht ein removeListener in
#    dispose(), sonst hält der Singleton den zerstörten State am Leben.
# ═══════════════════════════════════════════════════════════════════════════
def check_listeners() -> None:
    section("Listener")
    problems = []
    for f in dart_files("lib"):
        with open(f, encoding="utf-8") as fh:
            src = fh.read()
        add = len(re.findall(r"\.addListener\(", src))
        rem = len(re.findall(r"\.removeListener\(", src))
        if add != rem:
            problems.append(f"{os.path.relpath(f, ROOT)}: {add}x addListener, {rem}x removeListener")
    if problems:
        for p in problems:
            fail("Listener", p)
    else:
        ok("addListener und removeListener sind in jeder Datei paarig")


# ═══════════════════════════════════════════════════════════════════════════
# 9. Keine dynamischen Casts, kein print()
#    D-1: `as List<List<String>>` auf einer Map<String, dynamic> fällt erst
#    zur Laufzeit auf. print() statt debugPrint landet im Release-Log.
# ═══════════════════════════════════════════════════════════════════════════
def check_code_hygiene() -> None:
    section("Hygiene")
    casts, prints = [], []
    for f in dart_files("lib"):
        with open(f, encoding="utf-8") as fh:
            for n, line in enumerate(fh, 1):
                code = line.split("//")[0]
                if re.search(r"\bas\s+(List|Map|String|int|double|bool)\b", code):
                    casts.append(f"{os.path.relpath(f, ROOT)}:{n}")
                if re.search(r"(?<![\w.])print\(", code):
                    prints.append(f"{os.path.relpath(f, ROOT)}:{n}")
    if casts:
        warn("Hygiene", f"Casts auf Basistypen: {casts}")
    else:
        ok("keine Casts auf Basistypen in lib/")
    if prints:
        fail("Hygiene", f"print() statt debugPrint(): {prints}")
    else:
        ok("kein nacktes print() in lib/")


# ═══════════════════════════════════════════════════════════════════════════
# 10. Datenschutzerklärung: beide Fassungen im Gleichstand
#     Block A: privacy_policy.md und web/privacy.html müssen zusammen
#     geändert werden. Geprüft wird das Datum und die Abschnittszahl.
# ═══════════════════════════════════════════════════════════════════════════
def check_privacy_pair() -> None:
    section("Datenschutzerklärung")
    md = read("privacy_policy.md")
    html = read("web/privacy.html")
    d_md = re.search(r"Stand / Last updated:\*\*\s*([0-9.]+)", md)
    d_html = re.search(r"Stand:\s*([0-9.]+)", html)
    if not d_md or not d_html:
        return warn("Datenschutz", "Datum in einer der beiden Fassungen nicht gefunden")
    if d_md.group(1) != d_html.group(1):
        fail("Datenschutz",
             f"privacy_policy.md ({d_md.group(1)}) und web/privacy.html "
             f"({d_html.group(1)}) tragen verschiedene Stände")
    else:
        ok(f"beide Fassungen tragen denselben Stand ({d_md.group(1)})")

    n_md = len(re.findall(r"^## \d+\.", md, re.M)) // 2   # DE + EN
    n_html = len(re.findall(r"<h2>\d+\.", html)) // 2
    if n_md != n_html:
        fail("Datenschutz", f"{n_md} Abschnitte in der Markdown-Fassung, {n_html} in der HTML-Fassung")
    else:
        ok(f"beide Fassungen haben {n_md} Abschnitte je Sprache")


# ═══════════════════════════════════════════════════════════════════════════
# 11. Standalone-HTML-Seiten tragen eine CSP
#     K-3: Sie liegen im harten Precache und werden offline auf
#     Klinikgeräten ausgeliefert.
# ═══════════════════════════════════════════════════════════════════════════
def check_html_csp() -> None:
    section("CSP")
    missing = []
    for f in sorted(glob.glob(os.path.join(ROOT, "web/*.html"))):
        with open(f, encoding="utf-8") as fh:
            if "Content-Security-Policy" not in fh.read():
                missing.append(os.path.basename(f))
    if missing:
        fail("CSP", f"HTML-Seiten ohne Content-Security-Policy: {missing}")
    else:
        ok("alle Seiten in web/ tragen eine CSP")


# ═══════════════════════════════════════════════════════════════════════════
# 12. Unreferenzierte Dateien in web/
#     Alles in web/ wandert in den Build und seit v0.4.6 in den HARTEN
#     Precache - jeder Besucher lädt es bei jedem Deploy neu. Eine Datei,
#     die niemand anfordert, ist damit nicht nur totes Gewicht, sondern
#     Gewicht mit Wiederholung.
# ═══════════════════════════════════════════════════════════════════════════
def check_unreferenced_web_files() -> None:
    section("Dateien in web/")
    web = os.path.join(ROOT, "web")
    if not os.path.isdir(web):
        return warn("web/", "Verzeichnis nicht gefunden")

    # Immer benötigt, auch ohne Referenz im Quelltext.
    always = {"index.html", "manifest.json", "sw.js", "CNAME", "favicon.ico"}

    # Suchraum: alles, was einen Dateinamen nennen könnte.
    haystack = ""
    for pattern in ("web/*.html", "web/*.js", "web/*.json", "lib/**/*.dart",
                    ".github/workflows/*.yml"):
        for f in glob.glob(os.path.join(ROOT, pattern), recursive=True):
            with open(f, encoding="utf-8", errors="replace") as fh:
                haystack += fh.read()

    orphans = []
    for f in sorted(glob.glob(os.path.join(web, "*"))):
        if os.path.isdir(f):
            continue                      # assets/ und icons/ erzeugt Flutter
        name = os.path.basename(f)
        if name in always:
            continue
        # Query-Strings (?v=9) abstreifen, indem nur der Name gesucht wird.
        if name not in haystack:
            kb = os.path.getsize(f) / 1024
            orphans.append(f"{name} ({kb:.0f} KB)")

    if orphans:
        warn("web/", "von nirgends referenziert, landen aber im Precache: "
                     + ", ".join(orphans))
    else:
        ok("jede Datei in web/ wird auch referenziert")


# ═══════════════════════════════════════════════════════════════════════════
# 13. Workflows: YAML gültig, Shell-Blöcke syntaktisch korrekt
# ═══════════════════════════════════════════════════════════════════════════
def check_workflows() -> None:
    section("Workflows")
    files = sorted(glob.glob(os.path.join(ROOT, ".github/workflows/*.yml")))
    if not files:
        return warn("Workflows", ".github/ fehlt im Paket")
    try:
        import yaml  # noqa
    except ImportError:
        return warn("Workflows", "PyYAML nicht installiert - Prüfung übersprungen")
    import yaml
    for wf in files:
        name = os.path.basename(wf)
        try:
            doc = yaml.safe_load(open(wf, encoding="utf-8"))
        except Exception as e:
            fail("Workflows", f"{name}: ungültiges YAML - {e}")
            continue
        bad = []
        for job in (doc.get("jobs") or {}).values():
            for step in job.get("steps", []):
                if "run" in step:
                    r = subprocess.run(["bash", "-n"], input=step["run"],
                                       text=True, capture_output=True)
                    if r.returncode != 0:
                        bad.append(step.get("name", "?"))
        if bad:
            fail("Workflows", f"{name}: Shell-Syntaxfehler in {bad}")
        else:
            ok(f"{name}: YAML gültig, alle run-Blöcke syntaktisch korrekt")


def main() -> int:
    print(f"\n{DIM}PerfusionCalc — Konsistenzprüfung{OFF}")
    print(f"{DIM}Repository: {ROOT}{OFF}")
    for check in (check_version, check_test_count, check_i18n,
                  check_sw_placeholders, check_sw_syntax, check_combined_report,
                  check_defaults_not_in_pdf, check_listeners, check_code_hygiene,
                  check_privacy_pair, check_html_csp,
                  check_unreferenced_web_files, check_workflows):
        try:
            check()
        except Exception as e:  # eine kaputte Prüfung darf den Lauf nicht abbrechen
            fail(check.__name__, f"Prüfung selbst fehlgeschlagen: {e}")

    print()
    if failures:
        print(f"{RED}{len(failures)} Fehler{OFF}"
              + (f", {len(warnings)} Warnungen" if warnings else ""))
        return 1
    print(f"{GREEN}Alle Prüfungen bestanden{OFF}"
          + (f", {len(warnings)} Warnungen" if warnings else ""))
    return 0


if __name__ == "__main__":
    sys.exit(main())
