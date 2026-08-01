# PerfusionCalc – Arbeitskontext

> Kompakter Projektstand als Arbeitsgedächtnis. **Zuerst lesen**, bevor
> Dateien durchsucht werden – erspart das erneute Ableiten von Struktur,
> Konventionen und Entscheidungen.
> Bei jeder Änderung mitpflegen.

**Stand:** v0.4.7+29 · 12 Tabs · **199 Unit-Tests** (8 Testdateien) · i18n 330/330 (EN+DE) · Kontakt: perfusioncalc@unbox.at

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
  die Console: `https://perfusioncalc.de/privacy.html` (nach dem nächsten
  Web-Deploy erreichbar). **Anschrift des Verantwortlichen fehlt noch** – in
  `privacy_policy.md` und `web/privacy.html` als Platzhalter markiert.
- St.-Thomas- und Eppendorf-Protokoll (in den Studienunterlagen ausgearbeitet).
- Perfusionsprotokoll mit Zeitstempeln (Bypass-/Klemmzeit, Temperaturverlauf).
- Heparin/Protamin + ACT-Rechner.
- Natives Share-Sheet (`share_plus`) – PDF kann aktuell nur gespeichert werden.
- Versionsnummer wird auf Zuruf angehoben (3 Stellen: `pubspec.yaml`,
  `kAppVersion` in `main.dart`, README-Badge).

---

## 7. Audit-Abarbeitung (v0.3.3 / v0.4.0)

Zwei Audits, zu fünf Blöcken zusammengefasst. Blöcke A–C ändern keinen
Dart-Code und sind daher ohne Toolchain verantwortbar; D und E brauchen
`flutter analyze` + Testlauf.

| Block | Inhalt | Status |
|---|---|---|
| **A** | Release-Blocker: `USE_EXACT_ALARM`, Datenschutzerklärung, `allowBackup`, `minSdk` | **erledigt (v0.4.1)** |
| **B** | Supply Chain / CI: Action-SHA-Pins, `flutter-version`, Gradle-SHA, Caddy-Pin, Expression Injection, `flutter test \|\| echo` | **erledigt (v0.4.1)** |
| **C** | Web / Service Worker: `notificationclick`-Handler, Cache an Build-SHA, CSP | **erledigt (v0.4.1)** |
| **D** | Klinische Rechenpfade: `expectedHb`, Transfusionsvolumen (Davies 2007), `fTPercent`, Nadler, PDF-Guards | **erledigt (v0.4.2)**, außer Nadler |
| **E** | Dart-Fehler, tote Pfade, Hygiene, fehlende Tests | **erledigt (v0.4.2)** |

### Entscheidungen aus Block A

- **`USE_EXACT_ALARM` entfernt.** Play-Restricted-Permission, nur für Apps mit
  Alarm-/Timer-/Kalender-Kernfunktion. `SCHEDULE_EXACT_ALARM` bleibt und deckt
  dieselbe Funktion ab; `requestExactAlarmsPermission()` und der
  `PlatformException`-Fallback auf `inexactAllowWhileIdle` existierten bereits.
  → Kein Dart-Code geändert.
- **`allowBackup="false"` + `data_extraction_rules.xml`.** Die
  Geräte-zu-Gerät-Übertragung wird von `allowBackup` *nicht* mitabgeschaltet,
  deshalb die zusätzliche Regeldatei. Patientendaten waren nie betroffen
  (nur im RAM), es geht um die SharedPreferences.
- **`minSdk = maxOf(24, flutter.minSdkVersion)`.** Plugin v21 verlangt API 24;
  Flutters Default liegt aktuell ebenfalls bei 24, ist aber beweglich.
- **Datenschutzerklärung** doppelt gepflegt: `privacy_policy.md` (Repo) und
  `web/privacy.html` (erreichbare URL für Play). **Beide Dateien und die
  Data-Safety-Angaben in der Play Console müssen zusammen geändert werden.**

