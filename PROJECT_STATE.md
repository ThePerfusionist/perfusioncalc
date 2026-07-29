# PerfusionCalc – Arbeitskontext

> Kompakter Projektstand als Arbeitsgedächtnis. **Zuerst lesen**, bevor
> Dateien durchsucht werden – erspart das erneute Ableiten von Struktur,
> Konventionen und Entscheidungen.
> Bei jeder Änderung mitpflegen.

**Stand:** v0.3.0+7 · 12 Tabs · 80 Unit-Tests · i18n 250/250 (EN+DE)

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
cd /home/claude/out && zip -rq /mnt/user-data/outputs/perfusioncalc_COMPLETE.zip . -x ".*"
```

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
**Sichtbar: Calafiore, Bretschneider.** Buckberg + del Nido sind ausgeblendet,
Code/Tests/Formeln bleiben vollständig erhalten → Reaktivierung = Eintrag in
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

### Intervall-Timer
Manuelle Stoppuhr, Zeitstempel in `PatientData.cardioplegiaLastDoseAt`.
Statuslogik ist **pure Funktion** `PatientData.cardioplegiaDoseStatus(elapsed, dueAfterMin, overdueAfterMin)`
→ deterministisch testbar. Schwellen: Calafiore 15/20 min, Bretschneider 150/180 min.
1-s-Ticker nur aktiv, wenn Zeitstempel gesetzt; in `dispose()` gecancelt.

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
  `com.perfusioncalc`, `versionCode` muss strikt steigen.
- St.-Thomas- und Eppendorf-Protokoll (in den Studienunterlagen ausgearbeitet).
- Perfusionsprotokoll mit Zeitstempeln (Bypass-/Klemmzeit, Temperaturverlauf).
- Heparin/Protamin + ACT-Rechner.
- Natives Share-Sheet (`share_plus`) – PDF kann aktuell nur gespeichert werden.
- Versionsnummer wird auf Zuruf angehoben (3 Stellen: `pubspec.yaml`,
  `kAppVersion` in `main.dart`, README-Badge).
