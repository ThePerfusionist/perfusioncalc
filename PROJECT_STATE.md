# PerfusionCalc – working context

> Compact project state, meant as working memory. **Read this first** before
> searching the tree — it saves re-deriving structure, conventions and
> decisions. Keep it up to date with every change.

**State:** v0.4.35+57 · 12 tabs · **287 tests** (13 files, incl. the first widget tests) · i18n complete
EN+DE (guarded by a parity test) · contact: perfusioncalc@unbox.at

---

## 1. Working agreement

| Rule | Reason |
|---|---|
| Always deliver a **complete cumulative ZIP** of every file ever changed | partial diffs caused `flutter analyze` errors in the past |
| **No compiler in the assistant's container** — Flutter/Dart cannot be installed (network allow-list) | substitute checks: `tool/verify/consistency_check.py` plus targeted greps |
| The maintainer runs `flutter analyze` / `flutter test` and reports back | that is the only real compile evidence |
| Verify formulas numerically **before** implementing them | clinical app — arithmetic errors are safety relevant |
| **Peer-reviewed primary sources only**, no textbooks | explicit maintainer requirement |
| A ZIP cannot delete files → list deletions explicitly in the accompanying text | packaging can only add and overwrite |
| **Never ship a generated file that cannot be correct here** (`pubspec.lock`) | see § 5, rule 15 |

### Standard verification after every change

```bash
python3 tool/verify/consistency_check.py     # 15 cross-language checks
flutter analyze && flutter test              # on the maintainer's machine
```

