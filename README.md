<div align="center">

# 🫀 PerfusionCalc

**A comprehensive, evidence-based medical calculator for perfusionists**

[![Version](https://img.shields.io/badge/version-0.1.7-orange?style=flat-square)](https://github.com/ThePerfusionist/perfusioncalc/releases)
[![Platform](https://img.shields.io/badge/platform-Android%20%7C%20iOS%20%7C%20Web-brightgreen?style=flat-square)](https://theperfusionist.github.io/perfusioncalc/)
[![License](https://img.shields.io/badge/license-GNU%20GPL%20v3.0-blue?style=flat-square)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-≥%203.4-54C5F8?style=flat-square&logo=flutter)](https://flutter.dev)
[![WebApp](https://img.shields.io/badge/WebApp-live-success?style=flat-square)](https://theperfusionist.github.io/perfusioncalc/)

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
every formula is traceable to its original publication via the in-app **Source** button.
The app covers the full spectrum of perfusion calculations: from basic BSA and oxygen
delivery to goal-directed perfusion thresholds, Severinghaus blood gas temperature
correction, pediatric perfusion parameters, and anatomical heart references.

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
| Min. Hb | `(272×BSA − 10×CO×0.0031×PaO₂) / (10×CO×1.34×SaO₂/100)` | |

### Vascular Resistances

| Parameter | Formula | Source |
|-----------|---------|--------|
| SVR | `(MAP − CVP) / CO × 80` [dyn·s·cm⁻⁵] | Barratt-Boyes & Wood, 1958 |
| PVR | `(PAP − LAP) / CO × 80` [dyn·s·cm⁻⁵] | Skimming et al., 1997 |

### Electrolytes & Buffer

| Parameter | Formula | Source |
|-----------|---------|--------|
| Sodium need | `(Na_target − Na_actual) × BW × 0.2 / 1.71` ml NaCl 10% | Larsen, 2018 |
| Potassium need | `(K_target − K_actual) × BW × 0.2 / 1.0` ml KCl 7.45% | Larsen, 2018 |
| Calcium need | `(Ca_target − Ca_actual) × BW × 0.2 / 0.225` ml Ca.gluc. 10% | Larsen, 2018 |
| NaBic 8.4% | `BE × BW × 3 / (−10)` ml | Larsen, 2018 |
| TRIS 36.34% | `BE × BW / (−10)` ml | Larsen, 2018 |

### Tube Volumes

| Size | Factor (ml/cm) | Source |
|------|---------------|--------|
| 1/2" | × 1.2668 | Tschaut, 2020 |
| 3/8" | × 0.7126 | Tschaut, 2020 |
| 1/4" | × 0.3167 | Tschaut, 2020 |
| 3/16" | × 0.1781 | Tschaut, 2020 |

### Pediatric Blood Volume

| Age group | Factor | Source |
|-----------|--------|--------|
| Premature infants | 100 ml/kg | Hazinski, 2012 |
| < 3 months | 85 ml/kg | Hazinski, 2012 |
| ≥ 3 months | 75 ml/kg | Hazinski, 2012 |
| Male adolescents | 70 ml/kg | Hazinski, 2012 |
| Female adolescents | 65 ml/kg | Hazinski, 2012 |
| Transfusion volume | `BW × ΔHb × 3 / (HctEK × 0.01)` | Davies et al., 2007 |

### Severinghaus Blood Gas Temperature Correction

| Parameter | Formula | Source |
|-----------|---------|--------|
| PO₂ correction | `PO₂(T) = PO₂(37) × e^(fT × ΔT)` · `fT = 0.058 × (0.243 × (PO₂/100)^3.88 + 1)^−1 + 0.013` | Severinghaus, 1979, Eq. 3 |
| PCO₂ correction | `PCO₂(T) = PCO₂(37) × 10^(0.0185 × ΔT)` | Bradley, Stupfel & Severinghaus, 1956 |
| pH correction | `pH(T) = pH(37) − 0.0147 × ΔT` | Severinghaus & Bradley, 1956 |
| O₂ saturation (ODC) | `S = ((23400 × (PO₂³ + 150×PO₂)^−1) + 1)^−1` | Severinghaus, 1979, Eq. 1 |
| HCO₃⁻ | `0.0307 × PCO₂ × 10^(pH − 6.105)` | Severinghaus, 1966 |

### Charriere Converter

| Direction | Formula |
|-----------|---------|
| Ch → mm | `Ch / 3` |
| mm → Ch | `mm × 3` |

---

## 📚 References

| # | Reference |
|---|-----------|
| [1] | Du Bois D, Du Bois EF. A formula to estimate the approximate surface area if height and weight be known. *Arch Intern Med.* 1916;17(6):863–871. |
| [2] | Silbernagl S, Despopoulos A. *Taschenatlas Physiologie.* 9th ed. Stuttgart: Thieme; 2019. |
| [3] | Nadler SB, Hidalgo JU, Bloch T. Prediction of blood volume in normal human adults. *Surgery.* 1962;51(2):224–232. |
| [4] | de Somer F et al. O₂ delivery and CO₂ production during cardiopulmonary bypass as determinants of acute kidney injury. *Crit Care.* 2011;15(4):R192. doi:10.1186/cc10349 |
| [5] | Newland RF et al. Predictive Capacity of Oxygen Delivery During Cardiopulmonary Bypass on Acute Kidney Injury. *Ann Thorac Surg.* 2019;108(6). |
| [6] | Newland RF, Baker RA. Low Oxygen Delivery as a Predictor of Acute Kidney Injury during CPB. *J Extra Corpor Technol.* 2017;49(4):224–230. PMID:29302112 |
| [7] | Ranucci M et al. Oxygen delivery during cardiopulmonary bypass and acute renal failure after coronary operations. *Ann Thorac Surg.* 2005;80(6):2213–2220. |
| [8] | Ranucci M et al. Goal-directed perfusion and DO₂i threshold. *J Thorac Cardiovasc Surg.* 2018. |
| [9] | Hüfner G. Über das Gesetz der Dissociation des Oxyhämoglobins. *Arch Anat Physiol.* 1884. |
| [10] | Barratt-Boyes BG, Wood EH. Cardiac output and related measurements. *J Lab Clin Med.* 1958;51(1):72–90. |
| [11] | Skimming JW, Cassin S, Nichols WW. Calculating Vascular Resistances. *Clin Cardiol.* 1997;20(9):805–808. |
| [12] | Gorlin R, Gorlin SG. Hydraulic formula for calculation of cardiac valve areas. *Am Heart J.* 1951;41(1):1–29. |
| [13] | Hazinski MF. *Nursing Care of the Critically Ill Child.* 3rd ed. Elsevier; 2012. |
| [14] | Howie SR. Blood sample volumes in child health research: review of safe limits. *Bull WHO.* 2011;89(1):46–53. |
| [15] | Davies P et al. Calculating the required transfusion volume in children. *Transfusion.* 2007;47(1):212–216. |
| [16] | Darling E et al. Oxygenator choice guidelines in paediatric perfusion. *Proc AMSECT Annual Meeting.* 2000. |
| [17] | Tschaut RJ (ed.). *Extrakorporale Zirkulation in Theorie und Praxis.* Pabst Science Publishers; 2020. |
| [18] | Larsen R. *Anästhesie.* 11th ed. Urban & Fischer; 2018. |
| [19] | Finck C. General Guideline to VA/VV Cannulation. Clinical Guideline; 2020. |
| [20] | Severinghaus JW. Simple, accurate equations for human blood O₂ dissociation computations. *J Appl Physiol.* 1979;46(3):599–602. |
| [21] | Bradley AF, Stupfel M, Severinghaus JW. Effect of temperature on PCO₂ and PO₂ of blood in vitro. *J Appl Physiol.* 1956;9(2):201–204. |
| [22] | Severinghaus JW. Blood gas calculator. *J Appl Physiol.* 1966;21(3):1108–1116. |
| [23] | Ashwood ER, Kost G, Kenny M. Temperature correction of blood-gas and pH measurements. *Clin Chem.* 1983;29(11):1877–1885. |
| [24] | Wikipedia contributors. Coronary arteries. *Wikipedia, The Free Encyclopedia.* Images: Blausen Medical (CC BY 3.0) |

---

## 🚀 Installation

### 🌐 WebApp (no installation required)

Open directly in any browser — works on iPhone, Android, and desktop:

**[https://theperfusionist.github.io/perfusioncalc/](https://theperfusionist.github.io/perfusioncalc/)**

On iPhone/iPad: tap **Share → Add to Home Screen** to install as an app icon.

---

### 🤖 Android – APK

#### Build from source

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
├── main.dart                      # App entry, navigation, drawer, dialogs
├── models/
│   └── patient_data.dart          # All calculation formulas (single source of truth)
├── screens/
│   ├── bsa_screen.dart
│   ├── o2_delivery_screen.dart
│   ├── resistances_screen.dart
│   ├── electrolytes_screen.dart
│   ├── tube_volume_screen.dart
│   ├── flow_drainage_screen.dart
│   ├── zoll_chairre_screen.dart
│   ├── hypothermia_screen.dart    # Includes Severinghaus BGA correction
│   ├── pediatric_screen.dart
│   ├── reference_pressure_screen.dart
│   └── heart_anatomy_screen.dart
└── widgets/
    └── common.dart                # InputCard, ResultCard, SourceButton, AppSources
```

---

## 🛠️ Built With

- [Flutter](https://flutter.dev) ≥ 3.4.0 — cross-platform framework
- [shared_preferences](https://pub.dev/packages/shared_preferences) — persistent local storage
- [flutter_svg](https://pub.dev/packages/flutter_svg) — SVG rendering

---

## 📄 License

This project is licensed under the **GNU General Public License v3.0**.
See the [LICENSE](LICENSE) file for details.

---

<div align="center">

*Created with 🤖 AI assistance · For educational use only · Not for clinical use*

[![GitHub](https://img.shields.io/badge/GitHub-ThePerfusionist%2Fperfusioncalc-181717?style=flat-square&logo=github)](https://github.com/ThePerfusionist/perfusioncalc)

</div>
