# Prüfwerkzeuge

Was hier liegt, prüft das, was `flutter analyze` und `flutter test` nicht
sehen können — und was in dieser Codebasis bereits schiefgegangen ist.

## Vollständiger Lauf (Windows)

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tool\verify\verify-all.ps1
```

Ruft der Reihe nach `flutter pub get`, `flutter analyze`, `flutter test`, die
Konsistenzprüfung und den Traversal-Test des Offline-Servers auf. Optionen:
`-SkipTests`, `-SkipServe`.

**Python unter Windows:** Das Skript probiert `py -3`, `python3` und `python`
und prüft jeden Kandidaten durch einen echten Programmlauf. `Get-Command`
allein genügt nicht — Windows legt unter
`%LOCALAPPDATA%\Microsoft\WindowsApps` App-Ausführungsaliase für `python.exe`
und `python3.exe` ab, die oft *vor* einer echten Installation im PATH stehen
und beim Aufruf nur den Microsoft Store öffnen (Exit 9009). Wenn das bei dir
passiert: *Einstellungen → Apps → Erweiterte App-Einstellungen →
App-Ausführungsaliase* → `python.exe` und `python3.exe` abschalten. Oder
schlicht `py -3` benutzen, der Launcher wird von den Aliassen nicht verdeckt.

## Die einzelnen Werkzeuge

### `tool/verify/consistency_check.py`

Sprachübergreifende Zusicherungen — Dart gegen YAML, Dart gegen JavaScript,
Code gegen Dokumentation. Dreizehn Prüfungen, jede davon steht für einen Fehler,
der in `PROJECT_STATE.md` § 7 dokumentiert ist:

| Prüfung | Verhinderter Fehler |
|---|---|
| Version an drei Stellen gleich | Auseinanderlaufen fällt sonst erst in der PDF-Fußzeile auf |
| Test-Badge = tatsächliche Anzahl | K-2: eine Zahl in der Doku, die nicht mitwächst |
| i18n vollständig, keine Waisen | im Code benutzter Schlüssel fehlt → Bug-Marker in der App |
| SW-Platzhalter ↔ `sed`-Muster der Workflows | 4.1 / N-2: reißt die Kopplung, läuft der Cache nie ab |
| `node --check web/sw.js` | Syntaxfehler in der Komponente, die offline alles trägt |
| Jeder PDF-Bauer im Gesamtbericht | B-1: ein Tab fehlt still im ausgelieferten Bericht |
| Keine Vorbelegung ungefiltert im PDF | C-1: Tab liegt jedem Bericht bei |
| `addListener` ↔ `removeListener` | Singleton hält zerstörte States am Leben |
| Keine Basistyp-Casts, kein `print()` | D-1: Laufzeitfehler statt Compilerfehler |
| Beide Datenschutzfassungen im Gleichstand | Block A: müssen zusammen geändert werden |
| CSP auf allen `web/*.html` | K-3: Seiten im harten Precache ohne Absicherung |
| Jede Abhängigkeit in der Data-Safety-SDK-Tabelle | ein neues Paket macht die Play-Angabe „keine Datenerhebung" unbemerkt falsch |
| Workflows: YAML + Shell-Syntax | ein kaputter `run`-Block fällt sonst erst im CI auf |

**Dokumentierte Ausnahmen:** Ein Fund lässt sich mit
`// verify:ok <Begründung>` in den acht Zeilen davor als bewusste Ausnahme
markieren. Die Prüfung bleibt streng, die Ausnahme steht am Ort und ist
begründet — statt die Regel aufzuweichen.

Läuft auch ohne Node und ohne PyYAML, überspringt dann die betreffenden
Prüfungen mit einer Warnung.

### `tool/verify/coverage_report.py`

```bash
flutter test --coverage
python3 tool/verify/coverage_report.py            # ungetestete Dateien zuerst
python3 tool/verify/coverage_report.py --min 60   # Exit 1 unterhalb der Schwelle
python3 tool/verify/coverage_report.py --all      # auch screens/ und widgets/
```

Blendet standardmäßig `lib/screens/`, `lib/widgets/` und `lib/theme/` aus —
die lassen sich sinnvoll nur mit Widget-Tests abdecken. Übrig bleibt der
Teil, der rechnet, und dort ist eine Lücke ein Befund.

Hintergrund: Bis v0.4.11 war `CardioplegiaSettings` die einzige der drei
persistierten Einstellungen ohne Tests. Gefunden wurde das beim Durchsehen,
nicht systematisch — eine Lücke, die man nicht sieht, schließt man nicht.

### `tool/offline/test-serve.ps1`

Startet `serve.ps1` in einer Sandbox und feuert siebzehn Anfragen dagegen:
erlaubte Pfade, neun Traversal-Varianten, zwei rohe TCP-Anfragen an der
Client-Normalisierung vorbei, zwei Fälle für fehlende Dateien.

**Das Prüfkriterium ist inhaltlich, nicht der Statuscode.** Die erste Fassung
erwartete für jeden Traversal ein 403 und meldete drei Fehlschläge, die
keine waren: `Invoke-WebRequest` normalisiert `..` in einer URL, *bevor* die
Anfrage den Server erreicht. Aus `/../geheim.txt` wird `/geheim.txt`, und
darauf antwortet der Server korrekt mit 404 — er hat nie einen Traversal
gesehen.

Genau deshalb sind die prozentkodierten Varianten die interessanten:
`%2e%2e%2f` überlebt jede Normalisierung und wird erst im Server durch
`UnescapeDataString` aufgelöst, dort wo `Get-SafePath` greift.

Geprüft wird daher: Der Inhalt der Datei außerhalb des Wurzelordners darf nie
in einer Antwort auftauchen. 403 (abgelehnt) und 404 (normalisiert
angekommen) sind beide in Ordnung; 200 mit dem Marker im Rumpf ist der
Befund. Die Zieldatei wird **absichtlich angelegt** — sonst sähe ein 404 wie
ein bestandener Test aus, obwohl der Server bereitwillig hinausgereicht
hätte.

Ersetzt die manuelle Gegenprobe, die vorher als Kommentar im Kopf von
`serve.ps1` stand.

## In der CI

`.github/workflows/checks.yml` läuft bei jedem Push und jedem Pull Request
auf `main`: `flutter analyze`, `flutter test`, dann die Konsistenzprüfung.
Bewusst getrennt von `deploy.yml`, damit die Prüfungen auch auf Branches und
in Forks laufen, ohne den Auslieferungspfad anzufassen.

Der Traversal-Test läuft dort **nicht** — er braucht Windows. Er gehört vor
jeden Bundle-Release, lokal.

## Was diese Werkzeuge nicht können

- **Klinische Richtigkeit.** Ob eine Formel stimmt, entscheidet die
  Primärliteratur. Die Unit-Tests sichern die Umsetzung gegen publizierte
  Referenzwerte, nicht die Wahl der Formel.
- **Rendering und Bedienung.** Ob eine Karte lesbar ist, ob eine
  Benachrichtigung feuert, ob der Screenreader den Banner vorliest — dafür
  braucht es ein Gerät.
- **Die Windows-Distribution im Einsatz.** Ob `caddy.exe` auf einem
  Klinik-PC startet oder von einer Richtlinie blockiert wird, zeigt sich
  erst dort.
