# PerfusionCalc – Arbeitskontext

> Kompakter Projektstand als Arbeitsgedächtnis. **Zuerst lesen**, bevor
> Dateien durchsucht werden – erspart das erneute Ableiten von Struktur,
> Konventionen und Entscheidungen.
> Bei jeder Änderung mitpflegen.

**Stand:** v0.4.21+43 · 12 Tabs · **276 Unit-Tests** (12 Testdateien) · i18n vollständig EN+DE (durch Paritätstest abgesichert) · Kontakt: perfusioncalc@unbox.at

---

## 1. Arbeitsablauf (verbindlich)

| Regel | Grund |
|---|---|
| **Immer komplettes kumulatives ZIP** aller je geänderten Dateien liefern | Teil-Diffs haben früher `flutter analyze`-Fehler verursacht |
| **Kein Compiler im Container** – Flutter/Dart nicht installierbar (Netzwerk-Whitelist) | Ersatzprüfung: `check_balance.py` (Klammerbalance) + gezielte Greps |
| Nutzer führt `flutter analyze` / `flutter test` selbst aus | Ergebnisse kommen als Feedback zurück |
| Formeln **vor** dem Einbau numerisch in Python gegenrechnen | Klinische App – Rechenfehler sind sicherheitsrelevant |
| **Nur peer-reviewte Primärquellen**, keine Lehrbücher | Ausdrückliche Nutzervorgabe |
| Löschen kann ich nicht per ZIP → Nutzer explizit bitten | ZIP kann nur anlegen/überschreiben |

### Standard-Verifikation (nach jeder Änderung)
```bash
cd /home/claude/perfusioncalc
python3 /home/claude/check_balance.py $(find lib test -name "*.dart")   # Klammern
python3 /home/claude/check_symbols.py $(find lib test -name "*.dart")   # private Symbole
grep -o "AppLocale.en:" lib/i18n/app_strings.dart | wc -l   # muss == de sein
grep -c "'key': 'tab_" lib/main.dart                        # muss == TabController(length:)
```

> ⚠️ **Kein Feld anlegen, nur um Wegoptimieren zu verhindern.** Ein
> write-only-Feld löst `unused_field` aus. Stattdessen dem Objekt eine echte
> Verwendung geben (z. B. `Notification.onclick`) – das erfüllt beide Ziele.
>
> ⚠️ **CI ist strenger als die lokale Analyse.** `flutter analyze --no-fatal-warnings`
> lässt Warnungen durchgehen, bricht aber bei **info**-Lints ab (Exit 1) – und die
> CI nutzt eine neuere Flutter-Version (aktuell 3.44.8) als die lokale Installation.
> Lokal „No issues found" ist daher **keine** Garantie. Typischer Kandidat:
> `unnecessary_string_interpolations` bei `Text('${expr}')`, wenn `expr` schon
> ein String ist → Anführungszeichen weglassen.
>
> ⚠️ **Testzahl immer über ALLE Dateien zählen**, nicht nur `patient_data_test.dart`:
> `grep -chE "^\s*test\(" test/*.dart | paste -sd+ | bc`
> (Eine frühere Angabe war zu niedrig, weil nur eine Datei gezählt wurde.)
>
> ⚠️ **Bei jedem `python3`-Patch `assert <anchor> in s` setzen.** Ein
> Replacement ohne Assert ist stillschweigend fehlgeschlagen (Anker existierte
> nicht) – die Methode fehlte anschließend im File.
>
> ⚠️ **`check_symbols.py` ist Pflicht nach jedem Löschen von Codeblöcken.**
> Beim Entfernen von `_phaseBtn` per Index-Slice wurden versehentlich zwei
> benachbarte Methoden (`_noteRow`, `_doseChip`) mitgelöscht – die
> Klammerbalance blieb dabei intakt, der Fehler fiel erst beim
> `flutter analyze` des Nutzers auf.
> **Nie per Index-Slice löschen**, ohne den entfernten Bereich vorher
> auszugeben und zu prüfen; besser gezielt per `str_replace` auf den
> vollständigen Methodenrumpf.
Kreuzcheck eines Screens (Keys / Ranges / Felder / Quellen):
```bash
F=lib/screens/<screen>.dart
grep -oP "t\('[a-z0-9_]+'\)" $F | sort -u | sed "s/t('//;s/')//" | while read k; do grep -q "'$k':" lib/i18n/app_strings.dart || echo "KEY FEHLT: $k"; done
for r in $(grep -oP "Ranges\.\K\w+" $F | sort -u); do grep -q "static const $r " lib/models/ranges.dart || echo "RANGE FEHLT: $r"; done
grep -oP "(patientData|pd)\.\K\w+" $F | sort -u | while read f; do grep -q "\b$f\b" lib/models/patient_data.dart || echo "FELD FEHLT: $f"; done
```

### Paketierung
```bash
rm -rf /home/claude/out && mkdir -p /home/claude/out
cd /home/claude/perfusioncalc
git status --short | while IFS= read -r line; do
  st=$(echo "$line" | cut -c1-2); f=$(echo "$line" | cut -c4-)
  case "$st" in *D*) continue ;; esac
  if [ -d "$f" ]; then mkdir -p "/home/claude/out/$f"; cp -r "$f"/* "/home/claude/out/$f/" 2>/dev/null
  else mkdir -p "/home/claude/out/$(dirname "$f")"; cp "$f" "/home/claude/out/$f"; fi
done
cd /home/claude/out && zip -rq /mnt/user-data/outputs/perfusioncalc_COMPLETE.zip . -x "*.git/*"
```

> ⚠️ **NIE `-x ".*"` verwenden.** Das schließt `.github/` mit aus – dadurch
> fehlten die Workflow-Dateien in jedem gelieferten Paket, ohne dass es
> auffiel. Nur `*.git/*` ausschließen.
>
> ⚠️ **Immer den ZIP-Inhalt prüfen, nicht den Quellordner:**
> `unzip -l <zip> | grep -i workflow`

---

## 2. Architektur

```
lib/
  main.dart              MainScreen, _kTabs, TabController, Drawer,
                         Theme-/Sprachumschalter, _exportCombinedReport()
  models/
    patient_data.dart    Zentrale Fall-Daten + ALLE Rechenformeln (Getter)
    bga_model.dart       Severinghaus-Temperaturkorrektur (eigenes Modell)
    ranges.dart          Plausibilitätsbereiche (nur UI-Warnung, kein Abbruch)
  i18n/app_strings.dart  EN/DE-Maps + t()-Helper + LocaleNotifier
  theme/app_theme.dart   ThemeNotifier (System/Hell/Dunkel) + buildAppTheme()
  widgets/common.dart    InputCard, ResultCard, SectionHeader, DataTable2,
                         PdfExportButton, SourceButton, AppSources, Farb-Tokens
  utils/pdf_export.dart  PdfSection/PdfRow, exportTabAsPdf, exportCombinedReportAsPdf
  screens/*.dart         Ein Screen pro Tab
test/                    patient_data_test, bga_model_test, ranges_test, i18n_test
```

### Zustandshaltung
- `PatientData` + `BgaModel` leben in `MainScreen`, werden an Screens durchgereicht.
  → Deshalb kann `_exportCombinedReport()` direkt darauf zugreifen.
- Screens rufen lokal `setState`, Parent-Callback ist `_noop` (globaler Rebuild
  war die Ursache für ruckelndes Tippen).
- Timer-/Zeitstempel-Zustand gehört ebenfalls in `PatientData` (überlebt Tab-Wechsel).

### Kritische Fallstricke
- **`TabController(length:)` == Anzahl `_kTabs` == Anzahl `TabBarView`-Children.**
  Bei jeder Tab-Änderung alle drei anpassen → sonst Laufzeit-Crash.
- **Kein `const`** auf Widgets, die `t()` aufrufen → sonst kein Sprachwechsel.
- Farb-Tokens in `common.dart` sind **Getter** (theme-abhängig), keine `const`.
  → `const Color(...)` in Default-Parametern nicht möglich; `Color?` + `?? kText`.
- `debugPrint` statt `print` (Lint `avoid_print`).
- Dart-SDK `>=3.4.0`: Records/Pattern-Matching ok, aber `.indexed` vorsichtig nutzen.

---

## 3. Tabs (Reihenfolge in `_kTabs`)

1. BSA/CO/Hb/Hct · 2. O₂-Delivery · 3. Hypothermie/BGA · 4. **Kardioplegie**
5. Elektrolyte/Puffer · 6. Ultrafiltration · 7. Widerstände · 8. Pädiatrie
9. Schlauchvolumen & Flussrate · 10. Zoll/Charrière · 11. Referenzdrücke · 12. Herzanatomie

**Gesamtbericht** (`_exportCombinedReport`): enthält die patientenbezogenen Tabs;
Filter = „mindestens eine Zeile ≠ `—`".
⚠️ Deshalb dürfen PDF-Zeilen **nicht bedingungslos aus Defaults** gerendert werden
(sonst gilt der Tab immer als ausgefüllt) → siehe `_hasCalafioreInput()`-Muster.

`flow_drainage_screen.dart` wurde in `tube_volume_screen.dart` integriert und
vom Nutzer gelöscht.

---

## 4. Kardioplegie-Tab (aktuellster Arbeitsschwerpunkt)

Protokoll-Auswahl über `_kVisibleProtocols` in `cardioplegia_screen.dart`.
**Sichtbar: Calafiore, Bretschneider, del Nido.** Nur Buckberg ist ausgeblendet,
Code/Tests/Formeln bleiben erhalten → Reaktivierung = Eintrag in
`_kVisibleProtocols` zurückschreiben.

### Calafiore (druckgesteuert, warme Blutkardioplegie)
Vollblut als Träger, K⁺(+Mg²⁺) kontinuierlich per Perfusor zutitriert.
Da druckgesteuert (90–100 mmHg) statt flussgesteuert, schwankt der Fluss →
Perfusorrate muss dem **aktuellen Fluss** folgen, damit die Konzentration konstant bleibt.

```
Perfusorrate [ml/h] = (Ziel-K⁺ − Serum-K⁺) × Fluss[ml/min] × 60 / (1000 × [K⁺]Spritze[mmol/ml])
```
Verifiziert gegen das institutionelle Excel (Serum 5,0 → Ziel 10, 200 ml/min,
2 mmol/ml ⇒ **30,0 ml/h**, exakt).

Dosisabhängige Zielwerte (intermittierend, alle 15–20 min):

| Gabe | Ziel-K⁺ | Mg²⁺-Bolus (separat am Ende) |
|---|---|---|
| 1 | 20 mmol/l | 1 g |
| 2 | 12 | 100 mg (Hinweis: bei Bedarf 500 mg) |
| 3 | 12 | 100 mg |
| 4–6 | 12 (alt. 10 / 8) | 500 / 100 / 100 mg |

Spritze: KCl-Gesamtvolumen + Konz. (14,9 % = 2 mmol/ml), **Mg optional**
(500 mg/ml MgSO₄·7H₂O = 20 mmol/10 ml ≈ 2,0 mmol/ml ≈ 50 % w/v).
Institutionell 40 ml KCl + 10 ml Mg ⇒ 1,6 mmol/ml K⁺, 0,4 mmol/ml Mg²⁺.
Konzentrationsfelder haben integrierten mmol/ml ⇄ %-Umschalter
(`InputCard.unitOptions`; Molmassen KCl 74,55 / MgSO₄·7H₂O 246,47).

### Bretschneider (HTK/Custodiol)
Einmalgabe, intrazellulär-kristalloid. Nur ein Rechner: `Volumen = Fluss × Zeit`.
Hinweise: 5–8 °C · Perfusionsdruck initial 100–110 mmHg, nach Herzstillstand
40–50 mmHg · Perfusionsdauer 6–8 min (Nachperfusion 2–3 min) · Organprotektion
bis zu 180 min.
*(Herzgewichts-/Zielvolumen-Rechner und Phasen-Umschalter wurden auf
Nutzerwunsch wieder entfernt.)*

### del Nido (Mischung + Gabezeit)
Followerprinzip: Kristalloidpumpe 100 %, Blutpumpe 25 % ⇒ mechanisch 4:1.
`Blut = Kristalloid/4` · `Gesamt = Kristalloid×1,25` · `Blutfluss = Fluss×0,25`
`Gesamtfluss = Fluss×1,25` · `Zeit = Kristalloid/Fluss` (= Gesamt/Gesamtfluss).
Die alte gewichtsbasierte Dosis (20 ml/kg, Deckelung 1000 ml) liegt weiterhin
im Modell + Tests, wird aber nicht angezeigt.

