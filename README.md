<div align="center">

# 🫀 PerfusionCalc

**A comprehensive, evidence-based medical calculator for perfusionists**

[![Version](https://img.shields.io/badge/version-0.1.9-orange?style=flat-square)](https://github.com/ThePerfusionist/perfusioncalc/releases)
[![Platform](https://img.shields.io/badge/platform-Android%20%7C%20iOS%20%7C%20Web-brightgreen?style=flat-square)](https://theperfusionist.github.io/perfusioncalc/)
[![License](https://img.shields.io/badge/license-GNU%20GPL%20v3.0-blue?style=flat-square)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-≥%203.4-54C5F8?style=flat-square&logo=flutter)](https://flutter.dev)
[![WebApp](https://img.shields.io/badge/WebApp-live-success?style=flat-square)](https://theperfusionist.github.io/perfusioncalc/)
[![Languages](https://img.shields.io/badge/i18n-EN%20%2F%20DE-blueviolet?style=flat-square)](#-internationalization)
[![Tests](https://img.shields.io/badge/tests-83%20passing-brightgreen?style=flat-square)](test/)
[![PWA](https://img.shields.io/badge/PWA-offline%20capable-5A0FC8?style=flat-square)](#-progressive-web-app)

</div>

---

> **⚠️ Disclaimer**
> This application is intended **only for educational and personal use**.
> It is **not validated for clinical use** and must **not** be used for medical diagnosis,
> treatment decisions, or patient management. No guarantee of accuracy.
> Always verify results with primary sources and qualified professionals.

---

## 📖 About

PerfusionCalc is a free, open-source mobile and web application designed to support
**perfusionists, cardiac surgery students, and clinical perfusion teams** with
quick reference calculations during education and training.

All implemented formulas are derived from **peer-reviewed primary literature** —
every formula is traceable to its original publication via the in-app **Source / Quelle**
button. The app covers the full spectrum of perfusion calculations: from basic BSA
and oxygen delivery to goal-directed perfusion thresholds, Severinghaus blood gas
temperature correction, pediatric perfusion parameters, and anatomical heart references.

The app is bilingual (English / German), works fully offline as a Progressive Web App,
runs in any modern browser including privacy-focused browsers without WebGL, and exports
calculation snapshots as PDF for documentation or sharing during training sessions.

---

## ✨ Features – 11 Tabs

| Tab | Calculations |
|-----|-------------|
| 🫀 **BSA / CO / Hb / Hct** | Body surface area (DuBois), cardiac output, blood volume ♂/♀, expected Hb & Hct after priming |
| 💨 **O₂ Delivery** | CaO₂, CvO₂, Ca-vDO₂, DO₂, DO₂i, VO₂, VO₂i, O₂-ER, min. cardiac output, min. Hb · CO/CI toggle |
| 🔁 **Resistances** | SVR and PVR in dyn·s·cm⁻⁵ |
| ⚗️ **Electrolytes / Buffer** | Sodium, potassium, calcium needs · NaBic 8.4% · TRIS 36.34% |
| 📏 **Tube Volume** | Fill volume (ml) for 3/16", 1/4", 3/8", 1/2" per entered length |
| 💧 **Flow / Drainage Rate** | Max. flow and drainage reference table by tube size |
| 📐 **Zoll / Charriere** | Diameter reference table · Ch ↔ mm converter |
| ❄️ **Hypothermia** | Level table (Light/Moderate/Deep/Profound) · **BGA temperature correction (Severinghaus)** |
| 👶 **Pediatric** | Tube sizes (Darling) · Perfusion rates (Tschaut) · VA/VV cannula sizes (Finck) · Blood volume · Transfusion volume |
| 📊 **Reference Values Pressure** | Haemodynamic pressure reference values with normal ranges |
| ❤️ **Heart Anatomy** | Coronary circulation anterior/posterior · Heart cross-section · Coronary arteries schematic — tap to zoom |

---

## 🌟 Cross-Cutting Features

### 🌐 Internationalization

The entire app — labels, hints, dialogs, source citations, PDF exports — is available
in **English** and **German**. The language is selected via the burger menu and
persists across sessions. All texts switch live without app restart.

Scientific source references (e.g. "DuBois 1916", "Severinghaus 1979") remain in
the original English to follow international convention.

### 📄 PDF Export

Each calculation tab has an **Export as PDF / Als PDF exportieren** button that
generates a professional, branded PDF snapshot:

- **Header:** PerfusionCalc logo (gold), tab title, export timestamp
- **Inputs section:** all entered patient/clinical values
- **Results section:** all computed values
- **Footer:** disclaimer, version, page numbers

PDF language follows the app language. On the **web**, the PDF is downloaded
directly. On **Android/iOS**, a system save dialog opens (Storage Access Framework
on Android, Files app on iOS) — the user picks the destination. No storage
permissions required.

### ✅ Plausibility Ranges

All input fields validate values against medically reasonable ranges. Out-of-range
values are highlighted with a soft orange border and warning icon, but the
calculation continues — useful for teaching scenarios (e.g. discussing extreme
cases in trauma or congenital defects).

### 📱 Progressive Web App

The web version is a fully-featured PWA:
- **Offline capable:** custom service worker caches all assets after first load
- **Installable:** add to home screen on iOS, install button in Chrome/Edge on desktop
- **App-like:** runs in standalone window, no browser chrome

### 🔬 Browser Compatibility

Tested in privacy-focused browsers (Ungoogled Chromium, Brave on Aggressive Shields,
LibreWolf) with WebGL disabled. Images use `Image.network` with
`webHtmlElementStrategy: prefer` to render via native `<img>` tags in the DOM,
working in any browser regardless of CanvasKit availability.

### 🧪 Test Coverage

**83 unit tests** verify all medical formulas against published reference values:
- BSA (DuBois), CO, blood volume (Silbernagl/Nadler)
- CaO₂/CvO₂/DO₂i/VO₂/O₂-ER (Hüfner/Ranucci) with goal-directed perfusion threshold
- Electrolyte and buffer corrections (Larsen)
- Severinghaus 1979 temperature correction, Henderson-Hasselbalch
- Pediatric transfusion volume (Davies/Howie)
- NaN/Infinity input safety, plausibility ranges, full i18n key coverage

Run tests with:
```bash
flutter test
```

---

## 🧮 Formulas

### Body Surface Area & Hemodynamics

| Parameter | Formula | Source |
|-----------|---------|--------|
| BSA | `0.007184 × H^0.725 × W^0.425` | Du Bois & Du Bois, 1916 |
| Cardiac output | `BSA × CI` (CI default 2.4 l/min/m²) | Gorlin & Gorlin, 1951 |
| Blood volume ♂ | `0.041 × kg + 1.53 L` | Silbernagl & Despopoulos |
| Blood volume ♀ | `0.047 × kg + 0.86 L` | Silbernagl & Despopoulos |
| Expected Hb | `Hb − (Hb × priming) / (BW × 100)` | |
| Expected Hct ♂/♀ | `Hct × BV / (BV + priming)` | Nadler et al., 1962 |

### Oxygen Delivery & Consumption

| Parameter | Formula | Source |
|-----------|---------|--------|
| CaO₂ | `(Hb × 1.34 × SaO₂/100) + (PaO₂ × 0.0031)` | Hüfner, 1884 |
| CvO₂ | `(Hb × 1.34 × SvO₂/100) + (PvO₂ × 0.0031)` | Hüfner, 1884 |
| DO₂ | `CaO₂ × CO × 10` | de Somer et al., 2011 |
| DO₂i | `CaO₂ × CI × 10` — threshold **> 272 ml/min/m²** | Ranucci et al., 2005 |
| VO₂ | `Ca-vDO₂ × CO × 10` | Fick principle |
| O₂-ER | `VO₂ / DO₂ × 100` | |
| Min. cardiac output | `272 × BSA / (CaO₂ × 10)` | Ranucci et al., 2005 |

### Resistances

| Parameter | Formula |
|-----------|---------|
| SVR | `(MAP − CVP) × 80 / CO` |
| PVR | `(PAP − LAP) × 80 / CO` |

### Hypothermia / BGA Correction (Severinghaus 1979)

| Parameter | Formula |
|-----------|---------|
| PO₂(T) | `PO₂(37) × e^(fᵀ × ΔT)` |
| PCO₂(T) | `PCO₂(37) × 10^(0.0185 × ΔT)` |
| pH(T) | `pH(37) − 0.0147 × ΔT` |
| HCO₃⁻ | `0.0307 × PCO₂ × 10^(pH−6.105)` |
| SaO₂ from PaO₂ | `(23400 × (PO₂³+150 × PO₂)⁻¹ + 1)⁻¹` |

### Pediatric

| Parameter | Source |
|-----------|--------|
| Tube sizes by weight | Darling et al., 2000 |
| Perfusion rate | Tschaut, 2020 |
| VA/VV cannula sizes | Finck, 2020 |
| Blood volume (premature, infant, child, adolescent) | Hazinski 2013 / Howie 2008 |
| Transfusion volume | `Δ Hb × BV × 3 / Hct(EK 55%)` (Davies 2007) |

---

## 📚 Sources

All formulas are traceable via the in-app **Source / Quelle** buttons. The complete
source list is available in [`lib/widgets/common.dart`](lib/widgets/common.dart) under `AppSources`.

Selected primary references:

| # | Reference |
|---|-----------|
| [1] | Du Bois D, Du Bois EF. A formula to estimate the approximate surface area if height and weight be known. *Arch Intern Med.* 1916;17:863–871. |
| [2] | Nadler SB, Hidalgo JU, Bloch T. Prediction of blood volume in normal human adults. *Surgery.* 1962;51(2):224–232. |
| [3] | Silbernagl S, Despopoulos A. *Color Atlas of Physiology.* Thieme. |
| [4] | Hüfner G. Neue Versuche zur Bestimmung der Sauerstoffcapacität des Blutfarbstoffs. *Arch Anat Physiol.* 1894:130–176. |
| [5] | Gorlin R, Gorlin SG. Hydraulic formula for calculation of the area of the stenotic mitral valve. *Am Heart J.* 1951;41(1):1–29. |
| [6] | de Somer F et al. O2 delivery and CO2 production during cardiopulmonary bypass. *Crit Care.* 2011;15(4):R192. |
| [7] | Ranucci M et al. Oxygen delivery during cardiopulmonary bypass and acute renal failure. *Ann Thorac Surg.* 2005;80(6):2213–2220. |
| [8] | Newland RF et al. Goal-directed perfusion in cardiac surgery. *J Extra Corpor Technol.* 2017;49(2):88–93. |
| [9] | Larsen R. *Anästhesie und Intensivmedizin in Herz-, Thorax- und Gefäßchirurgie.* Springer. |
| [10] | Tschaut RJ. *Extracorporeal Circulation in Theory and Practice.* 2nd ed. Pabst Science Publishers. |
| [11] | Darling EM et al. Use of dilatational percutaneous tracheostomy in pediatric patients. *Pediatr Crit Care Med.* 2000;1(1):66–69. |
| [12] | Hazinski MF. *Nursing Care of the Critically Ill Child.* 3rd ed. Mosby. |
| [13] | Howie SR. Blood sample volumes in child health research. *Bull World Health Organ.* 2011;89(1):46–53. |
| [14] | Davies P et al. Reference ranges for the haemoglobin concentration of red cell concentrates. *Vox Sang.* 2007;92(2):195–198. |
| [15] | Finck C. General Guideline to VA/VV Cannulation. Clinical Guideline; 2020. |
| [16] | Severinghaus JW. Simple, accurate equations for human blood O₂ dissociation computations. *J Appl Physiol.* 1979;46(3):599–602. |
| [17] | Bradley AF, Stupfel M, Severinghaus JW. Effect of temperature on PCO₂ and PO₂ of blood in vitro. *J Appl Physiol.* 1956;9(2):201–204. |
| [18] | Severinghaus JW. Blood gas calculator. *J Appl Physiol.* 1966;21(3):1108–1116. |

---

## 🚀 Installation

### 🌐 WebApp (no installation required)

Open directly in any browser — works on iPhone, Android, and desktop:

**[https://theperfusionist.github.io/perfusioncalc/](https://theperfusionist.github.io/perfusioncalc/)**

On iPhone/iPad: tap **Share → Add to Home Screen** to install as an app icon.

The PWA service worker caches all assets on first visit, so subsequent loads
work fully offline.

---

### 🤖 Android – APK

Build from source

**Requirements:**

| Tool | Version |
|------|---------|
| Flutter SDK | ≥ 3.4.0 |
| Java JDK | ≥ 17 (Temurin 17 recommended) |

```bash
# Clone repository
git clone https://github.com/ThePerfusionist/perfusioncalc.git
cd perfusioncalc

# Install dependencies
flutter pub get

# Set Java version if needed (Windows example)
flutter config --jdk-dir "C:\Program Files\Eclipse Adoptium\jdk-17.x-hotspot"

# Build release APK
flutter build apk --release
```

APK location: `build/app/outputs/flutter-apk/app-release.apk`

---

### 🍎 iOS – App Store / TestFlight

> iOS requires an **Apple Developer Account** ($99/year) and cannot be built without macOS or a CI/CD service.

#### Option A: WebApp (recommended, no account needed)

The WebApp works fully in Safari on iPhone/iPad.
Open [https://theperfusionist.github.io/perfusioncalc/](https://theperfusionist.github.io/perfusioncalc/)
and use **Share → Add to Home Screen** for an app-like experience.

#### Option B: Build via Codemagic CI/CD (no Mac required)

1. **Apple Developer Account:** enroll at [developer.apple.com](https://developer.apple.com/programs/enroll/) ($99/year)
2. **Fork or clone** this repository to your GitHub account
3. **Codemagic:** sign up at [codemagic.io](https://codemagic.io) → connect GitHub → add this repo
4. **Configure workflow:**
   - Platform: iOS
   - Flutter channel: stable
   - Build for: App Store
5. **Code signing:** App Store Connect API Key → upload to Codemagic → enable Automatic signing
6. **Start build** → IPA is built on Apple Silicon VMs in the cloud → uploaded to TestFlight automatically

Codemagic free tier includes **500 build minutes/month** — sufficient for occasional updates.

#### Option C: Build on macOS (if you have access)

```bash
flutter build ipa --release
# Open Xcode → Organizer → Distribute App
```

---

### 🌐 WebApp – Self-Hosted Deployment

```bash
# Build with correct base path
flutter build web --release --base-href /perfusioncalc/

# Deploy: drag build/web/ folder to netlify.com/drop
# OR push to GitHub → GitHub Actions deploys automatically (see .github/workflows/deploy.yml)
```

---

## 🏗️ Project Structure

```
lib/
├── main.dart                       # App entry, navigation, drawer, language switcher
├── i18n/
│   └── app_strings.dart            # All EN/DE translations + LocaleNotifier
├── models/
│   ├── patient_data.dart           # All calculation formulas (single source of truth)
│   ├── bga_model.dart              # Severinghaus BGA temperature correction
│   └── ranges.dart                 # Plausibility ranges for input validation
├── screens/
│   ├── bsa_screen.dart
│   ├── o2_delivery_screen.dart
│   ├── resistances_screen.dart
│   ├── electrolytes_screen.dart
│   ├── tube_volume_screen.dart
│   ├── flow_drainage_screen.dart
│   ├── zoll_chairre_screen.dart
│   ├── hypothermia_screen.dart     # Includes Severinghaus BGA correction
│   ├── pediatric_screen.dart
│   ├── reference_pressure_screen.dart
│   └── heart_anatomy_screen.dart
├── utils/
│   ├── pdf_export.dart             # Central PDF generator (Roboto-based)
│   ├── pdf_download_web.dart       # Browser download via Blob + <a download>
│   └── pdf_download_stub.dart      # Mobile/desktop save dialog (file_picker)
└── widgets/
    └── common.dart                 # InputCard, ResultCard, SourceButton, PdfExportButton, BrowserSafeImage

test/
├── patient_data_test.dart          # BSA, CO, BV, Hb, DO₂, electrolytes, etc.
├── bga_model_test.dart             # Severinghaus temperature correction
├── ranges_test.dart                # Plausibility range validation
└── i18n_test.dart                  # Translation key coverage

assets/
├── fonts/                          # Roboto Regular/Bold/Italic for PDF export
├── icon.png, o2_chart.png
├── finck_va.jpg, finck_vv.jpg      # Pediatric cannula tables
├── heart_anterior.jpg, heart_posterior.jpg, heart_cross_section.jpg
└── coronary_arteries.jpg
```

---

## 🛠️ Built With

- [Flutter](https://flutter.dev) ≥ 3.4.0 — cross-platform framework
- [shared_preferences](https://pub.dev/packages/shared_preferences) — locale & settings persistence
- [pdf](https://pub.dev/packages/pdf) — PDF generation
- [file_picker](https://pub.dev/packages/file_picker) — native save dialog on Android/iOS
- [web](https://pub.dev/packages/web) — DOM access for browser PDF download

---

## 🤝 Contributing

Contributions, suggestions, and bug reports welcome. Please open an issue or pull request on GitHub.

When proposing new formulas, please include the **primary peer-reviewed source**.
PerfusionCalc only accepts calculations with verifiable, citable origins.

---

## 📄 License

This project is licensed under the **GNU General Public License v3.0**.
See the [LICENSE](LICENSE) file for details.

---

<div align="center">

*Created with 🤖 AI assistance · For educational use only · Not for clinical use*

[![GitHub](https://img.shields.io/badge/GitHub-ThePerfusionist%2Fperfusioncalc-181717?style=flat-square&logo=github)](https://github.com/ThePerfusionist/perfusioncalc)

</div>
