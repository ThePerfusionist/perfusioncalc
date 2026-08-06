# Play Console — Data safety, cross-checked against the privacy policy

**State:** v0.4.31+53 · checked against `privacy_policy.md`, `web/privacy.html`,
`pubspec.yaml` and the release manifest.

A filling aid for *Play Console → App content → Data safety*. Each answer
records what it rests on — divergence between the form and the privacy policy
is the most common reason for rejection in this category.

> I am not a lawyer and the Play Console UI changes. The answers below follow
> Google's current definition of "collect"; field labels may differ in detail.

---

## 1. The decisive definition

Google defines **"collect" as: data leaves the device.** Not: data is
processed. Not: data is stored.

Everything else for PerfusionCalc follows from that:

| What the app does | Leaves the device? | Declare in the form? |
|---|---|---|
| Calculate patient values in memory | no | **no** |
| Store language, theme, alarm parameters, del Nido ratio, RBC haematocrit in `SharedPreferences` | no | **no** |
| Save a PDF through the system save dialog | no — the user picks the destination and the app never reads the file again | **no** |
| Schedule a local notification | no | **no** |

The strongest evidence sits in the manifest: **the release build declares no
`INTERNET` permission.** The declared permissions are `POST_NOTIFICATIONS`,
`SCHEDULE_EXACT_ALARM`, `VIBRATE`, `WAKE_LOCK`, `RECEIVE_BOOT_COMPLETED` — none
of which grants network access. An app without `INTERNET` is technically
incapable of transmitting anything.

---

## 2. Answers, field by field

### Data collection and security

| Question | Answer | Reason |
|---|---|---|
| Does your app collect or share any of the required user data types? | **No** | see above; no `INTERNET` permission in the release build |

With "No" the follow-up questions on data types, purposes, encryption in
transit and deletion mechanism disappear. The form is **still mandatory** —
there is no way to skip it for apps that collect nothing.

### Should the form show those questions anyway

| Question | Answer |
|---|---|
| Is all collected data encrypted in transit? | **not applicable** (nothing is transmitted) |
| Can users request that their data be deleted? | **not applicable** — uninstalling removes everything; a deletion mechanism presupposes server-side data, of which there is none |
| Is the data collection independently validated against a security standard? | **No** (optional declaration) |

### Adjacent sections under "App content"

| Section | Answer | Reason |
|---|---|---|
| Privacy policy (URL) | `https://perfusioncalc.de/privacy.html` | reachable since v0.4.1, bilingual |
| Advertising ID | **No** | no ad SDKs, no `AD_ID` permission |
| Ads | **The app contains no ads** | |
| App access | **All functionality available without special access** | no login, no account |
| Target audience | **18+ only** | professional tool for clinical perfusion; do not classify as child-directed |
| News app | **No** | |
| Government app, financial features | **No** | |
| Health apps declaration | **check** — see below |

---

## 3. Three points that need a deliberate decision

### 3.1 Store category: Education — decided

**Category: *Education*, not *Medical*.**

The *Medical* category triggers follow-up questions about medical device
status in several regions, and PerfusionCalc explicitly rules that status out
(section 12 of the privacy policy: **not a medical device** within the meaning
of Regulation (EU) 2017/745, not validated for clinical use). Choosing a
category that triggers precisely the review whose outcome you deny in advance
creates work without any benefit.

*Education* covers the stated purpose — training and personal use in clinical
perfusion — and is therefore the more accurate classification, not an evasion.

**For the choice to hold, the store text has to match it.** That is the real
point: the category is one line in a form, but what gets read is the
description.

| belongs in | does not belong in |
|---|---|
| "for training and continuing education in clinical perfusion" | "for clinical use" |
| "reference and calculation aid" | "for treatment decisions" |
| "results must be verified against the primary literature and your institution's protocols" | "validated", "certified", "approved" |
| the MDR exclusion verbatim | claims about patient safety or quality of care |

The MDR exclusion belongs **verbatim in the store description**, not only in
the privacy policy. A cardiac perfusion calculator without that note in the
listing invites exactly the question it is trying to avoid.

**The health apps declaration depends on functionality, not on the category.**
If Play asks for it, answer truthfully — *Education* does not exempt you. What
the category changes is the likelihood of the review taking the medical device
route at all.

### 3.2 The web app does **not** belong in the form

`perfusioncalc.de` runs on GitHub Pages, and GitHub processes IP address,
timestamp and user agent in server log files while doing so — section 6 of the
privacy policy says so explicitly.

That is **no contradiction** to the "No" in the form: the data safety
declaration covers the Android app delivered through Play, not a website.
Conflating the two would declare a collection the app is incapable of.

Should the Play review come back to this, that separation is the answer — and
the privacy policy supports it, because it treats both cases separately.

### 3.3 SDK review: done, but keep it verifiable

Google attributes data transmitted by an embedded SDK to the app. Complete
list of runtime dependencies:

| Package | Transmits data? |
|---|---|
| `shared_preferences` | no — device storage |
| `flutter_local_notifications` | no — local scheduling, no push service |
| `timezone` | no — bundled zone database |
| `pdf` | no — produces bytes in memory |
| `file_picker` | no — system dialog, the user picks the destination |
| `web` | no — interop bindings, active only in the web build |

No analytics, no Crashlytics, no Firebase, no ad SDKs.

Crash reports that Google Play itself gathers through Android Vitals are
Google's own collection, not the app's.

**There is nothing to decide here — it is an obligation with an expiry date.**
The "No" in the form holds for the state of this list. If a dependency that
transmits data is added later, the declaration becomes false without anybody
having done anything wrong.

`tool/verify/consistency_check.py` therefore checks this table mechanically
against `pubspec.yaml`: every runtime dependency has to be listed here, or the
check fails — locally and in CI. A new package thus forces a deliberate line
in this table instead of relying on someone remembering.

What to do then: look up in the package documentation whether it sends data
off the device, add the row with "no" or "yes — what exactly", and for "yes"
adjust the form.

---

## 4. Consistency: form against privacy policy

Each line is a statement that has to agree in both documents.

| Statement in the form | Covered in the privacy policy |
|---|---|
| No data collection | section 2: "collects no personal data"; section 3: values held in memory only |
| No sharing with third parties | section 8 |
| No advertising IDs | section 2 |
| No account, no login | section 2 ("no sign-up, no user account") |
| No deletion mechanism needed | sections 9 (no retention) and 10 (access requests answered in the negative for want of data) |
| Local settings without personal reference | section 4, with the full table |
| No cloud backup, no device transfer | section 4, evidenced by `allowBackup="false"` and `data_extraction_rules.xml` |
| Not directed at children | section 11 |

**If one of these statements changes, three things have to move together:**
`privacy_policy.md`, `web/privacy.html` and the form. The first two are
checked against each other by `tool/verify/consistency_check.py`; no script
can reach the form.

---

## 5. Order of operations

1. Deploy `web/privacy.html` and open it in a browser — the URL has to be
   reachable **before** it is entered into the form.
2. Enter the privacy policy URL under *App content*.
3. Fill in the data safety form: main question **No**, submit.
4. Answer advertising ID, ads, app access, target audience.
5. Choose the category **Education** and align the store description with the
   table in section 3.1, including the MDR note in the body text.
6. Review the data safety card preview — it should then read along the lines
   of "No data collected" and "No data shared". That is exactly what should
   appear on the store page.