**Mischungsverhältnis** ist eine *persistierte institutionelle Einstellung*
(`models/cardioplegia_settings.dart`), kein Falldatum. Eingabe als
Kristalloid-Anteil in % (50–95, Default 80 = 4:1); Blutanteil, Verhältnis und
Follower-% sind abgeleitet und werden read-only gezeigt.
Die del-Nido-Formeln in `PatientData` sind deshalb **Methoden mit Anteil-Parameter**
statt Getter – so bleibt `PatientData` frei von Singleton-Abhängigkeiten und
testbar. Bei 80 % ergeben sich exakt die alten 4:1-Zahlen (Rückwärtskompatibilität
per Test abgesichert).
`delNidoTotalPerKg(share)` = Gesamtvolumen / `cardioplegiaWeight` → Gegenprobe zur
Protokolldosis (~20 ml/kg, max. 1000 ml).

`delNidoRecommendedTotal` = Gewicht × 20 ml/kg, **bewusst ungedeckelt** (zeigt den
hypothetischen Bedarf); `delNidoRecommendedExceedsMax` signalisiert nur, dass die
Protokollgrenze von 1000 ml Einzeldosis überschritten ist.

### Intervall-Timer
⚠️ **Chrome für Android wirft bei `new Notification()`** ("Illegal
constructor") – dort ist `ServiceWorkerRegistration.showNotification()` Pflicht.
Reihenfolge: **Konstruktor zuerst** (Desktop, kostenlos), Service Worker als
Fallback mit 2-s-Timeout (sonst hängt `ready` ewig, wenn keiner registriert ist).
Umgekehrte Reihenfolge kostet auf Desktop unnötig Wartezeit.
**In-App-Banner** (`widgets/in_app_alert.dart`, OverlayEntry – bewusst kein
Dialog, der die Rechner blockieren würde) schließt per **Tippen, Wischen
(`Dismissible`, horizontal) oder X**; `dismiss()` ist idempotent, damit der
30-s-Auto-Ausblender und eine parallele Nutzergeste kollisionsfrei sind. Der
`Dismissible`-Key liegt im State (nicht vom Widget abgeleitet), sonst wäre er
bei jedem Rebuild neu wird **zusätzlich** zur System-
Benachrichtigung gezeigt, plattformübergreifend. Grund: System-Meldungen
können lautlos unterdrückt werden, ohne dass ein Fehler zurückkommt – genau
das trat im Test auf (Windows-Einstellung). Auto-Ausblendung nach 30 s.
⚠️ **Firefox unter Windows reicht Benachrichtigungen an das Betriebssystem
durch** – sind sie dort für Firefox deaktiviert oder ist „Fokusassistent" aktiv,
erscheint nichts, ohne dass die Web-API einen Fehler meldet.
⚠️ **Ergebnis des Konstruktors in einer Variablen halten** – sonst kann dart2js
den Aufruf im Release-Build als toten Code entfernen.
**Web-Benachrichtigungen** über `utils/web_notifications_{stub,web}.dart`
(bedingter Import wie bei `pdf_download_*`). Browser können **nicht vorplanen**
→ der 1-s-Ticker löst am Triggerpunkt selbst aus (`showNow()`), Tab muss offen
bleiben. Auf Android bleibt es bei der geplanten OS-Notification.
Offline-Paket für Windows: wird in **`release.yml`** gebaut und ans Release
gehängt (neben APK/AAB). `offline-bundle.yml` ist nur noch **manuell** und
erzeugt ausschließlich ein Artefakt.
⚠️ **Nur ein Workflow darf `action-gh-release` nutzen** – zwei Workflows am
selben Tag sind ein Wettlauf, dabei ging das Offline-Paket verloren.
Inhalt: Web-Build + portabler Server (Caddy, Apache-2.0) + PowerShell-Fallback
+ `start.bat` aus `tool/offline/`. Für Offline zwingend:
`--no-web-resources-cdn` (sonst wird CanvasKit vom CDN geladen).
`--base-href /` ist bereits der Stand in `deploy.yml` (CNAME perfusioncalc.de),
die frühere Angabe `/perfusioncalc/` ist überholt.
Alarm-Einstellungen sind **standardmäßig eingeklappt** (Kopfzeile mit Ein/Aus-Switch
+ Kurzfassung „15 min · Ton · Vibration"). Fehler-/Berechtigungshinweise bleiben
auch eingeklappt sichtbar, weil sie Handlung erfordern. Triggerzeit über
Stepper + Presets statt Slider (Platz).
Manuelle Stoppuhr, Zeitstempel in `PatientData.cardioplegiaLastDoseAt`.
Statuslogik ist **pure Funktion** `PatientData.cardioplegiaDoseStatus(elapsed, dueAfterMin, overdueAfterMin)`
→ deterministisch testbar. Schwellen: Calafiore 15/20 min, Bretschneider 150/180 min.
1-s-Ticker nur aktiv, wenn Zeitstempel gesetzt; in `dispose()` gecancelt.

**Alarm** (`models/cardioplegia_alarm_settings.dart`, Muster wie ThemeNotifier,
in `main()` geladen): Ein/Aus, freie Triggerzeit (1–240 min), Ton, Vibration,
Wiederholung – alles in SharedPreferences persistiert.
Auslösung über die pure Funktion `expectedFireCount(elapsed, enabled,
triggerMinutes, repeat)`, verglichen mit einem Zähler `_alarmsFired` → ein
verpasster Tick holt nach statt zu überspringen.
**Benachrichtigung** (`utils/notification_service.dart`): geplante OS-Notification
via `flutter_local_notifications` + `timezone`, dadurch auch aus dem Hintergrund
und bei ausgeschaltetem Bildschirm. Kanal `Importance.max`, `fullScreenIntent`,
`AndroidScheduleMode.exactAllowWhileIdle`.
Geplant wird beim Erfassen der Gabe (nicht beim Ablauf!) – deshalb `_rescheduleReminder()`
bei jeder Änderung von Zeitstempel *oder* Einstellungen aufrufen.
⚠️ **`SystemSound.play()` ist auf Android wirkungslos** – war die Ursache, dass der
frühere In-App-Alarm auf einem Samsung S23+ stumm blieb. Nicht wieder verwenden.
Vordergrund gibt es nur noch `HapticFeedback` als Ergänzung.
**Lautstärke** weiterhin keine App-Einstellung: folgt dem Benachrichtigungskanal.
Plattform-Konfiguration liegt in `AndroidManifest.xml` (6 Permissions + 2 Receiver)
und `android/app/build.gradle.kts` (core library desugaring).
`zonedSchedule()` braucht in **flutter_local_notifications 18.x** zusätzlich den
Pflichtparameter `uiLocalNotificationDateInterpretation` (in neueren Majors entfernt)
– beim Anheben der Plugin-Version prüfen.

**flutter_local_notifications 22.x** (Upgrade von 18.0.1 am 01.08.2026).
Breaking Changes, die den Code betrafen:
- **v19**: `uiLocalNotificationDateInterpretation` aus `zonedSchedule()` entfernt;
  `timezone` min. 0.10.0; GSON 2.12 → ProGuard-Regeln laut Plugin nicht mehr nötig
  (wir behalten sie defensiv).
- **v20**: **alle positionalen Parameter → benannte Parameter** bei `initialize()`,
  `show()`, `cancel()`, `zonedSchedule()`. Konkret:
  `initialize(settings:)`, `show(id:, title:, body:, notificationDetails:)`,
  `cancel(id:)`, `zonedSchedule(id:, title:, body:, scheduledDate:,
  notificationDetails:, androidScheduleMode:)`. Java 17 Pflicht.
- **v21**: Dart ≥3.10.0 / Flutter ≥3.38.1, Android min. API 24, compileSdk 36,
  AGP 8.11.1. **`timezone` auf ^0.11.0** – der Changelog sagt hier nur „bumped
  timezone dependency" ohne Zahl; die 0.10.0 aus dem v19-Eintrag ist überholt.
  ⚠️ Bei Upgrades die transitive Anforderung nicht aus älteren Changelog-Einträgen
  ableiten, sondern `flutter pub get` entscheiden lassen – der Fehler nennt die
  exakte Version.
- **v22**: **natives Web-Support im Plugin.** Unser eigener Wrapper
  (`web_notifications_*.dart`) läuft weiter, weil alle `kIsWeb`-Guards *vor* den
  Plugin-Aufrufen greifen. Mittelfristig könnte der Wrapper durch die
  Plugin-eigene Web-Implementierung ersetzt werden – dann käme auch `cancel()`
  auf Web zum Tragen.
⚠️ Signaturen bei künftigen Upgrades **aus dem Quellcode verifizieren**, nicht
raten: `raw.githubusercontent.com/MaikuB/flutter_local_notifications/master/
flutter_local_notifications/lib/src/flutter_local_notifications_plugin.dart`
(pub.dev ist nicht in der Netzwerk-Whitelist, GitHub schon).

⚠️ **Absturz-Fallen bei Android-Notifications** (beide bereits ausgeräumt):
1. **Small Icon muss monochrom sein.** `@mipmap/ic_launcher` (adaptives Icon) als
   Small Icon führt zu `Bad notification posted … Couldn't create icon` – und zwar
   nur bei *geplanten* Benachrichtigungen (Zustellung aus dem BroadcastReceiver),
   während die Sofort-Benachrichtigung funktioniert. Deshalb eigenes
   `res/drawable/ic_notification.xml` (weißer Vektor).
2. **`fullScreenIntent: true` nicht ohne `USE_FULL_SCREEN_INTENT`.** Startet beim
   Auslösen eine Activity; ab Android 14 rechtebeschränkt. Im Vordergrund wird der
   Pfad unterdrückt → Test läuft, geplante Zustellung stürzt ab. Entfernt;
   `Importance.max` + `category: alarm` reichen für Heads-up mit Ton/Vibration.
3. **Exakte Alarme** können verweigert werden → `PlatformException`. Es gibt jetzt
   einen Fallback auf `inexactAllowWhileIdle` statt eines verlorenen Reminders.
4. **Icon-Name OHNE `@drawable/`-Präfix** an `AndroidInitializationSettings`.
   Das Plugin löst über `Resources.getIdentifier(name, "drawable", pkg)` auf; mit
   Präfix schlägt der Lookup fehl, `initialize()` wirft, und danach sind **alle**
   Methoden stille No-Ops → Button reagiert nicht, keine Benachrichtigung, kein
   Hinweis. Deshalb gibt es jetzt `lastError`, `ensureReady()` (Selbstheilung) und
   eine eigene UI-Meldung für „Dienst nicht gestartet" vs. „Recht fehlt".
   **Regel:** Fehler in Plattformdiensten nie still schlucken – sonst ist ein
   Ausfall von einer verweigerten Berechtigung nicht unterscheidbar.
5. **R8/ProGuard bricht geplante Benachrichtigungen im Release-Build.**
   Absturz beim Auslösen mit
   `RuntimeException: Missing type parameter` in
   `ScheduledNotificationReceiver.onReceive`. Ursache: Das Plugin legt die
   Notification-Details als JSON ab und liest sie im Receiver per Gson-`TypeToken`
   – R8 verwirft die dafür nötigen generischen Signaturen.
   Fix: `android/app/proguard-rules.pro` (v. a. `-keepattributes Signature` +
   `-keep class com.dexterous.** { *; }`), eingebunden über `proguardFiles(...)`
   im `release`-Block von `build.gradle.kts`.
   **Diagnostisch wichtig:** Sofort-Benachrichtigung funktioniert, *geplante*
   stürzt ab → immer zuerst an R8/Serialisierung denken, nicht an Kanal/Icon.
   Verkürzte Klassennamen (`q0.a`) im Stacktrace sind das Erkennungszeichen.
6. **Icon-Name wird von `initialize()` VALIDIERT** – ist er nicht über
   `getIdentifier` auflösbar, wirft die Methode und der komplette Dienst bleibt
   tot. Deshalb jetzt eine Kandidatenliste mit Fallback auf `@mipmap/ic_launcher`
   statt eines einzelnen Namens.
7. **Build-Nummer bei JEDEM Testbuild erhöhen** (`+N` in `pubspec.yaml`).
   v29–v32 trugen alle `0.3.2+9`; dadurch war aus einem Gerätedump nicht
   feststellbar, welcher Stand installiert war – das hat eine Debugging-Runde
   gekostet.
**Windows-Build:** Plugins brauchen Symlink-Support → Entwicklermodus aktivieren
(`start ms-settings:developers`), sonst schlägt der Build fehl.

### Applikationsdruck (protokollübergreifend, Key `cardio_pressure_limits`)
Antegrad max. 70–100 mmHg, retrograd max. 50–70 mmHg.
Bei Bretschneider wird stattdessen der protokollspezifische Druck gezeigt.

---

## 5. Formeln & Quellen (Kurzreferenz)

| Bereich | Formel/Wert | Primärquelle |
|---|---|---|
| BSA | DuBois 1916 | DuBois & DuBois, Arch Intern Med 1916 |
| CI-Default 2,4 | – | Kunst et al., EACTS/EACTAIC/EBCP, Br J Anaesth 2025 |
| DO₂i-Schwelle **272** ml/min/m² | Warnung in `ResultCard.warnBelow` | Ranucci et al., Ann Thorac Surg 2005;80:2213 |
| Blutvolumen | 0,041×kg+1,53 (♂) / 0,047×kg+0,86 (♀) | Silbernagl/Despopoulos (+ Nadler 1962 als Quercheck) |
| BGA-Temperaturkorrektur | PaO₂ f_T, PCO₂ 0,0185, **pH 0,0147** | Severinghaus 1958/1979; pH-Konstante = **Rosenthal 1948** (nicht Bradley!) |
| O₂-Dissoziation | S = ((PO₂³+150·PO₂)⁻¹×23400+1)⁻¹, P50 Eq.1 = 26,86 | Severinghaus, J Appl Physiol 1979 |
| Ultrafiltration | Hct₁×V₁ = Hct₂×V₂ (auch mit Hb) | Klineberg et al., Anesthesiology 1984;60:478 · Hensley et al., Perfusion 2024 |
| Kardioplegie Buckberg | 4:1 Blut:Kristalloid, 15–20 min | Buckberg, J Thorac Cardiovasc Surg 1987;93:127 |
| Kardioplegie del Nido | 4:1 Kristalloid:Blut, max. 1000 ml | Matte & del Nido, J Extra Corpor Technol 2012;44:98 |
| Kardioplegie Calafiore | s. o. | Calafiore et al., Ann Thorac Surg 1995;59:398 · Calafiore et al., Thorac Cardiovasc Surg 2020;68:232 |
| Bretschneider | s. o. | Bretschneider, Thorac Cardiovasc Surg 1980;28:295 · Bretschneider et al., J Cardiovasc Surg 1975;16:241 · Gebhard et al., Thorac Cardiovasc Surg 1984;32:271 |

---

## 6. Offene Punkte / Ideen

- **Play-Store-Release**: Internal-Test-Track (20 Tester / 14 Tage), Paketname
  `com.perfusioncalc`, `versionCode` muss strikt steigen. Datenschutz-URL für
  die Console: `https://perfusioncalc.de/privacy.html` (erreichbar seit
  v0.4.1). **Ausfüllhilfe für das Data-Safety-Formular: `docs/PLAY_DATA_SAFETY.md`**
  — Feld für Feld, mit Code-Beleg je Antwort und einer Konsistenztabelle
  gegen die Datenschutzerklärung. Kernantwort: keine Datenerhebung, weil der
  Release-Build keine `INTERNET`-Berechtigung deklariert.
- St.-Thomas- und Eppendorf-Protokoll (in den Studienunterlagen ausgearbeitet).
- Perfusionsprotokoll mit Zeitstempeln (Bypass-/Klemmzeit, Temperaturverlauf).
- Heparin/Protamin + ACT-Rechner.
- Natives Share-Sheet (`share_plus`) – PDF kann aktuell nur gespeichert werden.
- Versionsnummer wird auf Zuruf angehoben (3 Stellen: `pubspec.yaml`,
  `kAppVersion` in `main.dart`, README-Badge). Alles andere leitet ab:
  Android über `flutter.versionName/versionCode`, iOS/macOS über
  `$(FLUTTER_BUILD_NAME)`, Windows/Linux über CMake, die PDF-Fußzeile über
  `kAppVersion`, der Bundle-Dateiname über `grep '^version:' pubspec.yaml`.
  `sw.js` trägt bewusst die Commit-SHA statt der App-Version.

---

## 7. Audit v0.3.3 / v0.4.0 — Abarbeitung, Entscheidungen, Lehren

Zwei Audits, zu 47 deduplizierten Befunden und fünf Blöcken zusammengefasst,
abgearbeitet zwischen v0.4.1 und v0.4.7 (01.08.2026). Dieser Abschnitt ist als
**Ausgangspunkt für das nächste Audit** geschrieben: er hält fest, was geändert
wurde, warum es so und nicht anders entschieden wurde, was bewusst offen
blieb — und welche Fehler die Abarbeitung selbst produziert hat.

### 7.1 Blockschnitt

Der Schnitt folgte nicht der Priorität der Befunde, sondern der
**Verifizierbarkeit**: Blöcke A–C ändern keine Datei, die kompiliert wird
(YAML, Manifest, Gradle, `sw.js`, HTML, Markdown), D und E sind fast
ausschließlich Dart. Das war entscheidend, weil die Umsetzung in einer
Umgebung ohne Dart/Flutter-Toolchain stattfand.

| Block | Inhalt | Ergebnis |
|---|---|---|
| **A** | Release-Blocker: `USE_EXACT_ALARM`, Datenschutzerklärung, `allowBackup`, `minSdk` | erledigt (v0.4.1) |
| **B** | Supply Chain / CI: Action-SHA-Pins, Flutter-Pin, Gradle-SHA, Caddy-Pin, Expression Injection, `flutter test \|\| echo` | erledigt (v0.4.1) |
| **C** | Web / Service Worker: `notificationclick`, Cache an Build-SHA, CSP | erledigt (v0.4.1), **drei Folgefehler** → 7.4 |
| **D** | Klinische Rechenpfade | erledigt (v0.4.2), außer Nadler → 7.5 |
| **E** | Dart-Fehler, tote Pfade, Hygiene, Tests | erledigt (v0.4.2) |

### 7.2 Verifikationsprotokoll

| Stufe | Inhalt | Ergebnis |
|---|---|---|
| 1 | `pub get`, `analyze`, `test` | grün — drei Erstbefunde behoben (falsche Testerwartung, `unnecessary_non_null_assertion`, `unawaited_futures`) |
| 2 | verschärfter Analyzer | `No issues found!` — `strict-casts` und `use_build_context_synchronously` ohne Treffer |
| 3 | klinische Rechenwege am Gerät | verifiziert |
| 4 | EK-Hämatokrit | aus der Entscheidung wurde ein persistiertes Eingabefeld (v0.4.4) |
| 5 | Benachrichtigungen, Release-Build Android | verifiziert — feuert im Hintergrund, kein Absturz, Tap öffnet die App |
| 6 | Web / Service Worker | verifiziert nach v0.4.6 (22 Requests, **0 B transferred**) und erneut nach v0.4.15 — siehe 7.19 |
| 7 | CI | verifiziert am Release-Lauf v0.4.7 und am ersten `checks.yml`-Lauf v0.4.15 — siehe 7.19. Offen bleibt nur der Release-Pfad der aktuellen Version. |

**Was Stufe 5 nebenbei beantwortet hat:** Die ProGuard-`-keep`-Regeln greifen
weiterhin, und der Wegfall von `USE_EXACT_ALARM` hat die Funktion nicht
beschädigt — `SCHEDULE_EXACT_ALARM` allein trägt sie.

### 7.3 Entscheidungen, die kein Befund war

Diese Punkte sind bewusst so und nicht anders entschieden. Wer sie ändert,
sollte den Grund kennen.

**Block A**
- `USE_EXACT_ALARM` entfernt: Play-Restricted-Permission, nur für Apps mit
  Alarm-/Timer-/Kalender-Kernfunktion. `SCHEDULE_EXACT_ALARM` deckt dieselbe
  Funktion ab, der `PlatformException`-Fallback auf `inexactAllowWhileIdle`
  existierte bereits. Kein Dart-Code geändert.
- `allowBackup="false"` **plus** `data_extraction_rules.xml`: Die
  Geräte-zu-Gerät-Übertragung wird von `allowBackup` *nicht* mitabgeschaltet.
- `minSdk = maxOf(24, flutter.minSdkVersion)` statt fester 24 — bleibt
  korrekt, egal wohin sich Flutters Default bewegt.
- Datenschutzerklärung doppelt gepflegt: `privacy_policy.md` und
  `web/privacy.html`. **Beide Dateien und das Data-Safety-Formular müssen
  zusammen geändert werden.** Anschrift auf ausdrücklichen Wunsch des
  Verantwortlichen nicht veröffentlicht (Art. 13 Abs. 1 lit. a DSGVO verlangt
  sie formal); stattdessen der Hinweis, dass sie auf Anfrage mitgeteilt wird.

**Block B**
- Actions auf volle Commit-SHAs gepinnt, **innerhalb der bisherigen Major**
  (`checkout` v6.1.0, nicht v7). Pinnen und Major-Sprung gehören nicht in
  denselben Commit.
- `FLUTTER_VERSION` als workflow-weite Variable in allen drei Workflows.
  **Muss mit `flutter --version` auf den Entwicklungsmaschinen übereinstimmen**
  — sonst testet man gegen eine andere Toolchain, als die CI baut.
- Caddy mit **SHA-512** gepinnt (nicht SHA-256): Der Hersteller veröffentlicht
  in `caddy_<version>_checksums.txt` SHA-512, damit ist der Wert direkt
  gegenprüfbar. Version, SHA-256 und SHA-512 stehen in `OFFLINE_WINDOWS.md`,
  damit Klinik-IT eine unbekannte `.exe` freigeben kann.
- Kein stilles Debug-Signing mehr: fehlt `KEYSTORE_BASE64`, bricht der Job ab,
  bevor gebaut wird. Ein debug-signiertes APK unter dem Release-Namen sieht
  echt aus, lässt sich sideloaden und ist nie wieder durch ein korrekt
  signiertes Update ersetzbar.
- `commit_message` im gh-pages-Deploy nur noch die SHA — `head_commit.message`
  war nicht vertrauenswürdiger Input in einer Action-Eingabe.

**Block C**
- `notificationclick`-Handler in `sw.js`: Beim Service-Worker-Zustellweg wird
  der Klick an den Worker zugestellt, nicht an die Seite — `onclick` im
  Dart-Code kann dort strukturell nicht greifen. **Kopplung in beiden Dateien
  kommentiert**, damit nicht eine Seite ohne die andere entfernt wird.
- Cache-Name an die Commit-SHA gekoppelt, Ersetzung im CI mit `grep`
  verifiziert. **Der Platzhalter-String darf nicht geändert werden, ohne das
  `sed`-Muster in allen drei Workflows mit anzupassen.**

**Block D**
- **1.4 Transfusionsvolumen war kein Fehler.** Davies 2007 lautet
  `Gewicht × ΔHb × 3 / Hkt(EK)`, mit dem Hkt als **Bruch** im Nenner; der
  Faktor 3 enthält ihn *nicht* bereits. Davies' eigenes Beispiel
  (20 kg × 2 g/dl × 3 / 0,6 = 200 ml = 10 ml/kg) reproduziert die Formel
  exakt. Die Auditbegründung „Doppelkorrektur" war falsch. Der Divisor ist
  seit v0.4.4 eine persistierte Einstellung → 7.6.
- `expectedHb` → `expectedHbMale`/`expectedHbFemale`, exakte Verdünnung gegen
  das eigene Blutvolumenmodell. Der alte Wert war systematisch +0,71 g/dl zu
  optimistisch (11,38 statt 10,67 bei 80 kg / Hb 14 / 1500 ml).
- `cavDO2` beidseitig abgesichert — damit fallen VO₂, VO₂i und O₂-ER auf
  „nicht berechnet" zurück, sobald der venöse Satz unvollständig ist,
  **Bildschirm und PDF**. Das war der Weg, auf dem „O₂-ER 100 %" ins
  ausgelieferte Dokument kam.
- `PdfRow.numeric` bekam `zeroIsValid` statt die 0-Regel global zu streichen:
  Ein echter Nullwert wird nur dort gedruckt, wo 0 eine Messung ist (BE, ZVD,
  LAP). Der „nur gefüllte Tabs"-Filter des Gesamtberichts bleibt so
  funktionsfähig.

**Block E**
- `Range.note` → `Range.noteKey`, alle 40 Hinweise über i18n.
- `MainScreen.kTabs` als Record-Typ, `@visibleForTesting`; `TabController`
  leitet seine Länge daraus ab.
- **ProGuard bewusst NICHT entschlackt.** Die beiden `-keep class`-Zeilen
  kosten APK-Größe, aber ihr Wegfall zeigt sich erst im Release-Build und der
  Fehlerfall ist ein Absturz beim Feuern einer klinischen Erinnerung. Der
  konkrete Test dafür steht in `proguard-rules.pro`.
- `analysis_options.yaml` verschärft (`strict-casts`, `avoid_dynamic_calls`,
  `unawaited_futures`, `use_build_context_synchronously`,
  `always_declare_return_types`, `prefer_final_locals`).
  `strict-raw-types` bewusst nicht — feuert auf Fremdbibliotheks-Signaturen.
- Schließen-Button nur noch auf Android: `SystemNavigator.pop()` ist im Web
  wirkungslos und auf iOS ein Ablehnungsgrund.

### 7.4 Regressionen aus der Abarbeitung selbst

Vier Fehler wurden **durch** die Auditumsetzung eingeführt. Sie sind hier
vollständig dokumentiert, weil sie zusammen ein Muster ergeben (→ 7.7).

**v0.4.3 — Web-Version ohne Text.** Befund 2.6 hielt `gstatic.com` in der CSP
für ungenutzt, weil die Builds mit `--no-web-resources-cdn` laufen. Das Flag
holt aber nur `canvaskit.js`/`.wasm` lokal, **nicht die Schrift**. CanvasKit
lud Roboto von `fonts.gstatic.com`; die verschärfte CSP sperrte den Abruf, und
ohne Schrift rendert Flutter Web gar keinen Text. Material-Icons blieben
sichtbar (gebündeltes Asset) — dadurch sah es wie ein Layout-, nicht wie ein
Schriftproblem aus.
*Behebung:* `font-src`/`connect-src` erlauben `fonts.gstatic.com` wieder,
**und** Roboto ist als `fonts:`-Familie gebündelt (`fontFamily: 'Roboto'` in
`buildAppTheme`). Die Schrift hing vorher an einem Google-Abruf — betroffen
wären auch die Offline-Distribution, gesperrte Klinik-Netze und die Aussage
der Datenschutzerklärung gewesen.

**v0.4.5 — zwei Service Worker um denselben Scope.** Alle drei Builds liefen
mit `--pwa-strategy offline-first`; Flutter erzeugt dabei ein eigenes
`flutter_service_worker.js`, das `flutter_bootstrap.js` registriert — im
selben Scope `/` wie `web/sw.js`. **Ein Service Worker wird pro Scope
registriert, nicht pro Dateiname**; die spätere Registrierung ersetzt die
frühere. Online unsichtbar, offline tödlich: der verdrängte Worker löste
seine offenen `respondWith`-Promises nie auf.
Der Kommentar in `index.html` behauptete das Gegenteil („anderer
Name/Scope, stört sich nicht daran") — eine falsche Annahme, schriftlich
festgehalten und dadurch nie wieder hinterfragt.
*Behebung:* `--pwa-strategy=none` in allen drei Builds; `index.html` löst vor
der eigenen Registrierung eine vorhandene Registrierung von
`flutter_service_worker.js` (einmalige Migration).

**v0.4.6 — Precache unvollständig.** Folge der eigenen Cache-Invalidierung aus
Block C: neuer Cache-Name pro Deploy → `install()` füllt nur `APP_SHELL` →
`activate()` löscht den alten Cache samt `main.dart.js` → der laufende Tab
fragt sie nicht erneut an → offline weiß. **Runtime-Caching füllt einen
frischen Cache nur mit dem, was nach der Übernahme noch einmal angefragt
wird.** Solange der Cache-Name konstant war, fiel das nicht auf.
*Behebung:* `sw.js` trennt `CORE_SHELL` (statisch, mit `?v=9`) von
`BUILD_ASSETS` (Platzhalter). Der CI-Schritt erzeugt die Liste aus dem
tatsächlichen Inhalt von `build/web` — mit Abbruch, wenn kein
`main.dart.*`/`flutter_bootstrap.js` gefunden wird oder die Ersetzung nicht
greift.

**v0.4.7 — Precache zu groß.** Der Generator schloss `.map` aus, aber nicht
`.symbols` (Symboltabellen neben jeder CanvasKit-Variante, zur Laufzeit nie
geladen) und nicht `canvaskit/experimental_webparagraph/`.
*Gemessen:* 45,5 MB → **33,2 MB**, 49 → 41 Dateien. Größte verbleibende
Einträge laut Release-Lauf v0.4.7: `canvaskit.wasm` 6,9 MB,
`chromium/canvaskit.wasm` 5,5 MB, `skwasm_heavy.wasm` 4,9 MB, `main.dart.js`
3,6 MB, `skwasm.wasm` 3,4 MB. Das sind Größen auf der Platte; ausgeliefert
wird komprimiert.
Die übrigen Renderer-Varianten bleiben **bewusst** drin — welche greift,
entscheidet erst der Browser. Der Schritt gibt seit v0.4.7 die fünf größten
Einträge aus, damit ein Zuwachs sichtbar wird statt still mitzulaufen.

### 7.5 Bewusst offen gelassen

| Punkt | Warum offen |
|---|---|
| **1.5 Nadler statt gewichtsbasierter Näherung** | Verschiebt jedes angezeigte Blutvolumen *und* beide Erwartungswerte und macht die Körpergröße zur Pflichteingabe. Klinische Produktentscheidung, kein Bugfix. Formel ausformuliert im Kommentar von `bloodVolumeMale`; die Karten sind bis dahin als Näherung gekennzeichnet (`bsa_bv_approx`). |
| **NEU-6 ProGuard entschlacken** | Kleineres APK, aber Wirkung erst im Release-Build sichtbar und Fehlerfall = Absturz beim Feuern einer klinischen Erinnerung. Testrezept steht in `proguard-rules.pro`. |
| **EK-Hkt 0,55** | Institutionelle Annahme, seit v0.4.4 einstellbar. Gegen das Etikett des eingesetzten Präparats prüfen (deutsche EK in Additivlösung: 0,50–0,70). |
| **Play Console Data Safety** | Muss mit der Policy abgeglichen werden. |
| **Major-Updates der GitHub Actions** | Dependabot ignoriert sie seit der Nachjustierung; bewusst einzeln und mit Testlauf zu machen, sinnvollerweise gemeinsam mit dem nächsten `FLUTTER_VERSION`-Anheben. |

### 7.6 Nachträgliche Erweiterungen (nicht aus dem Audit)

- **v0.4.4 — EK-Hämatokrit als Einstellung.** `TransfusionSettings`
  (persistiertes Singleton wie `CardioplegiaSettings`), Schlüssel
  `tx_rbc_unit_hct_percent`, Default 55 %, geklemmt auf 40–80 %.
  `PatientData.transfusionVolume` ist **keine Getter-Property mehr**, sondern
  nimmt den Hkt als Parameter — dasselbe Muster wie beim del-Nido-Verhältnis,
  damit `PatientData` frei von externen Abhängigkeiten und die Formel rein
  testbar bleibt. Der Wert steht **im PDF als Eingabezeile und als Fußnote**:
  ohne ihn ist das Volumen nicht reproduzierbar.
- **Dependabot-Nachjustierung.** Die erste Woche brachte vier Major-Sprünge
  auf einmal — genau das Gegenteil der Block-B-Entscheidung. Seither:
  `github-actions` ohne Majors, Patch/Minor gruppiert in einem PR pro Woche;
  `pub` unverändert, gesperrt nur `flutter_local_notifications` und `pdf`.

### 7.7 Regeln für künftige Audits

Aus den vier Regressionen und den drei Erstbefunden des ersten Testlaufs:

1. **Einen Befund, der eine Ressource für „ungenutzt" erklärt, nicht ohne
   Build umsetzen.** `gstatic` (v0.4.3) ist das Musterbeispiel: die Begründung
   klang schlüssig und war falsch.
2. **Kommentare im Code sind keine Belege.** Der Satz „stört sich nicht daran"
   in `index.html` hat den Service-Worker-Konflikt zwei Releases lang gedeckt,
   und der Header von `cardioplegia_alarm_settings.dart` beschrieb zwei
   Versionen lang das Gegenteil des Codes. Wo ein Kommentar eine Annahme
   trägt, gehört ein Test oder ein Prüfschritt daneben.
3. **Zusammengehörige Mechanismen gemeinsam ändern.** Cache-Invalidierung und
   Precache-Umfang bedingen einander (v0.4.6); CSP und Schriftbeschaffung
   ebenso (v0.4.3).
4. **Online-Tests decken Service-Worker-Fehler nicht auf.** Der Cache zeigt
   sich erst, wenn er gebraucht wird. Offline gehört in jeden Web-Prüfplan —
   und damit auch die Windows-Distribution, die dieselbe Web-App ist.
5. **Erwartungswerte in Tests nachrechnen, nicht schätzen.** Der erste
   Testlauf scheiterte an einem Wert, den der Autor im Kopf gerechnet hatte
   (10,6733 statt 10,6719). Die enge Toleranz hat es aufgedeckt — genau dafür
   ist sie da.
6. **Der Analyzer findet, was Menschen übersehen.** `unnecessary_non_null_assertion`
   und `unawaited_futures` waren beides echte Treffer im frisch geschriebenen
   Code. Die verschärfte Konfiguration hat sich innerhalb einer Stunde
   bezahlt gemacht.
7. **Jede CI-Ersetzung verifiziert sich selbst.** `BUILD_ID` und
   `BUILD_ASSETS` brechen den Job ab, wenn ihr `sed` nicht greift. Ein
   stilles Fehlschlagen würde genau den Fehler wieder einführen, den der
   Schritt behebt.
8. **Ein Fix, der ein Verhalten ändert, braucht denselben Prüfschritt wie der
   Befund, der ihn ausgelöst hat.** Nachgetragen nach N-1 (siehe 7.8): der
   Eingabefilter wurde auf Basis einer plausiblen Annahme über
   `FilteringTextInputFormatter.allow` umgebaut, ohne sie auszuführen. Genau
   das Muster von 1.4 und 2.6, nur in der Gegenrichtung.
9. **Ein Verzeichnis, dessen Inhalt ausgeliefert wird, gehört in den
   Prüfumfang — auch wenn dort kein Anwendungscode liegt.** Nachgetragen nach
   O-1 (siehe 7.10): `tool/offline/` enthält zwei handgeschriebene Skripte,
   die als ausführbare Dateien an Klinik-PCs gehen, und wurde vier Audits
   lang nicht geöffnet.
10. **Wenn zwei Ausgabewege dieselbe Rechnung darstellen, gehört ihre
    Übereinstimmung getestet — nicht nur jede für sich.** Nachgetragen nach
    A-1 (siehe 7.11). Bildschirm und PDF sind dreimal auseinandergelaufen
    (1.1, 1.2, A-1), jedes Mal in einer anderen Richtung, und jede Seite war
    für sich plausibel.
11. **Ein Vorbelegungswert ist keine Eingabe.** Nachgetragen nach C-1 (siehe
    7.12): alles, was in einen „hat der Nutzer hier etwas gemacht"-Filter
    einfließt, muss zwischen gesetzt und vorbelegt unterscheiden.
12. **Was in einem Audit von Hand nachgezählt wird, gehört danach in ein
    Skript.** Nachgetragen nach 7.13: `tool/verify/consistency_check.py` und
    `tool/offline/test-serve.ps1`. Die Funde der Runden 7.8 bis 7.12
    entstanden nicht, weil die Regeln unbekannt waren, sondern weil ihre
    Anwendung stichprobenartig blieb.
13. **Ein Prüfwerkzeug ist Code und braucht denselben Beweis wie der Code,
    den es prüft.** Nachgetragen nach 7.14: beide Werkzeugfehler waren
    plausible Annahmen über fremdes Verhalten, die niemand ausgeführt hatte.
14. **Eine Abdeckungslücke ist ein Hinweis, keine Aufgabe.** Nachgetragen
    nach 7.15: aussagekräftig war nicht die absolute Zahl, sondern das
    Gefälle — eine Klasse bei 10 %, während ihre beiden Geschwister
    desselben Musters bei 100 % standen.

### 7.8 Nachprüfung v0.4.7 → Umsetzung v0.4.8

Nachprüfung gegen `main` (`fd36309`), jeder der 36 Altbefunde einzeln im Code
verifiziert. Ergebnis: 31 behoben, 5 bewusst offen — und **ein neuer Fehler,
den die Abarbeitung selbst eingeführt hat**.

| Befund | Umsetzung |
|---|---|
| **N-1** Fehltipp leerte das ganze Eingabefeld | behoben, v0.4.8 |
| **N-2** `install()` schluckt Fehler, `activate()` löscht trotzdem | behoben, v0.4.8 |
| **N-3** Schrittknöpfe verengten die Trainingsabsicht | behoben, v0.4.8 |
| **N-4** Desktop: `initialise()` lief bei jedem Aufruf neu | behoben, v0.4.8 |
| **N-5** zwei stale gstatic-Kommentare in `sw.js` | behoben, v0.4.8 |
| **N-6** Postanschrift | offen, ausdrücklich zurückgestellt → 7.5 |
| **N-7** `SECURITY.md` neun Zeilen | behoben, v0.4.8 |

**N-1 war der ernsteste — und der lehrreichste.** In Block E wurde der
Eingabefilter auf eine verankerte Regex umgestellt, mit dem Kommentar
„validates the WHOLE field, not single characters". Genau das tut
`FilteringTextInputFormatter.allow` **nicht**: es filtert segmentweise über
`splitMapJoin`, und eine auf `^…$` verankerte Regex, die auf den Gesamtstring
nicht passt, liefert null Treffer — übrig bleibt ein **leeres Feld**.
Praktisch: 82,5 kg im Gewichtsfeld, ein Fehltipp daneben, Wert weg.

Der Zustand davor war anders falsch (Text blieb stehen, Wert war `null`), der
neue war konsistent, aber destruktiv. In einer OP-Situation ist Datenverlust
die schlechtere der beiden Fehlfunktionen.

*Behebung:* `DecimalTextInputFormatter` in `lib/utils/` — passt der neue
Gesamtstring, wird er übernommen, sonst bleibt der alte stehen. Der
Tastendruck verpufft, nichts geht verloren. `_safeParse` bleibt zweite
Verteidigungslinie. Dazu `test/decimal_input_formatter_test.dart` (14 Tests),
darunter der Fall „ein voller Wert überlebt jeden Fehltipp".

**Zu den übrigen Punkten:**

- **N-2:** Der Precache ist jetzt zweistufig. `BUILD_ASSETS` per `addAll` —
  wirft bei jedem Fehlschlag, damit `install()` rejected und der **alte**
  Worker samt Cache in Betrieb bleibt. `CORE_SHELL` weiter tolerant. Ein
  fehlgeschlagenes Update ist ein Nicht-Ereignis; ein halbes Update ist eine
  weiße Seite. Die zusammengeführte `APP_SHELL`-Konstante entfällt, weil
  beide Listen jetzt unterschiedliche Fehlersemantik haben.
- **N-3:** `_clampToRange` → `_clampStep`. Geklemmt wird nur noch, was
  physikalisch unmöglich ist (Start aus dem leeren Feld, Werte unter 0 bei
  nicht-negativer Range). Ein Hb lässt sich per Knopf wieder auf 3 g/dl
  senken — `ranges.dart` hält im Kopf ausdrücklich fest, dass Extremwerte
  fürs Training erlaubt sein sollen, und dafür existiert die orange Warnung.
- **N-4:** Neues Flag `_platformUnsupported`. `ensureReady()` unterscheidet
  jetzt zwischen „fehlgeschlagen, Wiederholung sinnvoll" (Android) und „kann
  nie funktionieren" (Windows/Linux). Der Desktop-Ausstieg steht außerdem
  **vor** dem Timezone-Block — mehrere hundert Zonendefinitionen einzulesen
  ist auf einer Plattform, die nie plant, reine Verschwendung.
- **N-5:** Die Regel (kein Cross-Origin im Cache) bleibt, nur die Begründung
  war überholt. Der Release-Build lädt nichts Fremdes mehr.
- **N-7:** `SECURITY.md` von 9 auf 81 Zeilen: unterstützte Versionen,
  Private Vulnerability Reporting als bevorzugter Weg, ehrliche
  Reaktionszeiten für ein Ein-Personen-Projekt, Scope. **Falsche klinische
  Berechnungen stehen ausdrücklich im Scope** — kein klassischer
  Sicherheitsfehler, aber die gefährlichste Fehlfunktion dieses Projekts.
  Dazu die Bitte, Fehlerberichten keine echten Patientendaten beizulegen.

**Regel 8 für 7.7:** *Ein Fix, der ein Verhalten ändert, braucht denselben
Prüfschritt wie der Befund, der ihn ausgelöst hat.* N-1 ist derselbe
Fehlertyp wie 1.4 und 2.6, nur in der Gegenrichtung: eine plausible
Behauptung über das Verhalten einer API, die niemand ausgeführt hat.

### 7.9 Gegenkontrolle v0.4.8 → Umsetzung v0.4.9

Diff-Prüfung der v0.4.8-Umsetzung. Sechs von sieben Punkten bestätigt, keine
neue Regression — die erste Runde in dieser Kette ohne selbstverursachten
Fehler. Drei Restpunkte, alle umgesetzt:

| Punkt | Umsetzung |
|---|---|
| **R-1** `./` und `index.html` blieben tolerant precached | behoben, v0.4.9 |
| **R-2** zwei Aufrufer umgingen `ensureReady()` | behoben, v0.4.9 |
| **R-3** `_clampStep` ohne Test | behoben, v0.4.9 |

**R-1 war der ernsteste** und eine direkte Folge von N-2: Der zweistufige
Precache machte `BUILD_ASSETS` hart, aber `./` und `./index.html` kommen von
dort nicht — `./` ist keine Datei im Build-Verzeichnis, `index.html` steht in
der `skip_exact`-Liste des CI-Generators, weil es schon in `CORE_SHELL`
geführt wird. Damit galt für die beiden weiterhin die alte Fehlersemantik.
Scheitert der `index.html`-Fetch transient, aktiviert sich der Worker mit
vollständigem Asset-Cache, `activate()` löscht den alten — und der
Navigations-Fallback `caches.match('./')` greift ins Leere. Derselbe
Endzustand wie N-2, verengt auf die eine Datei, ohne die der Rest des Caches
nichts nützt.
*Behebung:* `cache.addAll(['./', './index.html'])` vor Stufe 1; die
Filterung für Stufe 2 zieht beide über ein `Set` mit ab.

**R-2:** `requestPermission()` und `areNotificationsEnabled()` riefen
`initialise()` direkt. Seit der Umordnung in N-4 war das praktisch harmlos —
der Ausstieg kommt vor dem teuren Teil —, aber die Absicht des Flags galt nur
an einer von drei Stellen, und beim nächsten Umbau der Reihenfolge wäre die
Verschwendung stillschweigend zurück. Alle drei laufen jetzt über
`ensureReady()`. Dazu ein öffentlicher Getter `platformUnsupported`: der
„Wiederholen"-Knopf im Kardioplegie-Tab wird auf Windows/Linux gar nicht mehr
angezeigt, statt garantiert zu scheitern und die Fehlersuche in die falsche
Richtung zu schicken.

**R-3** ist die Anwendung von Regel 8 auf den eigenen Fix: `_clampStep` nach
`lib/utils/step_clamp.dart` gezogen (Muster wie `formatElapsed`) und mit 11
Tests belegt. Der Test, der zählt, ist der auf Ranges mit negativer
Untergrenze — dass Base Excess (−30…30) und ZVD (−5…30) ihre negativen Werte
behalten, hängt an der einzelnen Bedingung `range.min >= 0`, die beim Lesen
niemand nachprüft.

**Anmerkung zur Paketierung:** Die ZIPs enthielten kein `.github/`, weil
Dot-Verzeichnisse beim Packen wegfielen. Für künftige Runden gilt: die
Workflows gehören mit ins Paket, sonst ist die Kopplung zwischen `sw.js` und
CI-Generator nicht gegenprüfbar.

### 7.10 Prüfung v0.4.9 → Umsetzung v0.4.10

Erste Runde, in der ein Audit `tool/offline/` geöffnet hat — das Verzeichnis,
dessen Inhalt als ausführbares Skript an Klinik-PCs verteilt wird und das
vier Audits lang übersehen wurde, während die Lieferkette der `caddy.exe`
wiederholt geprüft wurde.

| Befund | Umsetzung |
|---|---|
| **O-1** Pfad-Traversal in `serve.ps1` | behoben, v0.4.10 |
| **O-2** PowerShell-Fallback praktisch unerreichbar | behoben, v0.4.10 |
| **O-3** Browser öffnet vor dem Server | behoben, v0.4.10 |
| **O-4** Python-Fallback und `application/wasm` | dokumentiert, v0.4.10 |
| **K-1** Testname behauptet das Gegenteil | behoben, v0.4.10 |
| **K-2** feste i18n-Zahl im Kopf | entfernt, v0.4.10 |
| **K-3** Standalone-Seiten ohne CSP | behoben, v0.4.10 |
| **S-1** `cache.addAll` umging den HTTP-Cache nicht | Eigenbefund, behoben, v0.4.10 |

**O-1 war eine echte Schwachstelle**, keine Formalie. `Join-Path`
normalisiert nicht: für `..\..\Windows\win.ini` entstand ein String, der mit
dem Wurzelpfad **beginnt**, die Prüfung `StartsWith` also bestand — und
`ReadAllBytes` löste die `..` anschließend auf. Verschärft durch
`UnescapeDataString` **nach** der Kanonisierung des `HttpListener`
(`%2e%2e%2f` überlebt, was ein Browser vorher kollabiert hätte) und durch das
fehlende Trennzeichen im Präfixvergleich (`webbackup` bestand ihn ebenfalls).

*Behebung:* `Get-SafePath` löst mit `[System.IO.Path]::GetFullPath` auf,
**bevor** verglichen wird, vergleicht gegen `$rootPrefix` mit angehängtem
Trenner und mit `OrdinalIgnoreCase`. Gegenprobe an neun Nutzlasten
nachgerechnet (`%2e%2e%2f`, `..%5c`, `....//`, `//etc/passwd`): alle
Traversal-Varianten → 403, legitime Pfade → 200. Der manuelle Prüfschritt
steht als Kommentar im Skriptkopf, adressiert an die Klinik-IT, die diese
Datei vor der Freigabe liest.

Mitgenommen: klare Fehlermeldung statt Ausnahme, wenn `web\` fehlt; SPA-
Rückfall nur noch für Pfade **ohne** Dateiendung (für eine fehlende `.js`
HTML zurückzugeben erzeugt einen Folgefehler, der wie ein Syntaxfehler
aussieht); `HEAD` ohne Rumpf; `X-Content-Type-Options`, `Referrer-Policy`
und `X-Frame-Options` als **echte** Header — der Offline-Bundle ist der
einzige Auslieferungsweg, auf dem sie überhaupt wirken können (bei GitHub
Pages nicht, siehe Kommentar in `web/index.html`).

**O-2:** `start.bat` prüfte nur, ob `caddy.exe` **existiert** — sie liegt
immer im Paket. Wurde sie von AppLocker oder SmartScreen blockiert, sprang
`goto :eof` an allen Fallbacks vorbei: der Fallback griff ausgerechnet in dem
Fall nicht, für den er gebaut wurde. Jetzt Startprobe (`caddy.exe version`)
vor dem Start, ebenso für PowerShell; Python wird mit `python -c "pass"`
geprüft statt mit `where python`, weil Windows einen Store-Platzhalter
mitliefert, der nur den Microsoft Store öffnet. `py -3` als vierte Stufe.

**O-3:** Der Browser wird nicht mehr vor der Server-Auswahl geöffnet, sondern
verzögert per Selbstaufruf (`start.bat --open <port>`) — das löst die
Verzögerung ohne verschachtelte Anführungszeichen.

**S-1 — Eigenbefund beim Durchsehen der eigenen N-2-Umsetzung.**
`cache.addAll()` erlaubt **keine** fetch-Optionen und holt daher über den
HTTP-Cache des Browsers. GitHub Pages liefert mit `Cache-Control: max-age=600`
aus — innerhalb dieser zehn Minuten hätte `addAll` nach einem Deploy die ALTE
Datei in den NEUEN Cache geschrieben. Bei gehashten Assets folgenlos, aber
`flutter_bootstrap.js` und `main.dart.js` tragen keinen Hash: der Nutzer wäre
offline auf einem veralteten klinischen Build gelaufen — genau das, was der
SHA-gekoppelte Cache-Name verhindern soll. Ersetzt durch `precacheStrict()`
mit `{cache: 'reload'}` und explizitem Wurf; die harte Fehlersemantik bleibt.

Gegen eine Minimalumgebung simuliert (sechs Szenarien): kritischer Ausfall →
`install()` rejected, `skipWaiting()` nicht erreicht, alter Worker bleibt in
Betrieb; tolerierbarer Ausfall → Installation läuft durch.

**Regel 9 für 7.7:** *Ein Verzeichnis, dessen Inhalt ausgeliefert wird, gehört
in den Prüfumfang — auch wenn dort kein Anwendungscode liegt.* Vier Audits
lang wurde die Prüfsummenkette der `caddy.exe` geprüft und die beiden
handgeschriebenen Skripte danebengelegt, die im selben ZIP an dieselben
Rechner gehen.

### 7.11 Eigene Prüfung v0.4.10 → v0.4.11

Die Prüfung v0.4.9 (O-1 bis O-4, K-1 bis K-3) war mit v0.4.10 vollständig
umgesetzt und wurde gegen den Baum verifiziert. Diese Runde ist daher eine
**selbst angesetzte** Prüfung der Bereiche, die in sieben Runden keine hatten:
die kleineren Rechenschirme, `cardioplegia_settings.dart` und die
PDF-Ausgabe jenseits von O₂ und BSA.

| Befund | Umsetzung |
|---|---|
| **A-1** PDF zeigte „—", wo der Bildschirm 0 zeigte | behoben |
| **A-2** `ufFinalVolume` war 0, wenn nichts entzogen wird | behoben |
| **A-3** `CardioplegiaSettings.load()` klemmte nicht | behoben |
| **A-4** negative Null erreichte die Anzeige | behoben |

**A-1 ist die Spiegelung von Auditbefund 1.1.** Dort druckte das PDF eine
Zahl, wo der Bildschirm „—" zeigte; hier war es umgekehrt. `ResultCard`
richtet sich nach `missingInputs`, **nicht** nach dem Wert — bei
vollständigen Eingaben zeigt sie also `0.0`. `PdfRow.numeric` zeigt für 0
dagegen „—". Bei einem **Base Excess von 0**, dem Normalbefund, lautete die
Aussage auf dem Bildschirm „0 ml NaBic, keine Korrektur nötig" und im PDF
„nicht berechenbar". Dasselbe, wenn Ist- und Sollwert eines Elektrolyts
übereinstimmen.

*Behebung:* neuer Helfer `resultIf(requiredInputs, value)` in
`pdf_export.dart` — gibt den Wert nur zurück, wenn alle Eingaben vorliegen,
sonst null. Zusammen mit `zeroIsValid: true` bilden beide Ausgaben dieselbe
Unterscheidung ab: fehlende Eingabe → „—", errechnete Null → „0.0".
Angewandt auf die fünf Elektrolyt-Ergebnisse und die beiden
Ultrafiltrations-Ergebnisse. Pauschales `zeroIsValid` wäre falsch gewesen —
ohne Eingaben hätte es „0.0" gedruckt, wo nichts gerechnet wurde.

**A-2 war auch auf dem Bildschirm falsch.** `ufFinalVolume` gab 0 zurück,
sobald nichts entzogen wird — die Karte las sich als „am Ende ist kein Blut
mehr im Kreislauf". Die Fälle „nichts zu entziehen" und „Eingaben
unvollständig" waren in einen Rückgabewert kollabiert. Jetzt dieselben
Vorbedingungen wie `ufVolumeToRemove`, danach `aktuell − entzogen`. Neuer
Test: entzogen + Endvolumen ergibt über alle Ziel-Hkt-Werte das
Ausgangsvolumen.

**A-3 war eine Asymmetrie zwischen zwei Klassen desselben Musters.**
`TransfusionSettings.load()` klemmt den gespeicherten Wert,
`CardioplegiaSettings.load()` übernahm ihn roh. Ein gespeichertes 100 hätte
den Blutanteil auf null und `delNidoRatio` auf eine Division durch null
gesetzt. `CardioplegiaSettings` war zugleich die einzige der drei
persistierten Einstellungen **ohne Tests** — 13 ergänzt, darunter genau
dieser Fall.

**A-4 fiel bei der Rechenprobe zu A-1 auf.** `(0 × 80 × 3) / (−10)` ist in
IEEE-754 **−0.0**, und Dart formatiert das als `"-0.0"`. Auf der Karte stand
also „−0.0 ml NaBic", sobald der Base Excess 0 war — fachlich dieselbe Null,
sieht aber nach einem Vorzeichenfehler aus. `_safe()` normalisiert jetzt über
`v + 0.0`; echte Vorzeichen bleiben erhalten, was ein Test absichert
(Azidose → positive Puffermenge, Alkalose → negative).

**Regel 10 für 7.7:** *Wenn zwei Ausgabewege dieselbe Rechnung darstellen,
gehört ihre Übereinstimmung getestet — nicht nur jede für sich.* Bildschirm
und PDF sind in dieser Kette dreimal auseinandergelaufen (1.1, 1.2, A-1),
jedes Mal in einer anderen Richtung, und jedes Mal war jede Seite für sich
plausibel.

### 7.12 Zweite eigene Pruefung -> v0.4.12

Systematische statt stichprobenartige Fortsetzung von 7.11: A-1 war dort nur
in den beiden Screens behoben worden, in die ich zufaellig gesehen hatte.
Diese Runde hat **alle** PDF-Ergebniszeilen aller zwoelf Tabs durchgezaehlt
und gegen die zugehoerigen `ResultCard`-Guards gestellt.

| Befund | Umsetzung |
|---|---|
| **A-1b** Calafiore: "-" statt 0, Hinweis fehlte ganz | behoben |
| **B-1** Kandidatenliste des Gesamtberichts handgepflegt | behoben |
| **C-1** Paediatrie-Tab lag jedem Bericht bei | behoben |
| **D-1** Referenztabelle ueber `Map<String, dynamic>` | behoben |

**A-1b ist die klinisch wichtigste Auspraegung.** `calafioreDeltaK` ist bei 0
geklemmt, wenn das Serum-Kalium den Zielwert bereits erreicht. Der Bildschirm
zeigt dann `0,0 ml/h` **und** blendet den Hinweis `cardio_no_dose_needed`
ein. Das PDF zeigte "-" und den Hinweis **gar nicht** - ein Leser konnte
nicht unterscheiden, ob die Rechnung fehlschlug oder keine Zufuhr noetig war.
Behoben mit `resultIf` + `zeroIsValid`; der Hinweis wandert als `note` in die
Zeile und nutzt damit die Notenausgabe, die in Block E (4.2)
wiederhergestellt wurde. Magnesium ist optional, dort heisst 0 "kein Mg in
der Spritze".

**Restliche A-1-Faelle bewusst offen und begruendet:** Bei allen uebrigen
Ergebniszeilen (Schlauchvolumen, Charriere, BSA, del Nido, Buckberg,
Widerstaende, paediatrisches Transfusionsvolumen) setzt eine Null eine
Eingabe voraus, die die App bereits als unplausibel markiert - 0 cm Schlauch,
0 Ch, Delta-Hb 0, MAP gleich ZVD. Die Divergenz ist damit fuer jeden Fall
geschlossen, der aus **plausibler** Eingabe entstehen kann. Zwoelf Dateien
blind umzuschreiben waere genau die Art breiter, unueberpruefbarer Aenderung,
die in dieser Kette schon zweimal einen Fehler erzeugt hat (N-1, N-3).

**B-1:** Die Kandidatenliste des Gesamtberichts war eine handgepflegte Kopie
der Tabreihenfolge in einer privaten Methode. Ein neuer Rechen-Tab haette
dort ergaenzt werden muessen, ohne dass irgendetwas daran erinnert -
dieselbe Fehlerklasse wie das frueher fest verdrahtete
`TabController(length: 12)`, nur leiser: keine Ausnahme beim Start, sondern
ein still fehlender Abschnitt im ausgelieferten Bericht. Jetzt
`buildCombinedReportCandidates()`, `@visibleForTesting`, plus
`kNonComputingTabKeys` fuer die beiden reinen Nachschlage-Tabs. Vier Tests
binden die Liste an `MainScreen.kTabs`.

**C-1 hat der neue Test sofort gefunden - und es war mein eigener Fehler aus
v0.4.4.** Die Zeile mit dem EK-Haematokrit im Paediatrie-PDF trug den Wert
aus `TransfusionSettings` ungefiltert ein. Der ist **immer** gesetzt, also
enthielt der Tab selbst dann eine Zahl, wenn ihn niemand angefasst hatte -
und der Filter "enthaelt mindestens einen Wert, der nicht - ist" legte den
Paediatrie-Tab folglich **jedem** Gesamtbericht bei. Genau die Falle, die
`natriumSollTouched` und `bsaCardiacIndexTouched` an anderer Stelle laengst
entschaerfen: ein Vorbelegungswert ist keine Eingabe.

**D-1:** `reference_pressure_screen.dart` hielt die Druck-Referenzwerte als
`List<Map<String, dynamic>>` und griff ueber `s['rows'] as
List<List<String>>` und `r[0]`/`r[1]`/`r[2]` darauf zu. Ein Tippfehler im
Schluessel oder eine Zeile mit zu wenigen Spalten waere erst zur Laufzeit
aufgefallen - in einer Tabelle klinischer Referenzwerte, die niemand
nachrechnet, weil sie ja nur angezeigt wird. Jetzt Records
(`RefSection`/`RefRow`), wie bei `MainScreen.kTabs`. **In `lib/` steht damit
kein `as`-Cast mehr.**

**Regel 11 fuer 7.7:** *Ein Vorbelegungswert ist keine Eingabe.*

### 7.13 Pruefwerkzeuge (v0.4.13)

Bis hierher lief jede Runde nach demselben Muster: ich habe die
Invarianten von Hand nachgezaehlt, und jede Runde hat welche gefunden, weil
Handzaehlen stichprobenartig ist. Jetzt sind sie ausfuehrbar.

**`tool/verify/consistency_check.py`** — zwoelf Pruefungen ueber
Sprachgrenzen hinweg: Dart gegen YAML, Dart gegen JavaScript, Code gegen
Dokumentation. Jede steht fuer einen dokumentierten Fehler aus § 7.
Ausnahmen werden mit `// verify:ok <Begruendung>` am Ort markiert, statt die
Regel aufzuweichen — beim Bau hat der Checker prompt `dnPct` in
`cardioplegia_screen.dart` gemeldet, was durch das umschliessende
`if (delNido)` gedeckt und damit die erste solche Ausnahme ist.

**`tool/offline/test-serve.ps1`** — ersetzt die manuelle Traversal-Gegenprobe
aus dem Kopf von `serve.ps1` durch dreizehn automatisierte Anfragen. Die
Zieldatei wird absichtlich angelegt, damit ein 404 nicht wie ein bestandener
Test aussieht.

**`tool/verify/verify-all.ps1`** — ein Aufruf fuer alles, in der Reihenfolge
„was hart fehlschlaegt zuerst".

**`.github/workflows/checks.yml`** — `analyze`, `test` und die
Konsistenzpruefung bei jedem Push und PR. Bewusst getrennt von `deploy.yml`,
damit die Pruefungen auch auf Branches und in Forks laufen, ohne den
Auslieferungspfad anzufassen. Der Traversal-Test laeuft dort nicht — er
braucht Windows und gehoert lokal vor jeden Bundle-Release.

**Regel 12 fuer 7.7:** *Was in einem Audit von Hand nachgezaehlt wird, gehoert
danach in ein Skript.* Elf Runden lang wurden dieselben Invarianten manuell
geprueft; die Funde entstanden nicht, weil die Regeln unbekannt waren,
sondern weil ihre Anwendung stichprobenartig blieb.

### 7.14 Werkzeuge am echten System geprueft (v0.4.14)

Erster Lauf von `verify-all.ps1` auf der Entwicklungsmaschine. `flutter
analyze` und `flutter test` (250) grün; die beiden anderen Schritte rot — und
zwar **beide wegen Fehlern in den Werkzeugen, nicht in der App**.

**Der Traversal-Test hatte eine falsche Erwartung.** Drei der neun Faelle
schlugen fehl, alle drei die **Klartext**-Varianten (`/../geheim.txt`,
`/assets/../../geheim.txt`, `/../webbackup/nachbar.txt`), alle mit 404 statt
403. Ursache: `Invoke-WebRequest` normalisiert `..` in einer URL, **bevor**
gesendet wird. Aus `/../geheim.txt` wird `/geheim.txt` — der Server hat nie
einen Traversal gesehen, und 404 ist die richtige Antwort auf das, was ankam.
Die vier prozentkodierten Varianten, also genau die sicherheitsrelevanten,
liefen von Anfang an auf 403.

*Behebung:* Das Pruefkriterium ist jetzt **inhaltlich**. Geprueft wird, dass
der Marker aus der Datei ausserhalb des Wurzelordners nie in einer Antwort
auftaucht; 403 und 404 sind beide in Ordnung, 200 mit Marker ist der Befund.
Dazu zwei rohe TCP-Anfragen an der Client-Normalisierung vorbei — nur so
laesst sich pruefen, was ein feindlicher Client tatsaechlich schickt. Von
dreizehn auf siebzehn Pruefungen.

**Die Python-Erkennung lief in genau die Falle, gegen die `start.bat` seit
O-2 abgesichert ist.** Windows legt unter `%LOCALAPPDATA%\Microsoft\
WindowsApps` App-Ausfuehrungsaliase fuer `python.exe` und `python3.exe` ab,
die oft VOR einer echten Installation im PATH stehen und beim Aufruf nur den
Microsoft Store oeffnen (Exit 9009). `Get-Command` meldet sie als gefunden.
`verify-all.ps1` prueft jetzt durch einen echten Programmlauf und probiert
`py -3` zuerst — der Launcher wird von den Aliassen nicht verdeckt.

**Precache-Generator gegen einen echten Build geprueft.** Die Dateiliste
eines `flutter build web` (60 Dateien, 12 Verzeichnisse) durchgerechnet:
41 Precache-Eintraege, beide Entry Points erkannt, alle Ausschluesse korrekt
(`.symbols`, `experimental_webparagraph/`, `icons/`, die `?v=9`-Familie),
erzeugtes `sw.js` mit `node --check` gueltig. Der Build war ohne `--wasm`,
enthielt also kein `main.dart.wasm` — die Entry-Point-Pruefung akzeptiert
`main.dart.*` ODER `flutter_bootstrap.js` und traegt damit beide Bauarten.

**Neue Pruefung 12: unreferenzierte Dateien in `web/`.** Alles dort wandert in
den harten Precache, wird also bei jedem Deploy von jedem Besucher neu
geladen. Der erste Lauf meldet `pcalc-icon-v8-192.png`, `pcalc-icon-v8.ico`
und `pcalc-icon-v8.png` (zusammen 57 KB) — von nirgends referenziert.
Bewusst als **Warnung**, nicht als Fehler: das sind vermutlich Quellbilder
fuer die Icon-Erzeugung oder den Store-Eintrag, und wohin die gehoeren, ist
eine Entscheidung, keine Regelverletzung.

**`tool/verify/coverage_report.py`** wertet `coverage/lcov.info` aus und
listet ungetestete Dateien zuerst. `lib/screens/`, `lib/widgets/` und
`lib/theme/` sind ausgeblendet — dort braucht es Widget-Tests; uebrig bleibt
der Teil, der rechnet. In `checks.yml` informativ eingebunden, ohne Schwelle:
eine Zahl, die man erreichen muss, verleitet zu Tests, die nur Zeilen
abhaken.

**Regel 13 fuer 7.7:** *Ein Pruefwerkzeug ist Code und braucht denselben
Beweis wie der Code, den es prueft.* Beide Werkzeugfehler dieser Runde waren
plausible Annahmen ueber fremdes Verhalten — die Normalisierung von
`Invoke-WebRequest` und das Ergebnis von `Get-Command` — die niemand
ausgefuehrt hatte. Dasselbe Muster wie 1.4, 2.6 und N-1.

### 7.15 Abdeckung ausgewertet -> v0.4.15

Erste Auswertung von `coverage_report.py` auf echten Daten. Sie hat genau
das geleistet, wofuer sie gebaut wurde: die Luecke gezeigt UND den Fehler
darin.

| Datei | vorher | Befund |
|---|---|---|
| `cardioplegia_alarm_settings.dart` | 10,4 % | **Fehler gefunden**, jetzt getestet |
| `pdf_export.dart` | 10,4 % | Rendern war nicht erreichbar, jetzt getestet |
| `notification_service.dart` | 0 % | bleibt offen, Begruendung unten |
| `pdf_download_stub.dart`, `web_notifications_stub.dart` | 0 % | bleibt offen |
| `main.dart` 4,9 %, `screens/`, `widgets/` | — | Widget-Code, ausgeblendet |

**Der Fehler: `CardioplegiaAlarmSettings.load()` klemmte nicht.** Dritter
Fall derselben Asymmetrie — `TransfusionSettings` klemmte von Anfang an,
`CardioplegiaSettings` bekam es in v0.4.11, hier fehlte es noch. Die
Auswirkung ist die stillste der drei: `expectedFireCount()` gibt bei
`triggerMinutes <= 0` dauerhaft 0 zurueck. Ein gespeichertes 0 haette also
einen Alarm erzeugt, den die Oberflaeche als **eingeschaltet** anzeigt und
der **nie feuert** — ohne Fehlermeldung, an einer Erinnerung, auf die man
sich im Fall verlaesst. Ein gespeichertes 10000 wirkt genauso.

Dass die Klasse bei 10 % stand, waehrend ihre beiden Geschwister bei 100 %
lagen, war der Hinweis. 24 Tests ergaenzt, darunter der Feuerplan:
sekundengenaue Grenzen (899 s -> 0, 900 s -> 1), Monotonie des Zaehlers
ueber zwei Stunden, und das unbrauchbare Intervall.

**`pdf_export.dart`: Rendern vom Export getrennt.** Die Erzeugung war mit
dem Speichern-Dialog verwoben und damit im Unit-Test nicht erreichbar. Neu
`renderTabPdf()` und `renderCombinedPdf()`, `@visibleForTesting`; die
Export-Funktionen rufen sie auf und laden herunter. Sechs Tests bauen echte
PDF-Bytes und pruefen `%PDF-` am Anfang, `%%EOF` am Ende: gefuellter Tab,
leerer Tab (lauter Gedankenstriche), Zeile mit Fussnote (eigener
Layoutzweig seit 4.2), Gesamtbericht, leerer Gesamtbericht, und 120 Zeilen
fuer einen erzwungenen Seitenumbruch — ein Layoutfehler in Kopf- oder
Fusszeile faellt erst ab der zweiten Seite auf.

Das prueft nicht das Aussehen; dafuer braucht es Augen. Es prueft, dass der
Aufbau durchlaeuft — und ein Absturz dort bedeutet, dass der Export
ersatzlos fehlschlaegt.

**Bewusst ohne Tests, mit Begruendung:**

- `notification_service.dart` (0 %) haengt vollstaendig an
  `flutter_local_notifications`, `timezone` und `defaultTargetPlatform`. Ein
  Test brauchte einen Plugin-Mock und wuerde im Wesentlichen den Mock
  pruefen. Der reine Anteil — der Feuerplan — liegt bereits in
  `CardioplegiaAlarmSettings.expectedFireCount()` und ist jetzt abgedeckt.
  Die verbleibende Absicherung ist Stufe 5 des Pruefplans: Release-Build,
  Geraet, echte Benachrichtigung.
- Die beiden Stubs (3 bzw. 5 Zeilen) sind Weiterleitungen fuer bedingte
  Importe. Ein Test wuerde bestaetigen, dass `false` gleich `false` ist.

**Nachtrag aus dem Testlauf:** Ein Test war rot, und wieder war die
Erwartung falsch, nicht der Code. `expectValidPdf` verlangte pauschal 1000
Bytes; der leere Gesamtbericht liefert 427. Kein Defekt — ein Dokument, in
dem kein Text gezeichnet wird, bettet auch keine Schrift ein, und die
Roboto-Dateien machen den Loewenanteil eines normalen PDFs aus. Die Groesse
sagt dort etwas ueber den Inhalt, nicht ueber die Gueltigkeit. Die Schwelle
ist jetzt ein Parameter mit Begruendung.

Nebenbei geprueft: Der leere Gesamtbericht ist aus der Oberflaeche gar nicht
erreichbar — `_exportCombinedReport()` faengt den Fall ab und zeigt einen
Hinweis. Der Test sichert also nur zu, dass `renderCombinedPdf()` nicht
wirft, falls sich die Filterlogik einmal aendert.

**Regel 14 fuer 7.7:** *Eine Abdeckungsluecke ist ein Hinweis, keine
Aufgabe.* Von fuenf gemeldeten Luecken waren zwei echte Befunde, drei
begruendet unproblematisch. Wer alle fuenf schliesst, schreibt drei Tests,
die nichts absichern — und uebersieht womoeglich, dass die 10-%-Datei neben
den 100-%-Geschwistern der eigentliche Hinweis war.

### 7.16 Verwaiste Icons entfernt (v0.4.16)

Die Warnung aus 7.14 aufgeloest. Alle drei Dateien waren **byte-identische
Duplikate** von Dateien, die bereits im Repo liegen:

| Datei | MD5-gleich mit |
|---|---|
| `web/pcalc-icon-v8.png` (32x32) | `web/favicon.png` |
| `web/pcalc-icon-v8.ico` | `web/favicon.ico` |
| `web/pcalc-icon-v8-192.png` | `web/icons/Icon-192.png` |

Also kein Quellmaterial, sondern Ueberbleibsel einer Icon-Neuerzeugung — das
`v8` im Namen entspricht dem Cache-Buster `?v=8`, mit dem `anatomy.html` und
`cannulas.html` `favicon.png` anfordern. Damit ist Loeschen die richtige
Antwort und nicht Verschieben: 57 KB exakte Kopien umzulagern haette nichts
gewonnen. Geht nichts verloren — wer je ein 32x32-Icon braucht, findet
dasselbe Byte fuer Byte unter `web/favicon.png`.

**Der Checker meldet jetzt den Zwilling mit.** Aus „von nirgends
referenziert" wurde „von nirgends referenziert — inhaltsgleich mit
favicon.png". Das ist der Unterschied zwischen einer Warnung und einer
Entscheidungsgrundlage: eine Kopie kann weg, ein Original muss umziehen.
Gegengeprueft, indem eine Testkopie angelegt und die Meldung kontrolliert
wurde.

### 7.17 Icons verschoben, Serverpruefung bestanden, Data Safety vorbereitet (v0.4.17)

**Icons nach `assets/branding/`.** Auf Wunsch verschoben statt geloescht. Der
Ordner ist nicht in `pubspec.yaml` als Asset eingetragen, landet also in
keinem Build; das `README.md` dort haelt fest, dass alle drei Dateien
byte-identische Kopien von `web/favicon.png`, `web/favicon.ico` und
`web/icons/Icon-192.png` sind — wer sie spaeter loescht, verliert nichts.
Aus `web/` sind sie damit raus, und der harte Precache traegt 57 KB weniger.

**`test-serve.ps1`: 17 von 17 bestanden.** Aussagekraeftig sind vor allem die
beiden **rohen TCP-Anfragen**: Sie kamen mit `403 Forbidden` zurueck, nicht
mit 404. Das heisst, `http.sys` hat den unnormalisierten Pfad
`/../geheim.txt` durchgereicht und `Get-SafePath` hat ihn abgelehnt — die
Pruefung greift also tatsaechlich und wird nicht bloss von einer
Normalisierung weiter vorne verdeckt. Genau diese Unterscheidung war mit der
ersten Testfassung nicht moeglich.

**EK-Haematokrit bleibt auf 0,55** — bewusste Entscheidung des
Verantwortlichen, nicht mehr offen. Der Wert ist seit v0.4.4 im
Paediatrie-Tab einstellbar und steht im PDF; wer ein Praeparat mit anderem
Hkt einsetzt, aendert ihn dort.

**`docs/PLAY_DATA_SAFETY.md`** ergaenzt: Abgleich des
Datensicherheits-Formulars gegen die Datenschutzerklaerung, Feld fuer Feld,
mit Code-Beleg je Antwort. Kern: Google definiert „erheben" als *Daten
verlassen das Geraet* — lokal gespeicherte Einstellungen und ein vom Nutzer
selbst abgelegtes PDF fallen nicht darunter. Der belastbarste Beleg ist die
fehlende `INTERNET`-Berechtigung im Release-Build.

Drei Punkte darin brauchen eine Entscheidung: die Gesundheits-Deklaration
und die Store-Kategorie (Medizin vs. Bildung), die Abgrenzung der Web-App
(GitHub-Pages-Logfiles gehoeren NICHT ins Formular, weil es die Android-App
beschreibt), und die SDK-Tabelle, die bei jeder neuen Abhaengigkeit erneut
zu pruefen ist — dort wird ein „Nein" spaeter unbemerkt falsch.

### 7.18 Play-Entscheidungen getroffen (v0.4.18)

**ProGuard-Regeln bleiben.** Entscheidung des Verantwortlichen, meiner
Empfehlung folgend. Kosten: ein paar hundert Kilobyte APK-Groesse und
Optimierungsspielraum, den R8 nicht nutzen kann. Kein funktionaler oder
sicherheitsrelevanter Nachteil — der Code ist ohnehin quelloffen,
Verschleierung schuetzt hier nichts. Damit ist NEU-6 nicht mehr „offen",
sondern entschieden.

**Store-Kategorie: Bildung, nicht Medizin.** *Medizin* zieht in mehreren
Regionen Nachfragen zum Medizinprodukte-Status nach sich — eine Kategorie zu
waehlen, die genau die Pruefung ausloest, deren Ergebnis man vorab verneint,
schafft Aufwand ohne Gegenwert. *Bildung* deckt den erklaerten Zweck
(Ausbildung und persoenliche Nutzung) und ist die zutreffendere Einordnung,
keine Ausweichbewegung.

Damit die Wahl traegt, muss der Store-Text zu ihr passen: gelesen wird die
Beschreibung, nicht die Kategoriezeile. `docs/PLAY_DATA_SAFETY.md` § 3.1
enthaelt dafuer eine Gegenueberstellung „gehoert hinein / gehoert nicht
hinein" und den MDR-Ausschluss zur woertlichen Uebernahme. **Die
Gesundheits-Deklaration haengt an der Funktion, nicht an der Kategorie** —
falls Play sie abfragt, ist sie wahrheitsgemaess auszufuellen.

**Web-App abgegrenzt.** Die GitHub-Pages-Logfiles gehoeren nicht ins
Datensicherheits-Formular: es beschreibt die ueber Play ausgelieferte
Android-App, nicht eine Website. Die Datenschutzerklaerung behandelt beide
Faelle getrennt und belegt die Trennung, falls die Pruefung darauf
zurueckkommt.

**SDK-Tabelle: keine Entscheidung, sondern eine Pflicht mit Verfallsdatum.**
Das „Nein" im Formular gilt fuer den Stand der Abhaengigkeitsliste. Kommt ein
Paket dazu, das Daten uebertraegt, wird die Angabe falsch, ohne dass jemand
etwas Falsches getan haette. `consistency_check.py` prueft die Tabelle
deshalb jetzt mechanisch gegen `pubspec.yaml` (Pruefung 13): Jede
Laufzeitabhaengigkeit muss bewertet sein, sonst schlaegt der Lauf fehl —
lokal und in der CI. Gegengeprueft, indem `firebase_analytics` versuchsweise
eingetragen wurde; die Pruefung schlug an und nannte den naechsten Schritt.

Das ist Regel 12 auf eine Compliance-Zusage angewandt: Was sonst in einem
Dokument steht und dort veraltet, haengt jetzt am Build.

### 7.19 Erster CI-Lauf von checks.yml und Stufe 6 (v0.4.19)

**Stufe 6 — Web/Service Worker, bestaetigt an v0.4.15.** Zwei Screenshots
kurz nacheinander: erst `pcalc-8d174017…` UND `pcalc-78cb32d0…`
nebeneinander, dann nur noch der neue. Das ist nicht doppelt, sondern der
vorgesehene Ablauf sichtbar gemacht — `install()` legt den neuen Cache an
und fuellt ihn hart, **erst danach** raeumt `activate()` die alten weg. Bei
umgekehrter Reihenfolge staende ein Nutzer bei abgebrochenem Download ohne
jeden Cache da.

**Fuer kuenftige Pruefungen:** Zwei Caches unmittelbar nach einem Deploy sind
erwartet. Bleiben sie ueber mehrere Neuladungen bestehen, waere das ein
Befund.

Ebenfalls belegt: Text rendert (gebuendelte Schrift), Sprachumschaltung
funktioniert, keine CSP-Verstoesse. Die `script.js`-Fehlermeldung ist
endgueltig geklaert — der Screenshot zeigt die volle Herkunft
`chrome-extension://…/script.js:2`, also ein Content-Script einer
Browser-Erweiterung, kein Bestandteil der Seite.

**Stufe 7 — erster Lauf von `checks.yml`, vollstaendig gruen.**

| Schritt | Ergebnis |
|---|---|
| `flutter analyze --no-fatal-warnings` | `No issues found!` (11,6 s) |
| `flutter test` | 276 Tests |
| Konsistenzpruefung | alle 13 bestanden, 1 Warnung (die Icons, in v0.4.17 erledigt) |
| Coverage | informativ, bricht nicht ab |

Die Konsistenzpruefung lief damit zum ersten Mal ausserhalb meines
Containers und bestaetigte unter anderem, dass die `sed`-Muster **aller
drei** Workflows zu `web/sw.js` passen und alle zehn PDF-Bauer im
Gesamtbericht eingebunden sind.

**Die Abdeckungsauswertung zeigt die Wirkung von 7.15 in Zahlen:**

| Datei | v0.4.14 | v0.4.15 |
|---|---|---|
| `cardioplegia_alarm_settings.dart` | 10,4 % | **100 %** |
| `pdf_export.dart` | 10,4 % | **85,5 %** |
| gesamt | 17,2 % | 21,4 % |

Die drei verbleibenden Nullen sind die in 7.15 begruendeten:
`notification_service.dart` (Plugin-gebunden, Absicherung ueber Stufe 5) und
die beiden Stubs fuer bedingte Importe.

**Ein Befund aus dem Lauf:** GitHub meldete
„Node.js 20 is deprecated … actions/setup-node@… are being forced to run on
Node.js 24". `setup-node` v4 laeuft selbst auf Node 20. Dependabot faengt das
nicht auf, weil Major-Updates fuer Actions bewusst ignoriert werden — solche
Spruenge gehoeren einzeln und mit Testlauf gemacht. Genau das ist hier
geschehen: v5.0.0 auf Commit-SHA gepinnt, `node-version` von 20 auf 22
angehoben. Node wird ausschliesslich fuer `node --check web/sw.js` gebraucht.

### 7.20 Stufe 7 abgeschlossen, Major-Updates durchgefuehrt (v0.4.20)

**Stufe 7 ist damit vollstaendig.** Drei Laeufe zu v0.4.19, alle gruen, kein
`##[error]` in keinem davon.

| | Release-Lauf (ohne `--wasm`) | Deploy-Lauf (`--wasm`) |
|---|---|---|
| Precache | 41 Dateien, 33,2 MB | 43 Dateien, 36,9 MB |
| Entry Points | `flutter_bootstrap.js`, `main.dart.js` | zusaetzlich `main.dart.mjs`, `main.dart.wasm` |
| groesster Eintrag | `canvaskit.wasm` 6,9 MB | `canvaskit.wasm` 6,9 MB |

**Beide Bauarten sind damit belegt.** Die Entry-Point-Pruefung im Generator
akzeptiert `main.dart.*` ODER `flutter_bootstrap.js` — der Release-Lauf zeigt,
warum das ODER noetig ist: ohne `--wasm` gibt es kein `main.dart.wasm`, und
eine Pruefung, die es verlangt haette, haette den Release-Build blockiert.

Weiter belegt: `caddy.zip: OK` (SHA-512 gegen die offizielle Pruefsummenliste),
`Signing material removed from workspace.`, drei Artefakte hochgeladen,
`analyze` sauber, 276 Tests in beiden Laeufen.

**Major-Updates aller GitHub Actions.** Vorgehen: fuer jede Action die
`action.yml` des Zielstands von `raw.githubusercontent.com` geladen und
geprueft, ob jeder von uns benutzte Input dort noch existiert und ob sich
Defaults geaendert haben — statt auf „duerfte passen" zu setzen.

| Action | von | auf | Befund der Pruefung |
|---|---|---|---|
| `actions/checkout` | v6.1.0 | **v7.0.1** | keine Aenderung an Inputs oder Defaults |
| `actions/setup-java` | v4.9.0 | **v5.7.0** | nur neue optionale Inputs |
| `actions/upload-artifact` | v4.6.2 | **v7.0.1** | ein neuer optionaler Input (`archive`) |
| `softprops/action-gh-release` | v2.6.2 | **v3.0.2** | keine Aenderung an Inputs oder Defaults |
| `actions/setup-node` | v4.4.0 | **v5.0.0** | bereits in v0.4.19 |

Alle vier laufen jetzt auf `node24` — damit ist die Deprecation-Warnung aus
7.19 nicht bloss umgangen, sondern die Ursache beseitigt.
`peaceiris/actions-gh-pages` (v4) und `subosito/flutter-action` (v2) sind
bereits auf ihrer neuesten Major.

**`file_picker` 8.3.7 -> 11.0.3.** Der einzige pub-Major mit einer echten
Bruchstelle: v11 hat `FilePicker` auf **statische Methoden** umgestellt und
den instanzbasierten Zugriff ueber `.platform` entfernt. Genau eine
Aufrufstelle betroffen (`utils/pdf_download_stub.dart`), Signatur von
`saveFile()` gegen die Quelle von v11.0.3 geprueft — alle fuenf uebergebenen
Parameter existieren unveraendert.

Der Sprung ist nicht nur Pflege: v11 enthaelt einen Fix fuer eine
**Path-Traversal-Schwachstelle (CWE-22)** beim Aufloesen von Pfaden aus
externen Content-Providern. Dieselbe Fehlerklasse, die in `serve.ps1`
behoben wurde (O-1) — in einer Bibliothek, die das PDF auf dem Geraet
ablegt.

**Nicht betroffen:** Der `withData`-Bruch aus v11 (#1987) gilt fuer
`pickFiles()` im Web; die App benutzt ausschliesslich `saveFile()`.

**Zu pruefen nach `flutter pub get`:** `flutter analyze` faellt sofort auf,
falls die statische Signatur doch abweicht — das ist der Grund, warum diese
Migration trotz fehlender Toolchain vertretbar ist: der Fehlerfall ist ein
Compilerfehler, kein stiller Ausfall. Danach der PDF-Export **auf einem
Geraet**, weil der Speichern-Dialog nur dort laeuft.

### 7.21 Sperrdatei-Pruefung (v0.4.21)

Beim Anheben von `file_picker` auf `^11.0.3` fiel auf, dass `pubspec.lock`
im ausgelieferten Paket weiter auf 8.3.7 steht — in dieser Umgebung laesst
sich `flutter pub get` nicht ausfuehren, die Sperrdatei also nicht neu
schreiben. Lokal faellt das sofort auf, weil `pub get` sie erneuert; ein
Commit oder ein weitergereichtes Paket kann die alte Fassung aber
mitschleppen. Dann baut die CI gegen andere Versionen als die
Entwicklungsmaschine — genau das, was eine Sperrdatei verhindern soll.

Neue Pruefung 14: jede gesperrte Version muss die Constraint aus
`pubspec.yaml` erfuellen. Die Caret-Logik ist gegen zwoelf Faelle
gegengerechnet, einschliesslich der Sonderregel fuer Major 0
(`^0.11.0` erlaubt 0.11.x, nicht 0.12.0).

**Die Pruefung schlaegt im ausgelieferten Paket bewusst an.** Gruen werden
kann sie nur auf der Entwicklungsmaschine, weil nur dort `flutter pub get`
die korrekte Sperrdatei erzeugt. Die Fehlermeldung nennt genau diesen
Schritt.

**Merkposten fuer kuenftige Paketuebergaben:** Wenn ein ZIP von hier ueber
eine Arbeitskopie entpackt wird, ueberschreibt es `pubspec.lock` mit dem
Stand von hier. Nach jedem Entpacken gehoert daher `flutter pub get`
ausgefuehrt — und die dabei neu geschriebene Sperrdatei in den Commit.