### Entscheidungen aus Block B

- **Alle Actions auf vollständige Commit-SHAs gepinnt**, Tag als Kommentar
  dahinter. Bewusst innerhalb der bisherigen Major-Version geblieben
  (`checkout` v6.1.0, nicht v7) — Pinnen und Major-Sprung gehören nicht in
  denselben Commit. `.github/dependabot.yml` hält die SHAs nach.
- **`FLUTTER_VERSION: '3.44.8'`** als workflow-weite Variable in allen drei
  Workflows. **Muss mit der lokalen Version übereinstimmen** (`flutter --version`)
  — sonst testet man gegen eine andere Toolchain, als die CI baut. Beim
  Anheben: alle drei Workflows plus die Entwicklungsmaschinen gemeinsam.
- **Caddy 2.11.4 mit SHA-512 gepinnt** statt „neuestes Release aus dem API-Feed".
  Hash gegen `caddy_2.11.4_checksums.txt` verifiziert; Version, SHA-256 und
  SHA-512 sind in `OFFLINE_WINDOWS.md` dokumentiert, damit Klinik-IT das
  ausgelieferte Bundle selbst prüfen kann.
- **`distributionSha256Sum` im Gradle-Wrapper.** Quelle:
  gradle.org/release-checksums, „Complete (-all) ZIP" für 8.14. Beim Anheben
  der Gradle-Version muss der Hash mitwandern, sonst schlägt jeder
  Android-Build fehl.
- **Kein stilles Debug-Signing mehr im Release-Workflow.** Fehlt
  `KEYSTORE_BASE64`, bricht der Job ab, bevor gebaut wird; zusätzlich wirft
  Gradle, wenn `PERFUSIONCALC_REQUIRE_RELEASE_SIGNING=true` gesetzt ist und
  `key.properties` fehlt. Lokale Builds ohne diese Variable verhalten sich
  unverändert.
- **`commit_message` im gh-pages-Deploy ist jetzt nur noch die SHA.**
  `github.event.head_commit.message` war nicht vertrauenswürdiger Input in
  einer Action-Eingabe.
- **`permissions` in `deploy.yml` auf `contents: write` reduziert** —
  `pages:`/`id-token: write` gehören zum `actions/deploy-pages`-Weg, der hier
  nicht benutzt wird.
- **`web: any` → `^1.1.0`** (aufgelöst ist 1.1.1, Resolution ändert sich nicht).

### Entscheidungen aus Block C

- **`notificationclick`-Handler in `web/sw.js`.** Der Service-Worker-
  Zustellweg in `web_notifications_web.dart` (Chrome/Android) hatte keinen
  Klick-Empfaenger — die Erinnerung erschien, ein Tipp darauf tat nichts.
  Handler fokussiert ein vorhandenes Fenster (`includeUncontrolled: true`,
  sonst wird ein vor der Aktivierung geoeffneter Tab nicht gefunden) oder
  oeffnet eines. **Kopplung dokumentiert**: Kommentar in beiden Dateien, damit
  nicht eine Seite ohne die andere entfernt wird.
- **Cache-Name an die Commit-SHA gekoppelt.** `const BUILD_ID = 'DEV';` wird
  im CI per `sed` durch `$GITHUB_SHA` ersetzt — in allen drei Workflows, jeweils
  mit anschliessender `grep`-Verifikation, die den Job abbricht, wenn die
  Ersetzung nicht greift. Ein stilles Fehlschlagen wuerde genau den alten
  Fehler wieder einfuehren. **Der Platzhalter-String darf nicht geaendert
  werden, ohne das sed-Muster mit anzupassen.**
- **`flutter_bootstrap.js` und `main.dart.js` auf Network-First.** Beide tragen
  keinen Hash im Dateinamen und lagen im Cache-First-Zweig. Der SHA-Cache-Name
  loest das bereits; Network-First ist der zweite Riegel, falls ein Browser
  die alte `sw.js` noch nicht ersetzt hat. Offline greift weiter der Cache.