On Windows, one command runs everything including the offline server's
path-traversal test:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tool\verify\verify-all.ps1
```

### Traps learned the hard way

- **Never create a field just to prevent tree shaking.** A write-only field
  triggers `unused_field`. Give the object a real use instead (e.g.
  `Notification.onclick`) — that satisfies both goals.
- **CI is stricter than local analysis.** `flutter analyze --no-fatal-warnings`
  lets warnings through but exits 1 on **info** lints, and CI may run a newer
  Flutter than the local install. "No issues found" locally is not a
  guarantee.
- **Count tests across all files**, not just `patient_data_test.dart`.
- **Every scripted patch needs `assert <anchor> in s`.** A replacement
  without an assertion fails silently.
- **Never delete code by index slice.** Removing `_phaseBtn` that way also
  removed two neighbouring methods; bracket balance stayed intact and the
  error only surfaced in the maintainer's `flutter analyze`. Use targeted
  `str_replace` on the complete method body.
- **Check the ZIP contents, not the source folder:** `unzip -l <zip> | grep -i workflow`.
  Excluding `.*` once dropped `.github/` from every package unnoticed.

---

## 2. Architecture

```
lib/
  main.dart              MainScreen, kTabs, TabController, drawer,
                         theme/language switch, _exportCombinedReport()
  models/
    patient_data.dart    central case data + ALL calculation formulas (getters)
    bga_model.dart       Severinghaus temperature correction (own model)
    ranges.dart          plausibility ranges (UI warning only, never blocking)
    cardioplegia_settings.dart      persisted del Nido mixing ratio
    cardioplegia_alarm_settings.dart persisted re-dose alarm + firing schedule
    transfusion_settings.dart        persisted RBC unit haematocrit
  i18n/app_strings.dart  EN/DE maps + t() helper + LocaleNotifier
  theme/app_theme.dart   ThemeNotifier (system/light/dark) + buildAppTheme()
  widgets/common.dart    InputCard, ResultCard, SectionHeader, DataTable2,
                         PdfExportButton, SourceButton, AppSources, colour tokens
  utils/                 pdf_export, duration_format, step_clamp,
                         decimal_input_formatter, notification_service
  screens/*.dart         one screen per tab
test/                    12 files, 276 tests
tool/verify/             consistency_check.py, coverage_report.py, verify-all.ps1
tool/offline/            start.bat, serve.ps1, test-serve.ps1, LIESMICH.txt
```

### State handling

- `PatientData` and `BgaModel` live in `MainScreen` and are passed down, which
  is why `_exportCombinedReport()` can reach them directly.
- Screens call `setState` locally; the parent callback is `_noop`. A global
  rebuild was the cause of stuttering while typing.
- Timer and timestamp state belongs in `PatientData` so it survives tab
  switches.

### Critical pitfalls

- **`TabController(length:)` == `MainScreen.kTabs.length` == number of
  `TabBarView` children.** The controller now derives its length; the report
  candidate list is bound to `kTabs` by a test.
- **No `const`** on widgets that call `t()`, otherwise the language switch
  does not rebuild them.
- Colour tokens in `common.dart` are **getters** (theme dependent), not
  `const` — so `Color?` plus `?? kText` in default parameters.
- `debugPrint`, never `print` (lint `avoid_print`).

---

## 3. Tabs (order in `MainScreen.kTabs`)

1. BSA/CO/Hb/Hct · 2. O₂ delivery · 3. Hypothermia/BGA · 4. **Cardioplegia**
5. Electrolytes/buffers · 6. Ultrafiltration · 7. Resistances · 8. Pediatrics
9. Tube volume & flow · 10. Zoll/Charrière · 11. Reference pressures ·
12. Cardiac anatomy

**Combined report** (`buildCombinedReportCandidates`): the patient-related
tabs, filtered by "at least one row ≠ `—`". Tabs 11 and 12 are pure reference
material and deliberately excluded (`kNonComputingTabKeys`); a test asserts
exactly that difference.

⚠️ PDF rows must therefore **never be rendered unconditionally from
defaults** — otherwise the tab counts as filled forever. See the
`_hasCalafioreInput()` pattern and `resultIf()`.

---

## 4. Cardioplegia tab

Protocol selection via `_kVisibleProtocols`. **Visible: Calafiore,
Bretschneider, del Nido.** Buckberg is hidden; code, tests and formulas remain
so re-enabling is a one-line change.

### Calafiore (pressure controlled, warm blood cardioplegia)

Whole blood as carrier, K⁺ (+Mg²⁺) titrated continuously by syringe pump.
Because it is pressure controlled (90–100 mmHg) rather than flow controlled,
the flow varies — so the pump rate has to follow the **current** flow to keep
the concentration constant.

```
pump rate [ml/h] = (target K⁺ − serum K⁺) × flow[ml/min] × 60 / (1000 × [K⁺]syringe[mmol/ml])
```

Verified against the institutional spreadsheet (serum 5.0 → target 10,
200 ml/min, 2 mmol/ml ⇒ **30.0 ml/h**, exact).

Dose-dependent targets (intermittent, every 15–20 min):

| Dose | Target K⁺ | Mg²⁺ bolus (separately, at the end) |
|---|---|---|
| 1 | 20 mmol/l | 1 g |
| 2 | 12 | 100 mg (500 mg if needed) |
| 3 | 12 | 100 mg |
| 4–6 | 12 (alt. 10 / 8) | 500 / 100 / 100 mg |

Syringe: total KCl volume + concentration (14.9 % = 2 mmol/ml), **Mg
optional** (500 mg/ml MgSO₄·7H₂O = 20 mmol per 10 ml ≈ 2.0 mmol/ml ≈ 50 %
w/v). Institutionally 40 ml KCl + 10 ml Mg ⇒ 1.6 mmol/ml K⁺, 0.4 mmol/ml Mg²⁺.
Concentration fields have a built-in mmol/ml ⇄ % switch (molar masses KCl
74.55 / MgSO₄·7H₂O 246.47).

`calafioreDeltaK` is clamped at 0: when the serum potassium already meets the
target, the correct answer is "0 ml/h, no supplementation needed" — and that
statement now reaches the PDF as a row note, not as "—".

### Bretschneider (HTK/Custodiol)

Single dose, intracellular crystalloid. One calculation only:
`volume = flow × time`. Notes: 5–8 °C · perfusion pressure initially
100–110 mmHg, 40–50 mmHg after arrest · perfusion 6–8 min (re-perfusion
2–3 min) · organ protection up to 180 min.

### del Nido (mixture + delivery time)

Follower principle: crystalloid pump 100 %, blood pump 25 % ⇒ mechanically
4:1. `blood = crystalloid/4` · `total = crystalloid × 1.25` ·
`blood flow = flow × 0.25` · `total flow = flow × 1.25` ·
`time = crystalloid/flow`.

The **mixing ratio is a persisted institutional setting**
(`models/cardioplegia_settings.dart`), not case data. Entered as the
crystalloid share in % (50–95, default 80 = 4:1); blood share, ratio and
follower % are derived and shown read-only. The del Nido formulas in
`PatientData` are therefore **methods taking the share as a parameter**, not
getters — which keeps `PatientData` free of singleton dependencies and
testable. At 80 % the numbers match the old 4:1 values exactly (backward
compatibility covered by a test).

### Interval timer

⚠️ **Chrome for Android throws on `new Notification()`** ("Illegal
constructor") — there `ServiceWorkerRegistration.showNotification()` is
mandatory. Order: **constructor first** (desktop, free), service worker as a
fallback with a 2 s timeout, otherwise `ready` hangs forever when none is
registered.

A click on a notification raised through the service worker path is delivered
to the **worker**, not the page, so the Dart `onclick` cannot work for it. The
`notificationclick` handler in `web/sw.js` focuses or opens the window
instead — **do not remove one without the other.**

**In-app banner** (`widgets/in_app_alert.dart`, an OverlayEntry — deliberately
not a dialog, which would block the calculators) closes by tap, horizontal
swipe or the X; `dismiss()` is idempotent so the 30 s auto-hide and a parallel
user gesture cannot collide. It takes i18n **keys**, not finished strings, so
a language switch while it is up changes the whole banner. `liveRegion: true`
makes screen readers announce it, which matters because it appears without any
user action.

**Windows build:** plugins need symlink support → enable developer mode
(`start ms-settings:developers`).

### Application pressure (protocol independent, key `cardio_pressure_limits`)

Antegrade max. 70–100 mmHg, retrograde max. 50–70 mmHg. Bretschneider shows
its protocol-specific pressure instead.

---

## 5. Formulas and sources (quick reference)

| Area | Formula/value | Primary source |
|---|---|---|
| BSA | DuBois 1916 | DuBois & DuBois, Arch Intern Med 1916 |
| CI default 2.4 | – | Kunst et al., EACTS/EACTAIC/EBCP, Br J Anaesth 2025 |
| DO₂i threshold **272** ml/min/m² | warning via `ResultCard.warnBelow` | Ranucci et al., Ann Thorac Surg 2005;80:2213 |
| Blood volume | 0.041×kg+1.53 (♂) / 0.047×kg+0.86 (♀) | Silbernagl/Despopoulos (Nadler 1962 as cross-check) |
| Expected Hb/Hct after priming | X × BV / (BV + priming) | same dilution law for both |
| BGA temperature correction | PaO₂ f_T, PCO₂ 0.0185, **pH 0.0147** | Severinghaus 1958/1979; pH constant = **Rosenthal 1948** (not Bradley) |
| O₂ dissociation | S = ((PO₂³+150·PO₂)⁻¹×23400+1)⁻¹, P50 Eq.1 = 26.86 | Severinghaus, J Appl Physiol 1979 |
| Ultrafiltration | Hct₁×V₁ = Hct₂×V₂ (also with Hb) | Klineberg et al., Anesthesiology 1984;60:478 · Hensley et al., Perfusion 2024 |
| Pediatric transfusion | weight × ΔHb × 3 / Hct(RBC unit, a **fraction**) | Davies et al., Transfusion 2007;47:212 |
| Cardioplegia Buckberg | 4:1 blood:crystalloid, 15–20 min | Buckberg, J Thorac Cardiovasc Surg 1987;93:127 |
| Cardioplegia del Nido | 4:1 crystalloid:blood, max. 1000 ml | Matte & del Nido, J Extra Corpor Technol 2012;44:98 |
| Cardioplegia Calafiore | see above | Calafiore et al., Ann Thorac Surg 1995;59:398 · Thorac Cardiovasc Surg 2020;68:232 |
| Bretschneider | see above | Bretschneider, Thorac Cardiovasc Surg 1980;28:295 · J Cardiovasc Surg 1975;16:241 · Gebhard et al. 1984;32:271 |

---

## 6. Open points

| Item | Status |
|---|---|
| **Nadler instead of the weight-only blood volume approximation** | open — a clinical product decision. It would move every displayed blood volume *and* both expected values, and make height a mandatory input. The formula is written out in the comment on `bloodVolumeMale`; until then the two cards are labelled as an approximation. |
| **Play Store closed testing** (20 testers / 14 days) | open. Package `com.perfusioncalc`, `versionCode` must increase strictly. |
| **Play Data safety form** | fill in using `docs/PLAY_DATA_SAFETY.md`. Category **Education**, not Medical. |
| **RBC unit haematocrit 0.55** | deliberately left as is. Configurable in the pediatric tab since v0.4.4 and printed in the PDF. |
| **Postal address in the privacy policy** | deliberately omitted by the controller. Art. 13(1)(a) GDPR formally requires it. |
| **ProGuard `-keep` rules** | deliberately kept. Cost: a few hundred KB of APK size. Removing them only shows its effect in a release build and the failure mode is a crash when a scheduled reminder fires. Test recipe in `proguard-rules.pro`. |
| Safari PDF export | the only fix from block E without confirmation — needs a Mac or iPhone. |
| St. Thomas' and Eppendorf protocols · perfusion log with timestamps · heparin/protamine + ACT calculator · native share sheet | ideas |

**Version numbers** are raised on request in three places: `pubspec.yaml`,
`kAppVersion` in `main.dart`, README badge. Everything else derives: Android
via `flutter.versionName/versionCode`, iOS/macOS via `$(FLUTTER_BUILD_NAME)`,
Windows/Linux via CMake, the PDF footer via `kAppVersion`, the bundle file
name via `grep '^version:' pubspec.yaml`. `sw.js` deliberately carries the
commit SHA instead of the app version.

---

## 7. Audit history — decisions and lessons

Two audits (v0.3.3, v0.4.0) produced 47 deduplicated findings, worked through
in five blocks between v0.4.1 and v0.4.2. Twelve further review rounds
followed, up to v0.4.29. This section is written as a **starting point for the
next audit**: what was changed, why it was decided that way, what deliberately
stayed open, and which mistakes the remediation itself produced.

### 7.1 How the work was cut up

The blocks followed **verifiability**, not the severity of the findings:
blocks A–C touch no file that gets compiled (YAML, manifest, Gradle, `sw.js`,
HTML, Markdown), D and E are almost entirely Dart. That mattered because the
work happened without a Dart toolchain.

| Block | Content |
|---|---|
| **A** | release blockers: `USE_EXACT_ALARM`, privacy policy, `allowBackup`, `minSdk` |
| **B** | supply chain / CI: action SHA pins, Flutter pin, Gradle SHA, Caddy pin, expression injection, `flutter test \|\| echo` |
| **C** | web / service worker: `notificationclick`, cache tied to build SHA, CSP |
| **D** | clinical calculation paths |
| **E** | Dart defects, dead code, hygiene, tests |

### 7.2 Verification protocol

| Stage | Result |
|---|---|
| 1 `pub get`, `analyze`, `test` | green |
| 2 tightened analyzer | `No issues found!` — `strict-casts` and `use_build_context_synchronously` produced no hits |
| 3 clinical calculation paths on the device | verified |
| 4 RBC unit haematocrit | turned from a decision into a persisted input field |
| 5 notifications, Android release build | verified — a scheduled notification fires and does not crash |
| 6 web / service worker | verified: 22 requests, **0 B transferred**, 10.7 MB from the cache |
| 7 CI | verified across `checks.yml`, `deploy.yml`, `release.yml` and `offline-bundle.yml` |

Stage 5 also answered two things in passing: the ProGuard `-keep` rules still
work, and dropping `USE_EXACT_ALARM` did not break the feature —
`SCHEDULE_EXACT_ALARM` alone carries it.

### 7.3 Decisions that were not findings

Places where the obvious solution was not the one chosen. Anyone changing
them should know why.

**Android and release**
- `USE_EXACT_ALARM` removed: a Play restricted permission, granted only to
  apps whose core function is alarms, timers or calendars.
  `SCHEDULE_EXACT_ALARM` covers the same behaviour.
- `allowBackup="false"` **plus** `data_extraction_rules.xml`: device-to-device
  transfer is *not* covered by `allowBackup`.
- `minSdk = maxOf(24, flutter.minSdkVersion)` rather than a fixed 24 — stays
  correct wherever Flutter's default moves.
- No silent debug signing: if `KEYSTORE_BASE64` is missing, the release job
  aborts before building. A debug-signed APK under a release name looks
  genuine, can be sideloaded, and can never be replaced by a correctly signed
  update.

**Supply chain**
- Actions pinned to full commit SHAs, **within the existing major**. Pinning
  and a major jump do not belong in the same commit.
- `FLUTTER_VERSION` as a workflow-wide variable in all four workflows. **Must
  match `flutter --version` on the development machines.**
- Caddy pinned with **SHA-512**, because that is what the vendor publishes in
  `caddy_<version>_checksums.txt`. Version, SHA-256 and SHA-512 are documented
  in `OFFLINE_WINDOWS.md` so hospital IT can verify the shipped bundle.
- `commit_message` in the gh-pages deploy is the SHA only —
  `head_commit.message` was untrusted input in an action input.

**Clinical**
- **Finding 1.4 was not a defect.** Davies 2007 reads
  `weight × ΔHb × 3 / Hct(RBC unit)` with the haematocrit as a **fraction** in
  the denominator; the factor 3 does not already contain it. Davies' own
  worked example (20 kg × 2 g/dl × 3 / 0.6 = 200 ml = 10 ml/kg) reproduces the
  formula exactly. The audit's reasoning ("double correction") was wrong.
- `expectedHb` split into `expectedHbMale`/`expectedHbFemale` with exact
  dilution against the model's own blood volume. The old value was
  systematically +0.71 g/dl too optimistic.
- `cavDO2` guarded on both sides, so VO₂, VO₂i and O₂-ER fall back to "not
  calculated" as soon as the venous set is incomplete — **screen and PDF
  alike.** That was the path by which "O₂-ER 100 %" reached the delivered
  document.
- `PdfRow.numeric` gained `zeroIsValid` instead of dropping the zero rule
  globally: a real zero is printed only where 0 is a measurement (base excess,
  CVP, LAP). The combined report's "only filled tabs" filter keeps working.

**Code**
- `Range.note` → `Range.noteKey`, all 40 hints through i18n.
- `MainScreen.kTabs` as a record list, `@visibleForTesting`; the
  `TabController` derives its length from it. The reference pressure table
  moved to records as well — **there is no `as` cast left in `lib/`.**
- `analysis_options.yaml` tightened (`strict-casts`, `avoid_dynamic_calls`,
  `unawaited_futures`, `use_build_context_synchronously`,
  `always_declare_return_types`, `prefer_final_locals`). `strict-raw-types`
  deliberately not — it fires on third-party signatures.
- Close button only on Android: `SystemNavigator.pop()` is a no-op on web and
  a documented App Store rejection reason on iOS.

### 7.4 Defects introduced by the remediation itself

Documented in full, because together they form a pattern.

| Version | Defect | Cause |
|---|---|---|
| **v0.4.3** | web version rendered **without any text** | the CSP finding declared `gstatic.com` unused. `--no-web-resources-cdn` fetches only `canvaskit.js`/`.wasm` locally, **not the font**. Material icons stayed visible (bundled asset), which made it look like a layout problem. *Fixed twice over: the CSP allows `fonts.gstatic.com` again, and Roboto is bundled — which also fixes the offline distribution and hospital networks that block third-party hosts.* |
| **v0.4.5** | offline broken: two service workers competing for one scope | all builds ran with `--pwa-strategy offline-first`, so Flutter generated its own worker in the same scope `/` as `web/sw.js`. **A service worker is registered per scope, not per file name.** Invisible online, fatal offline. The comment in `index.html` claimed the opposite — a wrong assumption, written down, and therefore never questioned again. |
| **v0.4.6** | offline broken: incomplete precache | consequence of the SHA-tied cache name: a new cache per deployment, `activate()` deletes the old one, and runtime caching only fills a fresh cache with what is requested *after* the takeover. `main.dart.js` was lost. *Fixed by generating the precache list in CI from the actual `build/web`.* |
| **v0.4.7** | precache too large (45.5 MB) | the generator excluded `.map` but not `.symbols`, nor the experimental renderer variant. Measured after the fix: **33.2 MB**. |
| **v0.4.8** | a mistyped character cleared the whole input field | `FilteringTextInputFormatter.allow` filters segment by segment; an anchored `^…$` regex that matches nowhere yields an empty field. *Replaced by `DecimalTextInputFormatter`, which keeps the old value.* |
| **v0.4.9** | stepper buttons clamped away the training intent | the fix for "-0.1 kg from an empty field" overrode a documented design intent: `ranges.dart` states that extreme values are allowed for training. *Now only the physically impossible is stopped.* |

### 7.5 Findings from later self-audits

- **Screen and PDF disagreed in both directions.** Finding 1.1 had the PDF
  printing a number where the screen showed "—"; A-1 was the reverse. The
  `ResultCard` follows `missingInputs`, not the value, so with complete inputs
  it shows `0.0` — for a base excess of 0, the normal finding, the correct
  answer is "0 ml NaBic, no correction needed". Resolved with
  `resultIf(requiredInputs, value)` plus `zeroIsValid`.
- **`ufFinalVolume` was wrong on screen too.** It returned 0 whenever nothing
  was removed, so the card read "no blood is left in the circuit at the end".
- **The same clamping asymmetry appeared three times.**
  `TransfusionSettings.load()` clamped from the start,
  `CardioplegiaSettings.load()` got it in v0.4.11,
  `CardioplegiaAlarmSettings.load()` in v0.4.15. The last was the quietest: a
  stored 0 makes `expectedFireCount()` return 0 permanently — the alarm shows
  as enabled and never fires.
- **Negative zero reached the display.** `(0 × 80 × 3) / −10` is −0.0 in
  IEEE-754 and Dart formats it as `"-0.0"`. `_safe()` now normalises it.
- **The pediatric tab was attached to every combined report**, because the RBC
  haematocrit from a setting was written into a PDF row unfiltered — a default
  is always present, so the "only filled tabs" filter never excluded the tab.
- **A path traversal in `serve.ps1`.** `Join-Path` does not normalise, so a
  string starting with the root path passed `StartsWith` while `ReadAllBytes`
  resolved the `..` afterwards. Aggravated by `UnescapeDataString` running
  after canonicalisation and by a prefix comparison without a separator.
  Fixed with `GetFullPath` before the comparison; covered by
  `tool/offline/test-serve.ps1` with 17 checks including raw TCP requests that
  bypass client-side normalisation.

### 7.5b The stepper buttons stopped updating the field (v0.4.34)

Reported from use: + and - changed the value — every result on the screen
followed — but the number **inside the text field** kept showing the old one.
It only caught up once the field was tapped, as if for manual entry.

`_editing` was set on the field's `onTap` and cleared only by
`onEditingComplete` or `onTapOutside`. Tapping a stepper triggers neither:
both buttons sit inside the same `InputCard`, so the tap is not "outside" the
field, and no editing was completed. `_editing` stayed true, and
`didUpdateWidget` skipped the sync it guards. That the field corrected itself
on the next tap was the same cause seen from the other side.

The guard itself was right — while typing, writing the reformatted text back
would move the cursor and swallow a partial entry such as "1." or "-". It was
simply too broad. Two changes:

- each card now owns a `FocusNode`, and the guard applies only while the
  field **actually holds focus**. That is the state in which a cursor exists
  that could be moved.
- a stepper writes the new text **immediately** instead of waiting for the
  parent rebuild. Waiting works in the common case, but only as long as every
  screen calls `setState` in its `onChanged` — an assumption this widget
  should not depend on.

All three cards with this pattern were affected: `InputCard`,
`_CIInputCard` (BSA) and `_CoCiCard` (O₂ delivery). Fixing one and leaving the
others would have been the sample-based approach rule 12 warns about.

**The first widget tests in the project (7 of them).** The defect was
invisible to a unit test: the value was always correct, only its rendering was
not. The decisive case is the reported sequence — tap into the field, then
step — plus the counter-test that typing still survives a rebuild.

**The first version of the fix was still half wrong, and the new tests said
so (v0.4.35).** Keeping `_editing` as a second signal alongside focus failed
in the opposite direction: `enterText` focuses a field WITHOUT firing
`onTap`, so the flag stayed false while the user was genuinely typing, and a
rebuild overwrote the partial entry `82.` with `82`. The same state arises
from Tab navigation on web and desktop — a real case, not a test artefact.

The flag is gone. **Focus alone decides**, and the steppers write their text
themselves, so they work whether or not the field holds focus. That is
simpler than what it replaced: three `setState` calls and a flag disappeared
from each of the three cards.

Two follow-ups the consistency check caught immediately: its test counter did
not know `testWidgets`, and the listener rule flagged the new `FocusNode`
listeners. The latter is a real distinction rather than a false positive: a
listener on an **own** node is released by its `dispose()`, whereas one on a
settings singleton — which outlives the widget — has to be detached
explicitly. The check now separates the two.

### 7.6 Rules for future audits

1. **Do not implement a finding that declares a resource "unused" without a
   build.** `gstatic` is the model case: the reasoning sounded coherent and
   was wrong.
2. **Comments are not evidence.** "does not interfere" in `index.html` covered
   the service worker conflict for two releases; the header of
   `cardioplegia_alarm_settings.dart` described the opposite of the code for
   two versions. Where a comment carries an assumption, a test or a check
   belongs next to it.
3. **Change coupled mechanisms together.** Cache invalidation and precache
   scope depend on each other; so do the CSP and how fonts are obtained.
4. **Online tests do not reveal service worker defects.** The cache only shows
   itself when it is needed. Offline belongs in every web test plan — and
   therefore so does the Windows distribution, which is the same web app.
5. **Compute expected values in tests, do not estimate them.** The first test
   run failed on a value the author had done in his head.
6. **The analyzer finds what humans overlook.**
   `unnecessary_non_null_assertion` and `unawaited_futures` were both real
   hits in freshly written code.
7. **Every CI substitution verifies itself.** `BUILD_ID` and `BUILD_ASSETS`
   fail the job when their `sed` does not take effect.
8. **A fix that changes behaviour needs the same verification step as the
   finding that prompted it.**
9. **A directory whose contents are shipped belongs in scope** — even when it
   holds no application code. `tool/offline/` went unopened for four audits.
10. **When two output paths represent the same calculation, test that they
    agree** — not just each on its own. Screen and PDF diverged three times.
11. **A default value is not an entry.** Anything feeding a "has the user done
    something here" filter must distinguish set from pre-filled.
12. **What an audit counts by hand belongs in a script afterwards.** The
    findings of the later rounds arose not because the rules were unknown but
    because their application stayed sample-based.
13. **A verification tool is code and needs the same proof as the code it
    checks.** Two tool defects were plausible assumptions about foreign
    behaviour — `Invoke-WebRequest`'s URL normalisation and `Get-Command`'s
    result — that nobody had executed.
14. **A coverage gap is a hint, not a task.** What was informative was not the
    absolute number but the gradient: one class at 10 % while two siblings of
    the same pattern stood at 100 %.
15. **Never ship something known to be wrong and move the warning into prose.**
    `pubspec.lock` sat in packages although it could not be correct there.
    Either it is right, or it does not belong in the package.

### 7.7 Verification tooling

Built in v0.4.13 and extended since, because eleven rounds had checked the
same invariants by hand.

- **`tool/verify/consistency_check.py`** — 15 checks across language borders.
  Each stands for a documented defect above. Exceptions are marked at the site
  with `// verify:ok <reason>` rather than weakening the rule.
- **`tool/verify/coverage_report.py`** — evaluates `coverage/lcov.info`,
  untested files first. `lib/screens/`, `lib/widgets/` and `lib/theme/` are
  hidden; what remains is the part that calculates.
- **`tool/offline/test-serve.ps1`** — 17 requests against a sandboxed
  `serve.ps1`. The criterion is content, not status code: the contents of the
  file outside the root must never appear. 403 (refused) and 404 (request
  arrived normalised) are both fine.
- **`tool/verify/verify-all.ps1`** — one command for everything, on Windows.
- **`.github/workflows/checks.yml`** — `analyze`, `test` and the consistency
  check on every push and pull request, deliberately separate from the
  delivery path.

### 7.8 Language

Code, tests, tooling, workflows and developer documentation are English —
converted in v0.4.24 through v0.4.30, roughly 750 comment lines and 17,500
words of documentation. Nothing about behaviour changed: `consistency_check.py`
produced byte-identical output before and after its own translation, the CI
placeholders in `sw.js` survived, and the test count stayed at 276.

Four things stay German on purpose:

- the German half of `privacy_policy.md` and `web/privacy.html` — that *is*
  the German version, and for perfusioncalc.de it is the authoritative one;
- the German half of `AI-NOTICE.md`, for the same reason: it is a bilingual
  self-declaration that argues specifically about German copyright law;
- `tool/offline/LIESMICH.txt`, read by German-speaking staff at the clinical
  workstation;
- the console output of `start.bat` and `serve.ps1`, same audience. Their
  comments are English, their messages are not.

**A localisation gap closed on the way (v0.4.32).** The `AppSources` entries
in `common.dart` carried German explanatory sentences that the source dialog
displayed regardless of the selected language, because they sat inside the
`doi` field and were never part of the i18n table.

The field was doing two jobs at once: identifier and prose, separated by a
middle dot. `SourceRef` now has `doi` (DOI/PMID/URL, language independent) and
`noteKey` (an i18n key). 21 entries were split, 21 key pairs added, and the
dialog renders the note as its own line. Original paper titles — Hüfner 1894,
Silbernagl's *Taschenatlas Physiologie* — stay German, because that is what
they are called.

Two tests guard it: every `src_note_*` key resolves in both languages, and EN
and DE must **differ** — which catches the case where a German string was
pasted into both slots.

**The first pass caught only 21 of 30 entries (v0.4.33).** The conversion
script worked from a hand-written list of translations, so anything absent
from that list stayed German — Calafiore 2020 (source 35) among them. Three
further entries kept a German remnant because the script treated the LAST
segment separated by a middle dot as the description, and their descriptions
contained a middle dot themselves: a unit (`dyn · s · cm⁻⁵`), or several
equations. Six more were only found once the check no longer guessed the
language but examined the structure — is each segment an identifier? — and
once the escaped `\u00b7` was normalised before splitting.

That is check 16 in `consistency_check.py`: `SourceRef.doi` holds identifiers
only. It lives there rather than in a Dart test because `AppSources` has no
list of all entries, and maintaining one by hand would be the same trap as
the hard-wired `TabController`.

**Everything in the source dialog is selectable (v0.4.33).** Every line is a
`SelectableText` and one `SelectionArea` spans the whole list — that
combination is what allows a drag across several lines and several
references, so a citation can be copied in one piece into a search engine or
a reference manager. Individual `SelectableText`s without the surrounding
area would each be their own island and a selection would stop at the end of
a line. The bracketed number stays a plain `Text`: "[35]" labels the dialog,
it is not part of the citation.
