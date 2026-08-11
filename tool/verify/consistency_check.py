#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
PerfusionCalc — repository consistency check
============================================

Checks the guarantees that `flutter analyze` and `flutter test` CANNOT cover,
because they hold across file and language boundaries: Dart against YAML,
Dart against JavaScript, code against documentation.

Every check here stands for a defect that has actually occurred in this
codebase. The references point to PROJECT_STATE.md § 7.

Usage:
    python3 tool/verify/consistency_check.py
    python3 tool/verify/consistency_check.py --quiet     # failures only

Exits 0 when everything passes, otherwise 1.
"""

import glob
import hashlib
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
    print(f"  {RED}FAIL{OFF}  {check}")
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
#    A divergence would otherwise surface only in the delivered PDF, which
#    writes kAppVersion into its footer.
# ═══════════════════════════════════════════════════════════════════════════
def check_version() -> None:
    section("Version")
    pub = re.search(r"^version:\s*([0-9.]+)\+([0-9]+)\s*$", read("pubspec.yaml"), re.M)
    if not pub:
        return fail("Version", "keine 'version:'-Zeile in pubspec.yaml gefunden")
    ver, build = pub.group(1), pub.group(2)

    app = re.search(r"const kAppVersion = '([^']+)'", read("lib/main.dart"))
    if not app:
        return fail("Version", "kAppVersion not found in lib/main.dart")
    if app.group(1) != ver:
        return fail("Version", f"pubspec {ver} != kAppVersion {app.group(1)}")

    badge = re.search(r"badge/version-([0-9.]+)-orange", read("README.md"))
    if not badge:
        return fail("Version", "version badge not found in README.md")
    if badge.group(1) != ver:
        return fail("Version", f"pubspec {ver} != README-Badge {badge.group(1)}")

    ok(f"pubspec, kAppVersion and README badge agree ({ver}+{build})")


# ═══════════════════════════════════════════════════════════════════════════
# 2. The test badge in the README matches the actual count
#    K-2: a number in the documentation that does not grow with the code is
#    the same case as a comment carrying an outdated assumption.
# ═══════════════════════════════════════════════════════════════════════════
def check_test_count() -> None:
    section("Test count")
    actual = 0
    for f in dart_files("test"):
        with open(f, encoding="utf-8") as fh:
            actual += len(re.findall(r"^\s*test\(", fh.read(), re.M))
    badge = re.search(r"badge/tests-(\d+)%20passing", read("README.md"))
    if not badge:
        return fail("Test count", "test badge not found in README.md")
    if int(badge.group(1)) != actual:
        return fail("Test count",
                    f"README says {badge.group(1)}, counted {actual}")
    ok(f"README badge and test files agree ({actual})")


# ═══════════════════════════════════════════════════════════════════════════
# 3. i18n: completeness and no orphans
#    NEU-11 / 1.7: the Dart parity test checks EN against DE. What it cannot
#    see: whether a key used in the code exists at all (the app then shows
#    the bug marker) and whether keys have become orphaned.
# ═══════════════════════════════════════════════════════════════════════════
def check_i18n() -> None:
    section("i18n")
    table = set(re.findall(r"^\s*'([a-z0-9_]+)':\s*\{AppLocale",
                           read("lib/i18n/app_strings.dart"), re.M))
    if not table:
        return fail("i18n", "no keys found in app_strings.dart")

    used: set[str] = set()
    for f in dart_files("lib"):
        with open(f, encoding="utf-8") as fh:
            src = fh.read()
        used |= set(re.findall(r"\bt\('([a-z0-9_]+)'\)", src))
        used |= set(re.findall(r"(?:noteKey|titleKey|messageKey):\s*'([a-z0-9_]+)'", src))

    missing = sorted(used - table)
    if missing:
        fail("i18n", f"used in code but not defined: {missing}")
    else:
        ok(f"all {len(used)} keys in use are defined")

    # Orphans are only a warning: a key may legitimately be prepared for a
    # screen that is not wired up yet.
    referenced_anywhere: set[str] = set()
    for f in dart_files("lib", "test"):
        with open(f, encoding="utf-8") as fh:
            referenced_anywhere |= set(re.findall(r"'([a-z0-9_]+)'", fh.read()))
    orphans = sorted(table - referenced_anywhere)
    if orphans:
        warn("i18n", f"{len(orphans)} keys referenced nowhere: {orphans[:8]}")
    else:
        ok(f"no orphaned keys ({len(table)} in total)")


# ═══════════════════════════════════════════════════════════════════════════
# 4. Service worker placeholders and the sed patterns of the workflows
#    4.1 / N-2 / R-1: sw.js has been reworked repeatedly. The two
#    placeholders are the seam to CI — if the sed pattern no longer matches,
#    the job fails (good) or, without verification, silently ships a worker
#    without cache invalidation (bad).
# ═══════════════════════════════════════════════════════════════════════════
def check_sw_placeholders() -> None:
    section("Service worker ↔ CI")
    sw = read("web/sw.js")
    placeholders = {
        "BUILD_ID": "const BUILD_ID = 'DEV';",
        "BUILD_ASSETS": "const BUILD_ASSETS = [];",
    }
    for name, literal in placeholders.items():
        if literal not in sw:
            fail("SW placeholder", f"{literal!r} is no longer in web/sw.js")
        else:
            ok(f"{name} placeholder present")

    workflows = sorted(glob.glob(os.path.join(ROOT, ".github/workflows/*.yml")))
    if not workflows:
        return warn("SW ↔ CI", ".github/ missing from the package - workflows not checkable")

    for wf in workflows:
        with open(wf, encoding="utf-8") as fh:
            content = fh.read()
        if "Stamp service worker" not in content:
            continue
        name = os.path.basename(wf)
        if "const BUILD_ID = 'DEV';" not in content:
            fail("SW ↔ CI", f"{name}: sed pattern for BUILD_ID no longer matches sw.js")
        elif "const BUILD_ASSETS = \\[\\];" not in content and \
             "const BUILD_ASSETS = [];" not in content:
            fail("SW ↔ CI", f"{name}: pattern for BUILD_ASSETS no longer matches sw.js")
        else:
            ok(f"{name}: both patterns match web/sw.js")


# ═══════════════════════════════════════════════════════════════════════════
# 5. JavaScript syntax of sw.js
#    A syntax error here would otherwise surface only in the browser — and
#    the service worker is exactly the component that carries offline use.
# ═══════════════════════════════════════════════════════════════════════════
def check_sw_syntax() -> None:
    section("sw.js syntax")
    try:
        r = subprocess.run(["node", "--check", os.path.join(ROOT, "web/sw.js")],
                           capture_output=True, text=True)
    except FileNotFoundError:
        return warn("sw.js syntax", "node not installed - check skipped")
    if r.returncode != 0:
        fail("sw.js syntax", r.stderr.strip().splitlines()[0] if r.stderr else "node --check failed")
    else:
        ok("node --check passed")


# ═══════════════════════════════════════════════════════════════════════════
# 6. The combined report covers every calculating tab
#    B-1: the candidate list was a hand-maintained copy of the tab order. The
#    Dart test checks count and order; here we additionally check that every
#    screen with PDF sections is actually wired in — which the Dart test
#    cannot see.
# ═══════════════════════════════════════════════════════════════════════════
def check_combined_report() -> None:
    section("Combined report")
    builders = set()
    for f in dart_files("lib/screens"):
        with open(f, encoding="utf-8") as fh:
            builders |= set(re.findall(r"List<PdfSection>\s+(build\w+PdfSections)", fh.read()))
    main = read("lib/main.dart")
    used = set(re.findall(r"(build\w+PdfSections)\(", main))
    forgotten = sorted(builders - used)
    if forgotten:
        fail("Combined report",
             f"screens with PDF sections missing from the combined report: {forgotten}")
    else:
        ok(f"all {len(builders)} PDF builders are wired into the combined report")


# ═══════════════════════════════════════════════════════════════════════════
# 7. Default values must not reach the PDF unfiltered
#    C-1: a value from a setting is ALWAYS present. Written into a PDF row
#    unfiltered, it makes the tab permanently non-empty for the "only filled
#    tabs" filter — the tab is then attached to every report.
# ═══════════════════════════════════════════════════════════════════════════
def check_defaults_not_in_pdf() -> None:
    section("Defaults in the PDF")
    suspicious = []
    for f in dart_files("lib/screens"):
        with open(f, encoding="utf-8") as fh:
            src = fh.read()
        if "PdfSection" not in src:
            continue
        # Names of local variables that originate from a setting
        setting_vars = set(re.findall(r"final\s+(\w+)\s*=\s*\w*Settings\.instance\.\w+", src))
        if not setting_vars:
            continue
        for m in re.finditer(r"PdfRow\.numeric\((?:[^()]|\((?:[^()]|\([^()]*\))*\))*?value:\s*([^,\n]+)", src):
            val = m.group(1).strip()
            if val not in setting_vars:
                continue
            # Documented exception: a row may carry a setting value when it
            # only comes into existence if input is present anyway — for
            # instance inside an `if (delNido) ...[`. The checker cannot
            # parse that reliably, so the exception is justified at the site
            # (within the preceding eight lines) rather than weakening the
            # check.
            preceding = src[:m.start()].splitlines()[-8:]
            if any("verify:ok" in line for line in preceding):
                continue
            line_no = src[:m.start()].count("\n") + 1
            suspicious.append(
                f"{os.path.basename(f)}:{line_no}: value: {val} (from a setting, unfiltered)")
    if suspicious:
        for s in suspicious:
            fail("Default in the PDF",
                 s + "\n        → use resultIf(...), or mark the line with"
                     "\n          `// verify:ok <reason>` as a deliberate exception")
    else:
        ok("no setting values written unfiltered into PDF rows")


# ═══════════════════════════════════════════════════════════════════════════
# 8. Listener werden wieder abgemeldet
#    Every addListener in a State class needs a removeListener in dispose(),
#    otherwise the singleton keeps the destroyed state alive.
# ═══════════════════════════════════════════════════════════════════════════
def check_listeners() -> None:
    section("Listeners")
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
            fail("Listeners", p)
    else:
        ok("addListener and removeListener are paired in every file")


# ═══════════════════════════════════════════════════════════════════════════
# 9. No dynamic casts, no print()
#    D-1: `as List<List<String>>` on a Map<String, dynamic> only surfaces at
#    runtime. print() instead of debugPrint ends up in the release log.
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
        warn("Hygiene", f"casts to base types: {casts}")
    else:
        ok("no casts to base types in lib/")
    if prints:
        fail("Hygiene", f"print() instead of debugPrint(): {prints}")
    else:
        ok("no bare print() in lib/")


# ═══════════════════════════════════════════════════════════════════════════
# 10. Privacy policy: both versions in step
#     Block A: privacy_policy.md and web/privacy.html have to be changed
#     together. The date and the section count are checked.
# ═══════════════════════════════════════════════════════════════════════════
def check_privacy_pair() -> None:
    section("Privacy policy")
    md = read("privacy_policy.md")
    html = read("web/privacy.html")
    d_md = re.search(r"Stand / Last updated:\*\*\s*([0-9.]+)", md)
    d_html = re.search(r"Stand:\s*([0-9.]+)", html)
    if not d_md or not d_html:
        return warn("Privacy policy", "date not found in one of the two versions")
    if d_md.group(1) != d_html.group(1):
        fail("Privacy policy",
             f"privacy_policy.md ({d_md.group(1)}) and web/privacy.html "
             f"({d_html.group(1)}) carry different dates")
    else:
        ok(f"both versions carry the same date ({d_md.group(1)})")

    n_md = len(re.findall(r"^## \d+\.", md, re.M)) // 2   # DE + EN
    n_html = len(re.findall(r"<h2>\d+\.", html)) // 2
    if n_md != n_html:
        fail("Privacy policy",
             f"{n_md} sections in the Markdown version, {n_html} in the HTML version")
    else:
        ok(f"both versions have {n_md} sections per language")


# ═══════════════════════════════════════════════════════════════════════════
# 11. Standalone HTML pages carry a CSP
#     K-3: they sit in the hard precache and are served offline on clinical
#     devices.
# ═══════════════════════════════════════════════════════════════════════════
def check_html_csp() -> None:
    section("CSP")
    missing = []
    for f in sorted(glob.glob(os.path.join(ROOT, "web/*.html"))):
        with open(f, encoding="utf-8") as fh:
            if "Content-Security-Policy" not in fh.read():
                missing.append(os.path.basename(f))
    if missing:
        fail("CSP", f"HTML pages without a Content-Security-Policy: {missing}")
    else:
        ok("every page in web/ carries a CSP")


# ═══════════════════════════════════════════════════════════════════════════
# 12. Unreferenzierte Dateien in web/
#     Everything in web/ goes into the build and, since v0.4.6, into the
#     HARD precache — every visitor downloads it again on every deployment.
#     A file nobody requests is therefore not just dead weight but repeated
#     dead weight.
# ═══════════════════════════════════════════════════════════════════════════
def check_unreferenced_web_files() -> None:
    section("Dateien in web/")
    web = os.path.join(ROOT, "web")
    if not os.path.isdir(web):
        return warn("web/", "directory not found")

    # Always needed, even without a reference in the source.
    always = {"index.html", "manifest.json", "sw.js", "CNAME", "favicon.ico"}

    # Search space: everything that could name a file.
    haystack = ""
    for pattern in ("web/*.html", "web/*.js", "web/*.json", "lib/**/*.dart",
                    ".github/workflows/*.yml"):
        for f in glob.glob(os.path.join(ROOT, pattern), recursive=True):
            with open(f, encoding="utf-8", errors="replace") as fh:
                haystack += fh.read()

    # Report identical files too. That was the case with the three
    # pcalc-icon-v8 files: not source images but byte-identical copies of
    # favicon.png, favicon.ico and icons/Icon-192.png — leftovers from an
    # icon regeneration. The hint "identical to X" turns a vague warning
    # into a basis for a decision: a copy can go, an original has to move.
    by_hash: dict[str, list[str]] = {}
    for f in glob.glob(os.path.join(web, "**", "*"), recursive=True):
        if os.path.isdir(f):
            continue
        try:
            with open(f, "rb") as fh:
                digest = hashlib.md5(fh.read()).hexdigest()
        except OSError:
            continue
        by_hash.setdefault(digest, []).append(os.path.relpath(f, web).replace(os.sep, "/"))

    orphans = []
    for f in sorted(glob.glob(os.path.join(web, "*"))):
        if os.path.isdir(f):
            continue                      # assets/ and icons/ come from Flutter
        name = os.path.basename(f)
        if name in always:
            continue
        # Query strings (?v=9) are stripped by searching for the name only.
        if name in haystack:
            continue
        kb = os.path.getsize(f) / 1024
        with open(os.path.join(web, name), "rb") as fh:
            digest = hashlib.md5(fh.read()).hexdigest()
        twins = [t for t in by_hash.get(digest, []) if t != name]
        note = f" — identical to {', '.join(twins)}" if twins else ""
        orphans.append(f"{name} ({kb:.0f} KB){note}")

    if orphans:
        warn("web/", "referenced nowhere, yet end up in the precache:\n        "
                     + "\n        ".join(orphans))
    else:
        ok("every file in web/ is referenced somewhere")


# ═══════════════════════════════════════════════════════════════════════════
# 13. Every runtime dependency appears in the Data safety SDK table
#     Google attributes data transmitted by an embedded SDK to the app. The
#     "no data collected" declaration in the Play form therefore only holds
#     for the current dependency list. If a package that sends something is
#     added, the declaration becomes false — without anybody having done
#     anything wrong. This check forces one deliberate line per package
#     instead of relying on memory.
# ═══════════════════════════════════════════════════════════════════════════
def check_sdk_table() -> None:
    section("Data safety SDK table")
    doc_rel = "docs/PLAY_DATA_SAFETY.md"
    doc_path = os.path.join(ROOT, doc_rel)
    if not os.path.exists(doc_path):
        return warn("SDK table", f"{doc_rel} not found")
    try:
        import yaml
    except ImportError:
        return warn("SDK table", "PyYAML not installed - check skipped")

    pub = yaml.safe_load(read("pubspec.yaml"))
    deps = [d for d in (pub.get("dependencies") or {}) if d != "flutter"]
    doc = read(doc_rel)

    missing = [d for d in deps if f"`{d}`" not in doc]
    if missing:
        fail("SDK table",
             f"not listed in {doc_rel}: {missing}\n"
             f"        → check the package documentation for whether it sends\n"
             f"          data off the device and add a row to the SDK table.\n"
             f"          If it does, the Play form has to change as well.")
    else:
        ok(f"all {len(deps)} runtime dependencies are assessed in {doc_rel}")

    # The reverse: a row for a package that has long been removed is
    # misleading, but not an error.
    listed = set(re.findall(r"^\| `([a-z0-9_]+)` \|", doc, re.M))
    stale = sorted(listed - set(deps))
    if stale:
        warn("SDK table", f"assessed in {doc_rel} but no longer in "
                          f"pubspec.yaml: {stale}")


# ═══════════════════════════════════════════════════════════════════════════
# 14. pubspec.lock satisfies the constraints in pubspec.yaml
#     When file_picker was raised to ^11.0.3 the lock file initially stayed
#     at 8.3.7 — locally that surfaces at once because `flutter pub get`
#     rewrites it, but a package or a commit can carry the old version
#     along. CI would then build against different versions than the
#     development machine, which is precisely what a lock file prevents.
# ═══════════════════════════════════════════════════════════════════════════
def _satisfies(version: str, constraint: str) -> bool | None:
    """True/False, or None when the constraint form is not evaluated."""
    def parse(v: str) -> tuple[int, ...]:
        core = v.split("+")[0].split("-")[0]
        return tuple(int(x) for x in core.split(".") if x.isdigit())

    constraint = constraint.strip()
    if constraint in ("any", ""):
        return True
    if not constraint.startswith("^"):
        return None                      # ranges etc. are not evaluated here
    try:
        low = parse(constraint[1:])
        cur = parse(version)
    except ValueError:
        return None
    if cur < low:
        return False
    # Caret: up to the next major (or minor, when the major is 0)
    if low and low[0] > 0:
        return cur[0] == low[0]
    if len(low) > 1:
        return cur[:2] == low[:2]
    return True


def check_lockfile() -> None:
    section("pubspec.lock")
    try:
        import yaml
    except ImportError:
        return warn("pubspec.lock", "PyYAML not installed - check skipped")

    # A missing lock file is not an error but a `flutter pub get` that has
    # not been run yet — for instance right after unpacking a package that
    # deliberately omits it (see PROJECT_STATE § 7.23).
    if not os.path.exists(os.path.join(ROOT, "pubspec.lock")):
        return warn("pubspec.lock",
                    "not present - run `flutter pub get`; the lock file it\n"
                    "        writes belongs in the commit.")

    pub = yaml.safe_load(read("pubspec.yaml"))
    lock = yaml.safe_load(read("pubspec.lock"))
    packages = lock.get("packages") or {}

    problems, unchecked = [], 0
    for name, constraint in (pub.get("dependencies") or {}).items():
        if name == "flutter" or not isinstance(constraint, str):
            continue
        entry = packages.get(name)
        if not entry:
            problems.append(f"{name}: in pubspec.yaml but not in pubspec.lock")
            continue
        version = str(entry.get("version", ""))
        verdict = _satisfies(version, constraint)
        if verdict is None:
            unchecked += 1
        elif not verdict:
            problems.append(f"{name}: locked at {version}, required is {constraint}")

    if problems:
        fail("pubspec.lock",
             "\n        ".join(problems)
             + "\n        → run `flutter pub get` and commit the rewritten"
               "\n          pubspec.lock.")
    else:
        note = f", {unchecked} not evaluated" if unchecked else ""
        ok(f"all locked versions satisfy their constraints{note}")


# ═══════════════════════════════════════════════════════════════════════════
# 16. SourceRef.doi holds identifiers only, never prose
#     Source 35 (Calafiore 2020) kept its German description inside the `doi`
#     field and never got a noteKey, because the conversion worked from a
#     hand-written list. Three further entries kept a German remnant, because
#     the script treated the LAST segment separated by a middle dot as the
#     description — and their descriptions contained a middle dot themselves
#     (a unit, or several equations).
#
#     Checked here rather than in a Dart test on purpose: AppSources has no
#     list of all entries, and maintaining one by hand would be the same trap
#     as the hard-wired TabController. Reading the source text catches every
#     entry, including ones added later.
# ═══════════════════════════════════════════════════════════════════════════
def check_source_refs() -> None:
    section("Source references")
    src = read("lib/widgets/common.dart")
    start = src.find("class AppSources {")
    if start < 0:
        return warn("Source refs", "AppSources not found in common.dart")
    body = src[start:]

    entries = re.findall(r"static const (\w+) = SourceRef\((.*?)\n  \);", body, re.S)
    if not entries:
        return fail("Source refs", "no SourceRef entries found")

    prose = []
    for name, entry in entries:
        m = re.search(r"doi: '((?:[^']|\\')*)'", entry)
        if not m:
            continue
        # Dart escapes the middle dot as \u00b7 in some entries, so the
        # literal escape has to be normalised before splitting — otherwise
        # those entries look like a single identifier and slip through. That
        # gap hid two further German descriptions on the first run.
        doi = m.group(1).replace("\\u00b7", "·")
        parts = [p.strip() for p in doi.split("·") if p.strip()]
        # Several identifiers separated by a middle dot are legitimate
        # (doi + PMID). Only a segment that is not an identifier is prose —
        # checking the count instead produced false positives.
        for part in parts:
            if not re.match(r"^(doi:|PMID:|PMCID:|ISBN|https?://|www\.)", part):
                prose.append(f"{name}: {part[:60]}")

    if prose:
        fail("Source refs",
             "doi field contains prose instead of identifiers:\n        "
             + "\n        ".join(prose)
             + "\n        → move it into a noteKey and add an EN/DE pair")
    else:
        ok(f"all {len(entries)} doi fields contain identifiers only")



# ═══════════════════════════════════════════════════════════════════════════
# 17. Workflows: valid YAML, syntactically correct shell blocks
# ═══════════════════════════════════════════════════════════════════════════
def check_workflows() -> None:
    section("Workflows")
    files = sorted(glob.glob(os.path.join(ROOT, ".github/workflows/*.yml")))
    if not files:
        return warn("Workflows", ".github/ missing from the package")
    try:
        import yaml  # noqa
    except ImportError:
        return warn("Workflows", "PyYAML not installed - check skipped")
    import yaml
    for wf in files:
        name = os.path.basename(wf)
        try:
            doc = yaml.safe_load(open(wf, encoding="utf-8"))
        except Exception as e:
            fail("Workflows", f"{name}: invalid YAML - {e}")
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
            fail("Workflows", f"{name}: shell syntax errors in {bad}")
        else:
            ok(f"{name}: valid YAML, all run blocks syntactically correct")


def main() -> int:
    print(f"\n{DIM}PerfusionCalc — repository consistency check{OFF}")
    print(f"{DIM}Repository: {ROOT}{OFF}")
    for check in (check_version, check_test_count, check_i18n,
                  check_sw_placeholders, check_sw_syntax, check_combined_report,
                  check_defaults_not_in_pdf, check_listeners, check_code_hygiene,
                  check_privacy_pair, check_html_csp,
                  check_unreferenced_web_files, check_sdk_table,
                  check_lockfile, check_source_refs, check_workflows):
        try:
            check()
        except Exception as e:  # a broken check must not abort the run
            fail(check.__name__, f"check itself failed: {e}")

    print()
    if failures:
        print(f"{RED}{len(failures)} failure(s){OFF}"
              + (f", {len(warnings)} warning(s)" if warnings else ""))
        return 1
    print(f"{GREEN}All checks passed{OFF}"
          + (f", {len(warnings)} warning(s)" if warnings else ""))
    return 0


if __name__ == "__main__":
    sys.exit(main())