- **`passThrough()` (7 Aufrufe) und `NEVER_CACHE` (leer) entfernt.**
- **CSP entschlackt**: `gstatic.com` raus (beide Builds nutzen
  `--no-web-resources-cdn`). `X-Content-Type-Options` und `Permissions-Policy`
  als `<meta>` entfernt — sie werden von keinem Browser ausgewertet und
  suggerierten Schutz, den es nicht gab. Eine Tabelle im Kommentar haelt fest,
  welche Header als `<meta>` ueberhaupt wirken.
- **Eine Dart-Zeile in diesem Block**: `icon:` in `NotificationOptions`
  (sonst generisches Browser-Symbol statt App-Icon).

### Entscheidungen aus Block D

- **1.4 Transfusionsvolumen: kein Fehler.** Davies 2007 lautet
  `Gewicht x ΔHb x 3 / Hkt(EK)`, wobei der Hkt als **Bruch** im Nenner steht
  und der Faktor 3 ihn *nicht* bereits enthält. Davies' eigenes Beispiel
  (20 kg x 2 g/dl x 3 / 0,6 = 200 ml = 10 ml/kg) reproduziert die Formel
  exakt. Der Auditbefund „Doppelkorrektur" war falsch begründet.
  Der Divisor ist jetzt die dokumentierte Konstante
  `PatientData.kRbcUnitHematocrit = 0.55`. **Gegen das Etikett des
  eingesetzten EK prüfen** — deutsche EKs in Additivlösung sind mit
  Hkt 0,50–0,70 spezifiziert, bei Neugeborenen ist die Differenz relevant.
- **`expectedHb` → `expectedHbMale`/`expectedHbFemale`**, exakte
  Verdünnungsformel gegen das eigene Blutvolumenmodell. Der alte Wert war
  systematisch +0,70 g/dl zu optimistisch. Der BSA-Tab zeigt jetzt zwei
  Karten statt einer, analog zu Hct.
- **`cavDO2` beidseitig abgesichert.** Damit fallen VO₂, VO₂i und O₂-ER auf
  „nicht berechnet" zurück, sobald der venöse Satz unvollständig ist —
  Bildschirm *und* PDF. Das war der Weg, auf dem „O₂-ER 100 %" ins
  ausgelieferte Dokument kam.
- **`PdfRow.numeric` bekommt `zeroIsValid`** statt die 0-Regel global zu
  streichen: Ein echter Nullwert wird nur dort gedruckt, wo 0 eine Messung
  ist (BE, ZVD, LAP). Der „nur gefüllte Tabs"-Filter des Gesamtberichts
  bleibt dadurch funktionsfähig.
- **1.5 Nadler bleibt offen — bewusst.** Ein Wechsel würde jedes angezeigte
  Blutvolumen *und* beide Erwartungswerte verschieben und die Körpergröße zur
  Pflichteingabe für sie machen. Das ist eine klinische Produktentscheidung.
  Bis dahin sind die beiden Blutvolumen-Karten im UI als Näherung
  gekennzeichnet (`bsa_bv_approx`), und die Alternativformel steht
  ausformuliert im Kommentar von `bloodVolumeMale`.

### Entscheidungen aus Block E

- **`Range.note` → `Range.noteKey`**, alle 40 Hinweise über i18n; englische
  Fassungen ergänzt. Vorher hing an einem übersetzten Tooltip ein deutsches
  Literal.
- **`_kTabs` ist jetzt `MainScreen.kTabs`**, Record-Typ, `@visibleForTesting`;
  `TabController` leitet seine Länge daraus ab. Sechs Casts weniger.
