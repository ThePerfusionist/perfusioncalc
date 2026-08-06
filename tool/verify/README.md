# Verification tooling

What lives here checks the things `flutter analyze` and `flutter test` cannot
see — and the things that have already gone wrong in this codebase.

## Full run (Windows)

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tool\verify\verify-all.ps1
```

Runs `flutter pub get`, `flutter analyze`, `flutter test`, the consistency
check and the offline server's traversal test, in that order. Options:
`-SkipTests`, `-SkipServe`.

**Python on Windows:** the script tries `py -3`, `python3` and `python` and
probes each candidate with an actual program run. `Get-Command` alone is not
enough — Windows places app execution aliases for `python.exe` and
`python3.exe` under `%LOCALAPPDATA%\Microsoft\WindowsApps`, which often sit
*before* a real installation in PATH and merely open the Microsoft Store when
invoked (exit 9009). If that happens to you: *Settings → Apps → Advanced app
settings → App execution aliases* → turn off `python.exe` and `python3.exe`.
Or simply use `py -3`; the launcher is not shadowed by the aliases.

## The individual tools

### `tool/verify/consistency_check.py`

Cross-language guarantees — Dart against YAML, Dart against JavaScript, code
against documentation. Fifteen checks, each standing for a defect documented
in `PROJECT_STATE.md` § 7:

| Check | Defect it prevents |
|---|---|
| version identical in three places | a divergence otherwise surfaces only in the PDF footer |
| test badge = actual count | a number in the docs that does not grow with the code |
| i18n complete, no orphans | a key used in code but missing shows the bug marker in the app |
| SW placeholders ↔ workflow `sed` patterns | if the coupling breaks, the cache never expires |
| `node --check web/sw.js` | a syntax error in the component that carries offline use |
| every PDF builder in the combined report | a tab silently missing from the delivered report |
| no default written unfiltered into the PDF | the tab is attached to every report |
| `addListener` ↔ `removeListener` | the singleton keeps destroyed states alive |
| no base-type casts, no `print()` | runtime error instead of compile error |
| both privacy policy versions in step | they have to be changed together |
| CSP on every `web/*.html` | pages in the hard precache without protection |
| every dependency in the Data safety SDK table | a new package makes the Play declaration "no data collected" quietly false |
| `pubspec.lock` satisfies the constraints | CI would otherwise build against different versions than the development machine (a missing file is only a warning, with a pointer to `flutter pub get`) |
| workflows: YAML + shell syntax | a broken `run` block otherwise surfaces only in CI |

**Documented exceptions:** a finding can be marked as deliberate with
`// verify:ok <reason>` within the preceding eight lines. The check stays
strict, the exception sits at the site and is justified — rather than
weakening the rule.

Runs without Node and without PyYAML too, skipping the affected checks with a
warning.

### `tool/verify/coverage_report.py`

```bash
flutter test --coverage
python3 tool/verify/coverage_report.py            # untested files first
python3 tool/verify/coverage_report.py --min 60   # exit 1 below the threshold
python3 tool/verify/coverage_report.py --all      # include screens/ and widgets/
```

Hides `lib/screens/`, `lib/widgets/` and `lib/theme/` by default — those can
only sensibly be covered with widget tests. What remains is the part that
calculates, and a gap there is a finding.

Background: until v0.4.11 `CardioplegiaSettings` was the only one of the three
persisted settings without tests. That was found by chance while reading, not
systematically — a gap you cannot see is a gap you do not close.

### `tool/offline/test-serve.ps1`

Starts `serve.ps1` in a sandbox and fires seventeen requests at it: allowed
paths, nine traversal variants, two raw TCP requests bypassing client-side
normalisation, two cases for missing files.

**The criterion is content, not the status code.** The first version expected
403 for every traversal and reported three failures that were none:
`Invoke-WebRequest` normalises `..` in a URL *before* the request reaches the
server. `/../secret.txt` becomes `/secret.txt`, and the server correctly
answers 404 — it never saw a traversal.

That is precisely why the percent-encoded variants are the interesting ones:
`%2e%2e%2f` survives any normalisation and is only resolved inside the server
by `UnescapeDataString`, where `Get-SafePath` takes effect.

What is checked, therefore: the contents of the file outside the root folder
must never appear in a response. 403 (refused) and 404 (arrived normalised)
are both fine; 200 with the marker in the body is the finding. The traversal's
target file is created **on purpose** — otherwise a 404 would look like a
passing test even though the server would happily have handed the file out.

Replaces the manual counter-check that used to sit as a comment in the header
of `serve.ps1`.

## In CI

`.github/workflows/checks.yml` runs on every push and pull request to `main`:
`flutter analyze`, `flutter test`, then the consistency check. Deliberately
separate from `deploy.yml` so the checks also run on branches and in forks
without touching the delivery path.

The traversal test does **not** run there — it needs Windows. It belongs
before every bundle release, locally.

## What these tools cannot do

- **Clinical correctness.** Whether a formula is right is decided by the
  primary literature. The unit tests guard the implementation against
  published reference values, not the choice of formula.
- **Rendering and usability.** Whether a card is readable, whether a
  notification fires, whether the screen reader announces the banner — that
  needs a device.
- **The Windows distribution in the field.** Whether `caddy.exe` starts on a
  hospital PC or is blocked by policy only shows there.
