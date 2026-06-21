<div align="center">

# 🫀 PerfusionCalc

**A comprehensive, evidence-based medical calculator for perfusionists**

[![Version](https://img.shields.io/badge/version-0.2.1-orange?style=flat-square)](https://github.com/ThePerfusionist/perfusioncalc/releases)
[![Platform](https://img.shields.io/badge/platform-Android%20%7C%20iOS%20%7C%20Web-brightgreen?style=flat-square)](https://perfusioncalc.de/)
[![License](https://img.shields.io/badge/license-GNU%20GPL%20v3.0-blue?style=flat-square)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-≥%203.4-54C5F8?style=flat-square&logo=flutter)](https://flutter.dev)
[![WebApp](https://img.shields.io/badge/WebApp-live-success?style=flat-square)](https://perfusioncalc.de/)
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
| 👶 **Pediatric** | Tube sizes (Oldeen) · Perfusion rates (Ramakrishnan) · VA/VV cannula sizes (Finck) · Blood volume (Linderkamp) · Transfusion volume (Davies) |
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
- Electrolyte and buffer corrections (Mellemgaard/Astrup · Nahas · Adrogué/Madias)
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
| Cardiac output | `BSA × CI` (CI default 2.4 l/min/m²) | EACTS/EACTAIC/EBCP Guidelines 2024 |
| Blood volume ♂ | `0.041 × kg + 1.53 L` | Silbernagl & Despopoulos |
| Blood volume ♀ | `0.047 × kg + 0.86 L` | Silbernagl & Despopoulos |
| Expected Hb | `Hb − (Hb × priming) / (BW × 100)` | |
| Expected Hct ♂/♀ | `Hct × BV / (BV + priming)` | |

### Oxygen Delivery & Consumption

| Parameter | Formula | Source |
|-----------|---------|--------|
| CaO₂ | `(Hb × 1.34 × SaO₂/100) + (PaO₂ × 0.0031)` | Hüfner, 1894 |
| CvO₂ | `(Hb × 1.34 × SvO₂/100) + (PvO₂ × 0.0031)` | Hüfner, 1894 |
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
| Tube sizes by weight | Oldeen et al., 2020 (AmSECT) |
| Perfusion rate | Ramakrishnan et al., 2023 / Oldeen et al., 2020 |
| VA/VV cannula sizes | Finck et al., APSA Pediatric Surgery NaT |
| Blood volume (premature, infant, child, adolescent) | Linderkamp et al., 1977 |
| Transfusion volume | `Δ Hb × BV × 3 / Hct(EK 55%)` (Davies 2007) |

---

## 📚 Sources

All formulas are traceable via the in-app **Source / Quelle** buttons. The complete
source list is available in [`lib/widgets/common.dart`](lib/widgets/common.dart) under `AppSources`. Numbering matches the in-app citation badges.

| # | Reference |
|---|-----------|
| [1]  | Du Bois D, Du Bois EF. A formula to estimate the approximate surface area if height and weight be known. *Arch Intern Med.* 1916;17(6):863–871. |
| [2]  | Kunst G, Gerber V, Milojevic M, et al; ESAIC Guidelines Task Force; EACTS, EACTAIC, EBCP Guidelines Committees. 2024 EACTS/EACTAIC/EBCP Guidelines on cardiopulmonary bypass in adult cardiac surgery. *Br J Anaesth.* 2025;134(4):917–1008. doi:10.1016/j.bja.2024.10.018 |
| [3]  | Silbernagl S, Despopoulos A. *Taschenatlas Physiologie.* 9. Auflage. Stuttgart: Thieme; 2019. |
| [4]  | Nadler SB, Hidalgo JH, Bloch T. Prediction of blood volume in normal human adults. *Surgery.* 1962;51(2):224–232. |
| [5]  | Ranucci M, Romitti F, Isgrò G, et al. Oxygen delivery during cardiopulmonary bypass and acute renal failure after coronary operations. *Ann Thorac Surg.* 2005;80(6):2213–2220. |
| [6]  | de Somer F, Mulholland JW, Bryan MR, Aloisio T, Van Nooten GJ, Ranucci M. O₂ delivery and CO₂ production during cardiopulmonary bypass as determinants of acute kidney injury: time for a goal-directed perfusion management? *Crit Care.* 2011;15(4):R192. doi:10.1186/cc10349 |
| [7]  | Newland RF, Baker RA. Low Oxygen Delivery as a Predictor of Acute Kidney Injury during Cardiopulmonary Bypass. *J Extra Corpor Technol.* 2017;49(4):224–230. |
| [8]  | Newland RF, Baker RA, Woodman RJ, Barnes MB, Willcox TW; Australian and New Zealand Collaborative Perfusion Registry. Predictive Capacity of Oxygen Delivery During Cardiopulmonary Bypass on Acute Kidney Injury. *Ann Thorac Surg.* 2019;108(6):1807–1814. |
| [9]  | Ranucci M, Johnson I, Willcox T, et al. Goal-directed perfusion to reduce acute kidney injury: a randomized trial. *J Thorac Cardiovasc Surg.* 2018;156(5):1918–1927. |
| [10] | Gao P, Liu J, Zhang P, Bai L, Jin Y, Li Y. Goal-directed perfusion for reducing acute kidney injury in cardiac surgery: a systematic review and meta-analysis. *Perfusion.* 2023;38(3):591–599. |
| [11] | Hüfner G. Neue Versuche zur Bestimmung der Sauerstoffcapacität des Blutfarbstoffs. *Arch Anat Physiol (Physiol Abt).* 1894:130–176. |
| [12] | Dijkhuizen P, Buursma A, Fongers TM, Gerding AM, Oeseburg B, Zijlstra WG. The oxygen binding capacity of human haemoglobin. *Pflügers Arch.* 1977;369(3):223–231. doi:10.1007/BF00582188 |
| [13] | Barratt-Boyes BG, Wood EH. Cardiac output and related measurements and pressure values in the right heart and associated vessels, together with an analysis of the hemodynamic response to the inhalation of high oxygen mixtures in healthy subjects. *J Lab Clin Med.* 1958;51(1):72–90. |
| [14] | Skimming JW, Cassin S, Nichols WW. Calculating Vascular Resistances. *Clin Cardiol.* 1997;20(9):805–808. |
| [15] | Mellemgaard K, Astrup P. The quantitative determination of surplus amounts of acid or base in the human body. *Scand J Clin Lab Invest.* 1960;12(2):187–199. doi:10.3109/00365516009062420 |
| [16] | Nahas GG. Use of an organic carbon dioxide buffer in vivo. *Science.* 1959;129(3346):782–783. doi:10.1126/science.129.3346.782 |
| [17] | Adrogué HJ, Madias NE. Hyponatremia. *N Engl J Med.* 2000;342(21):1581–1589. doi:10.1056/NEJM200005253422107 |
| [18] | Severinghaus JW. Simple, accurate equations for human blood O₂ dissociation computations. *J Appl Physiol.* 1979;46(3):599–602. |
| [19] | Bradley AF, Severinghaus JW, Stupfel M. Effect of temperature on PCO₂ and PO₂ of blood in vitro. *J Appl Physiol.* 1956;9(2):201–204. |
| [20] | Severinghaus JW. Blood gas calculator. *J Appl Physiol.* 1966;21(3):1108–1116. |
| [21] | Ashwood ER, Kost G, Kenny M. Temperature correction of blood-gas and pH measurements. *Clin Chem.* 1983;29(11):1877–1885. |
| [22] | Gocoł R, Hudziak D, Bis J, Mendrala K, Morkisz Ł, Podsiadło P, Kosiński S, Piątek J, Darocha T. The Role of Deep Hypothermia in Cardiac Surgery. *Int J Environ Res Public Health.* 2021;18(13):7061. doi:10.3390/ijerph18137061 |
| [23] | Linderkamp O, Versmold HT, Riegel KP, Betke K. Estimation and prediction of blood volume in infants and children. *Eur J Pediatr.* 1977;125(4):227–234. doi:10.1007/BF00493567 |
| [24] | Howie SR. Blood sample volumes in child health research: review of safe limits. *Bull World Health Organ.* 2011;89(1):46–53. |
| [25] | Davies P, Robertson S, Hegde S, Greenwood R, Massey E, Davis P. Calculating the required transfusion volume in children. *Transfusion.* 2007;47(2):212–216. doi:10.1111/j.1537-2995.2007.01091.x |
| [26] | Ramakrishnan KV, Zurakowski D, Pearson GD, Pourmoghadam KK, Jonas RA, Sinha P. Cardiopulmonary bypass in neonates and infants: advantages of high flow high hematocrit bypass strategy — clinical practice review. *Transl Pediatr.* 2023;12(7):1483–1495. doi:10.21037/tp-23-141 |
| [27] | Oldeen ME, Angona RE, Hodge A, Klein T. American Society of ExtraCorporeal Technology: Development of Standards and Guidelines for Pediatric and Congenital Perfusion Practice (2019). *J Extra Corpor Technol.* 2020;52(4):319–326. doi:10.1051/ject/202052319 |
| [28] | Finck C, et al. Extracorporeal Life Support. *Pediatric Surgery NaT*, American Pediatric Surgical Association, 2025. Pediatric Surgery Library. www.pedsurglibrary.com/apsa/view/Pediatric-Surgery-NaT/829025/all/Extracorporeal_Life_Support |
| [29] | Blausen.com staff. Medical gallery of Blausen Medical 2014. *WikiJournal of Medicine.* 2014;1(2):10. doi:10.15347/wjm/2014.010 (CC BY 3.0). |

---

## 🚀 Installation

### 🌐 WebApp (no installation required)

Open directly in any browser — works on iPhone, Android, and desktop:

**[https://perfusioncalc.de/](https://perfusioncalc.de/)**

On iPhone/iPad: tap **Share → Add to Home Screen** to install as an app icon.

The PWA service worker caches all assets on first visit, so subsequent loads
work fully offline.

---

### 🤖 Android – Download/Update from Releases

1. Go to **[Releases](https://github.com/ThePerfusionist/perfusioncalc/releases)**
2. Download the **[latest build](https://github.com/ThePerfusionist/perfusioncalc/releases/latest)**
3. Install the `.apk` on your android device

### 🤖 Android – Build APK from Source

This guide walks you through building your own PerfusionCalc APK from source — no
prior Flutter experience required. The process works on **Windows, macOS, and Linux**.

#### Requirements

| Tool | Version | Purpose |
|------|---------|---------|
| [Flutter SDK](https://docs.flutter.dev/get-started/install) | ≥ 3.4.0 | Build framework |
| [Java JDK](https://adoptium.net/temurin/releases/?version=17) | 17 (Temurin recommended) | Required by Gradle / Android build |
| [Android SDK](https://developer.android.com/studio) | API 34+ (Android 14) | Provided via Android Studio or `cmdline-tools` |
| [Git](https://git-scm.com/downloads) | any recent | Clone the repository |
| Free disk space | ~ 15 GB | Flutter + Android SDK + build artifacts |

> 💡 The simplest setup is to install **Android Studio**, which bundles the
> Android SDK, platform-tools, and an emulator. Flutter and JDK 17 are installed
> separately.

#### Step 1 – Verify your toolchain

After installing Flutter, run:

```bash
flutter doctor -v
```

Resolve every red **✗** before proceeding. Typical fixes:

- **Android licenses not accepted:** `flutter doctor --android-licenses` (accept all with `y`)
- **JDK not found:** point Flutter to JDK 17 (see Step 3)
- **cmdline-tools missing:** open Android Studio → *SDK Manager → SDK Tools* → check **Android SDK Command-line Tools (latest)** → Apply

#### Step 2 – Clone the repository

```bash
git clone https://github.com/ThePerfusionist/perfusioncalc.git
cd perfusioncalc
flutter pub get
```

#### Step 3 – Configure JDK 17 (only if `flutter doctor` complains)

PerfusionCalc's Gradle build requires **JDK 17**. If your system uses a different
default JDK, point Flutter to JDK 17 explicitly:

```bash
# Windows (PowerShell / CMD)
flutter config --jdk-dir "C:\Program Files\Eclipse Adoptium\jdk-17.0.x-hotspot"

# macOS (Homebrew Temurin)
flutter config --jdk-dir "/Library/Java/JavaVirtualMachines/temurin-17.jdk/Contents/Home"

# Linux (Debian/Ubuntu via apt)
flutter config --jdk-dir "/usr/lib/jvm/temurin-17-jdk-amd64"
```

Verify with `flutter doctor -v` — the *Android toolchain* section should report
**Java version OpenJDK Runtime Environment Temurin-17.x.x**.

#### Step 4 – Choose your build variant

| Variant | Command | Use case |
|---------|---------|----------|
| **Debug APK** | `flutter build apk --debug` | Quick test on your own device, includes debug symbols |
| **Release APK (universal)** | `flutter build apk --release` | One APK for all CPU architectures (~ 50 MB, easiest to share) |
| **Release APK (split per ABI)** | `flutter build apk --release --split-per-abi` | Three smaller APKs (arm64-v8a / armeabi-v7a / x86_64), pick the one matching your device |
| **App Bundle** *(Play Store only)* | `flutter build appbundle --release` | `.aab` file for Google Play upload — **do not use for sideloading** |

For most users, the **universal release APK** is the right choice:

```bash
flutter build apk --release
```

The first build downloads Gradle and Android dependencies and may take **5–15 minutes**.
Subsequent builds finish in under a minute.

#### Step 5 – Locate your APK

| Variant | Output path |
|---------|-------------|
| Debug | `build/app/outputs/flutter-apk/app-debug.apk` |
| Release (universal) | `build/app/outputs/flutter-apk/app-release.apk` |
| Release (split) | `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` *(and 2 more)* |
| App Bundle | `build/app/outputs/bundle/release/app-release.aab` |

> ℹ️ Without your own signing key, release APKs are signed with Flutter's **debug
> key**. They install fine for personal use but cannot be published to the Play
> Store. To sign with your own key, see the next section.

#### Step 6 *(optional)* – Sign your release APK with your own key

Required only if you want to publish or distribute the APK officially:

```bash
# Generate a keystore (one-time, keep the .jks file safe!)
keytool -genkey -v -keystore ~/perfusioncalc-release.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias perfusioncalc
```

Create `android/key.properties` (do **not** commit this file):

```properties
storePassword=<your-password>
keyPassword=<your-password>
keyAlias=perfusioncalc
storeFile=/absolute/path/to/perfusioncalc-release.jks
```

Then rebuild: `flutter build apk --release`. Verify the signature with
`apksigner verify --print-certs build/app/outputs/flutter-apk/app-release.apk`.

#### Step 7 – Install the APK on your Android device

**Option A — direct transfer:** Copy the `.apk` file via USB, cloud storage, or
messenger to your phone, then tap it. You may need to enable
*Settings → Apps → Special access → Install unknown apps* for your file manager.

**Option B — via ADB (developer mode required):**

```bash
adb install build/app/outputs/flutter-apk/app-release.apk

# Reinstall while keeping app data
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

#### Troubleshooting

| Symptom | Solution |
|---------|----------|
| `Execution failed for task ':app:checkDebugAarMetadata'` | Update Flutter: `flutter upgrade` and run `flutter clean` |
| `Unsupported class file major version 65` | JDK > 17 in use — switch to JDK 17 (Step 3) |
| `SDK location not found` | Set `ANDROID_HOME` env var, or create `android/local.properties` with `sdk.dir=/path/to/Android/sdk` |
| `App not installed` on device | Uninstall any previous PerfusionCalc version first — different signing keys conflict |
| Build hangs at "Running Gradle task" | First build downloads ~ 1 GB; check your internet connection and wait |
| `cmdline-tools component is missing` | Android Studio → SDK Manager → SDK Tools → install **Android SDK Command-line Tools (latest)** |

After a failed build, always try `flutter clean && flutter pub get` before reporting an issue.

---

### 🍎 iOS – App Store / TestFlight

> iOS requires an **Apple Developer Account** ($99/year) and cannot be built without macOS or a CI/CD service.

#### Option A: WebApp (recommended, no account needed)

The WebApp works fully in Safari on iPhone/iPad.
Open [https://perfusioncalc.de/](https://perfusioncalc.de/)
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
# Build for custom domain (perfusioncalc.de)
flutter build web --release --base-href /

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

Copyright (C) 2026 ThePerfusionist

This project is licensed under the **GNU General Public License v3.0**.
See the [LICENSE](LICENSE) file for details.

---

<div align="center">

*Created with 🤖 AI assistance · For educational use only · Not for clinical use*

[![GitHub](https://img.shields.io/badge/GitHub-ThePerfusionist%2Fperfusioncalc-181717?style=flat-square&logo=github)](https://github.com/ThePerfusionist/perfusioncalc)

</div>
