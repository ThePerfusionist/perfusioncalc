# Security Policy

PerfusionCalc is a calculator for cardiac perfusion. It is **not a medical
device** under Regulation (EU) 2017/745 and is not validated for clinical
use — but it is used to check numbers that inform clinical work, so reports
are taken seriously.

## Supported versions

Only the latest release receives fixes. Older versions are not patched;
please update before reporting.

| Version | Supported |
|---|---|
| latest release | yes |
| everything older | no |

Current release: see the [releases page](https://github.com/ThePerfusionist/perfusioncalc/releases).

## Reporting a vulnerability

**Preferred:** [GitHub Private Vulnerability Reporting](https://github.com/ThePerfusionist/perfusioncalc/security/advisories/new)
— keeps the report out of the public issue tracker until a fix exists.

**Alternative:** perfusioncalc@unbox.at

Please do not open a public issue for anything exploitable.

### What helps

- Affected version (burger menu → info button) and platform (Web / Android / iOS / offline Windows bundle)
- Steps to reproduce, ideally minimal
- The file and line, if you already found them
- What an attacker gains — impact matters more than severity labels

### What to expect

This is a single-maintainer project run alongside clinical work, so response
times are honest rather than aspirational:

| | |
|---|---|
| Acknowledgement | within 7 days |
| Initial assessment | within 14 days |
| Fix for a confirmed high-impact issue | next release, and a note in the release text |

If you have not heard back after 14 days, send a reminder — the report was
probably missed, not ignored.

## In scope

- The Flutter app (Android, iOS, web at [perfusioncalc.de](https://perfusioncalc.de))
- The offline Windows bundle, including its bundled Caddy configuration
- The build and release pipeline (`.github/workflows/`), including signing and supply-chain concerns
- The service worker and its caching behaviour
- **Incorrect clinical calculations.** These are not classic security bugs but
  are treated with the same urgency: a wrong number that looks plausible is
  the most dangerous failure this project has. Please cite the primary
  literature you checked against.

## Out of scope

- GitHub Pages / GitHub infrastructure itself — report those to GitHub
- Missing HTTP security headers that GitHub Pages cannot set
  (`X-Frame-Options`, `Permissions-Policy`; the reasoning is documented in `web/index.html`)
- Findings from automated scanners without a demonstrated impact
- Social engineering, physical access, or attacks requiring a compromised device

## Data handling

The app collects no personal data, has no account system, and the Android
release build declares no `INTERNET` permission. Details:
[privacy policy](https://perfusioncalc.de/privacy.html).

Values entered are held in memory only. **If you report a bug, do not attach
real patient data** — construct an equivalent example instead.

## Credit

Reporters are credited in the release notes unless they prefer otherwise.
There is no bug bounty; this is an unfunded open-source project.
