# 🫀 PerfusionCalc

![Version](https://img.shields.io/badge/version-0.1.2-orange)
![Platform](https://img.shields.io/badge/platform-Android-green)
![License](https://img.shields.io/badge/license-GNU%20GPL%20v3.0-blue)
![Flutter](https://img.shields.io/badge/Flutter-%3E%3D3.0-blue)

> **⚠️ Disclaimer: Not for clinical use! Only for education and personal use. No guarantee of the results.**

A medical calculator app for perfusionists, built with Flutter.

---

## 🚀 Getting Started

### Prerequisites

| Tool | Version | Download |
|------|---------|----------|
| Flutter SDK | ≥ 3.0.0 | [flutter.dev](https://flutter.dev/docs/get-started/install) |
| Android Studio | latest | [developer.android.com/studio](https://developer.android.com/studio) |
| Java JDK | ≥ 17 (Temurin 17 recommended) | [adoptium.net](https://adoptium.net) |

### Build APK

```bash
# 1. Clone the repository
git clone https://github.com/your-username/perfusion_calc.git
cd perfusion_calc_new

# 2. Install dependencies
flutter pub get

# 3. Set Java version (if needed)
flutter config --jdk-dir "C:\Program Files\Eclipse Adoptium\jdk-17.x-hotspot"

# 4. Build release APK
flutter build apk --release
```

The APK will be at:
```
build/app/outputs/flutter-apk/app-release.apk
```

### Install on Android

1. Transfer the APK to your Android device
2. Enable **Install unknown apps** in Android settings
3. Open the APK file and install

---

## 📄 License

This project is licensed under the **GNU General Public License v3.0**.
See the [LICENSE](LICENSE) file for details.

---

*Created with 🤖 AI assistance*