- **NEU-6 ProGuard: bewusst NICHT geändert.** Die beiden `-keep class`-Zeilen
  kosten APK-Größe, aber ihr Wegfall zeigt sich erst im Release-Build und der
  Fehlerfall ist ein Absturz beim Feuern einer geplanten Benachrichtigung.
  Der Kommentar in `proguard-rules.pro` nennt jetzt den konkreten Test, nach
  dem sie entfernt werden können.
- **`analysis_options.yaml` verschärft** (`strict-casts`, `avoid_dynamic_calls`,
  `unawaited_futures`, `use_build_context_synchronously`,
  `always_declare_return_types`, `prefer_final_locals`). `strict-raw-types`
  bewusst nicht — feuert auf Fremdbibliotheks-Signaturen.
  **Das ist die Änderung, die am ehesten neue Analyzer-Ausgaben erzeugt.**
- **Schließen-Button nur noch auf Android** (`SystemNavigator.pop()` ist im
  Web wirkungslos und auf iOS ein Ablehnungsgrund).
- **`formatElapsed` nach `lib/utils/duration_format.dart` extrahiert**, damit
  die Zeitanzeige von Timer-Karte und Banner testbar identisch bleibt.

### Hotfix v0.4.3 — Web-Version rendert ohne Text

**Symptom:** Nach dem Deploy von v0.4.2 zeigte perfusioncalc.de Layout, Karten,
+/−-Buttons und Material-Icons, aber **keine einzige Beschriftung**.

**Ursache:** Auditbefund 2.6 hatte `gstatic.com` in der CSP für ungenutzt
gehalten, weil beide Builds mit `--no-web-resources-cdn` laufen. Das Flag holt
aber nur `canvaskit.js`/`.wasm` vom eigenen Origin — **nicht die Schrift**.
CanvasKit lädt Roboto zur Laufzeit von `fonts.gstatic.com`; die verschärfte CSP
sperrte den Abruf, und ohne Schrift rendert Flutter Web gar keinen Text. Die
Material-Icons blieben sichtbar, weil sie ein gebündeltes Asset sind — das
machte den Fehler wie ein Layout-, nicht wie ein Schriftproblem aussehen.

**Behebung, zweistufig:**
1. `font-src` und `connect-src` erlauben `https://fonts.gstatic.com` wieder.
   `script-src` bleibt ohne `www.gstatic.com` — dieser Teil des Befundes war
   richtig.
2. Roboto ist jetzt als `fonts:`-Familie in `pubspec.yaml` gebündelt und in
   `buildAppTheme()` als `fontFamily` gesetzt. Die App braucht den Netzabruf
   damit gar nicht mehr.

**Der zweite Punkt ist der eigentliche Fund.** Die Schrift hing die ganze Zeit
an einem Abruf zu Google — auch vor der CSP-Verschärfung. Betroffen wären
davon gewesen:
- die **Offline-Windows-Distribution** (per Definition ohne Internet)
- jedes Klinik-Netz, das `fonts.gstatic.com` sperrt
- der Datenschutz: bei jedem Aufruf ging eine Verbindung zu Google, was die
  Datenschutzerklärung so nicht abbildete („keine externen Ressourcen")

**Lehre:** `--no-web-resources-cdn` deckt Schriften nicht ab. Und: einen
Befund, der eine Ressource für „ungenutzt" erklärt, nicht ohne einen Build
umsetzen, der es zeigt.

### v0.4.4 — EK-Hämatokrit als Einstellung

Aus Stufe 4 des Prüfplans wurde statt einer einmaligen Entscheidung ein
Eingabefeld: `TransfusionSettings` (persistiertes Singleton wie
`CardioplegiaSettings`), Schlüssel `tx_rbc_unit_hct_percent`, Default 55 %,
geklemmt auf 40–80 %.

- `PatientData.transfusionVolume` ist **keine Getter-Property mehr**, sondern
  `transfusionVolume(double rbcUnitHematocritPercent)`. Damit bleibt die
  Formel rein und testbar; die Einstellung wird an der Aufrufstelle gelesen —
  dasselbe Muster wie beim del-Nido-Verhältnis.
- Der Wert steht **im PDF als Eingabezeile und als Fußnote am Ergebnis**. Ohne
  ihn ist das Transfusionsvolumen nicht reproduzierbar: ein Leser sieht
  sonst nicht, für welches Präparat gerechnet wurde.
- Solange der Auslieferungswert unverändert ist, weist ein Hinweis darauf hin
  (`ped_hct_ek_default`). Nach der ersten Bestätigung verschwindet er.
- Datenschutzerklärung ergänzt: der Wert ist eine weitere lokal gespeicherte
  Einstellung.

**Adresse in der Datenschutzerklärung:** Platzhalter auf Wunsch entfernt.
Statt einer Anschrift steht dort jetzt der Satz, dass eine Postanschrift auf
Anfrage mitgeteilt wird. Art. 13 Abs. 1 lit. a DSGVO verlangt formal die
Angabe; der Verzicht ist eine bewusste Entscheidung des Verantwortlichen.

### Dependabot-Nachjustierung

Die erste Woche hat gezeigt, dass die Konfiguration aus Block B das Gegenteil
dessen vorschlug, was dort entschieden wurde: vier von fünf PRs waren
Major-Sprünge (checkout 6→7, setup-java 4→5, gh-release 2→3,
upload-artifact 4→**7**).

- `github-actions`: **Major-Updates ignoriert** (`dependency-name: "*"`).
  Innerhalb der Major werden die SHAs weiter automatisch nachgezogen — das
  war der Sicherheitszweck des Pinnens. Major-Wechsel gehören einzeln
  gemacht, mit Testlauf, am besten gemeinsam mit dem nächsten Anheben von
  `FLUTTER_VERSION`. Sicherheits-Updates meldet Dependabot Alerts unabhängig
  davon.
- Patch- und Minor-Updates von Actions laufen jetzt **gruppiert** in einem PR
  pro Woche statt fünf einzelnen.
- `pub`: unverändert. Major-PRs sind hier als Erinnerung erwünscht, gesperrt
  bleiben nur `flutter_local_notifications` und `pdf`.

**Offene PRs im Repo:** #2–#5 (Actions, Major) können geschlossen werden —
Dependabot öffnet sie mit dieser Konfiguration nicht erneut. #6
(`pdf` 3.12.0 → 3.13.0) ist ein Minor innerhalb von `^3.11.1` und kann nach
einem lokalen `flutter test` gemergt werden.

### Prüfstatus v0.4.4 (Stand 01.08.2026)

| Stufe | Inhalt | Status |
|---|---|---|
| 1 | `pub get`, `analyze`, `test` | **grün** (199 Tests; drei Erstbefunde behoben: Testerwartung, `unnecessary_non_null_assertion`, `unawaited_futures`) |
| 2 | Verschärfter Analyzer | **grün** — `strict-casts` und `use_build_context_synchronously` ohne Treffer |
| 3 | Klinische Rechenwege am laufenden System | **verifiziert** |
| 4 | EK-Hämatokrit | aus der Entscheidung wurde ein persistiertes Eingabefeld (v0.4.4) |
| 5 | Benachrichtigungen im Release-Build, Android | **verifiziert** — geplante Benachrichtigung feuert und stürzt nicht ab |
| 6 | Web / Service Worker | Cache-Name ✔, Fontfix ✔ (0 gstatic-Requests), **Offline-Laden war defekt → v0.4.5** |
| 7 | CI | **verifiziert** am Release-Lauf v0.4.6 (analyze sauber, 199 Tests, Keystore-Pflicht, Caddy-SHA-512, Precache-Generator, Cleanup) |

**Was Stufe 5 nebenbei beantwortet hat:** Die ProGuard-`-keep`-Regeln greifen
weiterhin, und der Wegfall von `USE_EXACT_ALARM` hat die Funktion nicht
beschädigt — `SCHEDULE_EXACT_ALARM` allein trägt sie. Der Play-Store-Blocker
ist damit ohne Funktionsverlust weg.

**Toolchain angeglichen:** lokal läuft Flutter **3.44.8** / Dart 3.12.2
(Framework-Revision 058e0af2c2, 23.07.2026). `FLUTTER_VERSION` in allen drei
Workflows steht jetzt auf demselben Wert — vorher 3.44.7, was bedeutet hätte,
dass lokal gegen eine andere Toolchain getestet wird als die CI baut.

### Hotfix v0.4.5 — zwei Service Worker um denselben Scope

**Symptom:** Online lief alles. Mit DevTools → Network → Offline brach die App
ab: Dokument und `flutter_bootstrap.js` kamen noch aus dem Cache, dann blieben
`main.dart.js`, `canvaskit.js` und `canvaskit.wasm` auf *pending* stehen, und
der Reload endete in `ERR_INTERNET_DISCONNECTED`.

**Ursache:** Alle drei Web-Builds liefen mit `--pwa-strategy offline-first`.
Flutter erzeugt damit ein eigenes `flutter_service_worker.js`, das
`flutter_bootstrap.js` beim Start registriert — **im selben Scope `/` wie
unser `web/sw.js`**. Ein Service Worker wird pro Scope registriert, nicht pro
Dateiname; die spätere Registrierung ersetzt die frühere. Unser gerade
verdrängter Worker löste seine offenen `respondWith`-Promises nie auf, daher
die hängenden Requests.

Der Kommentar in `index.html` behauptete das Gegenteil („unser sw.js hat einen
anderen Namen/Scope und stört sich nicht daran"). Das war der eigentliche
Fehler: eine falsche Annahme, schriftlich festgehalten und dadurch nie wieder
hinterfragt.

**Behebung:**
- Alle drei Builds auf `--pwa-strategy=none`. Unser `sw.js` übernimmt das
  Caching vollständig; Flutter braucht dafür keinen zweiten Worker.
- `index.html` löst vor der eigenen Registrierung eine eventuell vorhandene
  Registrierung von `flutter_service_worker.js` — einmalige Migration für
  Nutzer, die eine ältere Fassung geöffnet hatten. Bewusst nur diese eine.
- Kommentar korrigiert.

**Warum es online unsichtbar war:** Beide Worker liefern online aus dem Netz.
Der Konflikt zeigt sich ausschließlich, wenn der Cache tatsächlich gebraucht
wird — also im Offline-Fall und damit in der Windows-Distribution.

### App-Shell-Precache erweitert

`anatomy.html`, `cannulas.html` und `privacy.html` samt ihrer sechs Bilder
werden jetzt bei der Installation vorgeladen. Vorher landeten sie nur im
Cache, wenn sie jemand einmal geöffnet hatte — wer die App offline nahm, ohne
vorher die Anatomieseite besucht zu haben, bekam dort eine Fehlerseite.

### Hotfix v0.4.6 — Precache wird im CI generiert

**Symptom nach v0.4.5:** Der Worker-Konflikt war weg (kein
`flutter_service_worker.js` mehr in den Requests), `canvaskit.js` und
`canvaskit.wasm` kamen offline aus dem Cache — aber `main.dart.js` schlug mit
`ERR_FAILED` fehl (`sw.js:205`, der Entry-Point-Zweig). Ergebnis: Ladekreis,
dann weißer Bildschirm.

**Ursache — eine Folge der eigenen Cache-Invalidierung aus Block C:**

```
Deploy → neuer CACHE_NAME → install() legt einen LEEREN Cache an
       → füllt nur APP_SHELL
       → activate() löscht den alten Cache samt main.dart.js
       → der bereits geladene Tab fragt main.dart.js nicht erneut an
       → die Datei fehlt im neuen Cache → offline weiß
```

Runtime-Caching füllt einen frischen Cache eben nur mit dem, was **nach** der
Übernahme noch einmal angefragt wird. Solange der Cache-Name konstant war,
fiel das nicht auf. Die Kopplung an die Commit-SHA war richtig — sie hat nur
eine zweite Voraussetzung sichtbar gemacht: **wenn der Cache pro Deploy neu
ist, muss der Precache vollständig sein.**

**Behebung:** `sw.js` trennt jetzt `CORE_SHELL` (statisch, mit `?v=9`) von
`BUILD_ASSETS` (Platzhalter `const BUILD_ASSETS = [];`). Der CI-Schritt
erzeugt die Liste aus dem tatsächlichen Inhalt von `build/web` und ersetzt den
Platzhalter — analog zum `BUILD_ID`-Stamping und mit denselben zwei Riegeln:

- Abbruch, wenn kein `main.dart.*` oder `flutter_bootstrap.js` im Build liegt
  (halber Build → wertloser Precache)
- Abbruch, wenn die Ersetzung nicht greift

Ausgenommen sind `.map`-Dateien und alles, was schon mit `?v=9` in
`CORE_SHELL` steht. `APP_SHELL` ist die Vereinigung beider Listen über ein
`Set`, Doppel fallen weg.

**Nebeneffekt:** Der Precache umfasst jetzt den kompletten Build (~12 MB statt
~1 MB). Für eine App, die im OP ohne Netz funktionieren muss, ist das die
richtige Seite des Kompromisses — und es ist genau das, was Flutters eigene
`offline-first`-Strategie getan hätte, die wir in v0.4.5 abschalten mussten.

**Lehre:** Der Umbau in Block C hat zwei Dinge geändert, die zusammengehören —
Cache-Invalidierung und Precache-Umfang — aber nur eines davon wurde
angefasst. Offline war der einzige Testfall, der das aufgedeckt hätte, und der
stand in Stufe 6.

### v0.4.7 — Precache entschlackt

Der Release-Lauf v0.4.6 meldete `Precache: 49 Dateien, 45.5 MB`, während der
Offline-Betrieb tatsächlich nur 10,7 MB anforderte. Die Differenz waren
Dateien, die der Browser nie lädt:

- **`.symbols`** — Symboltabellen zum Entschlüsseln von Stacktraces. Flutter
  legt neben jede CanvasKit-Variante eine; zusammen der größte Posten. Beim
  Bau des Generators war `.map` ausgeschlossen, `.symbols` nicht.
- **`canvaskit/experimental_webparagraph/`** — experimentelle Renderer-
  Variante, wird nur mit gesetztem Flag geladen.

**Bewusst drin geblieben** sind die übrigen Renderer-Varianten (`canvaskit/`,
`canvaskit/chromium/`, `skwasm`, `skwasm_heavy`, `wimp`). Welche greift,
entscheidet erst der Browser zur Laufzeit — Offline-Robustheit über
verschiedene Browser hinweg wiegt hier schwerer als ein paar MB.

Zusätzlich gibt der Schritt jetzt die **fünf größten Einträge** aus. Damit ist
beim nächsten Lauf ohne Nachmessen sichtbar, wohin das Gewicht geht, falls
Flutter neue Varianten mitliefert.

Gegen einen nachgebauten Build-Baum (64 Dateien, 43,1 MB) geprüft: 44 Dateien
/ 21,2 MB im Precache, alle vier Entry Points erkannt, erzeugtes `sw.js` mit
`node --check` validiert.

**Warum das zählt:** Für die Windows-Distribution ist die Größe folgenlos,
dort liegt ohnehin alles lokal. Für die Web-PWA lädt jeder Besucher den
Precache bei **jedem** Deploy neu — der Cache-Name hängt an der Commit-SHA.
Auf einem Klinik-Tablet über Mobilfunk ist das der Unterschied.
